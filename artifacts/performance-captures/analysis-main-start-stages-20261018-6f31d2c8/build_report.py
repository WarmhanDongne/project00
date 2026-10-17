"""Render a two-page Korean body; calculations and full evidence stay separate."""
import json, csv, statistics, hashlib, sys, html
from pathlib import Path
from collections import defaultdict
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import SimpleDocTemplate, Paragraph, Table, TableStyle, Spacer, PageBreak, Flowable

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[2]
DATA=json.loads((OUT/'measurements.json').read_text(encoding='utf-8'))
STATS={(s['scenario'],s['metric']):s for s in DATA['statistics']}
SCENARIOS=['initial_start','menu_restart','result_restart']
NAMES={'initial_start':'최초 시작','menu_restart':'메뉴 재시작','result_restart':'결과 재시작'}
TRIALS=DATA['trials']
TIMELINE=list(csv.DictReader((OUT/'timeline.csv').open(encoding='utf-8-sig')))
CMDS=list(csv.DictReader((OUT/'commands.csv').open(encoding='utf-8-sig')))
def stat(s,m):return STATS[s,m]
def fmt(s,m,br=False):
 d=stat(s,m)
 return f"{d['median_s']:.2f}"+('<br/>' if br else ' ')+f"({d['min_s']:.2f}~{d['max_s']:.2f})"
def mdtable(header,rows):
 return '\n'.join(['| '+' | '.join(header)+' |','| '+' | '.join(['---']*len(header))+' |']+['| '+' | '.join(map(str,row))+' |' for row in rows])

CONCLUSIONS=[
 '확인: 17건 모두 선공 폰이 마지막에 준비됐다. 전체 중앙값은 최초 15.01초, 메뉴 10.09초, 결과 11.88초다.',
 '주요 구간: 카드 배분 연출 약 2.82초, 손패 반영 후 폰 안내 약 3.64/1.94/3.63초가 흐름을 이어간다.',
 '개선 여지: 폰 안내의 직렬 배치와 배분 뒤 상태 전달은 검토 근거가 있다. 의도된 연출을 낭비로 판정한 것은 아니다.',
 '미확인: 요청 변동의 서버·인증·통신별 원인, 무선 ADB의 게임 성능 영향, 실제 단축 효과는 이번 자료로 분리할 수 없다.',
 '우선 행동: 폰 안내를 겹쳐도 되는지 결정하고, 배분 완료 통보부터 손패 반영까지의 원인을 좁힌 뒤 같은 조건으로 비교한다.'
]
SCOPE='대상: 10/18 예비 검증 뒤 유효 본 수집 17건(최초 6·메뉴 5·결과 6). 복구본 1건과 추가 승인된 결과 1건 포함. “최초”는 자리 배치 후 시작 경로이며 앱·서버의 첫 실행 조건을 뜻하지 않는다.'
SUMMARY_HEADERS=['경로 / 유효 n','전체 완료: 중앙값 (최소~최대)','사용자 단독 대기 제외','태블릿 준비 중앙값']
SUMMARY_ROWS=[[f"{NAMES[s]} / {sum(t['scenario']==s for t in TRIALS)}",fmt(s,'total'),fmt(s,'adjusted'),f"{stat(s,'tablet_ready')['median_s']:.2f}초"] for s in SCENARIOS]
SUMMARY_NOTE='단위: 초. 전체 완료는 버튼 콜백부터 태블릿·선공 폰 중 늦은 입력 준비 프레임까지다. 실제 제출은 포함하지 않는다. 대기 제외는 관측상 두 기기 모두 자동 작업 없이 사용자 탭만 기다린 구간을 한 번만 뺀 값이다. CPU 시간이나 즉시 탭했을 때의 예상 시간이 아니다.'
FLOW_NOTE='아래는 각 경로에서 중앙값에 가장 가까운 실제 1회다. 위·아래 줄은 동시에 흐른다. 폰의 “상태 대기”에는 태블릿 진행이 포함된다. 단계별 중앙값은 서로 다른 회차에서 올 수 있으므로 합산하지 않는다.'
SUBMIT_HEADERS=['별도 지표 / n=6·5·6','최초 시작','메뉴 재시작','결과 재시작']
SUBMIT_ROWS=[['입력 준비→첫 제출 조작 (사용자 행동)']+[fmt(s,'input_human_delay') for s in SCENARIOS],['첫 제출 조작→성공 콜백 (처리)']+[fmt(s,'submit_completion') for s in SCENARIOS]]

STAGE_DEFS=[
 ('action_to_deck','시작 처리·화면 이동','버튼 콜백→태블릿 카드 더미 탭 가능','선행 구간. 최초는 자리 저장·통신·착석/줌이 겹친다. 최초가 느린 것을 통신 탓만으로 볼 수 없다.'),
 ('tablet_entry','태블릿 카드 더미 등장','등장 시작→완료','자동 연출. 이번에는 모두 등장 뒤 탭했지만 원래 탭과 겹칠 수 있다.'),
 ('tablet_after_entry_wait','태블릿 탭 대기','등장 완료→실제 탭','배분 시작을 늦춘 사용자 행동. 아래 폰 대기와 무조건 합산·차감하지 않는다.'),
 ('tablet_deal','카드 배분','배분 시작→연출 종료','17건 모두 후속 상태 전달에 선행. 일정한 의도된 연출이며 성능 오류 증거는 없다.'),
 ('tablet_after_deal','태블릿 상태 반영·테이블 안내','배분 연출 종료→태블릿 준비 프레임','폰 흐름과 병행. 태블릿은 먼저 준비됐으므로 이 구간을 폰 완료 뒤에 더하지 않는다.'),
 ('deal_to_phone_data','손패 상태 전달·반영','배분 연출 종료→선공 폰 새 손패 반영','폰 안내의 선행 구간. 요청·네트워크·상태 적용이 섞여 있으며 순수 서버 시간은 아니다.'),
 ('phone_data_to_pack','폰 안내 후 카드팩 생성','새 손패 반영→카드팩 등장 시작','폰 완료 경로의 직렬 구간. 최초·결과는 GAME START 후 기준 카드 안내, 메뉴는 기준 카드 안내만 관측.'),
 ('phone_entry','폰 카드팩 도착 연출','카드팩 등장 시작→탭 가능','자동 연출. 입력 준비 경로에 있으나 제거가 필요한 낭비로 확인된 것은 아니다.'),
 ('phone_wait','폰 카드팩 탭 대기','탭 가능→실제 탭','사용자 행동. 이 시간 전체를 자동 처리 지연으로 세지 않는다.'),
 ('phone_reveal','폰 손패 공개','탭→공개 연출 종료','턴 준비 요청과 병행. 요청 시간을 별도로 더하지 않는다.'),
 ('phone_reveal_to_ready','최종 입력 준비','공개 연출 종료→선공 입력 준비 프레임','입력 준비는 조작부 등장 연출 전체 종료와 다르다. 작은 프레임·상태 반영 잔여 구간이다.')
]
PRIORITIES=[
 ('1. 폰 안내 구성','[사실] 손패 반영 뒤 3.64/1.94/3.63초. 최초·결과의 약 1.7초 GAME START가 추가로 관측됨.',
  '[제안] 시작 안내와 기준 카드 안내·카드팩 등장을 겹치거나 통합하는 시안 검토.',
  '17건 모두 폰이 마지막이어서 완료 경로와 연결된다. 다만 경로 간 차이는 인과 실험이 아니며 1.7초 단축을 보장하지 않는다. 정보 전달·첫 턴 규칙을 보존하는 UX 승인이 먼저다.'),
 ('2. 배분 뒤 상태 전달','[사실] 배분 종료→폰 손패 반영은 0.32~2.65초. 이 상태가 들어와야 폰 안내가 진행됨.',
  '[가설] 배분 완료 통보·승인·구독 반영의 어느 부분이 변동하는지 분리. 확인 후 중복 준비나 전달 대기 축소 검토.',
  '폰 안내의 선행 조건이므로 단축 후보 근거는 있다. 현재는 앱·서버·네트워크 원인을 분리하지 못했다. 요청별 서버 실행과 상태 도착을 연결하기 전에는 단축량을 제시하지 않는다.'),
 ('3. 최초 시작의 느린 1회',f"[사실] 버튼→카드 더미 7.01초(중앙 {stat('initial_start','action_to_deck')['median_s']:.2f}). 그 회차의 자리 저장 2.59초, 시작 요청 2.87초.",
  '[가설] 평소 겹쳐 가려지던 준비가 느려져 착석·화면 이동을 붙잡았을 수 있음. 먼저 조건과 요청 세부 시간 확인.',
  '이 구간은 전체 시작의 앞부분이다. 원인은 미확정이며 서버 첫 실행으로 단정하지 않는다. 연출을 줄이기 전에 요청 지연과 재현 조건을 확인한다.')
]
DECISION='지금 계획할 수 있는 것: 폰 안내 통합·병행 시안과 동일 조건 비교 기준. 추가 측정 뒤 결정할 것: 요청 처리 최적화의 구체적 위치·예상 단축량, 최초 느린 회차의 재현 대책. 의도된 배분 연출 자체는 이번 자료만으로 축소 대상으로 정하지 않는다.'
LIMIT='품질·한계: 17건 모두 해시·순번·게임/기기 연결·실제 선택/제출 검증 통과. 전체와 대기 제외 시간의 추정 범위 폭은 최대 0.145초(기준 0.250초). Debug 기준이며 Release 속도·프레임 품질을 뜻하지 않는다. 동일 기기·2폰 참여 조건을 유지하되 앱 재실행·캐시·네트워크 조건이 완전 통제된 시나리오 비교는 아니다.'

# Reusable body text. Exact evidence and definitions live in APPENDIX.md.
md=['# 게임 시작·재시작 단계별 성능 분석','', '2026-10-18 | Debug 본 수집 기준 | 본문 A4 2쪽 PDF와 같은 핵심 내용','', '## 1. 결론','']+CONCLUSIONS+['','## 2. 시나리오별 전체 흐름','',SCOPE,'',mdtable(SUMMARY_HEADERS,SUMMARY_ROWS),'',SUMMARY_NOTE,'',FLOW_NOTE,'','대표 흐름은 본문 PDF의 기기별 시간선으로 표시했다. 같은 시간축에서 위·아래 줄은 병행되고, 요청 띠는 연출 위에 겹쳐 표시된다.','']
for s in SCENARIOS:
 md += [f"- {NAMES[s]}: 버튼→태블릿 더미 {stat(s,'action_to_deck')['median_s']:.2f}초; 배분 {stat(s,'tablet_deal')['median_s']:.2f}초 뒤 폰 상태 반영 {stat(s,'deal_to_phone_data')['median_s']:.2f}초 → 폰 안내 {stat(s,'phone_data_to_pack')['median_s']:.2f}초 → 카드팩 등장 {stat(s,'phone_entry')['median_s']:.2f}초 → 사용자 탭 대기 {stat(s,'phone_wait')['median_s']:.2f}초 → 공개 {stat(s,'phone_reveal')['median_s']:.2f}초 → 입력 준비 잔여 {stat(s,'phone_reveal_to_ready')['median_s']:.2f}초. 이 값은 단계별 중앙값이며 전체 시간에 합산하지 않는다."]
md += ['',mdtable(SUBMIT_HEADERS,SUBMIT_ROWS),'','제출 처리에는 요청·상태 확인과 병행한 0.42초 카드 퇴장 연출도 포함된다. 순수 서버 시간이 아니다.','', '## 3. 단계별 측정','', '각 경로의 유효 n=6/5/6이며 아래 모든 단계에 적용한다. 각 값은 중앙값(최소~최대), 단위 초.','',mdtable(['단계 / 시작→종료','최초 n=6','메뉴 n=5','결과 n=6','완료에 미치는 영향 / 판단'], [[label+' / '+boundary]+[fmt(s,key) for s in SCENARIOS]+[judgment] for key,label,boundary,judgment in STAGE_DEFS]),'','## 4. 개선 후보 우선순위','',mdtable(['우선순위','문제와 근거','줄일 방법','전체 단축 근거 / 더 확인할 것'],PRIORITIES),'','## 5. 결정할 사항','',DECISION,'',LIMIT,'','계산식·파일 대응·상세 이벤트·개별값은 [부록](APPENDIX.md), 재사용 데이터는 [measurements.json](measurements.json)과 stages.csv에 분리했다.']
(OUT/'REPORT.md').write_text('\n'.join(md),encoding='utf-8')

# Detailed appendix: provenance, formulas, missingness and comparison contract.
appendix=['# 부록: 계산·검증·파일 대응','', '## A. 범위와 표본 선택','',
 '사용자가 제시한 최초 시작 6·메뉴 5·결과 5에, 추가 포함을 승인한 결과 재시작 015354-ef07417b 1건을 더했다. 총 17건이다. 게임 시작 3번의 복구본은 원본과 같은 시험이며 한 번만 센다. 결과 6번은 추가 식별 번호이고 수집 시각 순서가 아니다. 예비 수집과 실패 시도는 성능 중앙값에서 제외하지만 아래에 보존한다. 실패율 추정은 이번 보고서의 범위가 아니다.','',
 mdtable(['ID','원본/분석 폴더','선공','이벤트','조건'],[[t['trial'],t['folder'],t['first_turn_phone'],t['events'],t['condition']] for t in TRIALS]),'',
 '제외한 예비 수집: 002045-9b6b7c9b / 002756-323a0f5a / 002851-bc6fb4ee. 기존 영상을 기준으로 철회했던 수치는 사용하지 않았다.','',
 mdtable(['제외 기록','사유 / 근거'],[
 ['005259-48330e9b','수집 도중 FAILED, 209건. 유효 완료로 복구·검증하지 않아 제외.'],
 ['005434-e1faa81d','수집 준비 실패, 0건. 당시 failed_phase_clock_preflight 표기는 원인 분류의 한계가 있었음.'],
 ['010031-cd88cf80 원본','원본 FAILED 보존. 복구본 258건을 같은 시험 1건으로 대체하여 사용.'],
 ['012816-d5c02b32','연결 단계 실패 0건. 사용자 메모: 태블릿 연결하지 않고 실행.'],
 ['013223-0f3392e4','수집 중 시간 초과, 60건. B 종료 실패. 사용자 메모: 네트워크 오류 실패; 게임 서버 오류로 확정하지 않음.'],
 ['013519-5b2c6e88','이전 수집이 남아 arm 거절, 0건. already_armed.']]),'',
 '## B. 측정 경계와 계산식','',
 '시작: 태블릿의 action_accepted(최초는 설정 완료, 메뉴/결과는 해당 버튼의 실제 콜백). 종료: 새 게임에서 tablet_playing_frame과 실제 선공 phone_first_turn_playable_frame 중 늦은 것. 이번에는 17건 모두 폰 완료의 가능한 가장 이른 시각이 태블릿 완료의 가장 늦은 시각보다 뒤이므로 “폰이 마지막”이 시계 추정 범위로도 구분된다.','',
 '동일 기기 시간은 단조 시계의 종료−시작이다. CSV lower=upper는 저장된 시계 수치의 정확한 차이라는 뜻이며 물리적 계측 오차가 0이라는 뜻은 아니다. 서로 다른 기기는 host_range(가까운 clock 교환 5개, 200ppm 드리프트·기기당 5ms 여유)의 범위를 사용한다. 이벤트 X의 범위가 [XL,XU], Y가 [YL,YU]면 Δ=[YL−XU,YU−XL]. 시작 S, 태블릿 T, 폰 P에 대해 전체=[max(TL,PL)−SU, max(TU,PU)−SL].','',
 '보고서 대표값은 각 시험 범위의 중점이며 경로별 중앙값은 중점들의 중앙값이다. 최소~최대도 중점들의 최소~최대이고 신뢰구간·백분위가 아니다. 각 원시 추정 범위와 중앙값 하한·상한은 measurements.json/stage_statistics.csv에 보존한다. 단계 중앙값을 더해 전체 중앙값으로 만들지 않는다.','',
 '사용자 단독 대기: tablet/선공의 관측상 자동 작업 없음(명령 없음, 세션·route·foreground 허용)과 탭 대기 조건을 충족하는 시간 교집합을 구한 뒤 합집합으로 중복 제거한다. 태블릿 등장은 제외하지 않고, 폰의 관련 없는 다른 차례 대기는 더하지 않는다. 완전히 다른 기기의 유휴 범위 안에 들어간 동종 시계 대기는 단조 차이와 드리프트로 계산한다. 전체 대기 제외 범위=[max(0,전체L−대기U), 전체U−대기L]. 즉시 탭 가상 시험·CPU 시간·서버 단독 시간으로 해석하지 않는다.','',
 '폰 상태 반영 경계는 새 게임 alias의 선공 private_applied 첫 이벤트다. 이번 표본에서는 배분 연출 종료 뒤이면서 GAME START/공개 단계와 카드팩 등장 앞에 있다. 개인 payload나 손패 내용은 읽지 않았다. 초기 경로에서 첫 손패 반영→카드팩 생성 구간은 GAME START 및 기준 카드 안내와 프레임 전환을 포함한다. 기준 카드 안내만의 시작 이벤트는 없으므로 이 전체를 순수 애니메이션 실시간이라고 부르지 않는다. phone_stage=5→pack_entry_started는 안내 구간의 보조 근거다.','',
 '요청 논리 시간은 command_start→command_end이며 인증·준비·재시도·정리 등을 포함할 수 있다. attempt_start→attempt_end는 전송 경계이나 네트워크와 서버를 분리하지 못한다. 요청의 끝과 상태 적용의 도착 순서를 강제하지 않는다. 서버 중앙값을 앱 시간에서 빼지 않았다.','',
 '## C. 지표 사전','',
 mdtable(['metric','쉬운 이름','시작→종료'],[[key,label,boundary] for key,label,boundary,_ in STAGE_DEFS]+[
 ['seating_prepare','자리 저장·이동 전체','seating_prepare_start→seating_prepare_end; 요청/착석/배경 준비 병행 뒤 줌'],
 ['phone_controls','조작부 등장','controls_started→controls_completed; 입력 준비와 별도'],
 ['input_human_delay','완료 후 첫 제출까지 사용자 행동','선공 phone_first_turn_playable_frame→첫 submit_handler'],
 ['submit_completion','첫 제출 처리 성공','첫 submit_handler→다음 submit_result=1'],
 ['ready_response_minus_ready','입력 준비 대비 준비 응답 도착','command_end−phone_first_turn_playable_frame(양수는 응답이 나중)']]),'',
 '단계별 CSV에는 시작/종료 이벤트명·기기·seq, 범위, 분류, trial ID가 있다. aggregate 값은 단일 이벤트 쌍이 아니라 전체/교집합 계산이므로 이벤트 칸이 비어 있다. timelines의 target_game=false인 원게임/조작 전 이벤트는 새 게임의 손패 반영 구간에 사용하지 않는다.','',
 '## D. 상세 통계와 요청','']
for s in SCENARIOS:
 appendix += ['### '+NAMES[s],'',mdtable(['지표','n','중앙값','최소','최대'],[[d['metric'],d['n'],f"{d['median_s']:.6f}",f"{d['min_s']:.6f}",f"{d['max_s']:.6f}"] for d in DATA['statistics'] if d['scenario']==s]),'']
appendix += ['## E. 병행·원인 해석과 예외','',
 '16/17건의 선공 ready_turn 논리 응답은 손패 공개 및 입력 준비보다 먼저 끝났다. 최초 시작 1번은 반대로 논리 응답이 입력 준비보다 1.555388초 늦게 끝났지만, 실제 선택·제출 성공이 검증됐다. 따라서 이 응답 잔여를 시작 지연에 더하거나 “응답이 느렸으니 그만큼 입력이 막혔다”고 판정할 수 없다. 논리 응답과 상태 반영은 다른 이벤트다. 공개 연출 약 1.47초와 준비 요청 시간을 무조건 직렬로 세지 않는다.','',
 '조작부 등장 애니메이션은 약 0.93초지만 폰 입력 준비 프레임 이후에도 이어졌다. 현재 완료 기준은 실제 선택/제출 조건이지 조작부 모양이 완전히 정지한 시점이 아니다. 이를 바꾸면 이전 baseline과 같은 지표가 아니므로 별도 지표를 추가해야 한다.','',
 '메뉴 2의 특이사항: 선공 B 입력 준비 후 첫 제출 및 성공, 이후 선택 이벤트와 추가 제출 성공이 기록됐다. 원시 탭과 취소된 탭 전체를 기록한 것이 아니므로 처음 선택 시도가 무반응이었다는 원인을 복원하지 않는다. 선택 기록이 최종적으로 존재하므로 현재 예비 검증 기준은 통과한다. 검증을 통과했다는 사실과 UX 불편 가능성은 별개이며 메모를 보존한다. 최초 시작 3번에도 첫 제출 뒤 선택 이벤트가 있다. 코드상 탭 선택(_toggleSelection)은 card_selection_handler를 남기지만 직접 드래그(_startDragging)의 내부 선택은 이 이벤트를 남기지 않는다. 이런 입력 경로 차이가 있으므로 “선택 로그가 늦음”을 곧바로 수집 누락이나 선택 불능으로 판정하지 않는다.','',
 '제출 처리 시간은 순수 네트워크 왕복이 아니다. _submitSelectedCards는 요청과 카드 퇴장 연출을 병행하고, 420ms 퇴장 대기를 마친 뒤 요청 결과까지 확인하여 submit_result를 남긴다. 따라서 약 0.42초의 최솟값을 서버 지연이라고 해석하지 않는다.','',
 '최초 시작 1번은 전체 19.961초이고 배경·요청 준비 조건을 통제한 반복 검증 없이 서버 cold start라고 부를 수 없다. 포함/제외를 바꿔 좋은 결과만 고르지 않았다. 메뉴·결과의 차이 중 관측된 추가 GAME START는 구현 흐름과 일치하지만, 네트워크·앱 유지 조건·선공이 달라 경로 간 전체 차이를 연출 하나의 인과 효과로 간주하지 않는다.','',
 '무선 ADB는 계측 전송 경로이고 앱 게임 통신과 같은 지표가 아니다. 시계 추정 범위가 기준 이내라는 것과 무선 연결의 게임 처리 부하가 0이라는 것은 다르다. 유선 대 무선 통제 실험·Release frame profile은 없다. 실패 수집의 로컬 통신 오류를 서비스의 운영 실패율로 환산하지 않는다.','',
 '## F. 개선 전후 비교 계약','',
 '경로별로 본문의 총시간·관측상 대기 제외 시간·단계별 개별값을 비교한다. 최초/메뉴/결과를 합쳐 평균내지 않는다. 최초는 first_after_launch가 확인되지 않은 unspecified 6건이다. 추후는 앱 새 실행/유지, 동일 방/참여자 수·선공, 기기·Debug 구성, 연결 방식·망, 사용자 탭 지연을 기록하고 통제한다. 현재 baseline과 조건이 다르면 같은 조건의 새 baseline부터 확보한다. 서버 시작 조건은 별도 증거 없이 붙이지 않는다.','',
 '전체 시간이 줄었는지와 해당 단계가 줄었는지 둘 다 보고한다. 중앙값과 개별값·범위를 함께 남기고 표본이 작으므로 유의성·p95·운영 SLA를 주장하지 않는다. 선택/제출 성공을 유지하고 사용자 대기를 자동 지연으로 바꾸지 않는다. 단축 예상치는 현재 제시하지 않는다. 네트워크 원인 규명 시 요청 alias를 연결할 수 있는 최소 단계 계측/서버 조회를 별도 승인 범위에서 계획하고 이번 자료를 변경하지 않는다.','',
 '## G. 재사용 파일','',
 mdtable(['파일','용도'],[
 ['measurements.json','trial·단계·통계·원본 해시를 함께 담은 기준 데이터'],
 ['stages.csv','시험별 단계 시간 및 시작/종료 근거'],
 ['stage_statistics.csv','경로별 n/중앙값/범위 및 중앙값 하한·상한'],
 ['trials.csv','회차·기기 역할·복구·조건·사용자 메모'],
 ['commands.csv','개별 논리 요청 시간 및 버튼 상대 시작/종료'],
 ['timeline.csv','모든 정제 이벤트의 버튼 상대 시간 추정 범위'],
 ['input_validation.csv','선공 선택·제출·성공 이벤트의 입력 준비 이후 시각'],
 ['analyze.py / build_report.py','원본 읽기 전용 재계산 및 본문/부록/PDF 생성'],
 ['validation.json / integrity.json','검사 결과 및 이번 산출물 자체 해시']]),'',
 '## H. 실행·보존','',
 'Python 표준 라이브러리로 원본 파일별 해시·개수·schema/역할/게임 연결을 재검사하고 현재 strict 분석기를 실행했다. 참여자 커버리지·연속 순번·동일 process·단조 시각·종료 이벤트·실제 선택/제출을 확인했다. 해석에 사용한 phone/screens/game_screen.dart, phone/widgets/hand_card_stack.dart, shared/providers/game_controller.dart, tablet/src/board_state.dart, 공용 player_layout_editor.dart는 17건 모두 수집 당시 PC 소스 해시와 현재 해시가 일치했다. PC 소스 기록이며 설치 APK의 바이너리 동일성 증명은 아니다. 새 출력만 이 고유 폴더에 썼으며 원본·기존 보고서·제품 소스는 수정하지 않았다. 실기기 조작·서버 조회·설치·FULL 검증은 하지 않았다. PDF 작성은 번들 ReportLab/맑은 고딕을 사용했다. 실행과 시각 검사는 validation.json에 기록한다.','',
 '본문 수치는 보기 좋게 0.01초로 반올림했지만 인증된 물리 오차가 0.01초라는 뜻은 아니다. 계산 원본의 추정 범위 폭은 최대 0.144996초다.']
(OUT/'APPENDIX.md').write_text('\n'.join(appendix),encoding='utf-8')

# PDF layout: separate explicit pages, no appendix content in the two-page body.
pdfmetrics.registerFont(TTFont('Malgun',r'C:\Windows\Fonts\malgun.ttf'))
pdfmetrics.registerFont(TTFont('MalgunBold',r'C:\Windows\Fonts\malgunbd.ttf'))
INK=colors.HexColor('#183344'); TEAL=colors.HexColor('#238E93'); BLUE=colors.HexColor('#769BDC'); ORANGE=colors.HexColor('#E9AF60'); PALE=colors.HexColor('#EEF3F6'); GRAY=colors.HexColor('#C6D0D5')
W=A4[0]-68
styles={
 'title':ParagraphStyle('title',fontName='MalgunBold',fontSize=18,leading=23,textColor=INK,spaceAfter=6,wordWrap='CJK'),
 'sub':ParagraphStyle('sub',fontName='Malgun',fontSize=8,leading=11,textColor=colors.HexColor('#526471'),spaceAfter=5,wordWrap='CJK'),
 'body':ParagraphStyle('body',fontName='Malgun',fontSize=8.5,leading=12.2,textColor=INK,spaceAfter=4,wordWrap='CJK'),
 'small':ParagraphStyle('small',fontName='Malgun',fontSize=7.6,leading=10.6,textColor=INK,spaceAfter=4,wordWrap='CJK'),
 'h':ParagraphStyle('h',fontName='MalgunBold',fontSize=11,leading=15,textColor=INK,spaceBefore=6,spaceAfter=5,wordWrap='CJK'),
 'cell':ParagraphStyle('cell',fontName='Malgun',fontSize=7.6,leading=10.5,textColor=INK,wordWrap='CJK'),
 'head':ParagraphStyle('head',fontName='MalgunBold',fontSize=7.8,leading=11,textColor=colors.white,wordWrap='CJK')}
def p(text,style='body'):return Paragraph(text,styles[style])
def table(headers,rows,widths):
 data=[[p(x,'head') for x in headers]]+[[p(str(x),'cell') for x in row] for row in rows]
 t=Table(data,colWidths=widths,hAlign='LEFT')
 t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),INK),('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),5),('RIGHTPADDING',(0,0),(-1,-1),5),('TOPPADDING',(0,0),(-1,-1),4),('BOTTOMPADDING',(0,0),(-1,-1),4),('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.white,PALE]),('LINEBELOW',(0,1),(-1,-1),.3,colors.HexColor('#D6E0E4'))]))
 return t

REPRESENTATIVES=[]
class LaneChart(Flowable):
 def __init__(self,s):
  Flowable.__init__(self);self.width=W;self.height=66;self.s=s
  trials=[t for t in TRIALS if t['scenario']==s]
  metrics={r['trial']:r['midpoint_s'] for r in DATA['stages'] if r['metric']=='total'}
  self.t=min(trials,key=lambda t:abs(metrics[t['trial']]-stat(s,'total')['median_s']))
  self.total=metrics[self.t['trial']]
  REPRESENTATIVES.append(dict(scenario=s,trial=self.t['trial'],total_s=self.total))
 def draw(self):
  c=self.canv;t=self.t;s=self.s
  rows=[e for e in TIMELINE if e['trial']==t['trial']]
  def ev(role,name):
   candidates=[e for e in rows if e['role']==role and e['event']==name and e['target_game']=='True']
   return float(candidates[0]['relative_midpoint_s'])
  role=t['first_turn_phone'];x0=43;scale=(W-x0-4)/21
  c.setFont('MalgunBold',8);c.setFillColor(INK)
  c.drawString(0,56,f"{NAMES[s]}  대표 {self.total:.2f}초")
  c.setFont('Malgun',6.4)
  for tick in [0,5,10,15,20]:
   c.setStrokeColor(PALE);c.line(x0+tick*scale,8,x0+tick*scale,49)
   c.setFillColor(INK);c.drawString(x0+tick*scale-2,0,str(tick)+'초')
  de=ev('tablet','tablet_deck_tappable_frame');en=ev('tablet','tablet_deck_entry_completed');tap=ev('tablet','tablet_deck_tap_accepted');deal=ev('tablet','tablet_deal_animation_completed');tr=ev('tablet','tablet_playing_frame')
  priv=ev(role,'private_applied');pe=ev(role,'pack_entry_started');pt=ev(role,'pack_tappable_frame');pa=ev(role,'pack_tap_accepted');rev=ev(role,'reveal_completed');pr=ev(role,'phone_first_turn_playable_frame')
  def bar(y,a,b,color,label=''):
   if b<=a:return
   c.setFillColor(color);c.rect(x0+a*scale,y,(b-a)*scale,12,stroke=0,fill=1)
   if label and (b-a)*scale>pdfmetrics.stringWidth(label,'Malgun',6.5)+4:
    c.setFont('Malgun',6.5);c.setFillColor(colors.white if color==TEAL else INK);c.drawCentredString(x0+(a+b)*scale/2,y+3,label)
  c.setFont('Malgun',7);c.setFillColor(INK);c.drawString(0,35,'태블릿');c.drawString(0,15,'선공 폰')
  for a,b,col,label in [(0,de,TEAL,'시작·이동'),(de,en,BLUE,''),(en,tap,ORANGE,''),(tap,deal,BLUE,'카드 배분'),(deal,tr,TEAL,'상태·안내'),(tr,self.total,GRAY,'태블릿 준비됨')]:bar(32,a,b,col,label)
  for a,b,col,label in [(0,priv,PALE,'태블릿 진행·상태 대기'),(priv,pe,BLUE,'폰 안내'),(pe,pt,BLUE,''),(pt,pa,ORANGE,''),(pa,rev,BLUE,'공개'),(rev,pr,TEAL,'')]:bar(12,a,b,col,label)
  calls=[r for r in CMDS if r['trial']==t['trial'] and r['role']==role and r['command'].endswith('ready_turn')]
  for call in calls:
   a,b=float(call['start_relative_s']),float(call['end_relative_s'])
   c.setStrokeColor(TEAL);c.setLineWidth(2.3);c.line(x0+a*scale,27,x0+b*scale,27)
   c.setFont('Malgun',6.3);c.setFillColor(TEAL);c.drawString(x0+a*scale,28.5,'준비 요청')

story=[p('게임 시작·재시작 단계별 성능 분석','title'),p('Debug 본 수집 기준 · 2026.10.18 · 본문 1/2','sub'),p('1. 결론','h')]
for i,text in enumerate(CONCLUSIONS,1):story.append(p(str(i)+'. '+text))
story += [p('2. 시나리오별 전체 흐름','h'),p(SCOPE,'small'),table(SUMMARY_HEADERS,[[r[0],r[1]+'초',r[2]+'초',r[3]] for r in SUMMARY_ROWS],[82,157,166,W-405]),p(SUMMARY_NOTE,'small'),p(FLOW_NOTE,'small'),p('청록: 요청·상태/혼합  |  파랑: 자동 연출  |  주황: 사용자 대기  |  회색: 준비됨','small')]
for s in SCENARIOS:story.append(LaneChart(s))
story += [p('실제 카드 제출은 시작 시간과 별도로 본다','h'),table(SUBMIT_HEADERS,SUBMIT_ROWS,[169,(W-169)/3,(W-169)/3,(W-169)/3]),p('선공 폰의 첫 제출만 집계. 처리에는 전송·상태 확인과 병행한 0.42초 카드 퇴장 연출도 포함된다. 순수 서버 시간이 아니다. 사용자가 고르는 시간은 시작 지연에 넣지 않는다.','small'),PageBreak(),p('3. 단계별 측정','h'),p('초 단위 중앙값 (최소~최대). 각 행의 유효 수: 최초 n=6 / 메뉴 n=5 / 결과 n=6. 각 단계는 아래 경계로 따로 측정했다.','small')]
stage_rows=[]
for key,label,boundary,judgment in STAGE_DEFS:
 stage_rows.append([label+'<br/>'+boundary]+[fmt(s,key,True) for s in SCENARIOS]+[judgment])
story += [table(['단계 / 시작→종료','최초 n=6','메뉴 n=5','결과 n=6','전체 완료에 미치는 영향 / 현재 판단'],stage_rows,[117,70,70,70,W-327]),p('요청 자체와 후속 상태 반영, 연출은 겹칠 수 있다. 준비 요청 응답은 16/17건에서 공개 연출보다 먼저 끝났고, 나머지 1건은 입력 준비 뒤에 끝났다. 응답 시간을 그대로 시작 지연에 더하지 않는다. 조작부 등장 약 0.93초도 입력 준비 이후까지 이어져 별도 지표로 보존했다.','small'),p('4. 개선 후보 우선순위','h'),table(['후보','문제·근거 / 줄일 방법','전체 단축 근거 / 확인할 사항'],[[r[0],r[1]+'<br/>'+r[2],r[3]] for r in PRIORITIES],[75,211,W-286]),p('5. 결정할 사항','h'),p(DECISION),p(LIMIT,'small'),p('계산식·원본 파일 대응·개별값·상세 이벤트는 별도 APPENDIX.md와 CSV/JSON에 보존했다. 본문은 개선 방향 판단용이며 기대 단축량이나 운영 성능 보장은 제시하지 않는다.','small')]

def footer(c,doc):
 c.saveState();c.setStrokeColor(colors.HexColor('#CEDADF'));c.line(34,31,A4[0]-34,31)
 c.setFont('Malgun',7);c.setFillColor(INK);c.drawString(34,20,'Mosigame | 로컬 Debug 계측 · 17건 | 원본 보존')
 c.drawRightString(A4[0]-34,20,str(doc.page));c.restoreState()
SimpleDocTemplate(str(OUT/'REPORT.pdf'),pagesize=A4,rightMargin=34,leftMargin=34,topMargin=28,bottomMargin=39,title='게임 시작·재시작 단계별 성능 분석',author='Mosigame').build(story,onFirstPage=footer,onLaterPages=footer)
(OUT/'representative_flows.json').write_text(json.dumps(REPRESENTATIVES,ensure_ascii=False,indent=2),encoding='utf-8')
print('Created REPORT.pdf, REPORT.md, APPENDIX.md')
