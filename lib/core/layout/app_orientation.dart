import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 휴대폰 게임이 허용하는 화면 방향입니다.
///
/// 이 정책은 휴대폰에만 적용됩니다. 태블릿 게임은 게임 종류와 관계없이 항상
/// 가로 고정이며, 태블릿용 방향 옵션을 이 enum에 추가하면 안 됩니다.
enum PhoneGameOrientation { portraitOnly, landscapeOnly, portraitAndLandscape }

/// 플랫폼과 게임마다 사용하는 화면 방향 정책을 한곳에서 관리합니다.
///
/// 중요 불변 조건:
/// - 모든 태블릿 게임 화면은 [lockTabletGameLandscape]로 가로 고정합니다.
/// - 휴대폰 게임만 [applyPhoneGame]으로 게임별 방향을 선택합니다.
///
/// 새 게임을 추가할 때 태블릿용 게임별 회전 함수를 만들지 마세요. 휴대폰 정책은
/// `TemplateGame.phoneOrientation`에 선언하고 [applyPhoneGame]으로 적용합니다.
abstract final class AppOrientation {
  static const _portrait = [DeviceOrientation.portraitUp];
  static const _landscape = [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];
  static const _portraitAndLandscape = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  static List<DeviceOrientation>? _applied;
  static List<DeviceOrientation>? _pendingOrientations;
  static Future<void>? _pendingRequest;

  /// 게임 선택·방 참여·자리 배치 등 플랫폼 화면은 휴대폰에서 세로로 고정합니다.
  static Future<void> lockPlatformPortrait() => _apply(_portrait);

  /// 게임 선택·방 참여·자리 배치 등 플랫폼 화면은 태블릿에서 가로로 고정합니다.
  static Future<void> lockPlatformLandscape() => _apply(_landscape);

  /// 모든 태블릿 게임 화면을 가로로 고정합니다.
  ///
  /// 태블릿은 게임별 예외를 허용하지 않습니다. 휴대폰 회전 정책을 태블릿 화면에
  /// 적용하면 iOS에서 화면이 옆으로 밀리거나 검게 보일 수 있습니다.
  static Future<void> lockTabletGameLandscape() => _apply(_landscape);

  /// 휴대폰 게임에 해당 게임이 선언한 방향 정책을 적용합니다.
  static Future<void> applyPhoneGame(PhoneGameOrientation orientation) {
    return _apply(phoneGameOrientations(orientation));
  }

  /// 테스트와 정책 확인에서 사용하는 휴대폰 방향 해석 함수입니다.
  @visibleForTesting
  static List<DeviceOrientation> phoneGameOrientations(
    PhoneGameOrientation orientation,
  ) {
    return switch (orientation) {
      PhoneGameOrientation.portraitOnly => _portrait,
      PhoneGameOrientation.landscapeOnly => _landscape,
      PhoneGameOrientation.portraitAndLandscape => _portraitAndLandscape,
    };
  }

  /// 캐시를 비우고 다음 요청이 반드시 네이티브까지 전달되게 합니다.
  ///
  /// 앱이 백그라운드에서 돌아오는 등으로 iOS가 회전 요청을 놓쳤을 때, 같은
  /// 값이라 건너뛰면 영영 복구되지 않습니다. 그런 상황에서 호출하세요.
  static void invalidate() {
    _applied = null;
    _pendingOrientations = null;
    _pendingRequest = null;
  }

  /// 게임 나가기처럼 짧은 시간에 여러 화면이 같은 방향을 요청하는 경우가 많아,
  /// 직전에 적용한 값과 같으면 네이티브 회전 요청을 다시 보내지 않습니다.
  /// 연속된 회전 요청이 겹치면 화면 전환과 부딪혀 검은 화면에서 멈추는 문제가
  /// 있었습니다.
  static Future<void> _apply(List<DeviceOrientation> orientations) {
    if (_applied != null && listEquals(_applied, orientations)) {
      return Future<void>.value();
    }
    final pending = _pendingRequest;
    if (pending != null && listEquals(_pendingOrientations, orientations)) {
      return pending;
    }

    // 네이티브 호출이 끝나기 전에는 적용된 것으로 기록하지 않습니다. iOS scene이
    // 아직 연결되지 않았거나 플랫폼 호출이 실패했는데 캐시부터 갱신하면, 다음
    // 화면의 복구 요청이 중복으로 오인되어 검은 화면 상태가 고착됩니다.
    final requested = List<DeviceOrientation>.unmodifiable(orientations);
    late final Future<void> request;
    request = SystemChrome.setPreferredOrientations(requested)
        .then((_) {
          // 더 최근의 다른 방향 요청이 없다면 성공한 값만 적용 상태로 저장합니다.
          if (identical(_pendingRequest, request)) {
            _applied = requested;
          }
        })
        .whenComplete(() {
          if (identical(_pendingRequest, request)) {
            _pendingOrientations = null;
            _pendingRequest = null;
          }
        });
    _pendingOrientations = requested;
    _pendingRequest = request;
    return request;
  }
}
