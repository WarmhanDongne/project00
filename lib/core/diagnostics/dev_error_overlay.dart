import 'package:flutter/material.dart';
import 'package:project00/core/diagnostics/dev_error_log.dart';

/// 기존 앱 배선을 유지하는 무표시 진단 경계입니다.
///
/// 디버그에서도 배지·목록·오류 원문·stack trace를 화면에 그리지 않습니다.
class DevErrorOverlay extends StatelessWidget {
  const DevErrorOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

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
