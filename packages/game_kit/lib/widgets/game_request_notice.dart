import 'package:flutter/material.dart';

/// 마지막 정상 게임 화면을 유지하면서 요청의 진행/실패를 알리는 공용 표시입니다.
/// 재시도 버튼은 현재 단계에서 여전히 유효한 명령일 때만 호출부가 제공합니다.
class GameRequestNotice extends StatelessWidget {
  const GameRequestNotice({
    super.key,
    this.busy = false,
    this.message,
    this.onRetry,
    this.busyMessage = '서버 응답을 기다리고 있습니다…',
  });
  final bool busy;
  final String? message;
  final VoidCallback? onRetry;
  final String busyMessage;

  @override
  Widget build(BuildContext context) {
    if (!busy && (message == null || message!.isEmpty)) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Material(
              color: const Color(0xF0222430),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (busy) ...[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Flexible(
                      child: Text(
                        busy ? busyMessage : message!,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (!busy && onRetry != null)
                      TextButton(
                        onPressed: onRetry,
                        child: const Text(
                          '재시도',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
