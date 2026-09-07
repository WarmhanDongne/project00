import 'package:flutter/foundation.dart';

/// 게임 명령과 Realtime Database 수신을 같은 시간축에 남기는 개발용 기록입니다.
///
/// 카드, 방 코드, UID 같은 값은 저장하지 않습니다. 디버그 빌드에서만
/// 메모리에 유지하며 릴리스 빌드에서 [add]는 아무 일도 하지 않습니다.
class GameCommunicationLog extends ChangeNotifier {
  GameCommunicationLog._();

  static final GameCommunicationLog instance = GameCommunicationLog._();

  static const int maxEntries = 200;

  final List<GameCommunicationEntry> _entries = [];
  bool? _isRealtimeConnected;
  DateTime? _lastRealtimeEventAt;
  int _unseenProblemCount = 0;

  List<GameCommunicationEntry> get entries => List.unmodifiable(_entries);
  bool? get isRealtimeConnected => _isRealtimeConnected;
  DateTime? get lastRealtimeEventAt => _lastRealtimeEventAt;
  int get unseenProblemCount => _unseenProblemCount;

  void add({
    required GameCommunicationLevel level,
    required String title,
    required String detail,
    String? operation,
    String? traceId,
    DateTime? time,
  }) {
    if (!kDebugMode) return;
    final entry = GameCommunicationEntry(
      level: level,
      title: title,
      detail: detail,
      operation: operation,
      traceId: traceId,
      time: time ?? DateTime.now(),
    );
    _entries.insert(0, entry);
    if (_entries.length > maxEntries) _entries.removeLast();
    if (level == GameCommunicationLevel.warning ||
        level == GameCommunicationLevel.failure) {
      _unseenProblemCount += 1;
    }
    debugPrint(
      '[game_comm] level=${level.name} '
      'event=${_safeToken(title)} '
      'operation=${_safeToken(operation ?? 'none')} '
      'detail=${_safeToken(detail)}',
    );
    notifyListeners();
  }

  void recordConnection(bool connected) {
    if (!kDebugMode) return;
    if (_isRealtimeConnected == connected) return;
    _isRealtimeConnected = connected;
    add(
      level: connected
          ? GameCommunicationLevel.success
          : GameCommunicationLevel.failure,
      title: connected ? 'Firebase 연결됨' : 'Firebase 연결 끊김',
      detail: connected
          ? 'RTDB 실시간 연결이 복구됐습니다.'
          : 'RTDB .info/connected가 false입니다.',
      operation: 'realtime_connection',
    );
  }

  void recordRealtimeSnapshot({required String channel, Object? value}) {
    if (!kDebugMode) return;
    _lastRealtimeEventAt = DateTime.now();

    String detail;
    if (value is Map) {
      final revision = value['revision'];
      final phase = value['phase'];
      final status = value['status'];
      final fields = <String>[
        if (revision is num) 'revision=${revision.toInt()}',
        if (phase is String && phase.isNotEmpty) 'phase=$phase',
        if (status is String && status.isNotEmpty) 'status=$status',
      ];
      detail = fields.isEmpty ? '스냅샷 수신' : fields.join(' · ');
    } else {
      detail = value == null ? '빈 스냅샷 수신' : '스냅샷 수신';
    }

    add(
      level: value == null
          ? GameCommunicationLevel.warning
          : GameCommunicationLevel.info,
      title: '$channel 상태 수신',
      detail: detail,
      operation: 'realtime_database',
    );
  }

  void markSeen() {
    if (_unseenProblemCount == 0) return;
    _unseenProblemCount = 0;
    notifyListeners();
  }

  /// 현재 연결 상태는 유지하고 화면에 나열된 기록만 지웁니다.
  void clearEntries() {
    if (_entries.isEmpty && _unseenProblemCount == 0) return;
    _entries.clear();
    _unseenProblemCount = 0;
    notifyListeners();
  }

  /// 테스트·세션 초기화용 전체 초기화입니다.
  void clear() {
    if (_entries.isEmpty &&
        _unseenProblemCount == 0 &&
        _isRealtimeConnected == null &&
        _lastRealtimeEventAt == null) {
      return;
    }
    _entries.clear();
    _unseenProblemCount = 0;
    _isRealtimeConnected = null;
    _lastRealtimeEventAt = null;
    notifyListeners();
  }
}

enum GameCommunicationLevel { info, success, warning, failure }

@immutable
class GameCommunicationEntry {
  const GameCommunicationEntry({
    required this.level,
    required this.title,
    required this.detail,
    required this.time,
    this.operation,
    this.traceId,
  });

  final GameCommunicationLevel level;
  final String title;
  final String detail;
  final DateTime time;
  final String? operation;
  final String? traceId;

  String get asText {
    final timestamp = _formatTime(time);
    final trace = traceId == null ? '' : ' trace=$traceId';
    final operationText = operation == null ? '' : ' operation=$operation';
    return '$timestamp [${level.name}] $title - $detail$operationText$trace';
  }
}

String _safeToken(String value) {
  final normalized = value
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^A-Za-z0-9_./:=\-\uAC00-\uD7A3]'), '');
  return normalized.length <= 180 ? normalized : normalized.substring(0, 180);
}

String _formatTime(DateTime time) =>
    '${_two(time.hour)}:${_two(time.minute)}:${_two(time.second)}.'
    '${time.millisecond.toString().padLeft(3, '0')}';

String _two(int value) => value.toString().padLeft(2, '0');
