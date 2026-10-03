// [game_controller.dart] 는 새 게임 템플릿에서 사용하는 서버 상태 구독과 게임 명령을 조율하는 파일이다.
//
// - [Package] : 새 게임 템플릿
// - [Controller] : 공용 뼈대(GameSessionController)를 상속한 최소 컨트롤러
//
// 즉, 새 게임이 구독·오류·끊김 처리를 다시 짜지 않고 규칙 해석만 채우게 하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:game_kit/recovery/models/game_interruption.dart';
import 'package:game_kit/recovery/providers/game_session_controller.dart';
import 'package:game_kit/recovery/services/game_interruption_command_service.dart';
import 'package:game_kit/services/game_query_service.dart';
import 'package:game_template/shared/models/game_state.dart';
import 'package:game_template/shared/services/game_service.dart';
import 'package:game_template/shared/services/public_state_mapper.dart';

// ============================================================

// ---------------------------------------------------------------------------
// 새 게임 Riverpod 컨트롤러
// ---------------------------------------------------------------------------
/// 새 게임의 서버 미러 컨트롤러 견본입니다.
///
/// 구독 배선·방 삭제 확인·권한 오류·끊김 명령은 [GameSessionController]가
/// 이미 합니다. 새 게임이 채울 것은 두 가지뿐입니다.
/// - [applyPublicValue] : `game/public` 스냅샷을 상태로 옮기기
/// - [handlePrivateEvent] : `game/private/{uid}` 스냅샷을 상태로 옮기기(휴대폰만)
///
/// 상태는 **한 번의 `state = state.copyWith(...)`** 로 발행합니다. 필드마다
/// 따로 쓰면 알림이 여러 번 가고, 화면이 반쯤 바뀐 상태를 보게 됩니다.
class TemplateController extends GameSessionController<TemplateGameState> {
  TemplateController({
    required this.roomCode,
    required this.uid,
    required this.service,
    this.watchPrivate = true,
  });

  @override
  final String roomCode;
  @override
  final String uid;
  final TemplateService service;

  /// 휴대폰은 true(내 개인 상태 구독), 태블릿(진행 기기)은 false입니다.
  /// 태블릿이 개인 상태를 받으면 옆에서 보는 사람에게 전부 드러납니다.
  final bool watchPrivate;

  // ---------------------------------------------------------------------------
  // 공용 뼈대에 넘겨 주는 것
  // ---------------------------------------------------------------------------
  @override
  GameQueryService get query => service.query;

  @override
  GameInterruptionCommandService get interruptionCommands =>
      service.interruption;

  @override
  String get commandCrashReason => '템플릿 서버 명령';

  @override
  GameInterruption? get interruption => state.interruption;

  @override
  TemplateGameState build() {
    // build 안에서는 상태를 바꾸거나 로그를 남기는 일을 하지 않습니다.
    // 예열처럼 부수효과가 있는 일은 build가 끝난 뒤로 미룹니다.
    if (!watchPrivate) {
      Timer.run(() {
        if (ref.mounted) unawaited(_warmUp());
      });
    }
    startSession(watchPrivate: watchPrivate);
    return TemplateGameState.initial();
  }

  Future<void> _warmUp() async {
    try {
      await service.command.warmUpGameplayCommands();
    } catch (_) {
      // 예열 실패는 실제 명령이 다시 호출하므로 화면에 알리지 않습니다.
    }
  }

  // ---------------------------------------------------------------------------
  // 서버 스냅샷 해석
  // ---------------------------------------------------------------------------
  @override
  void applyPublicValue(Object? value) {
    // 빈 스냅샷 처리와 방 삭제 확인은 공용 뼈대가 먼저 합니다.
    if (value is! Map) return;
    final snapshot = TemplatePublicSnapshot.fromValue(
      value,
      fallbackStatus: state.status,
      fallbackPhase: state.phase,
      fallbackRound: state.round,
      fallbackRevision: state.revision,
    );
    state = state.copyWith(
      loading: false,
      status: snapshot.status,
      phase: snapshot.phase,
      round: snapshot.round,
      revision: snapshot.revision,
      interruption: snapshot.interruption,
    );
  }

  @override
  void handlePrivateEvent(DatabaseEvent event) {
    // 내 손패·역할처럼 나만 보는 값이 있는 게임만 여기서 해석합니다.
    // 필요 없으면 비워 두고, 화면에서 watchPrivate를 false로 두세요.
  }

  // ---------------------------------------------------------------------------
  // 게임 명령
  // ---------------------------------------------------------------------------
  /// 명령의 표준 모양입니다. [run]이 중복 전송을 막고, 진행 표시와 실패 문구를
  /// 상태에 반영합니다.
  Future<bool> play(String choice) =>
      run(() => service.command.play(roomCode: roomCode, choice: choice));
}
