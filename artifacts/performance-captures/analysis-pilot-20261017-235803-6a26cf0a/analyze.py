"""Read-only audit of one saved pilot. Writes a new report, never raw captures."""
import collections
import copy
import hashlib
import json
import math
import secrets
import statistics
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tool/startup_measurements'))
from collect import validate_event
from measurement_analysis import analyze, host_range

SOURCE = ROOT / 'artifacts/performance-captures/debug-game-start-20261017-235803-e2abd37a'
OUT = ROOT / 'artifacts/performance-captures' / ('analysis-pilot-20261017-235803-' + secrets.token_hex(4))
OUT.mkdir(exist_ok=False)

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args], stderr=subprocess.DEVNULL).decode().strip()

before = {p.name: sha(p) for p in SOURCE.iterdir() if p.is_file()}
tracked_before = git('status', '--porcelain=v1', '--untracked-files=no')
m = json.loads((SOURCE / 'manifest.json').read_text())
s = json.loads((SOURCE / 'summary.json').read_text())
events = [json.loads(line) for line in (SOURCE / 'events.sanitized.jsonl').read_text().splitlines()]
integrity = json.loads((SOURCE / 'integrity.json').read_text())
assert all(sha(SOURCE / name) == digest for name, digest in integrity.items())
assert len(events) == m['events'] == 198
for e in events:
    validate_event(e, e['role'], m['capture'], 'trial-1')
source_matches = {name: sha(ROOT / name) == digest for name, digest in m['working_copy_sources_sha256'].items()}
assert all(source_matches.values())
raw = analyze(events, m['clocks'], [])
for key in ['status', 'issues', 'total_elapsed_estimated_range_us',
            'exclusive_user_wait_estimated_range_us', 'user_wait_excluded_total_estimated_range_us', 'progress']:
    assert raw[key] == s[key], key

# The user used this bundled Python for the capture. Its Windows monotonic
# source is GetTickCount64, resolution 15.625ms. Expand every host endpoint
# symmetrically by one resolution tick; retain original 5ms/200ppm allowances.
# This is conservative, not a certified physical-clock bound.
clock_info = vars(time.get_clock_info('monotonic'))
quantization_us = math.ceil(clock_info['resolution'] * 1_000_000)
assert quantization_us == 15625, 'Use the original bundled Python runtime to reproduce this audit'
expanded = copy.deepcopy(m['clocks'])
for probes in expanded.values():
    for p in probes:
        p['h0'] -= quantization_us
        p['h1'] += quantization_us
conservative = analyze(events, expanded, [])
assert conservative['status'] == 'VALID_OBSERVED_TRIAL'
assert conservative['total_elapsed_estimated_range_us'][1] - conservative['total_elapsed_estimated_range_us'][0] <= 250000

start = next(e for e in events if e['event'] == 'action_accepted')
start_host = host_range(start, expanded)
origin = sum(start_host) / 2
roles = {}
timeline = []
for role in m['roles']:
    local = [e for e in events if e['role'] == role]
    probes = m['clocks'][role]
    assert [e['seq'] for e in local] == list(range(1, len(local) + 1))
    assert all(b['mono_us'] >= a['mono_us'] for a, b in zip(local, local[1:]))
    assert len({e['process'] for e in local} | {p['process'] for p in probes}) == 1
    rtt = sorted(p['h1'] - p['h0'] for p in probes)
    roles[role] = {'events': len(local), 'probes': len(probes),
        'connection': 'Wi-Fi ADB (user-confirmed mapping)' if role == 'phone_B' else 'USB (user-confirmed mapping)',
        'rtt_us': {'min': min(rtt), 'median': statistics.median(rtt),
                   'p95_nearest_rank': rtt[math.ceil(.95 * len(rtt)) - 1], 'max': max(rtt)},
        'probes_over_100ms': sum(x > 100000 for x in rtt),
        'probes_over_250ms': sum(x > 250000 for x in rtt),
        'event_counts': dict(collections.Counter(e['event'] for e in local)),
        'largest_probe': max(probes, key=lambda p: p['h1'] - p['h0'])}
    for e in local:
        bounds = host_range(e, expanded)
        timeline.append({'role': role, 'event': e['event'], 'value': e.get('value'),
                         'request': e.get('request'), 'seq': e['seq'], 'mono_us': e['mono_us'],
                         'host_range_us': bounds,
                         'relative_midpoint_seconds': (sum(bounds) / 2 - origin) / 1e6 if bounds else None})

def event(role, name):
    return next(e for e in events if e['role'] == role and e['event'] == name)

def elapsed(role, a, b):
    return event(role, b)['mono_us'] - event(role, a)['mono_us']

local_stages = {
    'seat_save': elapsed('tablet', 'seat_save_start', 'seat_save_end'),
    'tablet_deck_entry': elapsed('tablet', 'tablet_deck_entry_started', 'tablet_deck_entry_completed'),
    'tablet_after_entry_until_tap': elapsed('tablet', 'tablet_deck_entry_completed', 'tablet_deck_tap_accepted'),
    'tablet_deal_animation': elapsed('tablet', 'tablet_deal_started', 'tablet_deal_animation_completed'),
    'tablet_callback_to_ready': elapsed('tablet', 'action_accepted', 'tablet_playing_frame'),
    'phone_B_pack_entry': elapsed('phone_B', 'pack_entry_started', 'pack_tappable_frame'),
    'phone_B_pack_wait': elapsed('phone_B', 'pack_tappable_frame', 'pack_tap_accepted'),
    'phone_B_reveal': elapsed('phone_B', 'pack_tap_accepted', 'reveal_completed'),
    'phone_B_pack_to_input_gate': elapsed('phone_B', 'pack_entry_started', 'phone_first_turn_playable_frame'),
    'phone_B_ready_response_after_input_gate': elapsed('phone_B', 'phone_first_turn_playable_frame', 'command_end'),
}
assert all(e['event'] not in {'card_selection_handler', 'submit_handler', 'submit_result'} for e in events)
data = {'capture': SOURCE.name, 'manifest_status': m['status'], 'events': len(events),
        'roles': roles, 'integrity': 'PASS', 'source_hash_matches': source_matches,
        'recorded_summary': s, 'conservative_analysis': conservative,
        'host_quantization_allowance_us_per_endpoint': quantization_us,
        'audited_runtime': {'python': sys.version.split()[0], 'monotonic': clock_info},
        'local_stages_us': local_stages, 'timeline': timeline,
        'user_confirmation': 'The user opened the card pack only; did not select or submit cards.',
        'input_pilot_passed': False,
        'git': {'branch': git('branch', '--show-current'), 'head': git('rev-parse', 'HEAD')},
        'limitations': ['One sample, no wireless-vs-USB crossover on the same phone.',
                        'Diagnostic RPC RTT includes VM/UI queue/PC scheduling and clock quantization, not pure Wi-Fi RTT.',
                        'No server-internal timing query; SDK command durations are not server-only.',
                        'Input completion is the code gate frame; physical selection/submission was not tested.',
                        'Source hash is a PC working-copy check, not installed APK attestation.']}
(OUT / 'analysis.json').write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')

total = conservative['total_elapsed_estimated_range_us']
adjusted = conservative['user_wait_excluded_total_estimated_range_us']
lines = ['# 3번 게임 시작 예비 수집 분석', '',
    '**세 기기 로그와 시작 시간 측정은 확보됐다. 실제 선택·제출을 하지 않아 예비 입력 검증은 아직 미통과다. 무선 수집은 PC 시계 해상도 여유를 추가해도 250ms 기준을 통과했다.**', '',
    f'대상: `{SOURCE.name}`, 2026-10-17 23:58 KST. 실제 경로 initial_start, 실행 조건 unspecified.',
    '원본 로그·메타데이터·자동 보고서는 수정하지 않았다. 사용자 확인: 카드팩만 펼쳤고 손패 선택·제출은 하지 않았다.', '',
    '## 수집 품질과 완료 판정', '',
    '- 태블릿 68개, 폰 A 63개, 폰 B 67개: 총 198개 이벤트. 각 기기 순번·단조 시각·process/clock 대응 정상.',
    '- integrity에 나열된 4개 파일 해시와 PC 소스 15개 해시 일치. 원본 전체 5개 파일 보존.',
    '- 조작 1회, 새 게임 alias 일치, 참여 폰 2대 모두 수집. 선공은 무선 폰 B다.',
    '- 태블릿 탭/배분과 선공 폰 입력 gate 완료가 모두 있음. 명령/전송 3개가 각각 1회 성공, 기록된 command_error 없음.',
    '- 원본 status=VALID_OBSERVED_TRIAL은 관측 시간 기준이다. pilot_requested=true이나 pilot_passed=false이며, 실제 선택·제출 검증은 별개다.', '',
    '## 측정 시간', '', '| 구간 | 결과 |', '| --- | ---: |',
    f'| 설정 완료 콜백 → 태블릿 진행 준비 | {local_stages["tablet_callback_to_ready"]/1e6:.3f}초 (같은 기기) |',
    f'| 설정 완료 콜백 → 태블릿·선공 B 모두 입력 준비 | {total[0]/1e6:.6f}~{total[1]/1e6:.6f}초 |',
    f'| 관측상 사용자 단독 대기 제외 | {adjusted[0]/1e6:.6f}~{adjusted[1]/1e6:.6f}초 |',
    f'| 전체 추정 범위 폭 | {(total[1]-total[0])/1000:.3f}ms / 기준 250ms |', '',
    '원본 자동 계산은 22.137113~22.174970초, 폭 37.857ms다. 사용한 번들 Python 3.12.14의',
    'Windows monotonic 시계가 GetTickCount64(), 해상도 15.625ms임을 같은 실행 파일에서 확인했다.',
    '관측 RTT가 0/15/16/31/32ms 단위인 것도 일치한다. 0ms는 실제 통신 지연이 없다는 뜻이 아니다.',
    '추가 감사에서는 각 host h0를 15.625ms 낮추고 h1을 15.625ms 높인 뒤 원래 5ms/200ppm 가정을 유지했다.',
    '위 표는 이 보수적 재계산값이다. 인증된 물리 시계 오차 보장을 뜻하지 않는다.', '',
    '제외 가능한 대기는 B의 카드팩 탭 대기 약 83.839ms다. 태블릿의 원시 탭 대기는 1.392초이며',
    '등장 연출 0.670초 뒤 대기는 0.721초다. 이때 세션 준비/확인·paused gate가 닫혀 있어',
    '사용자 단독 대기로 제외하지 않았다. A의 0.927초 탭 대기는 선공의 완료를 결정하지 않아 제외하지 않았다.',
    '따라서 대기 제외값을 순수 서버 처리 시간·CPU 시간·즉시 탭한 가상 실행으로 부르지 않는다.', '',
    '## 같은 기기의 주요 구간', '', '| 구간 | 소요 |', '| --- | ---: |',
    f'| 좌석 저장 | {local_stages["seat_save"]/1e6:.3f}초 |',
    '| start_game 앱 호출 → 반환 | 2.976초 |',
    '| complete_dealing 앱 호출 → 반환 | 2.970초 |',
    '| 선공 B ready_turn 앱 호출 → 반환 | 2.896초 |',
    f'| 태블릿 실제 배분 연출 | {local_stages["tablet_deal_animation"]/1e6:.3f}초 |',
    f'| B 카드팩 진입 | {local_stages["phone_B_pack_entry"]/1e6:.3f}초 |',
    f'| B 탭 → 카드 공개 완료 | {local_stages["phone_B_reveal"]/1e6:.3f}초 |', '',
    '명령 시간은 SDK·통신·서버·클라이언트 준비를 포함하며 서버 내부 시간이 아니다. 연출·요청은 병행하므로 합산하지 않는다.',
    'ready_turn은 공개 연출과 병행해 입력 gate보다 약 1.252초 늦게 반환됐다. 이 함수는 첫 턴 타이머 설정이며',
    '클라이언트 canSubmitCards와 서버 submit-card의 제출 조건은 ready_turn 응답 완료 자체를 요구하지 않는다.',
    '그러므로 그 응답 시각을 임의로 최종 완료점으로 교체하지 않았다. 실제 제출 수락은 이번에는 검증하지 않았다.', '',
    '## 무선 디버깅 지연', '',
    '연결 역할은 사용자 설명 기준: tablet/phone_A=USB, phone_B=Wi-Fi ADB. 원본 manifest는 serial/IP를 저장하지 않는다.', '',
    '| 기기 | clock probe 수 | 관측 RTT 중앙값 | p95(최근접 순위) | 최대 |',
    '| --- | ---: | ---: | ---: | ---: |']
for role, r in roles.items():
    q = r['rtt_us']
    lines.append(f'| {role} | {r["probes"]} | {q["median"]/1000:.1f}ms | {q["p95_nearest_rank"]/1000:.1f}ms | {q["max"]/1000:.1f}ms |')
lines += ['',
    '무선 B는 100ms 초과 probe가 2개, 250ms 초과가 1개였다. 최대 328ms는 시작 콜백 후 약 6.76초에 관측됐다.',
    '이 값은 PC↔ADB↔VM 진단 확장 호출의 왕복이며 앱 UI 큐·PC 스케줄링·시계 양자화도 포함한다.',
    '따라서 USB 대비 중앙값 차이를 정확한 순수 Wi-Fi 추가 지연으로 확정할 수 없다.',
    '250ms 기준은 개별 RPC 최대값이 아니라 전체 시간 추정 범위 폭이다. 328ms probe 하나가 있다는 이유만으로 전체가 무효가 되지는 않는다.',
    '이벤트 시각은 앱 Stopwatch에 기록하므로 로그가 PC에 늦게 도착한 시간을 게임 시간에 그대로 더하지 않는다.',
    'USB 태블릿의 두 게임 요청도 약 3초여서 게임 요청의 초 단위 소요 전체를 무선 디버깅 탓으로 볼 근거는 없다.',
    '단, 무선 수집 부하가 실제 앱/게임 네트워크 성능에 미친 영향은 동일 폰의 USB/무선 교차 시험 없이 분리할 수 없다.', '',
    '## 다음 진행', '',
    '1. 이번 자료는 보존·사용한다. 코드상 입력 준비 시간과 무선 수집 품질은 확인됐지만 실제 조작 pilot은 미완료다.',
    '2. 다음 예비 수집에서는 선공 폰에서 팩 공개 후 카드를 선택하고 위로 드래그해 제출 성공까지 기다린 뒤 종료한다.',
    '3. 새 APK 설치가 필요한 누락은 확인되지 않았다. PC 시계는 설치되어 있는 Python 3.13.11(QPC, 0.1µs 해상도)로 바꾸는 것을 권한다.',
    '   실행 파일 확인: C:\\Users\\USER\\.pyenv\\pyenv-win\\versions\\3.13.11\\python.exe. 수집 명령 구조는 유지한다.',
    '4. 한 번의 수집만으로 대표 성능·무선 추가 지연·서버 cold start는 확정하지 않는다. 현재 메뉴/결과 경로의 보완판 예비 수집도 별도다.', '',
    '## 보존 검증', '',
    f'branch `{data["git"]["branch"]}`, HEAD `{data["git"]["head"]}`. 원본 파일·tracked/index 상태 유지.',
    '새 운영 서버 조회·로그인·코드 수정·빌드·FULL은 수행하지 않았다. 분석 스크립트와 JSON 계산 근거를 별도로 보관한다.', '']
(OUT / 'REPORT.md').write_text('\n'.join(lines), encoding='utf-8')
shutil = __import__('shutil')
shutil.copyfile(__file__, OUT / 'analyze.py')
assert before == {p.name: sha(p) for p in SOURCE.iterdir() if p.is_file()}
assert git('status', '--porcelain=v1', '--untracked-files=no') == tracked_before
verification = {'status': 'PASS', 'exit_code': 0, 'source_files_unchanged': len(before),
                'listed_integrity_files_verified': len(integrity), 'events': len(events),
                'source_hashes_verified': len(source_matches), 'tracked_unchanged': True,
                'pilot_input_verification': 'NOT_PERFORMED_USER_CONFIRMED',
                'whole_timing_quality': 'PASS_250MS_WITH_ADDITIONAL_PC_QUANTIZATION_ALLOWANCE'}
(OUT / 'verification.json').write_text(json.dumps(verification, indent=2), encoding='utf-8')
(OUT / 'integrity.json').write_text(json.dumps({p.name: sha(p) for p in OUT.iterdir() if p.is_file()}, indent=2), encoding='utf-8')
print(json.dumps({'report': str(OUT / 'REPORT.md'), 'verification': verification,
                  'conservative_total_us': total, 'conservative_adjusted_us': adjusted}, ensure_ascii=False))
