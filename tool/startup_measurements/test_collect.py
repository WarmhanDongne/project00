import copy
import json
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit

from collect import Device, analyze, clock_offset, exclusive_wait_segments, validate_event


class CollectorTests(unittest.TestCase):
    def test_vm_http_extension_protocol_without_exposing_auth_uri(self):
        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                parsed = urlsplit(self.path)
                if parsed.path.endswith("getVM"):
                    result = {"isolates": [{"id": "isolates/1"}]}
                elif parsed.path.endswith("getIsolate"):
                    result = {"extensionRPCs": ["ext.mosigame.startup"]}
                else:
                    self.server.last_op = parse_qs(parsed.query).get("op", [None])[0]
                    result = {"process": "a" * 12, "mono_us": 12345}
                body = json.dumps({"result": result}).encode()
                self.send_response(200)
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, *_):
                pass

        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        device = Device("adb", "tablet", "never-persist-serial")
        def adb(*args):
            if args[0] == "logcat":
                return f"The Dart VM service is listening on http://127.0.0.1:{server.server_port}/never-persist-token/"
            return str(server.server_port)
        device.shell_adb = adb
        try:
            device.connect()
            device.probe()
            self.assertEqual(server.last_op, "clock")
            self.assertEqual(device.probes[0]["mono_us"], 12345)
            self.assertNotIn("never-persist", json.dumps(device.probes))
        finally:
            device.close()
            server.shutdown()
            server.server_close()
            thread.join()

    def row(self, role, event, t, **extra):
        return dict(schema=1, capture="test", trial="one", scenario="initial_start",
                    role=role, process="a" * 12, seq=t + 1, mono_us=t, action=1,
                    event=event, game="b" * 32, **extra)

    def clocks(self):
        return {r: [dict(h0=t, h1=t + 100, mono_us=t, process="a" * 12)
                    for t in (0, 12000000)] for r in ("tablet", "phone_A")}

    def fixture(self):
        return [self.row("tablet", "action_accepted", 0),
                self.row("tablet", "game_bound", 100),
                self.row("phone_A", "game_bound", 200),
                self.row("tablet", "tablet_playing_frame", 4000000),
                self.row("phone_A", "foreground", 1000, value=1),
                self.row("phone_A", "pending_commands", 2000, value=0),
                self.row("phone_A", "session_can_send", 3000, value=1),
                self.row("phone_A", "phone_gate", 4000, value=12),
                self.row("phone_A", "pack_tappable_frame", 5000000),
                self.row("phone_A", "pack_tap_accepted", 10000000),
                self.row("phone_A", "phone_first_turn_playable_frame", 12000000)]

    def test_schema_rejects_private_fields_and_bad_aliases(self):
        row = self.row("tablet", "action_accepted", 0)
        validate_event(row, "tablet", "test", "one")
        for bad in ({**row, "payload": "secret"}, {**row, "game": "actual-room"}):
            with self.assertRaises(ValueError):
                validate_event(bad, "tablet", "test", "one")

    def test_clock_process_replacement_and_incompatible_probes_rejected(self):
        probes = self.clocks()["tablet"]
        self.assertIsNotNone(clock_offset(probes))
        other = copy.deepcopy(probes)
        other[1]["process"] = "b" * 12
        self.assertIsNone(clock_offset(other))
        other = copy.deepcopy(probes)
        other[1]["mono_us"] += 1000000
        self.assertIsNone(clock_offset(other))

    def test_twelve_seconds_with_five_second_user_wait_is_seven_seconds(self):
        result = analyze(self.fixture(), self.clocks(), [])
        self.assertEqual(result["status"], "VALID_OBSERVED_TRIAL")
        low, high = result["total_elapsed_estimated_range_us"]
        self.assertLess(low, 12000000)
        self.assertGreater(high, 12000000)
        self.assertEqual(result["exclusive_user_wait_estimated_range_us"], [5000000, 5000000])
        low, high = result["user_wait_excluded_total_estimated_range_us"]
        self.assertLess(low, 7000000)
        self.assertGreater(high, 7000000)

    def test_parallel_tablet_work_not_removed_as_user_wait(self):
        rows = self.fixture()
        for e in rows:
            if e["event"] == "tablet_playing_frame":
                e["mono_us"] = 8000000
        result = analyze(rows, self.clocks(), [])
        low, high = result["exclusive_user_wait_estimated_range_us"]
        self.assertLess(low, 2000000)
        self.assertGreater(high, 2000000)

    def test_parallel_phone_commands_and_unknown_gates_not_subtracted(self):
        local = [self.row("phone_A", "pack_tappable_frame", 0),
                 self.row("phone_A", "pack_tap_accepted", 5000000)]
        self.assertTrue(exclusive_wait_segments(local)[1])
        rows = self.fixture()
        rows.extend([self.row("phone_A", "pending_commands", 6000000, value=1),
                     self.row("phone_A", "pending_commands", 9000000, value=0)])
        result = analyze(rows, self.clocks(), [])
        self.assertEqual(result["exclusive_user_wait_estimated_range_us"], [2000000, 2000000])

    def test_no_phone_b_video_is_not_a_reason_to_guess_its_ready_time(self):
        rows = [e for e in self.fixture() if e["event"] != "phone_first_turn_playable_frame"]
        result = analyze(rows, self.clocks(), [])
        self.assertEqual(result["status"], "INCOMPLETE_OR_INVALID")
        self.assertIsNone(result["total_elapsed_estimated_range_us"])

    def test_gaps_and_multiple_actions_invalidate_total_but_keep_local_requests(self):
        rows = self.fixture() + [self.row("tablet", "command_start", 10000,
                                        request=1, command="game_liars_poker_start_game"),
                                 self.row("tablet", "command_end", 210000,
                                          request=1, value=1)]
        result = analyze(rows, self.clocks(), ["collector_gap"])
        self.assertIsNone(result["total_elapsed_estimated_range_us"])
        self.assertEqual(result["logical_command_totals"][0]["elapsed_us"], 200000)


if __name__ == "__main__":
    unittest.main()
