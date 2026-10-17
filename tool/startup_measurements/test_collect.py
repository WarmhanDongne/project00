import copy
import json
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit

from collect import Device, analyze, clock_offset, validate_event
from measurement_analysis import MAX_CLOCK_WIDTH_US, host_range, union_length

class CollectorTests(unittest.TestCase):
    def row(self, role, event, t, **extra):
        return dict(schema=2, capture='test', trial='one', scenario='initial_start', role=role,
                    process='a'*12, seq=t+1, mono_us=t, action=1, event=event, game='b'*32, **extra)

    def clocks(self, width=100):
        return {r: [dict(h0=t, h1=t+width, mono_us=t, process='a'*12) for t in (0,8_000_000,17_000_000)]
                for r in ('tablet','phone_A')}

    def fixture(self):
        rows=[]
        def add(role,event,t,**extra): rows.append(self.row(role,event,t,**extra))
        for role in ('tablet','phone_A'):
            add(role,'armed',0)
            add(role,'game_bound',200_000)
            for i,name in enumerate(['foreground','pending_commands','session_blockers','startup_uncovered']):
                add(role,name,210_000+i,value=1 if name in {'foreground','startup_uncovered'} else 0)
            add(role,'participant_count',220_000,value=1)
        add('tablet','action_accepted',0,source='initial_start')
        for event,t in [('tablet_deck_tappable_frame',300_000),('tablet_deck_entry_started',300_000),
                        ('tablet_deck_entry_completed',1_000_000),('tablet_deck_tap_accepted',6_000_000),
                        ('tablet_deal_started',6_000_000),('tablet_deal_animation_completed',8_000_000),
                        ('tablet_deal_completed',8_100_000),('tablet_playing_frame',9_000_000)]:
            add('tablet',event,t)
        add('tablet','tablet_gate',9_000_000,value=1)
        add('phone_A','phone_waiting_for_deal',230_000,value=1)
        add('phone_A','phone_waiting_for_deal',8_500_000,value=0)
        for event,t in [('pack_entry_started',8_500_000),('pack_tappable_frame',10_000_000),
                        ('pack_tap_accepted',15_000_000),('reveal_completed',16_500_000)]:
            add('phone_A',event,t)
        add('phone_A','phone_gate',16_500_000,value=15)
        add('phone_A','hand_gate',16_500_000,value=3)
        add('phone_A','phone_first_turn_playable_frame',16_500_000)
        for role,cmd,t,end,request in [('tablet','start_game',10,100_000,1),
                ('tablet','complete_dealing',8_100_000,8_400_000,2),
                ('phone_A','ready_turn',15_000_000,15_500_000,1)]:
            add(role,'command_start',t,request=request,command='game_liars_poker_'+cmd)
            add(role,'command_end',end,request=request,value=1)
        add('phone_A','card_selection_handler',16_600_000)
        add('phone_A','submit_handler',16_700_000)
        add('phone_A','submit_result',16_800_000,value=1)
        for role in ('tablet','phone_A'): add(role,'capture_stopped',17_000_000)
        return self.sequence(rows)

    def sequence(self, rows):
        result=[]
        for role in sorted({e['role'] for e in rows}):
            for n,e in enumerate(sorted((e for e in rows if e['role']==role),key=lambda e:e['mono_us']),1):
                result.append({**e,'seq':n})
        return result

    def test_joint_tablet_and_phone_waits_without_counting_entry(self):
        r=analyze(self.fixture(),self.clocks(),[])
        self.assertEqual(r['issues'],[])
        self.assertEqual(r['status'],'VALID_OBSERVED_TRIAL')
        self.assertEqual(r['quality_limit_us'],250_000)
        low,high=r['exclusive_user_wait_estimated_range_us']
        self.assertEqual([low,high],[9_998_000,10_002_000])
        low,high=r['user_wait_excluded_total_estimated_range_us']
        self.assertLess(low,6_500_000);self.assertGreater(high,6_500_000)
        self.assertTrue(all(r['progress']['input_validation'].values()))

    def test_parallel_commands_not_removed(self):
        rows=self.fixture()+[self.row('tablet','pending_commands',2_000_000,value=1),
                             self.row('tablet','pending_commands',4_000_000,value=0)]
        r=analyze(self.sequence(rows),self.clocks(),[])
        low,high=r['exclusive_user_wait_estimated_range_us']
        self.assertLessEqual(low,8_000_000);self.assertGreaterEqual(high,8_000_000)

    def test_missing_gate_does_not_qualify_wait(self):
        rows=[e for e in self.fixture() if not(e['role']=='tablet' and e['event']=='startup_uncovered')]
        r=analyze(self.sequence(rows),self.clocks(),[])
        self.assertIsNone(r['user_wait_excluded_total_estimated_range_us'])

    def test_early_tap_does_not_count_tablet_entry_wait(self):
        rows=self.fixture()
        for e in rows:
            if e['event']=='tablet_deck_tap_accepted': e['mono_us']=500_000
        r=analyze(self.sequence(rows),self.clocks(),[])
        low,high=r['exclusive_user_wait_estimated_range_us']
        self.assertEqual([low,high],[4_999_000,5_001_000])

    def test_parallel_phone_presentation_not_removed(self):
        rows=self.fixture()+[self.row('phone_A','phone_waiting_for_deal',2_000_000,value=0),
                             self.row('phone_A','phone_waiting_for_deal',4_000_000,value=1)]
        r=analyze(self.sequence(rows),self.clocks(),[])
        low,high=r['exclusive_user_wait_estimated_range_us']
        self.assertLessEqual(low,8_000_000);self.assertGreaterEqual(high,8_000_000)

    def test_wait_union_no_double_subtraction(self):
        self.assertEqual(union_length([[0,5],[2,7],[7,8],[10,9]]),8)

    def test_missing_tablet_tap_keeps_requests_but_no_total(self):
        rows=[e for e in self.fixture() if e['event']!='tablet_deck_tap_accepted']
        r=analyze(self.sequence(rows),self.clocks(),[])
        self.assertIsNone(r['total_elapsed_estimated_range_us'])
        self.assertEqual(len(r['logical_command_totals']),3)

    def test_repeated_deck_tap_is_not_silently_collapsed(self):
        rows=self.sequence(self.fixture()+[self.row('tablet','tablet_deck_tap_accepted',6_000_001)])
        r=analyze(rows,self.clocks(),[])
        self.assertIsNone(r['total_elapsed_estimated_range_us'])
        self.assertIn('missing_or_duplicate_tablet_deck_tap_accepted',r['issues'])

    def test_mislabelled_result_source_survives(self):
        rows=self.fixture()
        for e in rows:
            e['scenario']='menu_restart'
            if e['event']=='action_accepted':e['source']='result_restart'
        r=analyze(rows,self.clocks(),[])
        self.assertEqual(r['actual_scenario'],'result_restart')
        self.assertEqual(r['status'],'VALID_OBSERVED_TRIAL')
        self.assertIn('scenario_mismatch_actual_source_used',r['warnings'])

    def test_multiple_actions_and_collector_gap(self):
        rows=self.sequence(self.fixture()+[self.row('tablet','action_accepted',1000,source='initial_start')])
        r=analyze(rows,self.clocks(),['collector_gap'])
        self.assertIsNone(r['total_elapsed_estimated_range_us'])
        self.assertIn('expected_one_action',r['issues'])
        self.assertEqual(len(r['logical_command_totals']),3)

    def test_missing_first_turn_phone_or_participant(self):
        rows=[e for e in self.fixture() if e['event']!='phone_first_turn_playable_frame']
        r=analyze(self.sequence(rows),self.clocks(),[])
        self.assertIsNone(r['total_elapsed_estimated_range_us'])
        rows=self.fixture()
        for e in rows:
            if e['event']=='participant_count':e['value']=2
        self.assertIn('participant_phone_coverage_unconfirmed',analyze(rows,self.clocks(),[])['issues'])

    def test_revision_gate_not_network_failure(self):
        rows=self.fixture()+[self.row('phone_A','session_blockers',12_000_000,value=1),
                             self.row('phone_A','session_blockers',12_010_000,value=0)]
        r=analyze(self.sequence(rows),self.clocks(),[])
        self.assertEqual(r['status'],'VALID_OBSERVED_TRIAL')
        self.assertNotIn('recovery_during_phone_startup',r['issues'])

    def test_250ms_threshold_and_v1_not_reclassified(self):
        self.assertEqual(analyze(self.fixture(),self.clocks(100_000),[])['status'],'VALID_OBSERVED_TRIAL')
        r=analyze(self.fixture(),self.clocks(150_000),[])
        self.assertIn('cross_device_clock_quality_failed',r['issues'])
        self.assertIsNone(r['total_elapsed_estimated_range_us'])
        self.assertEqual(MAX_CLOCK_WIDTH_US,250_000)

    def test_exact_250ms_boundary(self):
        r=analyze(self.fixture(),self.clocks(114_900),[])
        self.assertEqual(r['status'],'VALID_OBSERVED_TRIAL')
        low,high=r['total_elapsed_estimated_range_us']
        self.assertEqual(high-low,250_000)
        r=analyze(self.fixture(),self.clocks(114_901),[])
        self.assertIsNone(r['total_elapsed_estimated_range_us'])

    def test_process_replacement_and_bad_probes(self):
        probes=self.clocks()['tablet'];self.assertIsNotNone(clock_offset(probes))
        other=copy.deepcopy(probes);other[1]['process']='b'*12
        self.assertIsNone(clock_offset(other))
        other=copy.deepcopy(probes);other[1]['mono_us']+=1_000_000
        self.assertIsNone(clock_offset(other))
        row=self.fixture()[0];row['process']='b'*12
        self.assertIsNone(host_range(row,self.clocks()))

    def test_sequence_and_monotonic_checks(self):
        rows=self.fixture();rows[2]['seq']+=100
        self.assertIn('event_sequence_gap',analyze(rows,self.clocks(),[])['issues'])
        rows=self.fixture();rows[2]['mono_us']=-1
        self.assertIn('non_monotonic_events',analyze(rows,self.clocks(),[])['issues'])

    def test_schema_rejects_private_fields_bad_aliases_sources_v1(self):
        row=self.row('tablet','action_accepted',0,source='initial_start')
        validate_event(row,'tablet','test','one')
        for bad in ({**row,'payload':'secret'},{**row,'game':'actual-room'},
                    {**row,'source':'secret'},{**row,'schema':1}):
            with self.assertRaises(ValueError):validate_event(bad,'tablet','test','one')

    def test_vm_http_extension_protocol_without_persisting_auth_uri(self):
        class Handler(BaseHTTPRequestHandler):
            protocol_version='HTTP/1.1'
            def do_GET(self):
                parsed=urlsplit(self.path)
                if parsed.path.endswith('getVM'):result={'isolates':[{'id':'isolates/1'}]}
                elif parsed.path.endswith('getIsolate'):result={'extensionRPCs':['ext.mosigame.startup']}
                else:
                    self.server.last_op=parse_qs(parsed.query).get('op',[None])[0]
                    result={'protocol':self.server.version,'process':'a'*12,'mono_us':12345}
                body=json.dumps({'result':result}).encode()
                self.send_response(200);self.send_header('Content-Length',str(len(body)));self.end_headers()
                self.wfile.write(body)
            def log_message(self,*_):pass
        server=ThreadingHTTPServer(('127.0.0.1',0),Handler);server.version=2
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        device=Device('adb','tablet','never-persist-serial')
        def adb(*args):
            if args[0]=='logcat':return f'The Dart VM service is listening on http://127.0.0.1:{server.server_port}/never-persist-token/'
            return str(server.server_port)
        device.shell_adb=adb
        try:
            device.connect();device.probe();device.probe()
            self.assertEqual(server.last_op,'clock');self.assertEqual(device.probes[0]['mono_us'],12345)
            self.assertNotIn('never-persist',json.dumps(device.probes))
            server.version=1
            with self.assertRaisesRegex(RuntimeError,'requires_new_debug_build'):device.probe()
        finally:
            device.close();server.shutdown();server.server_close();thread.join()

if __name__=='__main__':unittest.main()
