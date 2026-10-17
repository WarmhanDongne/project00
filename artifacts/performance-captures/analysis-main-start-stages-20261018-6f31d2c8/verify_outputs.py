"""Recheck provenance and arithmetic without touching captures."""
import json, hashlib, csv, statistics, sys, subprocess
from pathlib import Path
from collections import Counter,defaultdict
from pypdf import PdfReader
OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[2]
sys.path.insert(0,str(ROOT/'tool/startup_measurements'))
from measurement_analysis import analyze,host_range
data=json.loads((OUT/'measurements.json').read_text(encoding='utf-8'))
assert Counter(t['scenario'] for t in data['trials'])==dict(initial_start=6,menu_restart=5,result_restart=6)
assert len({t['original_capture'] for t in data['trials']})==17
events_by_trial={};hash_count=0;max_width=0
source_files=['packages/game_liars_poker/lib/phone/screens/game_screen.dart','packages/game_liars_poker/lib/phone/widgets/hand_card_stack.dart','packages/game_liars_poker/lib/shared/providers/game_controller.dart','packages/game_liars_poker/lib/tablet/src/board_state.dart','packages/game_kit/lib/player_layouts/widgets/player_layout_editor.dart']
source_hashes={f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest() for f in source_files}
for t,source in zip(data['trials'],data['source_integrity']):
 p=OUT.parent/t['folder']
 assert json.loads((p/'integrity.json').read_text())==source['hashes']
 for f,h in source['hashes'].items():
  assert hashlib.sha256((p/f).read_bytes()).hexdigest()==h,(t['trial'],f)
  hash_count+=1
 events=[json.loads(x) for x in (p/'events.sanitized.jsonl').read_text().splitlines()]
 mpath=p/'manifest.json'
 if mpath.exists():
  manifest=json.loads(mpath.read_text());clocks=manifest['clocks'];assert manifest['events']==len(events)
 else:clocks=json.loads((p/'clocks.json').read_text())
 original=json.loads((OUT.parent/t['original_capture']/'manifest.json').read_text())
 for f,h in source_hashes.items():assert original['working_copy_sources_sha256'][f]==h
 fresh=analyze(events,clocks,[]);saved=json.loads((p/'summary.json').read_text())
 for key in ['status','actual_scenario','total_elapsed_estimated_range_us','user_wait_excluded_total_estimated_range_us','exclusive_user_wait_estimated_range_us']:
  assert fresh[key]==saved[key],(t['trial'],key)
 assert all(fresh['progress']['input_validation'].values())
 assert saved['pilot_passed'] and fresh['status']=='VALID_OBSERVED_TRIAL'
 for key in ['total_elapsed_estimated_range_us','user_wait_excluded_total_estimated_range_us']:
  a,b=fresh[key];assert 0<=a<=b and b-a<=250000;max_width=max(max_width,b-a)
 for role in clocks:
  rows=sorted([e for e in events if e['role']==role],key=lambda e:e['seq'])
  assert rows[0]['event']=='armed' and rows[-1]['event']=='capture_stopped'
 events_by_trial[t['trial']]={(e['role'],e['seq']):e for e in events}
for row in data['stages']:
 assert row['lower_s']<=row['upper_s']
 if row['start_seq'] and row['end_seq'] and row['start_role']==row['end_role']:
  evs=events_by_trial[row['trial']]
  a,b=evs[row['start_role'],row['start_seq']],evs[row['end_role'],row['end_seq']]
  assert row['start_event']==a['event'] and row['end_event']==b['event']
  assert abs((b['mono_us']-a['mono_us'])/1e6-row['midpoint_s'])<1e-10
for s in data['statistics']:
 vals=[r['midpoint_s'] for r in data['stages'] if r['scenario']==s['scenario'] and r['metric']==s['metric']]
 assert len(vals)==s['n'] and statistics.median(vals)==s['median_s'] and min(vals)==s['min_s'] and max(vals)==s['max_s']
csv_rows=list(csv.DictReader((OUT/'stages.csv').open(encoding='utf-8-sig')))
assert len(csv_rows)==len(data['stages'])
doc=PdfReader(OUT/'REPORT.pdf');assert len(doc.pages)==2
for page in doc.pages:
 assert abs(float(page.mediabox.width)-595.2756)<.1 and abs(float(page.mediabox.height)-841.8898)<.1
text='\n'.join(p.extract_text() for p in doc.pages)
assert all(x in text for x in ['15.01','10.09','11.88','17건','5. 결정할 사항'])
late=[r for r in data['stages'] if r['metric']=='ready_response_minus_ready' and r['midpoint_s']>0]
assert len(late)==1 and late[0]['trial']=='initial_start-1'
assert len(list(csv.DictReader((OUT/'timeline.csv').open(encoding='utf-8-sig'))))==sum(t['events'] for t in data['trials'])
state=subprocess.run(['git','status','--short'],cwd=ROOT,capture_output=True,text=True,check=True).stdout.splitlines()
assert all(x.startswith('??') for x in state),'Unexpected tracked mutation'
validation=dict(status='PASS',exit_code=0,valid_samples=17,scenario_counts=dict(Counter(t['scenario'] for t in data['trials'])),original_file_hashes_checked=hash_count,event_count=sum(t['events'] for t in data['trials']),source_hashes_verified_in_all_17=source_hashes,max_estimation_width_ms=max_width/1000,pdf_pages=2,pdf_page_size='A4',visual_review='Both final rendered pages inspected: no clipping, overlaps or missing Korean glyphs',source_capture_modifications=False,product_source_modifications=False,full_validation='Not run: offline analysis only; user explicitly excluded FULL for temporary instrumentation',commands=[{'command':'Python 3.13 analyze.py','status':'PASS','exit_code':0},{'command':'Bundled Python build_report.py','status':'PASS','exit_code':0},{'command':'Poppler pdftoppm -scale-to 1600 -png REPORT.pdf','status':'PASS','exit_code':0},{'command':'Bundled Python verify_outputs.py','status':'PASS','exit_code':0}],working_tree_after=state)
(OUT/'validation.json').write_text(json.dumps(validation,ensure_ascii=False,indent=2),encoding='utf-8')
integrity={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(OUT.iterdir()) if p.is_file() and p.name!='integrity.json'}
(OUT/'integrity.json').write_text(json.dumps(integrity,indent=2),encoding='utf-8')
print(json.dumps({k:validation[k] for k in ['status','valid_samples','scenario_counts','original_file_hashes_checked','event_count','max_estimation_width_ms','pdf_pages']}))
