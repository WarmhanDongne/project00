// [dev_error_overlay.dart] 는 여러 게임이 함께 사용하는 게임 통신과 실행 오류를 기록하거나 화면에 보여주는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [ErrorOverlay] : 게임 통신과 실행 오류를 기록하고 화면에 표시
//
// 즉, 문제가 난 시점과 원인을 개발 화면에서 바로 확인하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/core/diagnostics/recovery_metrics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:game_kit/core/diagnostics/dev_error_log.dart';
import 'package:game_kit/core/diagnostics/game_communication_log.dart';

// ============================================================

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
  bool _refreshScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _log.addListener(_refresh);
  }

  void _refresh() {
    if (!mounted) return;

    // Provider/Widget build 중에도 서버 예열이나 RTDB 구독이 통신 로그를 남길 수
    // 있습니다. 이때 조상인 진단 오버레이를 즉시 setState하면 Flutter의
    // "setState() or markNeedsBuild() called during build" 예외가 발생합니다.
    // 현재 프레임이 빌드 중일 때만 프레임 뒤로 미루고, 같은 프레임의 여러 로그는
    // 한 번의 갱신으로 합칩니다. 빌드 밖에서는 기존처럼 즉시 반영합니다.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_refreshScheduled) return;
      _refreshScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshScheduled = false;
        if (mounted) setState(() {});
      });
      return;
    }

    setState(() {});
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
              // MaterialApp.builder puts this widget above Navigator's Overlay.
              // Header tooltips need an Overlay within the diagnostics subtree.
              child: Overlay.wrap(
                child: _GameCommunicationSheet(
                  onClose: () => setState(() => _isDiagnosticsOpen = false),
                ),
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
              animation: Listenable.merge([log, RecoveryMetrics.instance]),
              builder: (context, _) {
                final entries = log.entries;
                return Column(
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
                    if (log.droppedEntries > 0)
                      Text(
                        "이전 이벤트 ${log.droppedEntries}개 생략 · 복구 요약은 별도 보존",
                        style: const TextStyle(color: Colors.white70),
                      ),
                    if (RecoveryMetrics.instance.summaries.isNotEmpty)
                      SizedBox(
                        height: 112,
                        child: ListView(
                          children: [
                            for (final summary
                                in RecoveryMetrics.instance.summaries.reversed
                                    .take(5))
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                child: Text(
                                  '복구 ${summary.episode} · 시도 ${summary.batch} · ${summary.success ? "완료" : "미완료"} · ${summary.elapsed.inMilliseconds}ms\n'
                                  '${RecoveryStage.values.map((stage) => "${stage.name}: ${summary.stageText(stage)}").join(" · ")}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                          ],
                        ),
                      ),
                    const Divider(height: 1),
                    Expanded(
                      child: entries.isEmpty
                          ? const Center(
                              child: Text(
                                '아직 기록된 게임 통신이 없습니다.',
                                style: TextStyle(color: Colors.black54),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                              itemCount: entries.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) =>
                                  _CommunicationEntryTile(
                                    entry: entries[index],
                                  ),
                            ),
                    ),
                  ],
                );
              },
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
    final entries = log.entries;
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
            onPressed: entries.isEmpty
                ? null
                : () async {
                    final text = entries.reversed
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
            onPressed: entries.isEmpty ? null : log.clearEntries,
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
