"""Local Debug-only VM-service collector. Python standard library; no server access.

Never persist adb serials, service URIs/auth codes, capture keys or raw logcat.
One invocation = one explicitly armed scenario/trial on all participating devices.
"""
import argparse
import hashlib
import json
import re
import secrets
import subprocess
import time
from datetime import datetime
import urllib.parse
import urllib.request
from pathlib import Path

ROLES = {"tablet", "phone_A", "phone_B", "phone_C", "phone_D", "phone_E", "phone_F"}
SCENARIOS = {"initial_start", "menu_restart", "result_restart"}
EVENTS = set("""armed capture_stopped action_accepted action_rejected game_bound
game_replaced command_start command_end request_link attempt_start attempt_end
pending_commands foreground seating_prepare_start seating_prepare_end seat_save_start
seat_save_end public_received public_applied private_received private_applied
assets_start assets_end screen_ready session_can_send tablet_gate tablet_playing_frame
tablet_stage tablet_deal_completed tablet_round_reveal_completed phone_stage
pack_entry_started pack_tappable_frame pack_tap_accepted reveal_completed
controls_started controls_completed phone_game_intro_completed phone_gate hand_gate
phone_hand_selectable_frame phone_first_turn_playable_frame card_selection_handler
submit_handler""".split())
FIELDS = {"schema", "capture", "trial", "scenario", "role", "process", "seq",
          "mono_us", "action", "event", "game", "value", "request", "command", "link"}
TOKEN = re.compile(r"^[A-Za-z0-9_-]{1,64}$")
HEX32 = re.compile(r"^[0-9a-f]{32}$")


def validate_event(event, role, capture, trial):
    if not isinstance(event, dict) or set(event) - FIELDS:
        raise ValueError("unexpected_event_fields")
    if (event.get("schema") != 1 or event.get("event") not in EVENTS
            or event.get("role") != role or event.get("capture") != capture
            or event.get("trial") != trial or event.get("scenario") not in SCENARIOS):
        raise ValueError("unexpected_event_identity")
    if not re.fullmatch(r"[0-9a-f]{12}", event.get("process", "")):
        raise ValueError("invalid_process_alias")
    for key in ("seq", "mono_us", "action"):
        if type(event.get(key)) is not int or event[key] < 0:
            raise ValueError("invalid_event_number")
    for key in ("value", "request"):
        if key in event and type(event[key]) is not int:
            raise ValueError("invalid_optional_number")
    for key in ("game", "link"):
        if event.get(key) is not None and not HEX32.fullmatch(event[key]):
            raise ValueError("invalid_alias")
    if "command" in event and not re.fullmatch(r"game_liars_poker_[a-z_]{1,48}", event["command"]):
        raise ValueError("invalid_command")
    return event


def clock_offset(probes):
    """Estimated interval, with explicit 200 ppm drift allowance + 5ms margin.

    Not a hardware-guaranteed bound. Reject incompatible calibrations rather than
    inventing exact cross-device latency. Returned interval is deliberately wide.
    """
    if len(probes) < 2:
        return None
    if len({p["process"] for p in probes}) != 1:
        return None
    span = max(p["h1"] for p in probes) - min(p["h0"] for p in probes)
    margin = 5000 + int(span * 0.0002)
    low = max(p["h0"] - p["mono_us"] for p in probes) - margin
    high = min(p["h1"] - p["mono_us"] for p in probes) + margin
    if low > high:
        return None
    return [low, high]


def exclusive_wait_segments(local):
    """Only observed intervals with no known concurrent local blocker.

    The caller additionally clips to tablet-ready, so parallel tablet startup
    never gets subtracted. Missing gate state invalidates the adjusted metric.
    """
    states = {}
    prompt = False
    previous = None
    segments, unknown = [], False
    for e in local:
        if prompt and previous is not None:
            needed = {"phone_gate", "pending_commands", "session_can_send", "foreground"}
            if not needed.issubset(states):
                unknown = True
            elif (states["phone_gate"] & 8 and states["pending_commands"] == 0
                  and states["session_can_send"] == 1 and states["foreground"] == 1):
                if e["mono_us"] > previous:
                    segments.append([previous, e["mono_us"]])
        if e["event"] in {"phone_gate", "pending_commands", "session_can_send", "foreground"}:
            states[e["event"]] = e["value"]
        if e["event"] == "pack_tappable_frame":
            prompt = True
        elif e["event"] == "pack_tap_accepted":
            prompt = False
        previous = e["mono_us"]
    return segments, unknown or prompt


def analyze(events, clocks, issues):
    """Retain incomplete trials; never substitute zero or population medians."""
    issues = list(issues)
    starts = [e for e in events if e["event"] == "action_accepted"]
    games = {e["game"] for e in events if e["event"] == "game_bound"}
    if len(starts) != 1:
        issues.append("expected_one_action")
    if len(games) != 1:
        issues.append("unmatched_or_multiple_games")
    if any(e["event"] in {"game_replaced", "action_rejected"}
           or (e["event"] == "foreground" and e.get("value") == 0) for e in events):
        issues.append("action_or_lifecycle_interrupted")
    target = next(iter(games)) if len(games) == 1 else None
    tablet = [e for e in events if e["event"] == "tablet_playing_frame" and e["game"] == target]
    phone = [e for e in events if e["event"] == "phone_first_turn_playable_frame" and e["game"] == target]
    if len(tablet) != 1 or len(phone) != 1:
        issues.append("missing_or_ambiguous_completion")
    if len(phone) == 1:
        actor, end = phone[0]["role"], phone[0]["mono_us"]
        prompt_times = [e["mono_us"] for e in events
                        if e["role"] == actor and e["event"] == "pack_tappable_frame"]
        if prompt_times and any(e["role"] == actor and e["event"] == "session_can_send"
                                and e.get("value") == 0 and min(prompt_times) <= e["mono_us"] < end
                                for e in events):
            issues.append("recovery_during_phone_startup")
    offsets = {role: clock_offset(p) for role, p in clocks.items()}

    def host_range(e):
        probes = clocks.get(e["role"], [])
        if offsets.get(e["role"]) is None:
            return None
        near = sorted(probes, key=lambda p: abs(p["mono_us"] - e["mono_us"]))[:3]
        lows, highs = [], []
        for p in near:
            margin = 5000 + int(abs(p["mono_us"] - e["mono_us"]) * 0.0002)
            lows.append(e["mono_us"] + p["h0"] - p["mono_us"] - margin)
            highs.append(e["mono_us"] + p["h1"] - p["mono_us"] + margin)
        return [max(lows), min(highs)] if max(lows) <= min(highs) else None

    total = None
    if not issues and len(starts) == len(tablet) == len(phone) == 1:
        start, t_end, p_end = map(host_range, (starts[0], tablet[0], phone[0]))
        if start and t_end and p_end:
            total = [max(t_end[0], p_end[0]) - start[1], max(t_end[1], p_end[1]) - start[0]]
            if total[0] < 0 or total[1] - total[0] > 100000:
                issues.append("cross_device_clock_quality_failed")
                total = None
        else:
            issues.append("cross_device_clock_unavailable")
    calls = []
    attempts = []
    waits = []
    for role in clocks:
        local = sorted((e for e in events if e["role"] == role), key=lambda e: e["seq"])
        pending = {}
        pending_attempts = {}
        prompt = None
        for e in local:
            if e["event"] == "command_start":
                pending[e["request"]] = e
            elif e["event"] == "command_end":
                begin = pending.pop(e["request"], None)
                if begin:
                    calls.append({"role": role, "request": e["request"], "command": begin["command"],
                                  "elapsed_us": e["mono_us"] - begin["mono_us"], "outcome": e.get("value")})
            elif e["event"] == "attempt_start":
                pending_attempts[e["request"]] = e
            elif e["event"] == "attempt_end":
                begin = pending_attempts.pop(e["request"], None)
                if begin:
                    attempts.append({"role": role, "request": e["request"], "attempt": begin["value"],
                                     "elapsed_us": e["mono_us"] - begin["mono_us"], "outcome": e.get("value")})
            elif e["event"] == "pack_tappable_frame":
                prompt = e
            elif e["event"] == "pack_tap_accepted" and prompt:
                waits.append({"role": role, "elapsed_us": e["mono_us"] - prompt["mono_us"],
                              "classification": "prompt_wait_including_possible_parallel_work"})
                prompt = None
        for request in pending:
            calls.append({"role": role, "request": request, "status": "INCOMPLETE"})
        if prompt:
            waits.append({"role": role, "status": "NOT_TAPPED"})
    adjusted = None
    exclusive = None
    adjusted_reason = "Incomplete trial, missing gates, or clock quality failure"
    if total is not None and len(phone) == 1:
        actor = phone[0]["role"]
        local = sorted((e for e in events if e["role"] == actor
                        and e["mono_us"] <= phone[0]["mono_us"]), key=lambda e: e["seq"])
        segments, unknown = exclusive_wait_segments(local)
        offset, t_end = offsets[actor], host_range(tablet[0])
        if offset and t_end and not unknown:
            exclusive = [0, 0]
            for begin, end in segments:
                if begin + offset[0] >= t_end[1]:
                    exclusive[0] += end - begin
                    exclusive[1] += end - begin
                    continue
                lower_start = max(begin + offset[0], t_end[0])
                upper_start = max(begin + offset[1], t_end[1])
                exclusive[0] += max(0, end + offset[0] - upper_start)
                exclusive[1] += max(0, end + offset[1] - lower_start)
            adjusted = [total[0] - exclusive[1], total[1] - exclusive[0]]
            if adjusted[0] < 0:
                adjusted = None
                adjusted_reason = "Inconsistent subtraction bounds"
            else:
                adjusted_reason = "Observed user-only wait after tablet readiness excluded; not CPU time or a simulated instant-tap run"
    return {"status": "VALID_OBSERVED_TRIAL" if not issues and total else "INCOMPLETE_OR_INVALID",
            "issues": sorted(set(issues)), "total_elapsed_estimated_range_us": total,
            "clock_offset_estimates_us": offsets, "logical_command_totals": calls,
            "transport_attempt_round_trips": attempts, "card_pack_waits": waits,
            "exclusive_user_wait_estimated_range_us": exclusive,
            "user_wait_excluded_total_estimated_range_us": adjusted,
            "user_wait_excluded_reason": adjusted_reason,
            "clock_assumptions": "200ppm drift allowance, 5ms margin per device; estimated, not certified physical timing"}


class Device:
    def __init__(self, adb, role, serial):
        self.adb, self.role, self.serial = adb, role, serial
        self.port = None
        self.uri = None
        self.isolate = None
        self.after = 0
        self.process = None
        self.probes = []

    def shell_adb(self, *args):
        return subprocess.run([self.adb, "-s", self.serial, *args], check=True,
                              capture_output=True, timeout=15).stdout.decode("utf-8", "replace")

    def connect(self):
        # URI/auth token only exists in memory. Never print exceptions with URLs.
        raw = self.shell_adb("logcat", "-d", "-v", "raw", "-s", "flutter:I")
        found = re.findall(r"(?:Dart VM service is listening on|Observatory listening on)\s+(http://[^\s]+)", raw)
        if not found:
            raise RuntimeError("debug_service_not_found")
        remote = urllib.parse.urlsplit(found[-1].rstrip(".,"))
        if remote.hostname not in {"127.0.0.1", "localhost", "::1"} or not remote.port:
            raise RuntimeError("unexpected_service_address")
        self.port = int(self.shell_adb("forward", "tcp:0", f"tcp:{remote.port}").strip())
        self.uri = f"http://127.0.0.1:{self.port}{remote.path.rstrip('/')}/"
        vm = self.rpc("getVM")
        for isolate in vm["isolates"]:
            info = self.rpc("getIsolate", isolateId=isolate["id"])
            if "ext.mosigame.startup" in info.get("extensionRPCs", []):
                self.isolate = isolate["id"]
                return
        raise RuntimeError("measurement_extension_not_enabled")

    def rpc(self, method, **args):
        query = urllib.parse.urlencode(args)
        request = self.uri + method + ("?" + query if query else "")
        # Disable ambient proxies for the authenticated local service connection.
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        with opener.open(request, timeout=8) as response:
            envelope = json.load(response)
        if "error" in envelope:
            raise RuntimeError("vm_service_error")
        return envelope["result"]

    def control(self, op, **args):
        result = self.rpc("ext.mosigame.startup", isolateId=self.isolate, op=op, **args)
        if "error" in result:
            raise RuntimeError("measurement_control_rejected")
        return result

    def probe(self):
        h0 = time.monotonic_ns() // 1000
        reply = self.control("clock")
        h1 = time.monotonic_ns() // 1000
        if (not re.fullmatch(r"[0-9a-f]{12}", reply.get("process", ""))
                or type(reply.get("mono_us")) is not int or reply["mono_us"] < 0):
            raise RuntimeError("invalid_clock_reply")
        if self.process is not None and self.process != reply["process"]:
            raise RuntimeError("app_process_replaced")
        self.process = reply["process"]
        self.probes.append({"h0": h0, "h1": h1,
                            "process": reply["process"], "mono_us": reply["mono_us"]})

    def close(self):
        if self.port:
            self.shell_adb("forward", "--remove", f"tcp:{self.port}")


def write_report(out, summary):
    def seconds(bounds):
        return "미측정" if bounds is None else f"{bounds[0]/1e6:.3f}~{bounds[1]/1e6:.3f}초"
    lines = ["# Debug 게임 시작·재시작 측정", "", f"판정: {summary['status']}", "",
             f"- 전체 준비 완료: {seconds(summary['total_elapsed_estimated_range_us'])}",
             f"- 사용자 단독 대기 제외: {seconds(summary['user_wait_excluded_total_estimated_range_us'])}",
             "- 기기 간 시간은 시계 교환·드리프트 가정을 적용한 추정 범위다. Release 성능으로 사용하지 않는다.",
             "- 논리 명령 시간에는 사전 준비·재시도·정리가 포함된다. 실제 전송 시도 왕복은 별도로 확인한다.",
             "- 사용자 대기는 첫 턴 폰의 관측 구간 중 동시 작업·태블릿 준비와 겹치지 않는 구간만 제외한다.", "",
             "## 수집·판정 문제", ""]
    lines += [f"- {issue}" for issue in summary["issues"]] or ["없음"]
    lines += ["", "## 논리 명령", "", "| 기기 | 함수 | 요청 | 소요(ms) / 상태 |",
              "| --- | --- | ---: | ---: |"]
    for call in summary["logical_command_totals"]:
        duration = str(round(call["elapsed_us"]/1000, 3)) if "elapsed_us" in call else "미완료"
        lines.append(f"| {call['role']} | {call.get('command', '미확정')} | {call['request']} | {duration} |")
    lines += ["", "세부 단계·요청별 전송 시도·대기 분류는 summary.json과 events.sanitized.jsonl에 보존한다.", ""]
    (out / "REPORT.md").write_text("\n".join(lines), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", default="adb")
    parser.add_argument("--device", action="append", required=True, help="role=adb-serial (not saved)")
    parser.add_argument("--scenario", choices=sorted(SCENARIOS), required=True)
    parser.add_argument("--condition", choices=["first_after_launch", "repeated", "unspecified"], default="unspecified")
    parser.add_argument("--duration", type=int, default=180)
    parser.add_argument("--output-parent", type=Path, default=Path("artifacts/performance-captures"))
    args = parser.parse_args()
    if not 10 <= args.duration <= 1800:
        parser.error("duration must be 10..1800 seconds")
    devices = []
    for item in args.device:
        role, separator, serial = item.partition("=")
        if not separator or role not in ROLES or any(d.role == role for d in devices) or not serial:
            parser.error("unique allowed roles required")
        devices.append(Device(args.adb, role, serial))
    if "tablet" not in {d.role for d in devices} or len(devices) < 2:
        parser.error("tablet and all participating phones required")
    capture = "debug-game-start-" + time.strftime("%Y%m%d-%H%M%S") + "-" + secrets.token_hex(4)
    out = args.output_parent / capture
    out.mkdir(parents=True, exist_ok=False)
    trial, key = "trial-1", secrets.token_hex(32)
    started_at = datetime.now().astimezone().isoformat()
    events, issues, armed = [], [], []
    status = "FAILED"

    def drain(device, stream):
        while True:
            reply = device.control("drain", after=device.after)
            if reply["process"] != device.process or reply["dropped"]:
                raise RuntimeError("event_loss_or_process_replaced")
            batch = reply["events"]
            for raw in batch:
                e = validate_event(raw, device.role, capture, trial)
                if e["scenario"] != args.scenario or e["seq"] != device.after + 1:
                    raise RuntimeError("event_sequence_gap")
                if e["process"] != device.process:
                    raise RuntimeError("event_process_mismatch")
                events.append(e)
                stream.write(json.dumps(e, separators=(",", ":")) + "\n")
                device.after = e["seq"]
            stream.flush()
            if device.after >= reply["last_seq"]:
                return

    try:
        for device in devices:
            device.connect()
            for _ in range(3):
                device.probe()
        for device in devices:
            device.control("arm", capture=capture, trial=trial, role=device.role, scenario=args.scenario, key=key)
            armed.append(device)
        print("COLLECTING: all devices armed. Perform one start/restart only.", flush=True)
        print(f"Stop by creating {out / 'stop.request'} or press Ctrl+C.", flush=True)
        deadline, next_probe = time.monotonic() + args.duration, time.monotonic()
        with (out / "events.sanitized.jsonl").open("x", encoding="utf-8") as stream:
            try:
                while time.monotonic() < deadline and not (out / "stop.request").exists():
                    for device in devices:
                        drain(device, stream)
                    if time.monotonic() >= next_probe:
                        for device in devices:
                            device.probe()
                        next_probe = time.monotonic() + 3
                    time.sleep(0.2)
            except KeyboardInterrupt:
                pass
            finally:
                for device in armed:
                    device.control("stop")
                    drain(device, stream)
                    device.probe()
        status = "COLLECTED"
    except Exception:
        # Exception messages from HTTP/adb can contain URI tokens or device IDs.
        issues.append("collector_failed_or_incomplete")
        print("Collection incomplete. No raw exception or credentials stored.", flush=True)
    finally:
        for device in armed:
            try:
                device.control("stop")
            except Exception:
                pass
        for device in devices:
            try:
                device.close()
            except Exception:
                issues.append("forward_cleanup_failed")
        clocks = {d.role: d.probes for d in devices}
        summary = analyze(events, clocks, issues)
        (out / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
        write_report(out, summary)
        manifest = {"capture": capture, "scenario": args.scenario, "status": status,
                    "condition": args.condition,
                    "started_at": started_at,
                    "roles": [d.role for d in devices], "events": len(events),
                    "clocks": clocks, "privacy": "No service URIs, keys, serials, identifiers, raw logs or payloads"}
        repo = Path(__file__).resolve().parents[2]
        sources = ["lib/main.dart", "lib/platform/home/tablet/tablet_game_start.dart",
                   "packages/game_kit/lib/core/diagnostics/startup_measurements.dart",
                   "packages/game_kit/lib/phone/animations/card_receive_animation.dart",
                   "packages/game_kit/lib/player_layouts/widgets/player_layout_editor.dart",
                   "packages/game_kit/lib/recovery/providers/game_session_controller.dart",
                   "packages/game_kit/lib/services/game_command_service.dart",
                   "packages/game_kit/lib/tablet/widgets/game_settings_dialog.dart",
                   "packages/game_liars_poker/lib/phone/screens/game_screen.dart",
                   "packages/game_liars_poker/lib/phone/widgets/hand_card_stack.dart",
                   "packages/game_liars_poker/lib/shared/providers/game_controller.dart",
                   "packages/game_liars_poker/lib/tablet/src/board_state.dart",
                   "tool/startup_measurements/collect.py"]
        manifest["working_copy_sources_sha256"] = {
            name: hashlib.sha256((repo / name).read_bytes()).hexdigest()
            for name in sources if (repo / name).is_file()}
        manifest["source_note"] = "Collector working copy snapshot; not an attestation of the installed APK"
        manifest["working_copy_head"] = None
        try:
            head = subprocess.run(["git", "-C", str(repo), "rev-parse", "HEAD"],
                                  capture_output=True, timeout=5, check=True).stdout.decode().strip()
            if re.fullmatch(r"[0-9a-f]{40}", head):
                manifest["working_copy_head"] = head
        except Exception:
            pass
        (out / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
        hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in out.iterdir() if p.is_file()}
        (out / "integrity.json").write_text(json.dumps(hashes, indent=2), encoding="utf-8")
    print(f"{status}: {out}", flush=True)
    return 0 if status == "COLLECTED" and summary["status"] == "VALID_OBSERVED_TRIAL" else 1


if __name__ == "__main__":
    raise SystemExit(main())
