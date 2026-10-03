// [session_provider.dart] 는 새 게임 템플릿에서 사용하는 컨트롤러를 화면에 연결하는 Provider 파일이다.
//
// - [Package] : 새 게임 템플릿
// - [State] : 방·사용자·기기 역할당 컨트롤러 하나를 만들고 화면이 사라지면 정리함
//
// 즉, 휴대폰과 태블릿 화면이 같은 방식으로 서버 상태를 받기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_template/shared/models/game_state.dart';
import 'package:game_template/shared/providers/game_controller.dart';
import 'package:game_template/shared/services/game_service.dart';

// ============================================================

// ---------------------------------------------------------------------------
// 세션 식별자
// ---------------------------------------------------------------------------
/// Provider를 여는 열쇠입니다.
///
/// **값만 담습니다.** 함수(콜백)를 넣으면 열쇠 비교가 인스턴스에 묶여, 화면이
/// 다시 그려질 때 컨트롤러가 새로 만들어질 수 있습니다. 오류 표시는 화면이
/// `errorMessage`를 보고 합니다.
@immutable
class TemplateSessionArgs {
  const TemplateSessionArgs({
    required this.roomCode,
    required this.uid,
    required this.service,
    required this.watchPrivate,
  });

  final String roomCode;
  final String uid;
  final TemplateService service;

  /// 휴대폰은 true, 태블릿(진행 기기)은 false입니다.
  final bool watchPrivate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemplateSessionArgs &&
          roomCode == other.roomCode &&
          uid == other.uid &&
          identical(service, other.service) &&
          watchPrivate == other.watchPrivate;

  @override
  int get hashCode =>
      Object.hash(roomCode, uid, identityHashCode(service), watchPrivate);
}

// ---------------------------------------------------------------------------
// 세션 Provider
// ---------------------------------------------------------------------------
/// 화면에서는 이렇게 씁니다(세 게임 공통).
///
/// ```dart
/// // initState
/// _args = TemplateSessionArgs(roomCode: ..., uid: ..., service: ..., watchPrivate: true);
/// _subscription = ref.listenManual(templateSessionProvider(_args), (previous, next) {
///   // 소리·다이얼로그·단계 전환 같은 부수효과
/// });
/// _controller = ref.read(templateSessionProvider(_args).notifier);
///
/// // build
/// ref.watch(templateSessionProvider(_args)); // 다시 그리기
/// ```
final templateSessionProvider = NotifierProvider.autoDispose
    .family<TemplateController, TemplateGameState, TemplateSessionArgs>((args) {
      return TemplateController(
        roomCode: args.roomCode,
        uid: args.uid,
        service: args.service,
        watchPrivate: args.watchPrivate,
      );
    });
