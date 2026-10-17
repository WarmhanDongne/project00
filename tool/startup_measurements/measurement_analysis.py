"""Version 2 analysis. Local intervals first; uncertain cross-device intervals second."""
MAX_CLOCK_WIDTH_US = 250_000  # User approved on 2026-10-17; never applied to v1.


def clock_offset(probes):
    if len(probes) < 2 or len({p['process'] for p in probes}) != 1:
        return None
    span = max(p['h1'] for p in probes) - min(p['h0'] for p in probes)
    margin = 5000 + int(span * .0002)
    low = max(p['h0'] - p['mono_us'] for p in probes) - margin
    high = min(p['h1'] - p['mono_us'] for p in probes) + margin
    return [low, high] if low <= high else None


def host_range(event, clocks):
    probes = clocks.get(event['role'], [])
    if clock_offset(probes) is None or any(p['process'] != event['process'] for p in probes):
        return None
    # More exchanges reduce queue/HTTP overhead uncertainty without moving clocks.
    near = sorted(probes, key=lambda p: abs(p['mono_us'] - event['mono_us']))[:5]
    low, high = [], []
    for p in near:
        margin = 5000 + int(abs(p['mono_us'] - event['mono_us']) * .0002)
        low.append(event['mono_us'] + p['h0'] - p['mono_us'] - margin)
        high.append(event['mono_us'] + p['h1'] - p['mono_us'] + margin)
    return [max(low), min(high)] if max(low) <= min(high) else None


def union_length(segments):
    merged = []
    for start, end in sorted(segments):
        if end <= start:
            continue
        if merged and start <= merged[-1][1]:
            merged[-1][1] = max(merged[-1][1], end)
        else:
            merged.append([start, end])
    return sum(end - start for start, end in merged)


def fully_covered_wait_duration(t_idle, p_idle, clocks, start, finish):
    """Preserve same-clock duration when cross-device ordering is unambiguous.

    If every candidate wait is wholly inside an idle interval of the other
    device, and all such waits are provably disjoint, offsets cancel from each
    local duration (retaining the 200ppm drift allowance). Otherwise use the
    interval intersection/union below.
    """
    covered = []
    for own, other in [(t_idle, p_idle), (p_idle, t_idle)]:
        for a, b, wait in own:
            if not wait:
                continue
            ar, br = host_range(a, clocks), host_range(b, clocks)
            if not ar or not br or ar[0] < start[1] or br[1] > finish[0]:
                return None
            if not any(cr and dr and cr[1] <= ar[0] and dr[0] >= br[1]
                       for c, d, _ in other
                       for cr, dr in [(host_range(c, clocks), host_range(d, clocks))]):
                return None
            covered.append((ar[0], br[1], b['mono_us'] - a['mono_us']))
    covered.sort()
    if any(a[1] > b[0] for a, b in zip(covered, covered[1:])):
        return None
    duration = sum(s[2] for s in covered)
    drift = (duration + 4999) // 5000
    return [max(0, duration - drift), duration + drift]


def idle_segments(local, tablet):
    """Observed quiescence, not hypothetical instant-tap performance or CPU time.

    Idle requires no pending game commands, all composite session gates open,
    current route and foreground. Entry/reveal/controls remain automatic work.
    Tablet waiting is eligible only after deck entry; early taps have zero wait.
    """
    state, previous, result = {}, None, []
    prompt = entry_done = unknown = False
    for e in local:
        if previous is not None:
            clear = (state.get('pending_commands') == 0 and state.get('foreground') == 1
                     and state.get('session_blockers') == 0 and state.get('startup_uncovered') == 1)
            wait = prompt and entry_done
            if wait and not {'pending_commands', 'foreground', 'session_blockers', 'startup_uncovered'}.issubset(state):
                unknown = True
            ready = state.get('tablet_gate') == 1 if tablet else (
                state.get('phone_gate') == 15 and state.get('hand_gate') == 3)
            idle = ready or wait or (not tablet and state.get('phone_waiting_for_deal') == 1)
            if clear and idle and e['mono_us'] > previous['mono_us']:
                if result and result[-1][1] == previous and result[-1][2] == wait:
                    result[-1][1] = e
                else:
                    result.append([previous, e, wait])
        name = e['event']
        if 'value' in e:
            state[name] = e['value']
        if name == ('tablet_deck_tappable_frame' if tablet else 'pack_tappable_frame'):
            prompt = True
            if not tablet:
                entry_done = True
        if name == 'tablet_deck_entry_completed':
            entry_done = True
        if name == ('tablet_deck_tap_accepted' if tablet else 'pack_tap_accepted'):
            prompt = False
        previous = e
    return result, unknown


def analyze(events, clocks, issues):
    issues, warnings = list(issues), []
    roles = set(clocks)
    local = {role: sorted((e for e in events if e['role'] == role), key=lambda e: e['seq']) for role in roles}
    for role, rows in local.items():
        if [e['seq'] for e in rows] != list(range(1, len(rows) + 1)):
            issues.append('event_sequence_gap')
        if any(b['mono_us'] < a['mono_us'] for a, b in zip(rows, rows[1:])):
            issues.append('non_monotonic_events')
        if not rows or len({e['process'] for e in rows}) != 1:
            issues.append('missing_or_replaced_process')
        if any(e.get('schema') != 2 for e in rows):
            issues.append('unsupported_measurement_protocol')
    starts = [e for e in events if e['event'] == 'action_accepted' and e['role'] == 'tablet']
    if len(starts) != 1:
        issues.append('expected_one_action')
    actual = starts[0].get('source') if len(starts) == 1 else None
    if actual not in {'initial_start', 'menu_restart', 'result_restart'}:
        issues.append('missing_actual_action_source')
    elif actual != starts[0]['scenario']:
        warnings.append('scenario_mismatch_actual_source_used')
    games = {e['game'] for e in events if e['event'] == 'game_bound'}
    target = next(iter(games)) if len(games) == 1 else None
    if target is None:
        issues.append('unmatched_or_multiple_games')
    for role in roles:
        if len([e for e in local[role] if e['event'] == 'game_bound' and e['game'] == target]) != 1:
            issues.append('device_missing_target_game')
    if any(e['event'] == 'game_replaced' or
           (e['event'] == 'foreground' and e.get('value') == 0) for e in events):
        issues.append('game_or_lifecycle_interrupted')
    # Composite gates can drop briefly at a normal revision change. Keep them as
    # diagnostics, never infer a network error or invalidate all timing from this.
    gates = [{'role': e['role'], 'mono_us': e['mono_us'], 'mask': e['value']}
             for e in events if e['event'] == 'session_blockers']
    counts = {e['value'] for e in events if e['event'] == 'participant_count' and e['game'] == target}
    if counts != {len(roles) - 1}:
        issues.append('participant_phone_coverage_unconfirmed')
    selected = [e for e in events if e['game'] == target]
    tablet = [e for e in selected if e['event'] == 'tablet_playing_frame' and e['role'] == 'tablet']
    phone = [e for e in selected if e['event'] == 'phone_first_turn_playable_frame' and e['role'] != 'tablet']
    if len(tablet) != 1 or len(phone) != 1:
        issues.append('missing_or_ambiguous_completion')
    actor = phone[0]['role'] if len(phone) == 1 else None

    def one(role, name):
        rows = [e for e in selected if e['role'] == role and e['event'] == name]
        if len(rows) != 1:
            issues.append('missing_or_duplicate_' + name)
            return None
        return rows[0]

    t_names = ['tablet_deck_tappable_frame', 'tablet_deck_entry_started',
               'tablet_deck_entry_completed', 'tablet_deck_tap_accepted',
               'tablet_deal_started', 'tablet_deal_animation_completed', 'tablet_deal_completed',
               'tablet_playing_frame']
    p_names = ['pack_entry_started', 'pack_tappable_frame', 'pack_tap_accepted', 'reveal_completed']
    milestones = {'tablet': {name: one('tablet', name) for name in t_names}}
    if actor:
        milestones[actor] = {name: one(actor, name) for name in p_names}
        phone_rows = [e for e in selected if e['role'] == actor and e['mono_us'] <= phone[0]['mono_us']]
        states = {e['event']: e['value'] for e in phone_rows if 'value' in e}
        if (states.get('phone_gate') != 15 or states.get('hand_gate') != 3
                or states.get('session_blockers') != 0):
            issues.append('first_turn_input_gates_unconfirmed')
    # Validate the causal ordering while allowing the tablet tap during entry.
    t = milestones['tablet']
    chains = [[t[n] for n in ['tablet_deck_entry_started', 'tablet_deck_entry_completed',
                              'tablet_deal_started', 'tablet_deal_animation_completed', 'tablet_deal_completed']],
              [t[n] for n in ['tablet_deck_tappable_frame', 'tablet_deck_tap_accepted', 'tablet_deal_started']]]
    if actor:
        chains.append([milestones[actor][n] for n in p_names] + phone)
    for chain in chains:
        if all(chain) and any(b['mono_us'] < a['mono_us'] for a, b in zip(chain, chain[1:])):
            issues.append('invalid_milestone_order')

    calls, attempts, raw_waits, stages = [], [], [], []
    for role, rows in local.items():
        pending, transmitting, prompts = {}, {}, {}
        for e in rows:
            name = e['event']
            if name == 'command_start':
                pending[e['request']] = e
            elif name == 'command_end':
                begin = pending.pop(e['request'], None)
                if begin:
                    calls.append({'role': role, 'request': e['request'], 'game': begin['game'],
                                  'action': begin['action'], 'command': begin['command'],
                                  'start_us': begin['mono_us'], 'end_us': e['mono_us'],
                                  'elapsed_us': e['mono_us'] - begin['mono_us'], 'outcome': e.get('value')})
            elif name == 'attempt_start':
                transmitting[e['request']] = e
            elif name == 'attempt_end':
                begin = transmitting.pop(e['request'], None)
                if begin:
                    attempts.append({'role': role, 'request': e['request'], 'attempt': begin['value'],
                                     'elapsed_us': e['mono_us'] - begin['mono_us'], 'outcome': e.get('value')})
            elif name in {'tablet_deck_tappable_frame', 'pack_tappable_frame'}:
                prompts[e['game']] = e
            elif name in {'tablet_deck_tap_accepted', 'pack_tap_accepted'}:
                begin = prompts.pop(e['game'], None)
                if begin:
                    raw_waits.append({'role': role, 'elapsed_us': e['mono_us'] - begin['mono_us'],
                                      'classification': 'raw_prompt_wait_including_parallel_work'})
        for request, begin in pending.items():
            calls.append({'role': role, 'request': request, 'command': begin['command'], 'status': 'INCOMPLETE'})
        if transmitting:
            warnings.append('unfinished_transport_attempt')
        if prompts:
            warnings.append('untapped_pack_' + role)
    for role, ms in milestones.items():
        for a, b in zip(list(ms.values()), list(ms.values())[1:]):
            if a and b and b['mono_us'] >= a['mono_us']:
                stages.append({'role': role, 'from': a['event'], 'to': b['event'],
                               'elapsed_us': b['mono_us'] - a['mono_us']})
    if len(starts) == 1:
        for end in (t.get('tablet_deck_tappable_frame'), tablet[0] if len(tablet) == 1 else None):
            if end and end['mono_us'] >= starts[0]['mono_us']:
                stages.append({'role': 'tablet', 'from': 'action_accepted', 'to': end['event'],
                               'elapsed_us': end['mono_us'] - starts[0]['mono_us']})
    for role in roles - {'tablet'}:
        for begin_name, end_name in [('controls_started', 'controls_completed')]:
            begins = [e for e in selected if e['role'] == role and e['event'] == begin_name]
            ends = [e for e in selected if e['role'] == role and e['event'] == end_name]
            if len(begins) == len(ends) == 1 and ends[0]['mono_us'] >= begins[0]['mono_us']:
                stages.append({'role': role, 'from': begin_name, 'to': end_name,
                               'elapsed_us': ends[0]['mono_us'] - begins[0]['mono_us']})
    for call in calls:
        links = {e['link'] for e in local[call['role']] if e['event'] == 'request_link'
                 and e['request'] == call['request']}
        call['request_alias'] = next(iter(links)) if len(links) == 1 else None
        if len(links) > 1:
            issues.append('logical_command_alias_changed')
    # Successful root start, completed dealing and first-turn ready must be present.
    required_commands = [('tablet', 'game_liars_poker_start_game'),
                         ('tablet', 'game_liars_poker_complete_dealing')]
    if actor:
        required_commands.append((actor, 'game_liars_poker_ready_turn'))
    for role, command in required_commands:
        matches = [c for c in calls if c['role'] == role and c['command'] == command and c.get('outcome') == 1
                   and (command == 'game_liars_poker_start_game' or c.get('game') == target)]
        if not matches:
            issues.append('missing_successful_' + command)
    root_calls = [c for c in calls if c['role'] == 'tablet' and c['command'] == 'game_liars_poker_start_game']
    if len(root_calls) != 1 or (len(starts) == 1 and
        (root_calls[0].get('action') != starts[0]['action'] or
         root_calls[0].get('start_us', -1) < starts[0]['mono_us'])):
        issues.append('ambiguous_root_start_command')
    total, adjusted, exclusive = None, None, None
    observed_total = None
    if len(starts) == len(tablet) == len(phone) == 1:
        start, te, pe = (host_range(e, clocks) for e in [starts[0], tablet[0], phone[0]])
        if start and te and pe:
            observed_total = [max(te[0], pe[0]) - start[1], max(te[1], pe[1]) - start[0]]
            if observed_total[0] < 0 or observed_total[1] - observed_total[0] > MAX_CLOCK_WIDTH_US:
                issues.append('cross_device_clock_quality_failed')
        else:
            issues.append('cross_device_clock_unavailable')
    if not issues and observed_total is not None:
        total = observed_total
        t_idle, t_unknown = idle_segments([e for e in local['tablet'] if e['game'] == target], True)
        p_idle, p_unknown = idle_segments([e for e in local[actor] if e['game'] == target], False)
        guaranteed, possible = [], []
        for ts, tend, tw in t_idle:
            for ps, pend, pw in p_idle:
                if not (tw or pw):
                    continue
                ranges = [host_range(e, clocks) for e in [ts, tend, ps, pend]]
                if not all(ranges):
                    continue
                a, b, c, d = ranges
                # Intersect quiescent intervals of both relevant devices, then
                # union across all waits: simultaneous waits are excluded once.
                guaranteed.append([max(a[1], c[1], start[1]), min(b[0], d[0], max(te[0], pe[0]))])
                possible.append([max(a[0], c[0], start[0]), min(b[1], d[1], max(te[1], pe[1]))])
        exclusive = [union_length(guaranteed), union_length(possible)]
        exact_local = fully_covered_wait_duration(t_idle, p_idle, clocks, start,
                                                  [max(te[0], pe[0]), max(te[1], pe[1])])
        if exact_local is not None:
            exclusive = exact_local
        adjusted_bounds = [max(0, total[0] - exclusive[1]), total[1] - exclusive[0]]
        if t_unknown or p_unknown:
            warnings.append('missing_wait_classification_gates')
            exclusive = None
        elif adjusted_bounds[1] >= adjusted_bounds[0] and adjusted_bounds[1] - adjusted_bounds[0] <= MAX_CLOCK_WIDTH_US:
            adjusted = adjusted_bounds
        else:
            warnings.append('adjusted_clock_quality_failed')
    validation = {'selection_seen': False, 'submission_seen': False, 'submission_succeeded': False}
    if actor:
        after = [e for e in local[actor] if e['game'] == target and e['mono_us'] >= phone[0]['mono_us']]
        validation = {'selection_seen': any(e['event'] == 'card_selection_handler' for e in after),
                      'submission_seen': any(e['event'] == 'submit_handler' for e in after),
                      'submission_succeeded': any(e['event'] == 'submit_result' and e['value'] == 1 for e in after)}
    return {'protocol': 2, 'status': 'VALID_OBSERVED_TRIAL' if total else 'INCOMPLETE_OR_INVALID',
            'quality_limit_us': MAX_CLOCK_WIDTH_US, 'actual_scenario': actual,
            'issues': sorted(set(issues)), 'warnings': sorted(set(warnings)),
            'progress': {'tablet_completed': len(tablet) == 1, 'first_turn_phone': actor,
                         'input_validation': validation},
            'total_elapsed_estimated_range_us': total,
            'observed_total_reference_range_us': observed_total,
            'exclusive_user_wait_estimated_range_us': exclusive,
            'user_wait_excluded_total_estimated_range_us': adjusted,
            'user_wait_excluded_reason': 'Only observed joint quiescence with a pending user tap is excluded; not CPU time or a simulated instant-tap run',
            'clock_offset_estimates_us': {r: clock_offset(p) for r, p in clocks.items()},
            'logical_command_totals': calls, 'transport_attempt_round_trips': attempts,
            'card_pack_waits': raw_waits, 'local_milestones': stages, 'session_blocker_changes': gates,
            'command_errors': [{'role': e['role'], 'request': e['request'], 'code': e['value']}
                               for e in events if e['event'] == 'command_error'],
            'clock_assumptions': '200ppm drift allowance, 5ms margin per device; estimated, not certified physical timing'}
