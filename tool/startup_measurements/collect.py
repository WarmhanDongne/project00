"""Local Debug-only VM-service collector. Python standard library; no server access.

Never persist adb serials, service URIs/auth codes, capture keys or raw logcat.
One invocation = one explicitly armed scenario/trial on all participating devices.
"""
import argparse
import hashlib
import http.client
from concurrent.futures import ThreadPoolExecutor
import json
import re
import secrets
import signal
import subprocess
import time
from datetime import datetime
import urllib.parse
from pathlib import Path

from measurement_analysis import MAX_CLOCK_WIDTH_US, analyze, clock_offset

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
submit_handler submit_result command_error session_blockers participant_count
startup_uncovered phone_waiting_for_deal tablet_deck_tappable_frame
tablet_deck_entry_started tablet_deck_entry_completed tablet_deck_tap_accepted
tablet_deal_started tablet_deal_animation_completed""".split())
FIELDS = {"schema", "capture", "trial", "scenario", "role", "process", "seq",
          "mono_us", "action", "event", "game", "value", "request", "command", "link", "source"}
HEX32 = re.compile(r"^[0-9a-f]{32}$")


def safe_error_code(error):
    """Fixed vocabulary only; HTTP/adb exception text may contain credentials."""
    known = {'measurement_protocol_requires_new_debug_build', 'clock_preflight_quality_failed',
             'event_sequence_gap', 'event_loss_or_process_replaced', 'event_process_mismatch',
             'app_process_replaced', 'measurement_control_already_armed',
             'measurement_control_invalid_configuration', 'measurement_control_rejected',
             'vm_service_error', 'vm_service_http_error', 'invalid_clock_reply'}
    if isinstance(error, RuntimeError) and str(error) in known:
        return str(error)
    if isinstance(error, KeyboardInterrupt):
        return 'keyboard_interrupt'
    if isinstance(error, TimeoutError):
        return 'local_transport_timeout'
    if isinstance(error, http.client.HTTPException):
        return 'local_http_connection_state'
    if isinstance(error, OSError):
        return 'local_transport_error'
    if isinstance(error, ValueError):
        return 'invalid_diagnostic_data'
    return 'collector_internal_error'


def finalize_devices(devices, drain, issues, diagnostics):
    """Stop every recorder independently, even if one transport is interrupted.

    stop is idempotent; a fresh HTTP connection makes its one retry safe. drain
    validates sequence/process as usual; a semantic failure is never retried or
    converted to a successful measurement. Repeated Ctrl+C cannot abort cleanup.
    """
    previous = signal.signal(signal.SIGINT, signal.SIG_IGN)
    success = True
    try:
        for device in devices:
            device.reset_http()
            for attempt in range(2):
                operation = 'stop'
                try:
                    device.control('stop')
                    operation = 'drain'
                    if drain is not None:
                        drain(device)
                    operation = 'final_clock'
                    device.probe()
                    break
                except Exception as error:
                    diagnostics.append({'phase': 'finalizing', 'role': device.role,
                                        'operation': operation, 'attempt': attempt + 1,
                                        'code': safe_error_code(error)})
                    device.reset_http()
                    if attempt == 0 and isinstance(error, (OSError, http.client.HTTPException)):
                        continue
                    issues.append('device_finalization_failed_' + device.role)
                    success = False
                    # Still try stop for later devices; do not abandon cleanup.
                    break
    finally:
        signal.signal(signal.SIGINT, previous)
    return success


def validate_event(event, role, capture, trial):
    if not isinstance(event, dict) or set(event) - FIELDS:
        raise ValueError("unexpected_event_fields")
    if (event.get("schema") != 2 or event.get("event") not in EVENTS
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
    if "source" in event and event["source"] not in SCENARIOS:
        raise ValueError("invalid_action_source")
    return event


class Device:
    def __init__(self, adb, role, serial):
        self.adb, self.role, self.serial = adb, role, serial
        self.port = None
        self.uri = None
        self.isolate = None
        self.after = 0
        self.process = None
        self.probes = []
        self.http = None

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
        self.http = http.client.HTTPConnection("127.0.0.1", self.port, timeout=8)
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
        # Persistent direct loopback HTTP; no ambient proxy, no saved auth URI.
        parsed = urllib.parse.urlsplit(request)
        if self.http is None:
            self.http = http.client.HTTPConnection('127.0.0.1', self.port, timeout=8)
        try:
            self.http.request("GET", parsed.path + ("?" + parsed.query if parsed.query else ""))
            response = self.http.getresponse()
            body = response.read()
            if response.status != 200:
                raise RuntimeError("vm_service_http_error")
            envelope = json.loads(body)
            if "error" in envelope:
                raise RuntimeError("vm_service_error")
            return envelope["result"]
        except BaseException:
            # Ctrl+C can interrupt request(), getresponse(), or read(). The HTTP
            # state machine is then unusable, even though the socket still exists.
            self.reset_http()
            raise

    def reset_http(self):
        connection, self.http = self.http, None
        if connection is not None:
            try:
                connection.close()
            except Exception:
                pass

    def control(self, op, **args):
        result = self.rpc("ext.mosigame.startup", isolateId=self.isolate, op=op, **args)
        if "error" in result:
            if result['error'] in {'already_armed', 'invalid_configuration'}:
                raise RuntimeError('measurement_control_' + result['error'])
            raise RuntimeError("measurement_control_rejected")
        return result

    def probe(self):
        h0 = time.monotonic_ns() // 1000
        reply = self.control("clock")
        h1 = time.monotonic_ns() // 1000
        if reply.get("protocol") != 2:
            raise RuntimeError("measurement_protocol_requires_new_debug_build")
        if (not re.fullmatch(r"[0-9a-f]{12}", reply.get("process", ""))
                or type(reply.get("mono_us")) is not int or reply["mono_us"] < 0):
            raise RuntimeError("invalid_clock_reply")
        if self.process is not None and self.process != reply["process"]:
            raise RuntimeError("app_process_replaced")
        self.process = reply["process"]
        self.probes.append({"h0": h0, "h1": h1,
                            "process": reply["process"], "mono_us": reply["mono_us"]})

    def close(self):
        self.reset_http()
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
             "- 태블릿·선공 폰의 자동 작업이 모두 관측상 없고 사용자 탭을 기다리는 구간만 제외한다.", "",
             "## 수집·판정 문제", ""]
    lines += [f"- {issue}" for issue in summary["issues"]] or ["없음"]
    lines += ["", f"- 실제 조작: {summary['actual_scenario']}",
              f"- 시계 품질 기준: 추정 범위 폭 {summary['quality_limit_us']/1000:.0f}ms 이하",
              f"- 예비 검증 실제 선택·제출: {summary['progress']['input_validation']}"]
    lines += [f"- 참고: {warning}" for warning in summary["warnings"]]
    for diagnostic in summary.get('collector_diagnostics', []):
        lines.append(f"- 수집기 진단: {json.dumps(diagnostic, ensure_ascii=False)}")
    lines += ["", "## 같은 기기의 관측 구간", "", "| 기기 | 시작 → 종료 | 소요(ms) |",
              "| --- | --- | ---: |"]
    for stage in summary["local_milestones"]:
        lines.append(f"| {stage['role']} | {stage['from']} → {stage['to']} | {stage['elapsed_us']/1000:.3f} |")
    lines += ["", "연출·요청은 병행할 수 있다. 위 구간을 합산해 전체 시간으로 사용하지 않는다.",
              "", "## 논리 명령", "", "| 기기 | 함수 | 요청 | 소요(ms) | 결과 |",
              "| --- | --- | ---: | ---: | --- |"]
    for call in summary["logical_command_totals"]:
        duration = str(round(call["elapsed_us"]/1000, 3)) if "elapsed_us" in call else "미완료"
        outcome = {1: '성공', 2: '실패 반환', 3: '예외'}.get(call.get('outcome'), '미완료')
        lines.append(f"| {call['role']} | {call.get('command', '미확정')} | {call['request']} | {duration} | {outcome} |")
    lines += ["", "세부 단계·요청별 전송 시도·대기 분류는 summary.json과 events.sanitized.jsonl에 보존한다.", ""]
    (out / "REPORT.md").write_text("\n".join(lines), encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", default="adb")
    parser.add_argument("--device", action="append", required=True, help="role=adb-serial (not saved)")
    parser.add_argument("--scenario", choices=sorted(SCENARIOS), required=True)
    parser.add_argument("--condition", choices=["first_after_launch", "repeated", "unspecified"], default="unspecified")
    parser.add_argument("--pilot", action="store_true", help="Require real selection and successful submission after completion")
    parser.add_argument("--duration", type=int, default=180)
    parser.add_argument("--output-parent", type=Path, default=Path("artifacts/performance-captures"))
    args = parser.parse_args()
    if not 10 <= args.duration <= 1800:
        parser.error("duration must be 10..1800 seconds")
    devices = []
    for item in args.device:
        role, separator, serial = item.partition("=")
        if not separator or role not in ROLES or any(d.role == role or d.serial == serial for d in devices) or not serial:
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
    failure_phase = "connecting"
    last_progress = None
    finalized = False
    diagnostics = []
    stop_reason = 'not_started'

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
        def connect_and_calibrate(device):
            device.connect()
            for _ in range(5):
                device.probe()
        with ThreadPoolExecutor(max_workers=len(devices)) as pool:
            list(pool.map(connect_and_calibrate, devices))
        failure_phase = "clock_preflight"
        offsets = [clock_offset(d.probes) for d in devices]
        if any(o is None for o in offsets) or 2 * max(o[1] - o[0] for o in offsets) > MAX_CLOCK_WIDTH_US:
            raise RuntimeError("clock_preflight_quality_failed")
        failure_phase = 'arming'
        for device in devices:
            device.control("arm", capture=capture, trial=trial, role=device.role, scenario=args.scenario, key=key)
            armed.append(device)
        failure_phase = "collecting"
        print("COLLECTING: all devices armed. Perform one start/restart only.", flush=True)
        print(f"Stop by creating {out / 'stop.request'} or press Ctrl+C.", flush=True)
        deadline, next_probe = time.monotonic() + args.duration, time.monotonic()
        with (out / "events.sanitized.jsonl").open("x", encoding="utf-8") as stream:
            try:
                while time.monotonic() < deadline and not (out / "stop.request").exists():
                    for device in devices:
                        drain(device, stream)
                    if time.monotonic() >= next_probe:
                        def sample_clock(device):
                            for _ in range(2):
                                device.probe()
                        with ThreadPoolExecutor(max_workers=len(devices)) as pool:
                            list(pool.map(sample_clock, devices))
                        next_probe = time.monotonic() + 2
                    current = analyze(events, {d.role: d.probes for d in devices}, [])
                    progress = (current["status"], current["actual_scenario"],
                                current["progress"], current["user_wait_excluded_total_estimated_range_us"] is not None)
                    if progress != last_progress:
                        print("PROGRESS:", json.dumps({"status": progress[0], "actual_scenario": progress[1],
                              **progress[2], "wait_exclusion_measured": progress[3]}, ensure_ascii=False), flush=True)
                        last_progress = progress
                    time.sleep(0.2)
                stop_reason = 'stop_request' if (out / 'stop.request').exists() else 'duration'
            except KeyboardInterrupt:
                stop_reason = 'keyboard_interrupt'
            finally:
                cleanup_ok = finalize_devices(armed, lambda d: drain(d, stream), issues, diagnostics)
                finalized = True
        status = 'COLLECTED' if cleanup_ok else 'FAILED'
    except KeyboardInterrupt:
        issues.extend(['collector_interrupted_before_ready', 'failed_phase_' + failure_phase])
        stop_reason = 'keyboard_interrupt_before_ready'
    except Exception as error:
        code = safe_error_code(error)
        diagnostics.append({'phase': failure_phase, 'code': code})
        issues.append(code)
        issues.append("failed_phase_" + failure_phase)
        # Exception messages from HTTP/adb can contain URI tokens or device IDs.
        issues.append("collector_failed_or_incomplete")
        print("Collection incomplete. No raw exception or credentials stored.", flush=True)
    finally:
        if armed and not finalized:
            finalize_devices(armed, None, issues, diagnostics)
        for device in devices:
            try:
                device.close()
            except Exception:
                issues.append("forward_cleanup_failed")
        clocks = {d.role: d.probes for d in devices}
        summary = analyze(events, clocks, issues)
        summary['collector_diagnostics'] = diagnostics
        summary['stop_reason'] = stop_reason
        summary["pilot_requested"] = args.pilot
        summary["pilot_passed"] = (summary["status"] == "VALID_OBSERVED_TRIAL"
            and summary["user_wait_excluded_total_estimated_range_us"] is not None
            and all(summary["progress"]["input_validation"].values())) if args.pilot else None
        (out / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
        write_report(out, summary)
        manifest = {"protocol": 2, "quality_limit_us": MAX_CLOCK_WIDTH_US, "pilot": args.pilot, "capture": capture, "scenario": args.scenario, "status": status,
                    'stop_reason': stop_reason, 'collector_diagnostics': diagnostics,
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
                   "tool/startup_measurements/collect.py",
                   "tool/startup_measurements/measurement_analysis.py",
                   "packages/game_kit/lib/tablet/animations/card_deal_animation.dart"]
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
    return 0 if status == "COLLECTED" and summary["status"] == "VALID_OBSERVED_TRIAL" and (not args.pilot or summary["pilot_passed"]) else 1


if __name__ == "__main__":
    raise SystemExit(main())
