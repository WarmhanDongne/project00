import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_kit/firebase/firebase_backend.dart';
import 'package:game_kit/recovery/models/game_interruption.dart';
import 'package:game_kit/recovery/models/game_session_state.dart';
import 'package:game_kit/recovery/providers/game_session_controller.dart';
import 'package:game_kit/recovery/services/game_interruption_command_service.dart';
import 'package:game_kit/services/game_query_service.dart';
import 'package:game_yut/src/service.dart';

@immutable
class YutSessionArgs {
  const YutSessionArgs({
    required this.roomCode,
    required this.uid,
    required this.watchPrivate,
  });
  final String roomCode;
  final String uid;
  final bool watchPrivate;
  @override
  bool operator ==(Object other) =>
      other is YutSessionArgs &&
      roomCode == other.roomCode &&
      uid == other.uid &&
      watchPrivate == other.watchPrivate;
  @override
  int get hashCode => Object.hash(roomCode, uid, watchPrivate);
}

@immutable
class YutSessionState implements GameSessionState<YutSessionState> {
  const YutSessionState({
    this.loading = true,
    this.commandInFlight = false,
    this.errorMessage,
    this.publicState = const {},
    this.privateState = const {},
  });
  final bool loading;
  @override
  final bool commandInFlight;
  @override
  final String? errorMessage;
  final Map<String, dynamic> publicState;
  final Map<String, dynamic> privateState;
  YutSessionState copyWith({
    bool? loading,
    bool? commandInFlight,
    Object? errorMessage = _unset,
    Map<String, dynamic>? publicState,
    Map<String, dynamic>? privateState,
  }) => YutSessionState(
    loading: loading ?? this.loading,
    commandInFlight: commandInFlight ?? this.commandInFlight,
    errorMessage: identical(errorMessage, _unset)
        ? this.errorMessage
        : errorMessage as String?,
    publicState: publicState ?? this.publicState,
    privateState: privateState ?? this.privateState,
  );
  @override
  YutSessionState markCommandStarted() =>
      copyWith(commandInFlight: true, errorMessage: null);
  @override
  YutSessionState markCommandFinished() => copyWith(commandInFlight: false);
  @override
  YutSessionState withError(String? message) => copyWith(errorMessage: message);
  @override
  YutSessionState asRemovedGame() => copyWith(
    loading: false,
    publicState: const {'status': 'finished', 'phase': 'finished'},
  );
}

const _unset = Object();

/// 지금 로그인한 사용자 UID입니다. 로컬·서버 백엔드를 고른 Firebase 앱을 따릅니다.
final yutUidProvider = Provider<String>(
  (ref) => FirebaseBackend.auth.currentUser?.uid ?? '',
);

final yutSessionProvider = NotifierProvider.autoDispose
    .family<YutSessionController, YutSessionState, YutSessionArgs>(
      (args) => YutSessionController(args),
    );

class YutSessionController extends GameSessionController<YutSessionState> {
  YutSessionController(this.args);
  final YutSessionArgs args;
  late final _service = YutService();
  Future<bool> execute(Future<Object?> Function() command) => run(command);
  @override
  String get roomCode => args.roomCode;
  @override
  String get uid => args.uid;
  @override
  GameQueryService get query => _service.query;
  @override
  GameInterruptionCommandService get interruptionCommands =>
      GameInterruptionCommandService();
  @override
  String get commandCrashReason => '윷놀이 서버 명령';
  @override
  GameInterruption? get interruption {
    final value = state.publicState['recovery'];
    if (value is Map) {
      return GameInterruption.fromMap(Map<Object?, Object?>.from(value));
    }
    return null;
  }

  @override
  YutSessionState build() {
    startSession(watchPrivate: args.watchPrivate);
    return const YutSessionState();
  }

  @override
  void applyPublicValue(Object? value) {
    if (value is! Map) return;
    state = state.copyWith(
      loading: false,
      errorMessage: null,
      publicState: Map<String, dynamic>.from(value),
    );
  }

  @override
  void handlePrivateEvent(DatabaseEvent event) {
    final value = event.snapshot.value;
    state = state.copyWith(
      privateState: value is Map ? Map<String, dynamic>.from(value) : const {},
    );
  }
}
