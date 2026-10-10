import 'package:firebase_auth/firebase_auth.dart';
import 'package:game_kit/recovery/services/room_session_identity_store.dart';

/// An uncertain start must be reconciled before writing seats again.
Future<bool> hasPendingTabletGameStart(String roomCode) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return false;
  final store = RoomSessionIdentityStore.instance;
  await store.load();
  if (FirebaseAuth.instance.currentUser?.uid != uid) return false;
  return store.pendingGameStart(uid, 'controller', roomCode) != null;
}

Future<bool> prepareTabletGameStart({
  required String roomCode,
  required Future<bool> Function() saveSeats,
  required Future<void> Function() startGame,
  required bool Function() isCurrent,
}) async {
  final pending = await hasPendingTabletGameStart(roomCode);
  if (!isCurrent()) return false;
  if (!pending && !await saveSeats()) return false;
  if (!isCurrent()) return false;
  await startGame();
  return isCurrent();
}
