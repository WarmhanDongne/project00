import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project00/core/diagnostics/dev_error_log.dart';

//=======================개발용 오류 표시==============================
/// 개발 중에 오류를 화면에서 바로 보여 주는 덮개입니다.
///
/// 오류가 나면 화면 오른쪽 아래에 빨간 표시가 뜨고, 누르면 최근 오류 목록이
/// 열립니다. 목록에서 우리 코드(`package:project00`)의 첫 줄을 함께 보여 주므로
/// 어느 파일을 고쳐야 하는지 바로 알 수 있고, 눌러서 전체 스택을 복사할 수도
/// 있습니다.
///
/// **디버그 빌드에서만 보입니다.** 릴리스에서는 [child]를 그대로 통과시킵니다.
class DevErrorOverlay extends StatelessWidget {
  const DevErrorOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return child;
    return Stack(
      children: [
        child,
        // 화면 방향·크기와 무관하게 오른쪽 아래에 붙습니다.
        Positioned(
          right: 8,
          bottom: 8,
          child: SafeArea(child: _DevErrorBadge()),
        ),
      ],
    );
  }
}

/// 오류 개수를 보여 주는 작은 표시입니다. 오류가 없으면 아무것도 그리지 않습니다.
class _DevErrorBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DevErrorLog.instance,
      builder: (context, _) {
        final log = DevErrorLog.instance;
        if (log.isEmpty) return const SizedBox.shrink();
        final unseen = log.unseenCount;

        return Material(
          color: unseen > 0 ? const Color(0xFFD32F2F) : const Color(0xCC424242),
          borderRadius: BorderRadius.circular(20),
          elevation: 6,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _openList(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bug_report, size: 18, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    '오류 ${log.entries.length}${unseen > 0 ? ' (+$unseen)' : ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openList(BuildContext context) {
    DevErrorLog.instance.markSeen();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF17191F),
      isScrollControlled: true,
      builder: (_) => const _DevErrorSheet(),
    );
  }
}

class _DevErrorSheet extends StatelessWidget {
  const _DevErrorSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: ListenableBuilder(
          listenable: DevErrorLog.instance,
          builder: (context, _) {
            final entries = DevErrorLog.instance.entries;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '오류 ${entries.length}건 (개발 전용)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: DevErrorLog.instance.clear,
                        child: const Text('모두 지우기'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.white24),
                Expanded(
                  child: entries.isEmpty
                      ? const Center(
                          child: Text(
                            '오류가 없습니다',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : ListView.separated(
                          itemCount: entries.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1, color: Colors.white12),
                          itemBuilder: (context, index) =>
                              _DevErrorTile(entry: entries[index]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DevErrorTile extends StatelessWidget {
  const _DevErrorTile({required this.entry});

  final DevErrorEntry entry;

  @override
  Widget build(BuildContext context) {
    final frame = entry.firstProjectFrame;
    final time = entry.time;
    final stamp =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';

    return ExpansionTile(
      collapsedIconColor: Colors.white54,
      iconColor: Colors.white54,
      title: Text(
        entry.summary,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
      subtitle: Text(
        [stamp, ?entry.context, ?frame].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 11),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(
                entry.asText,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: entry.asText));
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(content: Text('오류 내용을 복사했습니다')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('복사'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

//=======================빌드 실패 화면==============================
/// 위젯이 빌드에 실패했을 때 화면에 그릴 것을 정합니다.
///
/// 기본 동작은 회색·빨간 화면에 프레임워크 문구만 나와, 어느 파일이 문제인지
/// 알기 어렵습니다. 개발 중에는 **오류 첫 줄과 우리 코드의 첫 스택 줄**을
/// 함께 보여 줍니다. 릴리스에서는 화면을 망치지 않도록 빈 자리로 둡니다.
void installDevErrorWidgetBuilder() {
  ErrorWidget.builder = (details) {
    DevErrorLog.instance.add(
      error: details.exceptionAsString(),
      stack: details.stack,
      context: '위젯 빌드',
      time: DateTime.now(),
    );
    if (!kDebugMode) return const SizedBox.shrink();

    final stack = details.stack?.toString().split('\n') ?? const [];
    final frame = stack.firstWhere(
      (line) => line.contains('package:project00'),
      orElse: () => '',
    );
    return Container(
      color: const Color(0xFF3A0D0D),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.white70, size: 28),
          const SizedBox(height: 8),
          Text(
            details.exceptionAsString(),
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          if (frame.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              frame.trim(),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  };
}
