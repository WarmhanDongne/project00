"""Offline baseline analysis. Never writes source captures or talks to devices."""
import sys, json, csv, hashlib, statistics
from pathlib import Path
from collections import Counter, defaultdict
OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[2]
sys.path.insert(0,str(ROOT/'tool/startup_measurements'))
from measurement_analysis import analyze, host_range
from collect import validate_event

GROUPS={'initial_start':['005036-0503abb7','005153-def595be','RECOVERED','011357-b4d246c7','011455-1bb8ff18','011603-364f9072'], 'menu_restart':['013848-20c24974','013939-85fe8948','014055-7e247e0f','014137-65719ea8','014211-58bb46e0'], 'result_restart':['014548-0f5eb212','014747-012542a4','015516-37282d37','015634-2d282724','015802-66b67dab','015354-ef07417b']}
STAGES=[]; TRIALS=[]; TIMELINE=[]; CALLS=[]; INPUTS=[]; SOURCES=[]
def mid(r):return sum(r)/2
def add(row,key,label,a=None,b=None,bounds=None,kind='mixed',lane='',note=''):
 if bounds is None:
  if a is None or b is None:return
  if a['role']==b['role']:
   bounds=[b['mono_us']-a['mono_us']]*2
  else:
   ar,br=host_range(a,row['_clocks']),host_range(b,row['_clocks'])
   if ar is None or br is None:return
   bounds=[br[0]-ar[1],br[1]-ar[0]]
 STAGES.append(dict(trial=row['trial'],scenario=row['scenario'],metric=key,label=label,kind=kind,lane=lane,lower_s=bounds[0]/1e6,upper_s=bounds[1]/1e6,midpoint_s=mid(bounds)/1e6,start_event=a['event'] if a else '',end_event=b['event'] if b else '',start_role=a['role'] if a else '',end_role=b['role'] if b else '',start_seq=a['seq'] if a else '',end_seq=b['seq'] if b else '',note=note))

for scenario, ids in GROUPS.items():
 for number,cid in enumerate(ids,1):
  name='recovered-debug-game-start-20261018-010031-4153e545' if cid=='RECOVERED' else 'debug-game-start-20261018-'+cid
  p=OUT.parent/name
  manifest=json.loads((p/'manifest.json').read_text()) if (p/'manifest.json').exists() else None
  integrity=json.loads((p/'integrity.json').read_text())
  assert all(hashlib.sha256((p/f).read_bytes()).hexdigest()==h for f,h in integrity.items()),name
  events=[json.loads(x) for x in (p/'events.sanitized.jsonl').read_text().splitlines()]
  capture='debug-game-start-20261018-010031-cd88cf80' if cid=='RECOVERED' else name
  clocks=manifest['clocks'] if manifest else json.loads((p/'clocks.json').read_text())
  for e in events:validate_event(e,e['role'],capture,'trial-1')
  for role in clocks:
   local=sorted([e for e in events if e['role']==role],key=lambda e:e['seq'])
   assert local[0]['event']=='armed' and local[-1]['event']=='capture_stopped'
   assert len({e['process'] for e in local})==1
  if manifest:assert manifest['events']==len(events)
  summary=analyze(events,clocks,[])
  saved=json.loads((p/'summary.json').read_text())
  assert summary['status']=='VALID_OBSERVED_TRIAL' and saved['pilot_passed'] and summary['actual_scenario']==scenario
  assert all(summary['progress']['input_validation'].values())
  actor=summary['progress']['first_turn_phone']
  game=next(e['game'] for e in events if e['event']=='game_bound')
  selected=[e for e in events if e.get('game')==game]
  def get(role,event,after=None,value=None,last=False):
   pregame={'action_accepted','seating_prepare_start','seating_prepare_end','seat_save_start','seat_save_end','assets_start','assets_end','screen_ready'}
   pool=events if event in pregame else selected
   es=[e for e in pool if e['role']==role and e['event']==event and (after is None or e['mono_us']>=after) and (value is None or e.get('value')==value)]
   return (es[-1] if last else es[0]) if es else None
  start=get('tablet','action_accepted'); tp=get('tablet','tablet_playing_frame'); pp=get(actor,'phone_first_turn_playable_frame')
  row=dict(trial=scenario+'-'+str(number),scenario=scenario,number=number,folder=name,original_capture=capture,recovered=cid=='RECOVERED',events=len(events),first_turn_phone=actor,condition=manifest['condition'] if manifest else 'unspecified',_clocks=clocks)
  sr=host_range(start,clocks); tr=host_range(tp,clocks); pr=host_range(pp,clocks)
  assert pr[0]>tr[1],('phone_not_last',name)
  row['completion_device']='first_turn_phone'
  for key,label in [('total_elapsed_estimated_range_us','total'),('user_wait_excluded_total_estimated_range_us','adjusted'),('exclusive_user_wait_estimated_range_us','exclusive_wait')]:
   add(row,label,label,bounds=summary[key],kind='aggregate')
  def stage(key,label,role,a,b,kind='mixed',**kwargs):add(row,key,label,get(role,a),get(role,b),kind=kind,lane=role,**kwargs)
  stage('seating_prepare','자리 저장·화면 이동', 'tablet','seating_prepare_start','seating_prepare_end')
  stage('seat_save','자리 저장','tablet','seat_save_start','seat_save_end',kind='request_state')
  stage('action_to_deck','버튼→태블릿 카드 더미','tablet','action_accepted','tablet_deck_tappable_frame')
  stage('tablet_entry','태블릿 카드 더미 등장','tablet','tablet_deck_entry_started','tablet_deck_entry_completed',kind='animation')
  stage('tablet_raw_wait','태블릿 원시 탭 대기','tablet','tablet_deck_tappable_frame','tablet_deck_tap_accepted',kind='user_wait_overlap')
  stage('tablet_after_entry_wait','태블릿 등장 완료→탭','tablet','tablet_deck_entry_completed','tablet_deck_tap_accepted',kind='user_wait_overlap')
  stage('tablet_deal','카드 배분 연출','tablet','tablet_deal_started','tablet_deal_animation_completed',kind='animation')
  stage('tablet_after_deal','배분 연출 끝→태블릿 준비','tablet','tablet_deal_animation_completed','tablet_playing_frame')
  stage('tablet_ready','버튼→태블릿 준비','tablet','action_accepted','tablet_playing_frame')
  stage('tablet_round_ending','테이블 안내 종료→태블릿 준비','tablet','tablet_round_reveal_completed','tablet_playing_frame')
  stage('phone_entry','폰 카드팩 등장',actor,'pack_entry_started','pack_tappable_frame',kind='animation')
  stage('phone_wait','폰 카드팩 탭 대기',actor,'pack_tappable_frame','pack_tap_accepted',kind='user_wait')
  stage('phone_reveal','폰 손패 공개',actor,'pack_tap_accepted','reveal_completed',kind='animation_parallel_request')
  stage('phone_reveal_to_ready','손패 공개 끝→폰 입력 준비',actor,'reveal_completed','phone_first_turn_playable_frame')
  stage('phone_controls','조작부 등장',actor,'controls_started','controls_completed',kind='animation_overlap_after_endpoint')
  for key,a,b in [('phone_ready_lag','tablet_playing_frame','phone_first_turn_playable_frame'),('deal_to_phone_entry','tablet_deal_animation_completed','pack_entry_started'),('deal_to_phone_data','tablet_deal_animation_completed','private_applied')]:
   aa=get('tablet',a);bb=get(actor,b)
   if key=='deal_to_phone_data':
    first_deal_mid=mid(host_range(aa,clocks));candidates=[e for e in selected if e['role']==actor and e['event']=='private_applied' and mid(host_range(e,clocks))>=first_deal_mid-.1e6];bb=candidates[0] if candidates else None
   add(row,key,key,aa,bb,lane='cross',kind='mixed')
  phase=get(actor,'phone_stage',value=1)
  if phase:
   add(row,'game_start_intro','폰 GAME START 안내',phase,get(actor,'phone_game_intro_completed'),kind='animation',lane=actor)
  private=get(actor,'private_applied')
  add(row,'phone_data_to_pack','폰 첫 손패 반영→카드팩 등장',private,get(actor,'pack_entry_started'),kind='mixed_announcement',lane=actor)
  add(row,'phone_stage5_to_pack','폰 공개 단계→카드팩 등장',get(actor,'phone_stage',value=5),get(actor,'pack_entry_started'),kind='mixed_announcement',lane=actor)
  for role in ['tablet',actor]:
   for key,a,b in [('assets','assets_start','assets_end'),('screen_after_assets','assets_end','screen_ready')]:
    stage(key+'_'+role,key,role,a,b,kind='assets')
  for c in summary['logical_command_totals']:
   if 'elapsed_us' not in c:continue
   ce=[e for e in events if e['role']==c['role'] and e.get('request')==c['request']]
   beg=next(e for e in ce if e['event']=='command_start');end=next(e for e in ce if e['event']=='command_end')
   command=c['command'];typ=command.replace('game_liars_poker_','')
   CALLS.append(dict(trial=row['trial'],scenario=scenario,role=c['role'],request=c['request'],command=command,duration_s=c['elapsed_us']/1e6,outcome=c['outcome'],start_relative_s=(mid(host_range(beg,clocks))-mid(sr))/1e6,end_relative_s=(mid(host_range(end,clocks))-mid(sr))/1e6))
   if c['role']=='tablet' and typ in ['start_game','complete_dealing'] or c['role']==actor and typ=='ready_turn':
    add(row,'call_'+typ,typ,beg,end,kind='request',lane=c['role'])
   if c['role']==actor and typ=='ready_turn':
    reveal=get(actor,'reveal_completed'); tail=max(0,end['mono_us']-reveal['mono_us'])
    add(row,'ready_response_after_reveal','손패 공개 뒤 준비 요청 응답 잔여',bounds=[tail]*2,kind='request_exposure',lane=actor)
    add(row,'ready_response_minus_ready','준비 요청 응답−입력 준비 시각',pp,end,kind='signed_diagnostic',lane=actor)
  for a in summary['transport_attempt_round_trips']:
   role=a['role'];req=a['request'];matching=[e for e in events if e['role']==role and e.get('request')==req]
   c=next(e['command'] for e in matching if e['event']=='command_start')
   if (role=='tablet' and c.endswith(('start_game','complete_dealing'))) or (role==actor and c.endswith('ready_turn')):
    add(row,'attempt_'+c.replace('game_liars_poker_',''),c,bounds=[a['elapsed_us']]*2,kind='request_attempt',lane=role)
  for e in events:
   hr=host_range(e,clocks)
   if hr:TIMELINE.append(dict(trial=row['trial'],scenario=scenario,role=e['role'],seq=e['seq'],event=e['event'],target_game=e.get('game')==game,value=e.get('value'),request=e.get('request'),command=e.get('command'),mono_us=e['mono_us'],relative_lower_s=(hr[0]-sr[1])/1e6,relative_upper_s=(hr[1]-sr[0])/1e6,relative_midpoint_s=(mid(hr)-mid(sr))/1e6))
  submits=[e for e in events if e['role']==actor and e['event']=='submit_handler' and e['mono_us']>=pp['mono_us']]
  if submits:
   sub=submits[0];res=get(actor,'submit_result',after=sub['mono_us'],value=1)
   add(row,'input_human_delay','폰 입력 준비→첫 제출 조작',pp,sub,kind='post_endpoint_human',lane=actor)
   add(row,'submit_completion','첫 제출 조작→성공 콜백',sub,res,kind='post_endpoint_request',lane=actor)
   for e in events:
    if e['role']==actor and e['event'] in ['card_selection_handler','submit_handler','submit_result']:
     INPUTS.append(dict(trial=row['trial'],role=actor,event=e['event'],seq=e['seq'],after_ready_s=(e['mono_us']-pp['mono_us'])/1e6,value=e.get('value')))
  if row['trial']=='menu_restart-2':row['user_note']='여러 번 선택 뒤 selection_seen=true; 첫 제출 뒤 선택 이벤트 관측. 시작 측정과 분리.'
  if cid=='015354-ef07417b':row['user_note']='사용자 목록에서 빠진 유효 수집; 사용자 동의로 추가. 회차 6은 식별 번호이며 촬영 시각 순서 아님.'
  TRIALS.append({k:v for k,v in row.items() if not k.startswith('_')})
  SOURCES.append(dict(trial=row['trial'],folder=name,hashes=integrity))

AGG=[]
for (scenario,metric),rows in __import__('itertools').groupby(sorted(STAGES,key=lambda r:(r['scenario'],r['metric'])),key=lambda r:(r['scenario'],r['metric'])):
 rows=list(rows);vals=[r['midpoint_s'] for r in rows]
 AGG.append(dict(scenario=scenario,metric=metric,label=rows[0]['label'],n=len(rows),median_s=statistics.median(vals),min_s=min(vals),max_s=max(vals),median_lower_s=statistics.median(r['lower_s'] for r in rows),median_upper_s=statistics.median(r['upper_s'] for r in rows)))
def csvwrite(name,rows):
 keys=list(dict.fromkeys(k for r in rows for k in r))
 with (OUT/name).open('w',newline='',encoding='utf-8-sig') as f:
  w=csv.DictWriter(f,keys);w.writeheader();w.writerows(rows)
for name,rows in [('stages.csv',STAGES),('stage_statistics.csv',AGG),('trials.csv',TRIALS),('commands.csv',CALLS),('timeline.csv',TIMELINE),('input_validation.csv',INPUTS)]:csvwrite(name,rows)
(OUT/'measurements.json').write_text(json.dumps(dict(unit='seconds; midpoint descriptive, bounds retained',trials=TRIALS,stages=STAGES,statistics=AGG,source_integrity=SOURCES),ensure_ascii=False,indent=2),encoding='utf-8')
for scenario in GROUPS:
 print('\n'+scenario)
 for r in AGG:
  if r['scenario']==scenario:print(f"{r['metric']:35} n={r['n']} {r['median_s']:.3f} [{r['min_s']:.3f},{r['max_s']:.3f}]")
