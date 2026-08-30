import 'package:flutter/foundation.dart';

//=======================개발용 오류 기록==============================
/// 개발 중 콘솔과 ADB logcat에서 확인하는 오류 기록입니다.
///
/// 개인정보가 섞일 수 있는 오류 원문은 출력하지 않고 오류 타입, 문맥, 프로젝트
/// 첫 stack frame만 구조화해 남깁니다. **디버그 빌드에서만** 쌓입니다
/// (릴리스에서는 [add]가 아무 일도 하지 않습니다).
///
/// 오류를 서버로 보내는 일은 [CrashReporting]이 맡습니다. 화면에는 표시하지 않습니다.
class DevErrorLog extends ChangeNotifier {
  DevErrorLog._();

  static final DevErrorLog instance = DevErrorLog._();

  /// 들고 있는 최대 개수입니다. 오래된 것부터 버립니다.
  static const int maxEntries = 50;

  final List<DevErrorEntry> _entries = [];

  /// 최근 오류가 앞에 오는 목록입니다.
  List<DevErrorEntry> get entries => List.unmodifiable(_entries);

  /// 마지막으로 사용자가 확인한 뒤 새로 쌓인 오류 수입니다.
  int get unseenCount => _unseenCount;
  int _unseenCount = 0;

  bool get isEmpty => _entries.isEmpty;

  void add({
    required Object error,
    StackTrace? stack,
    String? context,
    required DateTime time,
  }) {
    // 릴리스 빌드에서는 기록하지 않습니다. 화면에 띄울 일도 없습니다.
    if (!kDebugMode) return;
    _entries.insert(
      0,
      DevErrorEntry(
        error: error.toString(),
        stack: stack?.toString(),
        context: context,
        time: time,
      ),
    );
    if (_entries.length > maxEntries) _entries.removeLast();
    _unseenCount += 1;
    final entry = _entries.first;
    debugPrint(
      '[dev_error] context=${_safeToken(context ?? 'unknown')} '
      'errorType=${_safeToken(error.runtimeType.toString())} '
      'frame=${_safeFrame(entry.firstProjectFrame)}',
    );
    notifyListeners();
  }

  /// 목록을 열어 확인했다고 표시합니다.
  void markSeen() {
    if (_unseenCount == 0) return;
    _unseenCount = 0;
    notifyListeners();
  }

  void clear() {
    if (_entries.isEmpty && _unseenCount == 0) return;
    _entries.clear();
    _unseenCount = 0;
    notifyListeners();
  }
}

String _safeToken(String value) =>
    value.replaceAll(RegExp(r'[^A-Za-z0-9_./:-]'), '_');

String _safeFrame(String? value) {
  if (value == null || value.isEmpty) return 'none';
  final safe = _safeToken(value);
  return safe.length <= 240 ? safe : safe.substring(0, 240);
}

/// 오류 한 건입니다.
@immutable
class DevErrorEntry {
  const DevErrorEntry({
    required this.error,
    required this.time,
    this.stack,
    this.context,
  });

  final String error;
  final String? stack;

  /// 어디서 났는지 짧은 설명입니다(예: `위젯 빌드`, `비동기`).
  final String? context;
  final DateTime time;

  /// 눌러서 복사할 때 쓰는 전체 글입니다.
  String get asText => [
    '[$context] $error',
    if (stack != null && stack!.trim().isNotEmpty) stack,
  ].join('\n');

  /// 목록에 한 줄로 보여 줄 요약입니다.
  String get summary {
    final firstLine = error.split('\n').first.trim();
    return firstLine.length <= 120
        ? firstLine
        : '${firstLine.substring(0, 120)}…';
  }

  /// 스택에서 우리 코드(`package:project00`)가 처음 나오는 줄입니다.
  ///
  /// 프레임워크 줄이 길게 이어져 정작 어느 파일이 문제인지 찾기 어려워서,
  /// 목록에 이 줄을 함께 보여 줍니다.
  String? get firstProjectFrame {
    final lines = stack?.split('\n') ?? const [];
    for (final line in lines) {
      if (line.contains('package:project00')) return line.trim();
    }
    return null;
  }
}
