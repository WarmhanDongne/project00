"""Read-only reconstruction of the 16 explicitly selected captures. No product edits."""
import collections
import hashlib
import importlib.util
import json
import statistics
import subprocess
from datetime import datetime
from pathlib import Path

ROOT = Path.cwd().resolve()
OUT = Path(__file__).resolve().parent
BASE = ROOT / 'artifacts/performance-captures'
TIMES = ['201011','201059','201513','201731','201809','201941','202027',
         '202202','202301','202421','202520','202631','202744','203129','203417','204053']
RESULTS = {'203129','203417','204053'}
spec = importlib.util.spec_from_file_location('saved_collector', ROOT/'tool/startup_measurements/collect.py')
collector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(collector)
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
git = lambda *args: subprocess.check_output(['git',*args], cwd=ROOT, text=True).strip()
baseline = {'head':git('rev-parse','HEAD'), 'branch':git('branch','--show-current'),
            'trackedDiff':git('diff','--name-only'), 'indexDiff':git('diff','--cached','--name-only')}
snapshots, trials, calls_all, attempts_all = {}, [], [], []
processes = collections.defaultdict(dict)


def stats(values):
    return {'n':len(values),'median':statistics.median(values),'min':min(values),'max':max(values)} if values else None


def find(rows, event, role):
    return [e for e in rows if e['event']==event and e['role']==role]


def delta(a,b):
    assert a['role']==b['role'] and a['process']==b['process']
    assert b['mono_us']>=a['mono_us']
    return (b['mono_us']-a['mono_us'])/1e6


def host_bounds(event, clocks):
    probes = clocks.get(event['role'],[])
    if collector.clock_offset(probes) is None:
        return None
    near = sorted(probes,key=lambda p:abs(p['mono_us']-event['mono_us']))[:3]
    lows, highs = [], []
    for p in near:
        assert p['process']==event['process']
        margin = 5000+int(abs(p['mono_us']-event['mono_us'])*.0002)
        lows.append(event['mono_us']+p['h0']-p['mono_us']-margin)
        highs.append(event['mono_us']+p['h1']-p['mono_us']+margin)
    lo,hi=max(lows),min(highs)
    return [lo,hi] if lo<=hi else None


for time_key in TIMES:
    matches=list(BASE.glob(f'debug-game-start-20261017-{time_key}-*'))
    assert len(matches)==1,(time_key,len(matches))
    folder=matches[0]
    for p in folder.iterdir():
        if p.is_file(): snapshots[str(p.relative_to(ROOT))]=sha(p)
    manifest=json.loads((folder/'manifest.json').read_text(encoding='utf-8-sig'))
    integrity=json.loads((folder/'integrity.json').read_text(encoding='utf-8-sig'))
    for name,expected in integrity.items():
        p=(folder/name).resolve()
        assert p.parent==folder.resolve() and p.is_file() and sha(p)==expected,(time_key,name)
    p=folder/'events.sanitized.jsonl'
    events=[json.loads(line) for line in p.read_text(encoding='utf-8-sig').splitlines() if line.strip()] if p.exists() else []
    assert manifest['events']==len(events)
    assert set(manifest['roles'])=={'tablet','phone_A'}
    for e in events: collector.validate_event(e,e['role'],manifest['capture'],'trial-1')
    locals_by_role={r:sorted((e for e in events if e['role']==r),key=lambda e:e['seq']) for r in manifest['roles']}
    role_checks={}
    for role,local in locals_by_role.items():
        if not local:
            role_checks[role]={'events':0,'sequence':'NO_EVENTS'}
            continue
        assert [e['seq'] for e in local]==list(range(1,len(local)+1))
        assert all(a['mono_us']<=b['mono_us'] for a,b in zip(local,local[1:]))
        process_set={e['process'] for e in local}
        assert len(process_set)==1
        assert {p['process'] for p in manifest['clocks'][role]}==process_set
        process=next(iter(process_set))
        processes[role].setdefault(process,len(processes[role])+1)
        role_checks[role]={'events':len(local),'sequence':'CONTIGUOUS','monotonic':'PASS',
                           'processOrdinal':processes[role][process]}
    source_mismatches=[name for name,expected in manifest['working_copy_sources_sha256'].items()
                       if not (ROOT/name).is_file() or sha(ROOT/name)!=expected]
    assert not source_mismatches,source_mismatches
    saved=json.loads((folder/'summary.json').read_text(encoding='utf-8-sig'))
    actual_scenario='result_restart' if time_key in RESULTS else manifest['scenario']
    trial={'time':time_key,'folder':folder.name,'actualScenario':actual_scenario,
           'recordedScenario':manifest['scenario'],'condition':manifest['condition'],
           'eventCount':len(events),'storageIntegrity':'PASS','roles':role_checks,
           'workingCopyHead':manifest['working_copy_head'],'sourceFingerprintsMatchCurrent':True,
           'savedSummaryStatus':saved['status'],'savedSummaryIssues':saved['issues']}
    actions=find(events,'action_accepted','tablet')
    rejected=find(events,'action_rejected','tablet')
    trial['actionAcceptedCount']=len(actions)
    trial['actionRejectedCount']=len(rejected)
    root_start=actions[0] if len(actions)==1 else None
    method='original_action_accepted' if root_start else None
    if time_key in RESULTS:
        assert not actions and len(rejected)==1 and rejected[0]['action']==0
        cmd=find(events,'command_start','tablet')[0]
        assert cmd['command']=='game_liars_poker_start_game' and 0<=delta(rejected[0],cmd)<.01
        root_start=rejected[0]
        method='reconstructed_result_button_callback_user_attestation_and_matching_code'
    elif time_key=='201513':
        assert len(actions)==len(rejected)==1
        seats=find(events,'seat_save_end','tablet')
        assert len(seats)==2 and [e['value'] for e in seats]==[0,1]
        root_start=rejected[0]
        method='second_initial_attempt_after_recorded_seat_failure_not_a_clean_trial'
    elif rejected:
        method='multiple_user_actions_no_single_startup_trial'
    trial['startMethod']=method
    trial['startSequence']=root_start['seq'] if root_start else None
    trial['startMonoUs']=root_start['mono_us'] if root_start else None

    calls=[]; attempts=[]
    for role,local in locals_by_role.items():
        pending={}; pending_attempts={}
        for e in local:
            if e['event']=='command_start':pending[e['request']]=e
            elif e['event']=='command_end':
                begin=pending.pop(e['request'],None)
                assert begin
                calls.append({'time':time_key,'scenario':actual_scenario,'role':role,
                              'request':e['request'],'function':begin['command'],'seconds':delta(begin,e),
                              'outcome':{1:'SUCCESS',2:'HELD',3:'ERROR'}[e['value']],
                              'startSequence':begin['seq'],'endSequence':e['seq']})
            elif e['event']=='attempt_start':pending_attempts[e['request']]=e
            elif e['event']=='attempt_end':
                begin=pending_attempts.pop(e['request'],None)
                assert begin
                attempts.append({'time':time_key,'scenario':actual_scenario,'role':role,
                                 'request':e['request'],'attempt':begin['value'],
                                 'seconds':delta(begin,e),'outcome':e['value']})
        for request,begin in pending.items():
            calls.append({'time':time_key,'scenario':actual_scenario,'role':role,'request':request,
                          'function':begin['command'],'outcome':'INCOMPLETE',
                          'observedSeconds':delta(begin,local[-1]),'startSequence':begin['seq']})
        for request,begin in pending_attempts.items():
            attempts.append({'time':time_key,'role':role,'request':request,'outcome':'NO_ATTEMPT_END',
                             'observedSeconds':delta(begin,local[-1])})
    trial['commands']=calls
    trial['attempts']=attempts
    calls_all.extend(calls);attempts_all.extend(attempts)
    tablet=find(events,'tablet_playing_frame','tablet')
    actor=find(events,'phone_first_turn_playable_frame','phone_A')
    pack=find(events,'pack_tappable_frame','phone_A')
    tap=find(events,'pack_tap_accepted','phone_A')
    reveal=find(events,'reveal_completed','phone_A')
    select=find(events,'phone_hand_selectable_frame','phone_A')
    game_sets={r:{e['game'] for e in find(events,'game_bound',r)} for r in locals_by_role}
    matched_game=len(game_sets['tablet'])==len(game_sets['phone_A'])==1 and game_sets['tablet']==game_sets['phone_A']
    trial['matchedNewGameBothDevices']=matched_game
    trial['tabletCompleted']=len(tablet)==1
    trial['firstTurnPhoneCompleted']=len(actor)==1
    trial['phoneHandSelectable']=len(select)==1
    trial['phoneFirstTurnBitObserved']=any(e['value'] & 4 for e in find(events,'phone_gate','phone_A'))
    trial['localStagesSeconds']={}
    local_metrics=trial['localStagesSeconds']
    if root_start and len(tablet)==1:
        local_metrics['actionToTabletPlaying']=delta(root_start,tablet[0])
    if root_start and locals_by_role['tablet']:
        local_metrics['actionToCaptureEnd']=delta(root_start,locals_by_role['tablet'][-1])
    if len(pack)==len(tap)==1:
        local_metrics['phonePackUserWait']=delta(pack[0],tap[0])
    if len(tap)==len(reveal)==1:
        local_metrics['phoneTapToRevealCompleted']=delta(tap[0],reveal[0])
    if len(reveal)==len(select)==1:
        local_metrics['phoneRevealToSelectable']=delta(reveal[0],select[0])
    if len(actor)==len(tap)==1:
        local_metrics['phoneTapToFirstTurnPlayable']=delta(tap[0],actor[0])
    for first,last,key,role in [
        ('pack_entry_started','pack_tappable_frame','phonePackEntry','phone_A'),
        ('controls_started','controls_completed','phoneControlsEntry','phone_A'),
        ('tablet_deal_completed','tablet_playing_frame','tabletPostDealToPlaying','tablet')]:
        a,b=find(events,first,role),find(events,last,role)
        if len(a)==len(b)==1:local_metrics[key]=delta(a[0],b[0])
    intros=find(events,'phone_game_intro_completed','phone_A')
    stage1=[e for e in find(events,'phone_stage','phone_A') if e['value']==1]
    if len(intros)==len(stage1)==1:local_metrics['phoneGameIntro']=delta(stage1[0],intros[0])
    # Same-device pairs are exact log deltas; cross-device intervals stay estimates.
    cross={}
    if root_start and matched_game:
        a=host_bounds(root_start,manifest['clocks'])
        for name,ends in [('actionToPack',pack),('actionToPhoneSelectable',select),('actionToFirstTurnPlayable',actor)]:
            if a and len(ends)==1:
                b=host_bounds(ends[0],manifest['clocks'])
                if b:
                    cross[name]={'lowerSeconds':(b[0]-a[1])/1e6,'upperSeconds':(b[1]-a[0])/1e6,
                                 'widthMs':(b[1]-b[0]+a[1]-a[0])/1000}
        if a and len(tablet)==len(actor)==1:
            t,p=host_bounds(tablet[0],manifest['clocks']),host_bounds(actor[0],manifest['clocks'])
            if t and p:
                total={'lowerSeconds':(max(t[0],p[0])-a[1])/1e6,
                       'upperSeconds':(max(t[1],p[1])-a[0])/1e6}
                total['widthMs']=(total['upperSeconds']-total['lowerSeconds'])*1000
                total['meetsPredeclared100msWidth']=total['widthMs']<=100
                total['firstTurnPhoneDefinitelyLater']=p[0]>t[1]
                cross['totalObserved']=total
                # Phone-only user wait can be removed only when the tablet was
                # already ready and the phone has no observed parallel blocker.
                if len(pack)==len(tap)==1:
                    pack_host=host_bounds(pack[0],manifest['clocks'])
                    segments,unknown=collector.exclusive_wait_segments([
                        e for e in locals_by_role['phone_A'] if e['mono_us']<=actor[0]['mono_us']])
                    seconds=sum(end-begin for begin,end in segments)/1e6
                    wait=local_metrics['phonePackUserWait']
                    exclusive=(not unknown and pack_host and pack_host[0]>t[1] and abs(seconds-wait)<.000001)
                    if exclusive:
                        cross['phoneWaitOnlyAdjusted']={
                            'lowerSeconds':total['lowerSeconds']-wait,
                            'upperSeconds':total['upperSeconds']-wait,
                            'removedPhoneUserWaitSeconds':wait,
                            'isFullyUserWaitExcluded':False,
                            'limitation':'Tablet first-deal tap is not instrumented; do not call this system-only latency.'}
    trial['crossDeviceEstimates']=cross
    trial['strictEndToEndValid']=bool(cross.get('totalObserved',{}).get('meetsPredeclared100msWidth')) and not rejected
    # Preserve evidence without duplicating actual aliases or any private payload.
    timelines={}
    for role,local in locals_by_role.items():
        if not local:continue
        ref=root_start['mono_us'] if role=='tablet' and root_start else local[0]['mono_us']
        timelines[role]=[{'seq':e['seq'],'secondsFromReference':(e['mono_us']-ref)/1e6,
                          'event':e['event'],**{k:e[k] for k in ('value','request','command') if k in e}}
                         for e in local]
    trial['timelines']=timelines
    trials.append(trial)

assert len(trials)==16 and sum(t['eventCount'] for t in trials)==880
assert sum(t['eventCount']>0 for t in trials)==13
assert sum(t['firstTurnPhoneCompleted'] for t in trials)==3
assert sum(t['strictEndToEndValid'] for t in trials)==0
assert sum(t['tabletCompleted'] for t in trials)==7
aggregate={}
for scenario in ('initial_start','menu_restart','result_restart'):
    group=[t for t in trials if t['actualScenario']==scenario]
    aggregate[scenario]={'captures':len(group),'withEvents':sum(t['eventCount']>0 for t in group),
                         'tabletComplete':sum(t['tabletCompleted'] for t in group),
                         'firstTurnPhoneComplete':sum(t['firstTurnPhoneCompleted'] for t in group)}
functions={}
for name in sorted({c['function'] for c in calls_all}):
    group=[c for c in calls_all if c['function']==name]
    functions[name]={'outcomes':dict(collections.Counter(c['outcome'] for c in group)),
                     'successfulLogicalSeconds':stats([c['seconds'] for c in group if c['outcome']=='SUCCESS']),
                     'successfulTransportSeconds':stats([a['seconds'] for a in attempts_all
                         if a.get('outcome')==1 and any(c['time']==a['time'] and c['role']==a['role']
                            and c['request']==a['request'] and c['function']==name for c in group)])}
local_stage_stats={key:stats([t['localStagesSeconds'][key] for t in trials if key in t['localStagesSeconds']])
                   for key in ['phonePackEntry','phoneTapToRevealCompleted','phoneControlsEntry','phoneGameIntro']}
analysis={'status':'ANALYZED_WITH_EXPLICIT_PARTIAL_VALIDITY','generatedAt':datetime.now().astimezone().isoformat(),
          'baseline':baseline,'captures':trials,'scenarioCounts':aggregate,'functionStatistics':functions,
          'automaticStageStatistics':local_stage_stats,'strictEndToEndValidCaptures':0,
          'completedButClockWidthOverThresholdCaptures':3,'sourceAPKAttestation':False,
          'productSourceModified':False,'fullValidation':'NOT_RUN_USER_DECLINED',
          'serverAccess':False,'sourceSnapshots':snapshots,
          'criticalLimitations':['Tablet central-deck first-round user tap has no timing event.',
            'Only tablet and phone_A were collected; other first-turn phones are unobserved.',
            'canSend=false is an input gate, not proof of a network outage.',
            'Wrong scenario causes action_rejected without rejecting gameplay.',
            'Whole elapsed intervals include tablet user wait; subtracting phone wait alone does not isolate system latency.']}
(OUT/'analysis.json').write_text(json.dumps(analysis,ensure_ascii=False,indent=2),encoding='utf-8')
for name,expected in snapshots.items():assert sha(ROOT/name)==expected,name
assert git('diff','--name-only')==baseline['trackedDiff']
assert git('diff','--cached','--name-only')==baseline['indexDiff']
(OUT/'verification.json').write_text(json.dumps({'status':'PASS','exitCode':0,
   'captures':16,'capturesWithEvents':13,'events':880,'originalFilesUnchanged':len(snapshots),
   'integrityListedFilesVerified':sum(len(json.loads((BASE/t['folder']/'integrity.json').read_text())) for t in trials),
   'sequenceAndMonotonicity':'PASS_FOR_ALL_RECORDED_ROLES','recordedWorkingCopyFingerprintsMatch':True,
   'sourceAndIndexUnchanged':True,'analysisDataSha256':sha(OUT/'analysis.json')},indent=2),encoding='utf-8')
print(json.dumps({'scenarioCounts':aggregate,'functions':functions,'stages':local_stage_stats,
                   'strictValid':0,'completedClockLimited':3,'filesUnchanged':len(snapshots)},ensure_ascii=False))
