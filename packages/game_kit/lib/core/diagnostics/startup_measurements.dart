import 'dart:collection';
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Disposable, explicitly enabled Debug instrumentation. Never changes gameplay.
/// No production identifiers, payloads, error text or service credentials leave
/// this recorder. A separate bounded journal avoids the communication UI ring.
class StartupMeasurements with WidgetsBindingObserver {
  static const protocol = 4;
  static const buildId = String.fromEnvironment(
    'MEASUREMENT_BUILD_ID',
    defaultValue: 'unidentified',
  );
  StartupMeasurements({
    this.enabled = false,
    int Function()? clock,
    this.capacity = 6000,
  }) : _clock = clock ?? (() => _watch.elapsedMicroseconds);

  static final _watch = Stopwatch()..start();
  static final _instance = StartupMeasurements(
    enabled: kDebugMode && const bool.fromEnvironment('STARTUP_MEASUREMENTS'),
  );
  @visibleForTesting
  static StartupMeasurements? testInstance;
  static StartupMeasurements get instance => testInstance ?? _instance;

  final bool enabled;
  final int capacity;
  final int Function() _clock;
  final _journal = Queue<Map<String, Object?>>();
  final _states = <String, int>{};
  final _once = <String>{};
  final _requests = <int>{};
  final _requestActions = <int, int>{};
  late final String _process = List.generate(
    12,
    (_) => Random.secure().nextInt(16).toRadixString(16),
  ).join();
  String? _capture, _trial, _scenario, _role, _key;
  String? _identity, _baseline, _game;
  int _seq = 0, _requestSeq = 0, _action = 0, _dropped = 0;
  int _spanSeq = 0, _inputSeq = 0;
  final _spans = <int, MeasurementSpan>{};
  bool _installed = false;
  bool _foreground = true;
  bool get foreground => _foreground;
  int _epoch = 0;
  static final _requestKey = Object();
  int get currentRequest {
    final scope = Zone.current[_requestKey];
    return scope is (int, int) && scope.$1 == _epoch ? scope.$2 : 0;
  }

  Future<Map<String, dynamic>> measureCommand(
    String function, {
    required bool warmup,
    required Future<Map<String, dynamic>> Function() send,
  }) {
    if (!active || warmup || !function.startsWith('game_liars_poker_')) {
      return send();
    }
    final id = requestStart(function, warmup: warmup);
    return runZoned(() async {
      try {
        final result = await send();
        if (currentRequest != 0) {
          requestEnd(id, function, outcome: result['success'] == false ? 2 : 1);
        }
        return result;
      } catch (error) {
        recordError(error, request: currentRequest);
        if (currentRequest != 0) requestEnd(id, function, outcome: 3);
        rethrow;
      }
    }, zoneValues: {_requestKey: (_epoch, id)});
  }

  void linkRequest(Object? id) {
    if (!active || currentRequest == 0 || id is! String) return;
    final alias = Hmac(
      sha256,
      utf8.encode(_key!),
    ).convert(utf8.encode(id)).toString();
    record(
      'request_link',
      request: currentRequest,
      link: alias.substring(0, 32),
    );
  }

  int? get captureEpoch => active ? _epoch : null;
  bool get active => enabled && _trial != null;
  String? get game => active ? _game : null;
  int get action => _action;
  String? get scenario => _scenario;

  void install() {
    if (!enabled || _installed) return;
    _installed = true;
    WidgetsBinding.instance.addObserver(this);
    developer.registerExtension('ext.mosigame.startup', (_, args) async {
      try {
        return developer.ServiceExtensionResponse.result(
          jsonEncode(control(args)),
        );
      } catch (_) {
        return developer.ServiceExtensionResponse.result(
          jsonEncode({'error': 'invalid_measurement_control'}),
        );
      }
    });
  }

  /// Only called by the local Debug collector; service URI auth is never logged.
  Map<String, Object?> control(Map<String, String> args) {
    if (!enabled) return {'error': 'disabled'};
    switch (args['op']) {
      case 'clock':
        return {
          'protocol': protocol,
          'process': _process,
          'mono_us': _clock(),
          'build': buildId,
        };
      case 'arm':
        final capture = args['capture'] ?? '';
        final trial = args['trial'] ?? '';
        final scenario = args['scenario'] ?? '';
        final role = args['role'] ?? '';
        final key = args['key'] ?? '';
        if (!RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(capture) ||
            !RegExp(r'^[a-zA-Z0-9_-]{1,64}$').hasMatch(trial) ||
            !const {
              'initial_start',
              'menu_restart',
              'result_restart',
              'room_reset',
            }.contains(scenario) ||
            !const {
              'tablet',
              'phone_A',
              'phone_B',
              'phone_C',
              'phone_D',
              'phone_E',
              'phone_F',
            }.contains(role) ||
            !RegExp(r'^[a-f0-9]{64}$').hasMatch(key)) {
          return {'error': 'invalid_configuration'};
        }
        if (active) return {'error': 'already_armed'};
        _capture = capture;
        _epoch++;
        _trial = trial;
        _scenario = scenario;
        _role = role;
        _key = key;
        _baseline = _identity;
        _game = null;
        _action = 0;
        _seq = 0;
        _requestSeq = 0;
        _spanSeq = 0;
        _inputSeq = 0;
        _spans.clear();
        _dropped = 0;
        _journal.clear();
        _states.clear();
        _once.clear();
        _requests.clear();
        _requestActions.clear();
        record('armed');
        state('foreground', _foreground ? 1 : 0);
        state('pending_commands', 0);
        return {'ok': true, 'process': _process};
      case 'drain':
        final after = int.tryParse(args['after'] ?? '') ?? 0;
        while (_journal.isNotEmpty &&
            (_journal.first['seq']! as int) <= after) {
          _journal.removeFirst();
        }
        return {
          'process': _process,
          'dropped': _dropped,
          'last_seq': _seq,
          'events': _journal
              .where((e) => (e['seq']! as int) > after)
              .take(300)
              .toList(),
        };
      case 'stop':
        for (final span in _spans.values.toList()) {
          span.event('span_pending');
        }
        record('capture_stopped');
        _trial = null;
        _key = null;
        return {'ok': true};
      default:
        return {'error': 'invalid_operation'};
    }
  }

  void beginAction(String source) {
    if (!active || _role != 'tablet') return;
    if (!const {
      'initial_start',
      'menu_restart',
      'result_restart',
      'room_reset',
    }.contains(source)) {
      return;
    }
    _action++;
    record('action_accepted', source: source);
  }

  /// Called only after the normal session has accepted the public game context.
  void bindGame(String identity) {
    if (!enabled || identity.isEmpty) return;
    _identity = identity;
    if (!active || identity == _baseline) return;
    final alias = Hmac(
      sha256,
      utf8.encode(_key!),
    ).convert(utf8.encode(identity)).toString().substring(0, 32);
    if (_game == alias) return;
    if (_game != null) record('game_replaced');
    _game = alias;
    _states.clear();
    _once.clear();
    record('game_bound');
    state('foreground', _foreground ? 1 : 0);
    state('pending_commands', _requests.length);
  }

  /// Local opaque interaction number, not a card or server identifier.
  int nextInputId() => active ? ++_inputSeq : 0;

  int requestStart(String function, {required bool warmup}) {
    if (!active || warmup || !function.startsWith('game_liars_poker_')) {
      return 0;
    }
    final id = ++_requestSeq;
    _requests.add(id);
    _requestActions[id] = _action;
    record('command_start', request: id, command: function);
    state('pending_commands', _requests.length);
    return id;
  }

  void requestEnd(int id, String function, {required int outcome}) {
    if (id == 0 || !_requests.remove(id)) return;
    record('command_end', request: id, command: function, value: outcome);
    _requestActions.remove(id);
    state('pending_commands', _requests.length);
  }

  void state(String name, int value, {String? game}) {
    if (!active || (game != null && game != _game)) return;
    if (_states[name] == value) return;
    _states[name] = value;
    record(name, value: value, game: game);
  }

  void once(String name, {String? game}) {
    if (!active || _game == null || (game != null && game != _game)) return;
    if (_once.add(name)) record(name, game: game);
  }

  /// A bitmask is preferable to free-form diagnostics or private data.
  void phoneGate({
    required String? game,
    required bool selectable,
    required bool submittable,
    required bool firstTurn,
    required bool uncovered,
  }) {
    if (game == null || game != _game) return;
    final mask =
        (selectable ? 1 : 0) |
        (submittable ? 2 : 0) |
        (firstTurn ? 4 : 0) |
        (uncovered && _foreground ? 8 : 0);
    state('phone_gate', mask, game: game);
    checkPhone(game);
  }

  void handGate(
    String? game, {
    required bool selectable,
    required bool submittable,
  }) {
    if (game == null || game != _game) return;
    state(
      'hand_gate',
      (selectable ? 1 : 0) | (submittable ? 2 : 0),
      game: game,
    );
    checkPhone(game);
  }

  void checkPhone(String game) {
    if (!_foreground || _states['session_can_send'] != 1) return;
    final p = _states['phone_gate'] ?? 0;
    final h = _states['hand_gate'] ?? 0;
    if ((p & 9) == 9 && (h & 1) == 1) {
      once('phone_hand_selectable_frame', game: game);
    }
    if (p == 15 && h == 3) once('phone_first_turn_playable_frame', game: game);
  }

  /// Composite input blockers, not an assertion of network failure.
  void sessionState({
    required bool localUsable,
    required bool transportConnected,
    required bool transportRecovering,
    required bool controllerAvailable,
    required bool serverConfirmed,
    required bool paused,
    required bool leaving,
  }) {
    final mask =
        (!localUsable ? 1 : 0) |
        (!transportConnected ? 2 : 0) |
        (transportRecovering ? 4 : 0) |
        (!controllerAvailable ? 8 : 0) |
        (!serverConfirmed ? 16 : 0) |
        (paused ? 32 : 0) |
        (leaving ? 64 : 0);
    state('session_blockers', mask);
    state('session_can_send', mask == 0 ? 1 : 0);
  }

  /// Only a fixed code vocabulary leaves the app; never error.toString/details.
  void recordError(Object error, {required int request}) {
    const codes = [
      'unknown',
      'cancelled',
      'invalid-argument',
      'deadline-exceeded',
      'not-found',
      'already-exists',
      'permission-denied',
      'resource-exhausted',
      'failed-precondition',
      'aborted',
      'out-of-range',
      'unimplemented',
      'internal',
      'unavailable',
      'data-loss',
      'unauthenticated',
    ];
    final code = error is FirebaseFunctionsException
        ? codes.indexOf(error.code)
        : -1;
    record('command_error', request: request, value: code < 0 ? 0 : code);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    this.state('foreground', _foreground ? 1 : 0);
  }

  /// Alias inputs never enter persisted events or console output.
  String? alias(String domain, String? raw) {
    if (!active || raw == null || raw.isEmpty) return null;
    return Hmac(
      sha256,
      utf8.encode(_key!),
    ).convert(utf8.encode('$domain/$raw')).toString().substring(0, 32);
  }

  void diagnostic(
    String event, {
    String? room,
    String? subject,
    int? value,
    int? epoch,
  }) {
    if (!active || (epoch != null && epoch != _epoch)) return;
    record(
      event,
      room: alias('room', room),
      subject: alias('connection', subject),
      value: value,
    );
  }

  MeasurementSpan beginSpan(String kind, {String? room, String? subject}) {
    if (!active) return MeasurementSpan._disabled;
    return _newSpan(
      kind,
      room: alias('room', room),
      subject: alias('connection', subject),
      action: _action,
    );
  }

  MeasurementSpan _newSpan(
    String kind, {
    String? room,
    String? subject,
    required int action,
    int? parent,
  }) {
    if (!active) return MeasurementSpan._disabled;
    final span = MeasurementSpan._(
      this,
      _epoch,
      ++_spanSeq,
      action,
      kind,
      room,
      subject,
      parent,
    );
    _spans[span.id] = span;
    span.event('${kind}_start');
    return span;
  }

  Future<T> measureSpan<T>(
    String kind,
    Future<T> Function() body, {
    String? room,
    String? subject,
    int? epoch,
  }) {
    if (!active || (epoch != null && epoch != _epoch)) return body();
    final span = beginSpan(kind, room: room, subject: subject);
    return () async {
      try {
        final value = await body();
        span.end(1);
        return value;
      } catch (_) {
        span.end(3);
        rethrow;
      }
    }();
  }

  /// Event names are code constants, values are numeric. No arbitrary text data.
  void record(
    String event, {
    String? game,
    int? value,
    int? request,
    String? command,
    String? link,
    String? source,
    int? span,
    int? parent,
    int? actionOverride,
    String? room,
    String? subject,
    int? selection,
    int? submission,
    String? input,
  }) {
    if (!active) return;
    if (request == 0) return;
    if (game != null && game != _game) return;
    final row = <String, Object?>{
      'schema': protocol,
      'capture': _capture,
      'trial': _trial,
      'scenario': _scenario,
      'role': _role,
      'process': _process,
      'seq': ++_seq,
      'mono_us': _clock(),
      'action':
          actionOverride ??
          (request == null ? _action : (_requestActions[request] ?? _action)),
      'event': event,
      'game': game ?? _game,
      'value': ?value,
      'request': ?request,
      'command': ?command,
      'link': ?link,
      'source': ?source,
      'span': ?span,
      'parent': ?parent,
      'room': ?room,
      'subject': ?subject,
      'selection': ?selection,
      'submission': ?submission,
      'input': ?input,
    };
    _journal.add(row);
    if (_journal.length > capacity) {
      _journal.removeFirst();
      _dropped++;
    }
  }
}

/// Capture epoch and action are immutable: a late callback cannot join a new trial.
class MeasurementSpan {
  MeasurementSpan._(
    this._owner,
    this._epoch,
    this.id,
    this.action,
    this.kind,
    this.room,
    this.subject,
    this.parent,
  );
  static final _disabled = MeasurementSpan._(
    null,
    0,
    0,
    0,
    'disabled',
    null,
    null,
    null,
  );
  final StartupMeasurements? _owner;
  final int _epoch, id, action;
  final String kind;
  final String? room, subject;
  final int? parent;
  bool _ended = false;
  bool get active =>
      _owner != null && _owner.active && _owner._epoch == _epoch && !_ended;
  void event(String name, {int? value}) {
    if (!active) return;
    _owner!.record(
      name,
      value: value,
      span: id,
      parent: parent,
      command: kind,
      actionOverride: action,
      room: room,
      subject: subject,
    );
  }

  MeasurementSpan child(String kind) => active
      ? _owner!._newSpan(
          kind,
          room: room,
          subject: subject,
          action: action,
          parent: id,
        )
      : _disabled;
  void end(int outcome) {
    if (!active) return;
    event('${kind}_end', value: outcome);
    _ended = true;
    _owner!._spans.remove(id);
  }
}
