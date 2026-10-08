// [network_unavailable_modal.dart] 는 여러 게임이 함께 사용하는 네트워크 연결 상태와 재연결 흐름을 관리하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [RecoveryWidget] : 네트워크 단절 안내 모달을 표시함
//
// 즉, 통신이 끊겨도 연결 문제를 안내하고 안전하게 복구하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_connection.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';

// ============================================================

/// 인터넷 연결이 끊겼을 때 앱 전체에서 공통으로 사용하는 연결 끊김 화면입니다.
///
/// 시안 '내 인터넷 연결 끊김': 휴대폰은 위 장면·아래 시트, 태블릿은 왼쪽 장면·
/// 오른쪽 패널입니다. 아래 게임 화면은 그대로 두고 그 위를 덮습니다.
class NetworkUnavailableModal extends StatelessWidget {
  const NetworkUnavailableModal({
    super.key,
    required this.onRetry,
    this.isRetrying = false,
    this.retryEnabled = true,
    this.onExit,
    this.exitLabel = '홈으로',
    this.title = '인터넷 연결이 끊겼어요',
    this.description = '와이파이나 모바일 데이터를 확인해 주세요.',
    this.characterId,
  });

  static const cardKey = Key('network-unavailable-card');
  static const retryButtonKey = Key('network-unavailable-retry');

  final VoidCallback onRetry;
  final bool isRetrying;

  /// 오프라인에는 SDK 재연결을 기다리며 실행할 수 없는 재시도 버튼을 숨깁니다.
  final bool retryEnabled;
  final VoidCallback? onExit;
  final String exitLabel;
  final String title;
  final String description;

  /// 장면에 그릴 내 캐릭터입니다. 모르면 기본 캐릭터를 그립니다.
  final String? characterId;

  @override
  Widget build(BuildContext context) {
    final status = isRetrying
        ? '다시 연결하는 중'
        : retryEnabled
        ? '자동으로 다시 연결하는 중'
        : '인터넷 연결을 기다리는 중';
    return MosiConnectionLayout(
      key: cardKey,
      semanticLabel: '인터넷 연결 끊김',
      background: MosiColors.navy,
      scene: MosiWifiLostScene(characterId: characterId),
      tag: '내 기기',
      title: title,
      body: description,
      status: MosiConnectionStatus(text: status),
      actions: [
        // 인터넷은 돌아왔는데 서버 복구가 늦을 때만 직접 재시도를 내줍니다.
        if (retryEnabled)
          MosiConnectionButton(
            key: retryButtonKey,
            label: '다시 시도',
            primary: true,
            loading: isRetrying,
            semanticLabel: '네트워크 연결 재시도',
            onPressed: isRetrying ? null : onRetry,
          ),
        if (onExit != null)
          MosiConnectionButton(
            label: exitLabel,
            onPressed: isRetrying ? null : onExit,
          ),
      ],
    );
  }
}
