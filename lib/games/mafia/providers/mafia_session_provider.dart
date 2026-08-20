import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project00/games/mafia/controllers/mafia_controller.dart';
import 'package:project00/games/mafia/providers/mafia_game_state.dart';
import 'package:project00/games/mafia/services/mafia_service.dart';

//=======================마피아 세션 식별자==============================
@immutable
class MafiaSessionArgs {
  const MafiaSessionArgs({
    required this.roomCode,
    required this.uid,
    required this.service,
    required this.watchPrivate,
  });

  final String roomCode;
  final String uid;
  final MafiaService service;

  /// 휴대폰은 true, 태블릿은 false입니다.
  ///
  /// 태블릿이 개인 노드를 구독하면 신분이 화면 쪽 메모리로 흘러들어 옵니다.
  final bool watchPrivate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MafiaSessionArgs &&
          roomCode == other.roomCode &&
          uid == other.uid &&
          identical(service, other.service) &&
          watchPrivate == other.watchPrivate;

  @override
  int get hashCode =>
      Object.hash(roomCode, uid, identityHashCode(service), watchPrivate);
}

//=======================마피아 불변 세션 Provider==============================
/// 같은 방·사용자·기기 역할에는 Notifier를 하나만 생성합니다.
///
/// 화면이 사라지면 autoDispose가 공개·개인 구독을 함께 정리합니다.
final mafiaSessionProvider = NotifierProvider.autoDispose
    .family<MafiaController, MafiaGameState, MafiaSessionArgs>((args) {
      return MafiaController(
        roomCode: args.roomCode,
        uid: args.uid,
        service: args.service,
        watchPrivate: args.watchPrivate,
      );
    });
