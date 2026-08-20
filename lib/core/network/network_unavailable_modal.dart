import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/core/layout/device_layout.dart';
import 'package:project00/gen/assets.gen.dart';

/// 인터넷 연결이 끊겼을 때 앱 전체에서 공통으로 사용하는 반응형 모달입니다.
class NetworkUnavailableModal extends StatelessWidget {
  const NetworkUnavailableModal({
    super.key,
    required this.onRetry,
    this.isRetrying = false,
    this.onExit,
    this.exitLabel = '홈으로',
    this.title = '네트워크에 접속할 수 없습니다.',
    this.description = '네트워크 연결 상태를 확인해주세요.',
  });

  static const cardKey = Key('network-unavailable-card');
  static const retryButtonKey = Key('network-unavailable-retry');

  final VoidCallback onRetry;
  final bool isRetrying;
  final VoidCallback? onExit;
  final String exitLabel;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ModalBarrier(color: Color(0x99000000), dismissible: false),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final shortestSide = math.min(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                final isTablet = shortestSide >= DeviceLayout.tabletBreakpoint;
                final isCompact = constraints.maxHeight < 560;
                final horizontalMargin = isTablet ? 64.0 : 20.0;
                final maxCardWidth = isTablet
                    ? 720.0
                    : isCompact
                    ? 500.0
                    : 430.0;
                final cardWidth = math.min(
                  constraints.maxWidth - horizontalMargin * 2,
                  maxCardWidth,
                );
                final iconSize = isTablet
                    ? (isCompact ? 120.0 : 180.0)
                    : (isCompact ? 90.0 : 126.0);
                final titleSize = isTablet
                    ? (isCompact ? 28.0 : 36.0)
                    : (isCompact ? 21.0 : 25.0);
                final descriptionSize = isTablet
                    ? (isCompact ? 18.0 : 23.0)
                    : (isCompact ? 14.0 : 16.0);

                return Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalMargin,
                      vertical: isCompact ? 12 : 24,
                    ),
                    child: Container(
                      key: cardKey,
                      width: cardWidth,
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 64 : 28,
                        vertical: isTablet
                            ? (isCompact ? 30 : 54)
                            : (isCompact ? 22 : 36),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(isTablet ? 42 : 30),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 32,
                            offset: Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Assets.images.others.networkUnavailable.image(
                            width: iconSize,
                            height: iconSize,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                          SizedBox(height: isCompact ? 12 : 24),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFF404150),
                              fontSize: titleSize,
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                              letterSpacing: -0.6,
                            ),
                          ),
                          SizedBox(height: isCompact ? 6 : 12),
                          Text(
                            description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFF9697A7),
                              fontSize: descriptionSize,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                              letterSpacing: -0.25,
                            ),
                          ),
                          SizedBox(height: isCompact ? 18 : 32),
                          _RetryButton(
                            key: retryButtonKey,
                            isTablet: isTablet,
                            isCompact: isCompact,
                            isRetrying: isRetrying,
                            onPressed: onRetry,
                          ),
                          if (onExit != null) ...[
                            SizedBox(height: isCompact ? 8 : 12),
                            TextButton(
                              onPressed: isRetrying ? null : onExit,
                              child: Text(
                                exitLabel,
                                style: TextStyle(
                                  color: const Color(0xFF6F7080),
                                  fontSize: isTablet ? 20 : 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({
    super.key,
    required this.isTablet,
    required this.isCompact,
    required this.isRetrying,
    required this.onPressed,
  });

  final bool isTablet;
  final bool isCompact;
  final bool isRetrying;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final width = isTablet ? 360.0 : 270.0;
    final height = isTablet
        ? (isCompact ? 58.0 : 70.0)
        : (isCompact ? 48.0 : 56.0);

    return Semantics(
      button: true,
      enabled: !isRetrying,
      label: '네트워크 연결 재시도',
      child: Opacity(
        opacity: isRetrying ? 0.76 : 1,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                colors: [Color(0xFF5937F2), Color(0xFF7147E8)],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4D6940EC),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: isRetrying ? null : onPressed,
              child: Center(
                child: isRetrying
                    ? SizedBox(
                        width: isTablet ? 28 : 22,
                        height: isTablet ? 28 : 22,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        '재시도',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTablet ? 28 : 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
