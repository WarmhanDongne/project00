import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mosigame_core/core/diagnostics/dev_error_log.dart';
import 'package:mosigame_core/core/diagnostics/game_communication_log.dart';

/// 휴대폰과 태블릿 모두에서 게임 통신 기록을 여는 개발용 경계입니다.
///
/// 버튼과 타임라인은 디버그 빌드에서만 나타나며, 릴리스 빌드에서는
/// [child]를 그대로 반환합니다. 방 코드·UID·카드 값은 타임라인에 남기지
/// 않습니다.
class DevErrorOverlay extends StatefulWidget {
  const DevErrorOverlay({super.key, required this.child});

  static const diagnosticsButtonKey = Key(
    'game-communication-diagnostics-button',
  );
  static const diagnosticsSheetKey = Key(
    'game-communication-diagnostics-sheet',
  );

  final Widget child;

  @override
  State<DevErrorOverlay> createState() => _DevErrorOverlayState();
}

class _DevErrorOverlayState extends State<DevErrorOverlay>
    with WidgetsBindingObserver {
  GameCommunicationLog get _log => GameCommunicationLog.instance;
  bool _isDiagnosticsOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _log.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _log.removeListener(_refresh);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _log.add(
      level:
          state == AppLifecycleState.paused || state == AppLifecycleState.hidden
          ? GameCommunicationLevel.warning
          : GameCommunicationLevel.info,
      title: '앱 상태 ${state.name}',
      detail: state == AppLifecycleState.resumed
          ? '앱이 다시 화면에 보입니다.'
          : '통신·타이머 지연 여부를 확인합니다.',
      operation: 'app_lifecycle',
    );
  }

  void _openDiagnostics() {
    _log.markSeen();
    setState(() => _isDiagnosticsOpen = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return widget.child;
    final problemCount = _log.unseenProblemCount;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (!_isDiagnosticsOpen)
          Positioned.fill(
            child: SafeArea(
              top: false,
              left: false,
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Semantics(
                    button: true,
                    label: '게임 통신 진단 열기',
                    child: Material(
                      color: const Color(0xE6222222),
                      elevation: 6,
                      shape: const CircleBorder(),
                      child: InkWell(
                        key: DevErrorOverlay.diagnosticsButtonKey,
                        customBorder: const CircleBorder(),
                        onTap: _openDiagnostics,
                        child: SizedBox.square(
                          dimension: 46,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Center(
                                child: Icon(
                                  Icons.monitor_heart_outlined,
                                  color: Colors.white,
                                  size: 25,
                                ),
                              ),
                              if (problemCount > 0)
                                Positioned(
                                  right: -4,
                                  top: -5,
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minWidth: 20,
                                      minHeight: 20,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                    ),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD32F2F),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      problemCount > 99
                                          ? '99+'
                                          : '$problemCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_isDiagnosticsOpen) ...[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _isDiagnosticsOpen = false),
              child: const ColoredBox(color: Color(0x66000000)),
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              top: false,
              child: _GameCommunicationSheet(
                onClose: () => setState(() => _isDiagnosticsOpen = false),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _GameCommunicationSheet extends StatelessWidget {
  const _GameCommunicationSheet({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final log = GameCommunicationLog.instance;
    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        widthFactor: 1,
        heightFactor: 0.86,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Material(
            key: DevErrorOverlay.diagnosticsSheetKey,
            color: const Color(0xFFF8F8F8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            clipBehavior: Clip.antiAlias,
            child: AnimatedBuilder(
              animation: log,
              builder: (context, _) => Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  _DiagnosticsHeader(log: log, onClose: onClose),
                  const Divider(height: 1),
                  Expanded(
                    child: log.entries.isEmpty
                        ? const Center(
                            child: Text(
                              '아직 기록된 게임 통신이 없습니다.',
                              style: TextStyle(color: Colors.black54),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                            itemCount: log.entries.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) =>
                                _CommunicationEntryTile(
                                  entry: log.entries[index],
                                ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DiagnosticsHeader extends StatelessWidget {
  const _DiagnosticsHeader({required this.log, required this.onClose});

  final GameCommunicationLog log;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final connected = log.isRealtimeConnected;
    final connectionColor = switch (connected) {
      true => const Color(0xFF2E7D32),
      false => const Color(0xFFD32F2F),
      null => const Color(0xFF757575),
    };
    final connectionText = switch (connected) {
      true => 'RTDB 연결됨',
      false => 'RTDB 연결 끊김',
      null => 'RTDB 상태 대기',
    };
    final lastReceived = log.lastRealtimeEventAt;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '게임 통신 진단',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 12,
                  runSpacing: 3,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: connectionColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          connectionText,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    Text(
                      lastReceived == null
                          ? '상태 수신 없음'
                          : '마지막 수신 ${_displayTime(lastReceived)}',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '기록 복사',
            onPressed: log.entries.isEmpty
                ? null
                : () async {
                    final text = log.entries.reversed
                        .map((entry) => entry.asText)
                        .join('\n');
                    await Clipboard.setData(ClipboardData(text: text));
                    if (!context.mounted) return;
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(content: Text('통신 기록을 복사했습니다.')),
                    );
                  },
            icon: const Icon(Icons.copy_outlined),
          ),
          IconButton(
            tooltip: '기록 지우기',
            onPressed: log.entries.isEmpty ? null : log.clearEntries,
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            tooltip: '닫기',
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _CommunicationEntryTile extends StatelessWidget {
  const _CommunicationEntryTile({required this.entry});

  final GameCommunicationEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.level) {
      GameCommunicationLevel.info => const Color(0xFF546E7A),
      GameCommunicationLevel.success => const Color(0xFF2E7D32),
      GameCommunicationLevel.warning => const Color(0xFFEF6C00),
      GameCommunicationLevel.failure => const Color(0xFFC62828),
    };
    final icon = switch (entry.level) {
      GameCommunicationLevel.info => Icons.arrow_forward,
      GameCommunicationLevel.success => Icons.check_circle_outline,
      GameCommunicationLevel.warning => Icons.warning_amber_rounded,
      GameCommunicationLevel.failure => Icons.error_outline,
    };
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      childrenPadding: const EdgeInsets.fromLTRB(44, 0, 8, 10),
      leading: Icon(icon, color: color, size: 21),
      title: Text(
        entry.title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${_displayTime(entry.time)}  ${entry.detail}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SelectableText(
            [
              if (entry.operation != null) '요청: ${entry.operation}',
              if (entry.traceId != null) '추적 ID: ${entry.traceId}',
              '상세: ${entry.detail}',
            ].join('\n'),
            style: const TextStyle(fontSize: 12, height: 1.45),
          ),
        ),
      ],
    );
  }
}

String _displayTime(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}:'
    '${time.second.toString().padLeft(2, '0')}.'
    '${time.millisecond.toString().padLeft(3, '0')}';

/// 위젯 오류 원문과 stack trace가 사용자 화면에 노출되지 않게 합니다.
void installDevErrorWidgetBuilder() {
  ErrorWidget.builder = (details) {
    DevErrorLog.instance.add(
      error: details.exception,
      stack: details.stack,
      context: 'widget_build',
      time: DateTime.now(),
    );
    return const SizedBox.shrink();
  };
}
