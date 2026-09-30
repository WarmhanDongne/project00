// [game_session_controller.dart] 는 여러 게임이 함께 사용하는 게임 세션 구독과 명령 실행의 공통 뼈대를 담당하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [GameFlow] : 공개·개인 구독 배선, 방 삭제 감지, 명령 실행, 중단 처리를 담당함
//
// 즉, 게임마다 같은 배선을 다시 쓰다가 한 가지씩 빠뜨리지 않기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/core/diagnostics/crash_reporting.dart';
import 'package:game_kit/core/error/user_error_message.dart';
import 'package:game_kit/game_flow/game_interruption.dart';
import 'package:game_kit/game_flow/game_session_state.dart';
import 'package:game_kit/services/game_interruption_command_service.dart';
import 'package:game_kit/services/game_query_service.dart';
// ============================================================

//=======================게임 세션 공통 뼈대==============================
/// 게임 컨트롤러가 **게임 규칙과 무관하게** 똑같이 해야 하는 일을 모았습니다.
///
/// 마피아와 파이널콜 컨트롤러는 주석을 걷어내면 33%(153줄)가 글자 단위로 같았고,
/// 그 안에는 **한쪽에만 들어간 수정**이 섞여 있었습니다. 방이 사라졌을 때
/// 화면이 마지막 상태에 굳던 문제를 마피아만 고쳐 두었던 것이 그 예입니다.
/// 같은 코드를 두 벌 두면 고침도 두 벌 해야 하고, 실제로 한쪽이 빠집니다.
///
/// ## 여기서 하는 일
/// 1. 공개·개인 상태 구독을 열고, provider 폐기 때 닫습니다.
/// 2. 공개 상태가 비면 **바로 끝내지 않고** 1.5초 뒤 한 번 더 읽어 확인합니다.
///    (재연결 직후 캐시가 잠깐 비는 것을 게임 삭제로 오인하지 않기 위해)
/// 3. 읽기가 거부되면(`permission_denied`) 방이 사라진 것으로 보고 같은 확인을
///    거칩니다.
/// 4. 서버 명령을 하나씩만 보내고, 실패를 사용자 문구와 Crashlytics로 나눕니다.
/// 5. 게임 중단(끊김) 명령 네 가지를 제공합니다.
///
/// ## 여기서 하지 않는 일
/// **스냅샷 해석은 전부 게임의 몫입니다.** [applyPublicValue] 와
/// [handlePrivateEvent] 만 구현하면 됩니다. 공용 코드가 남의 게임 필드를
/// 해석하려 들면 게임이 늘 때마다 이 파일이 부풀어 오릅니다.
abstract class GameSessionController<TState extends GameSessionState<TState>>
    extends Notifier<TState> {
  //=======================게임이 제공해야 하는 것==============================
  /// 이 세션의 방 코드입니다.
  String get roomCode;

  /// 내 uid입니다.
  String get uid;

  /// 공개·개인 상태를 읽는 서비스입니다.
  GameQueryService get query;

  /// 게임 중단(끊김) 명령 서비스입니다.
  GameInterruptionCommandService get interruptionCommands;

  /// 지금 진행 중인 중단입니다. 게임 상태에서 꺼내 돌려주세요.
  GameInterruption? get interruption;

  /// Crashlytics에 남길 이름입니다(예: `'마피아 서버 명령'`).
  String get commandCrashReason;

  /// 공개 상태 스냅샷을 해석해 [state]에 반영합니다.
  @protected
  void applyPublicValue(Object? value);

  /// 개인 상태 이벤트를 해석해 [state]에 반영합니다.
  ///
  /// 개인 구독을 열지 않는 게임·기기(태블릿 등)는 호출되지 않습니다.
  @protected
  void handlePrivateEvent(DatabaseEvent event);

  //=======================구독 배선==============================
  StreamSubscription<DatabaseEvent>? _publicSubscription;
  StreamSubscription<DatabaseEvent>? _privateSubscription;
  Timer? _missingPublicTimer;

  /// [build] 안에서 한 번 부르세요. 구독을 열고 폐기 처리를 등록합니다.
  ///
  /// [watchPrivate]가 false면 개인 구독을 열지 않습니다. 태블릿 화면에 개인
  /// 정보(마피아의 역할 등)가 흘러들면 옆에서 보는 사람에게 다 드러납니다.
  @protected
  void startSession({required bool watchPrivate}) {
    _publicSubscription = query
        .watchPublicGame(roomCode)
        .listen(_handlePublic, onError: _handlePublicError);
    if (watchPrivate) {
      _privateSubscription = watchPrivateStream().listen(
        handlePrivateEvent,
        onError: handleSubscriptionError,
      );
    }
    ref.onDispose(() {
      _missingPublicTimer?.cancel();
      unawaited(_publicSubscription?.cancel());
      unawaited(_privateSubscription?.cancel());
    });
  }

  /// 개인 상태를 어떤 스트림에서 받을지 정합니다.
  ///
  /// 기본은 `game/private/{uid}` 전체입니다. 그 아래 특정 노드만 보는 게임은
  /// 재정의하세요 — 라이어스포커는 손패(`hand`)만 봅니다. 노드를 좁히면
  /// 받는 스냅샷 모양도 달라지므로, [handlePrivateEvent]와 짝을 맞춰야 합니다.
  @protected
  Stream<DatabaseEvent> watchPrivateStream() =>
      query.watchPrivatePlayer(roomCode: roomCode, uid: uid);

  void _handlePublic(DatabaseEvent event) {
    if (!ref.mounted) return;

    // 재연결 직후 캐시가 잠깐 null인 경우를 실제 게임 삭제로 오인하지 않습니다.
    if (!event.snapshot.exists || event.snapshot.value == null) {
      _confirmMissingPublicGame();
      return;
    }
    _missingPublicTimer?.cancel();
    _missingPublicTimer = null;
    applyPublicValue(event.snapshot.value);
  }

  /// 구독 오류를 어떻게 알릴지 결정합니다.
  ///
  /// 기본은 사용자 문구를 상태에 넣는 것입니다. 태블릿이 SnackBar로 알리거나,
  /// 초기 데이터 대기를 풀어 줘야 하는 게임은 이 메서드를 재정의하세요.
  ///
  /// `userErrorMessage`가 null을 돌려주면 **표시하지 않는다**는 뜻입니다.
  /// 정상 퇴장으로 권한이 사라진 경우가 여기 해당합니다 — 예외 원문을 그대로
  /// 화면에 띄우면 퇴장 중에 영문 permission-denied가 뜹니다.
  @protected
  void handleSubscriptionError(Object error) {
    setError(
      userErrorMessage(error, context: UserErrorContext.gameSubscription) ??
          UserErrorCopy.unstableConnection,
    );
  }

  /// 공개 상태 구독이 끊긴 경우입니다.
  ///
  /// **읽기가 거부되면(`permission_denied`) 방이 사라진 것으로 봅니다.** 방이
  /// 지워지거나 이 기기가 방에서 빠지면 규칙이 읽기를 막습니다. 예전에는 이때
  /// '연결이 불안정합니다'만 띄우고 **마지막 상태에 그대로 머물렀습니다** —
  /// 태블릿이 밤 화면에 굳은 채 마감 처리를 끝없이 다시 시도하며 오류만
  /// 쌓였습니다(2026-08 시뮬레이터에서 확인).
  ///
  /// 로그아웃·토큰 갱신 직후에도 잠깐 거부될 수 있어, 곧바로 끝내지 않고
  /// [_confirmMissingPublicGame]으로 한 번 더 읽어 확인합니다.
  void _handlePublicError(Object error) {
    if (!isPermissionDenied(error)) {
      handleSubscriptionError(error);
      return;
    }
    setError('게임을 읽을 수 없습니다. 방이 사라졌는지 확인합니다…');
    _confirmMissingPublicGame();
  }

  void _confirmMissingPublicGame() {
    if (_missingPublicTimer != null) return;
    _missingPublicTimer = Timer(const Duration(milliseconds: 1500), () async {
      _missingPublicTimer = null;
      try {
        final snapshot = await query.readPublicGame(roomCode);
        if (!ref.mounted) return;
        if (snapshot.exists && snapshot.value != null) {
          applyPublicValue(snapshot.value);
          return;
        }
        _finishForRemovedGame();
      } catch (error) {
        if (!ref.mounted) return;
        // 다시 읽어도 거부되면 방이 없는 것이 확실합니다.
        if (isPermissionDenied(error)) {
          _finishForRemovedGame();
          return;
        }
        // 네트워크가 아직 복구 중이면 마지막 정상 상태를 유지합니다. onValue가
        // 재연결 후 현재 공개 상태를 다시 전달하므로 임의 종료하지 않습니다.
      }
    });
  }

  void _finishForRemovedGame() {
    if (!ref.mounted) return;
    state = state.asRemovedGame();
  }

  //=======================명령 실행==============================
  /// 서버 명령 하나를 보냅니다. **동시에 하나만** 나갑니다.
  ///
  /// 성공 여부를 bool로 돌려줍니다. 서버가 `{success: false}`를 정상 응답으로
  /// 내려보내는 경우(예: 마감 전 타임아웃 호출)도 실패로 봅니다.
  @protected
  Future<bool> run(Future<Object?> Function() command) async {
    if (state.commandInFlight) return false;
    state = state.markCommandStarted();
    try {
      final result = await command();
      // 서버는 "아직 할 일이 아니다"를 예외가 아니라 정상 응답으로 알립니다
      // (예: 마감 전 타임아웃 호출 → {success: false, reason: "notExpired"}).
      // 이를 성공으로 넘기면 호출자가 재시도하지 않아 진행이 멈춥니다.
      // 명시적인 success:false만 실패로 봅니다(success 필드가 없는 명령도 있음).
      if (result is Map && result['success'] == false) return false;
      return true;
    } catch (error, stack) {
      // 사용자에게는 짧은 안내만 보여 주고, 실제 원인은 따로 남깁니다.
      // 개발 중에는 화면 오른쪽 아래 표시로, 출시 뒤에는 Crashlytics로
      // 올라가 어떤 명령이 실패했는지 추적할 수 있습니다.
      CrashReporting.recordError(error, stack, reason: commandCrashReason);
      setError(
        userErrorMessage(error, context: UserErrorContext.gameCommand) ??
            UserErrorCopy.requestFailed,
      );
      return false;
    } finally {
      if (ref.mounted) {
        state = state.markCommandFinished();
      }
    }
  }

  /// 화면에 보여 줄 오류 문구를 설정합니다.
  @protected
  void setError(String message) {
    if (!ref.mounted) return;
    state = state.withError(message);
  }

  /// 오류 문구를 지웁니다. 화면이 안내를 닫을 때 부릅니다.
  void clearError() {
    if (!ref.mounted) return;
    state = state.withError(null);
  }

  //=======================중단(끊김) 처리==============================
  /// 기다렸다가 계속하는 쪽에 한 표를 던집니다.
  Future<bool> voteToContinueInterruption() {
    final current = interruption;
    if (current == null) return Future.value(false);
    return run(
      () => interruptionCommands.voteToContinue(
        roomCode: roomCode,
        interruptionId: current.id,
      ),
    );
  }

  /// 마감이 지난 중단을 정리합니다.
  Future<bool> expireInterruption() {
    final current = interruption;
    if (current == null) return Future.value(false);
    return run(
      () => interruptionCommands.expire(
        roomCode: roomCode,
        interruptionId: current.id,
      ),
    );
  }

  /// 태블릿 진행자가 중단된 참가자를 제외하고 게임을 계속합니다.
  ///
  /// 호출부는 각 게임 태블릿 화면의 `GameInterruptionLayer.onContinue`입니다.
  /// 세 게임이 같은 자리, 같은 문구를 씁니다.
  Future<bool> excludeInterruptedPlayerAndContinue() {
    final current = interruption;
    if (current == null || !current.canContinue) return Future.value(false);
    return run(
      () => interruptionCommands.excludeAndContinue(
        roomCode: roomCode,
        interruptionId: current.id,
      ),
    );
  }

  /// 남은 인원이 부족한 중단을 마감 전에 즉시 종료합니다.
  ///
  /// [excludeInterruptedPlayerAndContinue]의 거울상입니다. 계속할 수 있는
  /// 중단은 투표·제외 흐름의 몫이므로 여기서 끝내지 않습니다.
  Future<bool> finishInterruptedGameNow() {
    final current = interruption;
    if (current == null || current.canContinue) return Future.value(false);
    return run(
      () => interruptionCommands.finishNow(
        roomCode: roomCode,
        interruptionId: current.id,
      ),
    );
  }
}
