import copy
import json
import threading
import unittest
import http.client
import signal
import tempfile
import contextlib
import io
from pathlib import Path
from unittest.mock import Mock, patch
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit

from collect import Device, analyze, clock_offset, validate_event, finalize_devices, safe_error_code
from collect import main
from measurement_analysis import MAX_CLOCK_WIDTH_US, host_range, union_length, validate_first_submission

class CollectorTests(unittest.TestCase):
    def test_main_ctrl_c_preserves_valid_pilot_and_real_io_errors_still_fail(self):
        for interrupt in (True,False):
            with self.subTest(keyboard_interrupt=interrupt), tempfile.TemporaryDirectory() as tmp:
                rows=self.fixture()
                clocks=self.clocks()
                devices=[]
                class FakeDevice:
                    def __init__(self,adb,role,serial):
                        self.build_id='b'*64;self.role=role;self.serial=serial;self.after=0;self.process='a'*12
                        self.probes=clocks[role];self.capture=None;self.stopped=False;self.closed=False
                        devices.append(self)
                    def connect(self):pass
                    def probe(self):pass
                    def reset_http(self):pass
                    def close(self):self.closed=True
                    def control(self,op,**kwargs):
                        if op=='arm':self.capture=kwargs['capture'];return {'ok':True}
                        if op=='stop':self.stopped=True;return {'ok':True}
                        events=[{**e,'capture':self.capture,'trial':'trial-1'} for e in rows if e['role']==self.role]
                        if not self.stopped:events=[e for e in events if e['event']!='capture_stopped']
                        return {'process':self.process,'dropped':0,'last_seq':events[-1]['seq'],
                                'events':[e for e in events if e['seq']>kwargs.get('after',0)]}
                apk=Path(tmp)/'fixture.apk';apk.write_bytes(b'fixture')
                argv=['collect.py','--build-id','b'*64,'--apk',str(apk),'--device','tablet=private-serial-1','--device','phone_A=private-serial-2',
                      '--scenario','initial_start','--duration','10','--pilot','--output-parent',tmp]
                failure=KeyboardInterrupt() if interrupt else OSError('private-uri-with-token')
                output=io.StringIO()
                with patch('collect.Device',FakeDevice),patch('sys.argv',argv), \
                     patch('collect.time.sleep',side_effect=failure),contextlib.redirect_stdout(output):
                    code=main()
                capture=next(x for x in Path(tmp).iterdir() if x.is_dir())
                summary=json.loads((capture/'summary.json').read_text())
                manifest=json.loads((capture/'manifest.json').read_text())
                self.assertEqual(code,0 if interrupt else 1,summary)
                self.assertEqual(summary['pilot_passed'],interrupt)
                self.assertEqual(manifest['status'],'COLLECTED' if interrupt else 'FAILED')
                if interrupt:
                    self.assertEqual(summary['stop_reason'],'keyboard_interrupt')
                    self.assertIn('COLLECTING',output.getvalue())
                    self.assertIn('final_validation_pending',output.getvalue())
                    self.assertNotIn('\"status\": \"INCOMPLETE_OR_INVALID\"', output.getvalue())
                else:self.assertIn('failed_phase_collecting',summary['issues'])
                self.assertTrue(all(d.stopped and d.closed for d in devices))
                stored=''.join(p.read_text() for p in capture.iterdir() if p.is_file())
                self.assertNotIn('private-serial',stored)
                self.assertNotIn('private-uri',stored+output.getvalue())
    def test_ctrl_c_at_each_http_stage_closes_connection_before_final_stop(self):
        for stage in ('request', 'getresponse', 'read'):
            with self.subTest(stage=stage):
                device=Device('adb','phone_B','never-persist-serial')
                device.uri='http://127.0.0.1:1234/never-persist-token/'
                device.port=1234
                stale=Mock()
                response=Mock(status=200)
                stale.getresponse.return_value=response
                target=response.read if stage=='read' else getattr(stale,stage)
                target.side_effect=KeyboardInterrupt()
                device.http=stale
                with self.assertRaises(KeyboardInterrupt):device.control('drain',after=0)
                stale.close.assert_called_once()
                self.assertIsNone(device.http)
                fresh=Mock()
                fresh.getresponse.return_value.status=200
                fresh.getresponse.return_value.read.return_value=b'{"result":{"ok":true}}'
                with patch('collect.http.client.HTTPConnection',return_value=fresh):
                    self.assertTrue(device.control('stop')['ok'])
                fresh.request.assert_called_once()

    def test_cleanup_continues_after_one_device_fails_and_restores_signal(self):
        failed=Mock(role='phone_B')
        failed.control.side_effect=TimeoutError('never-persist-token')
        good=Mock(role='tablet')
        issues,diagnostics=[],[]
        previous=signal.getsignal(signal.SIGINT)
        drained=[]
        self.assertFalse(finalize_devices([failed,good],lambda d:drained.append(d.role),issues,diagnostics))
        self.assertEqual(failed.control.call_count,2)
        good.control.assert_called_once_with('stop')
        good.probe.assert_called_once()
        self.assertEqual(drained,['tablet'])
        self.assertEqual(issues,['device_finalization_failed_phone_B'])
        self.assertEqual(signal.getsignal(signal.SIGINT),previous)
        self.assertNotIn('never-persist',json.dumps(diagnostics))

    def test_cleanup_transient_failure_uses_fresh_connection_without_invalidating_data(self):
        device=Mock(role='phone_B')
        device.control.side_effect=[http.client.CannotSendRequest('private-uri'),{'ok':True}]
        issues,diagnostics=[],[]
        self.assertTrue(finalize_devices([device],lambda d:None,issues,diagnostics))
        self.assertEqual(issues,[])
        self.assertEqual(device.reset_http.call_count,2)
        self.assertEqual(diagnostics[0]['code'],'local_http_connection_state')
        self.assertNotIn('private-uri',json.dumps(diagnostics))

    def test_cleanup_never_retries_or_hides_sequence_errors(self):
        device=Mock(role='phone_A')
        issues,diagnostics=[],[]
        def bad_drain(_):raise RuntimeError('event_sequence_gap')
        self.assertFalse(finalize_devices([device],bad_drain,issues,diagnostics))
        self.assertEqual(device.control.call_count,1)
        self.assertEqual(diagnostics[0]['operation'],'drain')
        self.assertEqual(diagnostics[0]['code'],'event_sequence_gap')
        self.assertTrue(issues)

    def test_logical_control_errors_are_allowlisted_without_raw_details(self):
        device=Device('adb','tablet','private-serial')
        device.rpc=Mock(return_value={'error':'already_armed'})
        with self.assertRaisesRegex(RuntimeError,'measurement_control_already_armed'):
            device.control('arm')
        self.assertEqual(safe_error_code(RuntimeError('private-token')),'collector_internal_error')
    def row(self, role, event, t, **extra):
        return dict(schema=4, capture='test', trial='one', scenario='initial_start', role=role,
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
        add('tablet','cleanup_scope_start',105_000,span=2,command='cleanup_scope')
        add('tablet','cleanup_scope_end',185_000,span=2,command='cleanup_scope',value=1)
        add('tablet','cleanup_lookup_start',110_000,span=1,command='cleanup_lookup')
        add('tablet','cleanup_lookup_end',120_000,span=1,command='cleanup_lookup',value=1)
        add('tablet','startup_transition_wait',180_000)
        add('tablet','startup_route_replaced',190_000)
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
        add('phone_A','card_selection_changed',16_600_000,selection=1,value=1,input='tap')
        add('phone_A','submit_handler',16_700_000,selection=1,submission=2,value=1)
        add('phone_A','submit_result',16_800_000,value=1,selection=1,submission=2)
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

    def test_new_protocol_build_and_missing_stop_are_rejected(self):
        rows=self.fixture()
        rows=[e for e in rows if not (e['role']=='phone_A' and e['event']=='capture_stopped')]
        self.assertIn('missing_or_duplicate_capture_stopped_phone_A',analyze(rows,self.clocks(),[])['issues'])
        d=Device('adb','tablet','private');d.expected_build='c'*64
        d.control=Mock(return_value={'protocol':4,'process':'a'*12,'mono_us':1,'build':'b'*64})
        with self.assertRaisesRegex(RuntimeError,'build_mismatch'):d.probe()
        d.control=Mock(return_value={'protocol':2,'process':'a'*12,'mono_us':1})
        with self.assertRaisesRegex(RuntimeError,'requires_new_debug_build'):d.probe()

    def reset_fixture(self):
        rows=[]
        def add(role,name,t,**kwargs):
            rows.append({**self.row(role,name,t,**kwargs),'scenario':'room_reset'})
        old='c'*32;conn='d'*32;new='e'*32
        for role in ('tablet','phone_A'):
            add(role,'armed',0)
            add(role,'room_cleared',2_000_000,room=old)
            add(role,'room_observed',3_000_000,room=new)
            add(role,'capture_stopped',35_000_000)
        add('tablet','action_accepted',10,source='room_reset')
        add('tablet','room_reset_start',11,span=1,command='room_reset',room=old)
        add('tablet','room_reset_members',12,span=1,command='room_reset',room=old,value=1)
        for name,t in [('close_identity',100),('close_intent_persisted',200),('close_confirmed',1_900_000)]:
            add('tablet',name,t,room=old,subject=conn)
        add('tablet','room_reset_local_done',2_000_010,span=1,command='room_reset',room=old)
        add('tablet','room_reset_end',2_000_020,span=1,command='room_reset',room=old,value=1)
        for kind,span,begin,end in [('close_request',2,300,1_800_000),('disconnect_cancel',3,201,2_500_000)]:
            add('tablet',kind+'_start',begin,span=span,command=kind,room=old,subject=conn)
            add('tablet',kind+'_end',end,span=span,command=kind,room=old,subject=conn,value=1)
        add('tablet','room_participants',3_000_001,room=new,value=1)
        return self.sequence(rows)

    def test_reset_late_cancel_and_followup_are_separate_from_main_latency(self):
        r=analyze(self.reset_fixture(),self.clocks(),[])
        self.assertEqual(r['issues'],[])
        self.assertEqual(r['status'],'VALID_OBSERVED_TRIAL')
        self.assertTrue(r['reset_followup_passed'])
        self.assertLess(r['total_elapsed_estimated_range_us'][1],2_100_000)
        cancel=next(s for s in r['diagnostic_spans'] if s['kind']=='disconnect_cancel')
        self.assertGreater(cancel['elapsed_us'],2_400_000)

    def test_reset_missing_phone_old_identity_and_pending_cancel_never_pass(self):
        rows=self.reset_fixture()
        for mode in ('missing_phone','wrong_connection','pending'):
            sample=copy.deepcopy(rows)
            if mode=='missing_phone':
                sample=[e for e in sample if not(e['role']=='phone_A' and e['event']=='room_cleared')]
            elif mode=='wrong_connection':
                for e in sample:
                    if e.get('command')=='disconnect_cancel':e['subject']='f'*32
            else:
                for e in sample:
                    if e['event']=='disconnect_cancel_end':
                        e['event']='span_pending';e.pop('value')
            r=analyze(self.sequence(sample),self.clocks(),[])
            self.assertEqual(r['status'],'INCOMPLETE_OR_INVALID',r)
            if mode=='pending':self.assertEqual(len(r['pending_spans']),1)

    def test_new_room_clear_and_insufficient_observation_fail_followup_only(self):
        rows=self.reset_fixture()
        rows.append({**self.row('phone_A','room_cleared',4_000_000,room='e'*32),'scenario':'room_reset'})
        r=analyze(self.sequence(rows),self.clocks(),[])
        self.assertEqual(r['status'],'VALID_OBSERVED_TRIAL')
        self.assertFalse(r['reset_followup_passed'])
        rows=self.reset_fixture()
        for e in rows:
            if e['event']=='capture_stopped':e['mono_us']=5_000_000
        self.assertFalse(analyze(self.sequence(rows),self.clocks(),[])['reset_followup_passed'])

    def test_first_submission_requires_actual_selection_and_same_result(self):
        for source in ('tap','drag'):
            rows=self.fixture()
            for e in rows:
                if e['event']=='card_selection_changed':e['input']=source
            r=analyze(rows,self.clocks(),[])
            self.assertTrue(all(r['progress']['input_validation'].values()))
            self.assertEqual(r['input_validation_details']['status'],'PASSED')

    def test_later_turn_selection_and_success_never_repair_first_submit(self):
        # The observed 00:24:40 failure shape: first submit succeeds without a
        # prior selection record; the first selection record arrives a turn later.
        rows=[e for e in self.fixture() if e['event']!='card_selection_changed']
        rows += [self.row('phone_A','card_selection_changed',16_850_000,selection=3,value=1,input='tap'),
                 self.row('phone_A','submit_handler',16_860_000,selection=3,submission=4,value=1),
                 self.row('phone_A','submit_result',16_870_000,selection=3,submission=4,value=1)]
        r=analyze(self.sequence(rows),self.clocks(),[])
        self.assertEqual(r['status'],'VALID_OBSERVED_TRIAL') # timing independent
        self.assertFalse(r['progress']['input_validation']['selection_seen'])
        self.assertFalse(r['progress']['input_validation']['submission_succeeded'])
        self.assertEqual(r['input_validation_details']['submission'],2)

    def test_failed_first_attempt_not_replaced_by_successful_retry(self):
        rows=self.fixture()
        for e in rows:
            if e['event']=='submit_result':e['value']=0
        rows += [self.row('phone_A','submit_handler',16_850_000,selection=1,submission=3,value=1),
                 self.row('phone_A','submit_result',16_860_000,selection=1,submission=3,value=1)]
        r=analyze(self.sequence(rows),self.clocks(),[])
        self.assertFalse(r['progress']['input_validation']['submission_succeeded'])
        self.assertIn('first_submission_failed',r['input_validation_details']['issues'])

    def test_unlinked_duplicate_result_and_stale_selection_never_pass(self):
        for mode in ('wrong_submission','wrong_selection','duplicate_result','stale_selection','zero_count','state_only'):
            rows=self.fixture()
            result=next(e for e in rows if e['event']=='submit_result')
            chosen=next(e for e in rows if e['event']=='card_selection_changed')
            if mode=='wrong_submission':result['submission']=99
            if mode=='wrong_selection':result['selection']=99
            if mode=='duplicate_result':rows.append({**result,'mono_us':16_800_001})
            if mode=='stale_selection':rows.append(self.row('phone_A','card_selection_changed',16_650_000,selection=3,value=0,input='tap'))
            if mode=='zero_count':chosen['value']=0
            if mode=='state_only':chosen['input']='state'
            r=analyze(self.sequence(rows),self.clocks(),[])
            self.assertFalse(r['progress']['input_validation']['submission_succeeded'],mode)

    def test_early_selection_retained_but_first_submit_must_follow_ready(self):
        rows=self.fixture()
        for e in rows:
            if e['event']=='card_selection_changed':e['mono_us']=16_400_000
        self.assertTrue(all(analyze(self.sequence(rows),self.clocks(),[])['progress']['input_validation'].values()))
        rows=self.fixture()
        for e in rows:
            if e['event']=='submit_handler':e['mono_us']=16_400_000
        r=analyze(self.sequence(rows),self.clocks(),[])
        self.assertIn('first_submission_before_input_ready',r['input_validation_details']['issues'])
        self.assertFalse(r['progress']['input_validation']['submission_succeeded'])

    def test_old_apk_and_private_input_fields_rejected(self):
        d=Device('adb','tablet','private')
        d.control=Mock(return_value={'protocol':3,'process':'a'*12,'mono_us':1,'build':'b'*64})
        with self.assertRaisesRegex(RuntimeError,'requires_new_debug_build'):d.probe()
        row=next(e for e in self.fixture() if e['event']=='card_selection_changed')
        validate_event(row,'phone_A','test','one')
        for bad in ({**row,'card_ids':[1]}, {**row,'input':'private-card'}, {**row,'selection':0}, {**row,'schema':3}):
            with self.assertRaises(ValueError):validate_event(bad,'phone_A','test','one')

    def test_vm_http_extension_protocol_without_persisting_auth_uri(self):
        class Handler(BaseHTTPRequestHandler):
            protocol_version='HTTP/1.1'
            def do_GET(self):
                parsed=urlsplit(self.path)
                if parsed.path.endswith('getVM'):result={'isolates':[{'id':'isolates/1'}]}
                elif parsed.path.endswith('getIsolate'):result={'extensionRPCs':['ext.mosigame.startup']}
                else:
                    self.server.last_op=parse_qs(parsed.query).get('op',[None])[0]
                    result={'protocol':self.server.version,'process':'a'*12,'mono_us':12345,'build':'b'*64}
                body=json.dumps({'result':result}).encode()
                self.send_response(200);self.send_header('Content-Length',str(len(body)));self.end_headers()
                self.wfile.write(body)
            def log_message(self,*_):pass
        server=ThreadingHTTPServer(('127.0.0.1',0),Handler);server.version=4
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
