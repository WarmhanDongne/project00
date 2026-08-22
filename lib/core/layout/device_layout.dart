import 'package:flutter/widgets.dart';

abstract final class DeviceLayout {
  static const double tabletBreakpoint = 600;

  static bool isTablet(BoxConstraints constraints) {
    return constraints.biggest.shortestSide >= tabletBreakpoint;
  }

  /// 지금 기기가 태블릿인지입니다.
  ///
  /// 창 크기를 직접 읽으므로 [BuildContext] 없이도 쓸 수 있습니다. 화면 방향
  /// 복원처럼 위젯 트리 밖(dispose·앱 시작)에서 판단해야 하는 곳이 있습니다.
  static bool isTabletDevice() {
    // 바인딩의 dispatcher를 씁니다. 시험에서 화면 크기를 바꿔 확인할 수 있어야
    // 하고(PlatformDispatcher.instance는 시험의 창 설정을 따르지 않습니다),
    // 실제 앱에서는 같은 객체입니다.
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final view = dispatcher.implicitView ?? dispatcher.views.firstOrNull;
    final size = view != null
        ? (view.physicalSize / view.devicePixelRatio)
        : const Size(390, 844);
    return size.shortestSide >= tabletBreakpoint;
  }
}
