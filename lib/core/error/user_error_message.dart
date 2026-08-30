import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:project00/core/error/app_exception.dart';
import 'package:project00/platform/home/room/services/room_common.dart';

/// 오류가 난 문맥입니다.
///
/// 같은 예외라도 문맥에 따라 다른 재시도 안내를 붙이고, 어떤 문맥에서는 아예
/// 표시하지 않습니다. 대표적인 예가 `permission-denied`입니다 — 정상 퇴장으로
/// 구독 권한이 사라진 것이므로 퇴장·구독 문맥에서는 오류가 아니지만, 명령을
/// 보내려다 거부된 것이라면 사용자에게 알려야 합니다.
enum UserErrorContext {
  leaveRoom,
  leaveGame,
  roomCommand,
  roomSubscription,
  gameCommand,
  gameSubscription,
}

/// 화면에 표시할 한국어 문구입니다. **null은 "표시하지 않는다"는 뜻입니다.**
///
/// `FirebaseException`, `PlatformException`, 네이티브 stack trace, 영어 원문을
/// UI에 그대로 넣지 않기 위한 단일 관문입니다. 이 함수는 [error]를 문자열에
/// 보간하지 않습니다. 새 매핑을 추가할 때도 그 규칙을 지켜야 하며,
/// `test/user_error_message_test.dart`의 불변식 시험이 이를 강제합니다.
///
/// 우리 Cloud Functions가 `HttpsError`로 내려보낸 한국어 문구는 그대로
/// 통과시킵니다. 상황별로 가장 정확한 안내가 서버 쪽에 있기 때문입니다.
String? userErrorMessage(Object? error, {required UserErrorContext context}) {
  if (error == null) return null;

  // 1. 권한 거부: 정상 퇴장으로 구독이 끝난 경우라 사용자 오류가 아닙니다.
  if (isPermissionDenied(error)) {
    return switch (context) {
      UserErrorContext.leaveRoom ||
      UserErrorContext.leaveGame ||
      UserErrorContext.roomSubscription ||
      UserErrorContext.gameSubscription => null,
      UserErrorContext.roomCommand ||
      UserErrorContext.gameCommand => UserErrorCopy.noPermission,
    };
  }

  // 2. 네이티브 잡음: RTDB 스트림은 연결이 돌아오면 최신 값을 다시 보냅니다.
  //    iOS 플러그인의 긴 unknown Stacktrace를 화면에 덮지 않습니다.
  if (_isTransientNativeNoise(error)) return null;

  // 3. 우리 서버가 준 한국어 안내는 그대로 씁니다.
  final serverMessage = _koreanServerMessage(error);
  if (serverMessage != null) return serverMessage;

  // 4. 코드·타입별 매핑.
  if (_isNetworkError(error)) {
    return switch (context) {
      UserErrorContext.leaveRoom => UserErrorCopy.leaveRoomNetwork,
      UserErrorContext.leaveGame => UserErrorCopy.leaveGameNetwork,
      UserErrorContext.roomSubscription ||
      UserErrorContext.gameSubscription => UserErrorCopy.unstableConnection,
      UserErrorContext.roomCommand ||
      UserErrorContext.gameCommand => UserErrorCopy.serverUnreachable,
    };
  }

  switch (_codeOf(error)) {
    case 'not-found':
      return UserErrorCopy.roomNotFound;
    case 'unauthenticated':
      return UserErrorCopy.signInExpired;
    case 'resource-exhausted':
      return UserErrorCopy.roomFull;
  }

  // 5. 정체를 모르는 오류는 문맥별 일반 안내로 덮습니다.
  return switch (context) {
    UserErrorContext.leaveRoom => UserErrorCopy.leaveRoomFailed,
    UserErrorContext.leaveGame => UserErrorCopy.leaveGameFailed,
    UserErrorContext.roomSubscription ||
    UserErrorContext.gameSubscription => UserErrorCopy.unstableConnection,
    UserErrorContext.roomCommand ||
    UserErrorContext.gameCommand => UserErrorCopy.requestFailed,
  };
}

/// 사용자에게 아무것도 표시하지 않아야 하는 오류인지입니다.
bool isSilentUserError(Object? error, {required UserErrorContext context}) =>
    userErrorMessage(error, context: context) == null;

/// 읽기·쓰기 권한이 거부된 오류인지입니다.
///
/// RTDB는 규칙에 막히면 `permission-denied`(Dart 코드) 또는
/// `permission_denied`(원본 메시지)로 알려 줍니다. 둘 다 봅니다.
bool isPermissionDenied(Object error) {
  if (_codeOf(error).replaceAll('_', '-') == 'permission-denied') return true;
  final text = error.toString();
  return text.contains('permission_denied') ||
      text.contains('permission-denied');
}

String _codeOf(Object error) {
  if (error is FirebaseException) return error.code;
  if (error is PlatformException) return error.code;
  return '';
}

/// 연결이 돌아오면 스스로 복구되는, 사용자가 할 일이 없는 오류입니다.
bool _isTransientNativeNoise(Object error) {
  if (_codeOf(error) == 'cancelled') return true;
  final text = error.toString().toLowerCase();
  return text.contains('firebase_database/unknown') ||
      text.contains('stacktrace:');
}

/// 우리 Cloud Functions·서비스 계층이 만든 한국어 안내만 통과시킵니다.
///
/// Firebase SDK가 만든 영어 문장과 네이티브 오류는 걸러야 하므로, 한글이
/// 들어 있고 길이가 짧고 개행·플러그인 흔적이 없는 문구만 사용자 문구로
/// 인정합니다.
String? _koreanServerMessage(Object error) {
  final raw = switch (error) {
    RoomCommandException(:final message) => message,
    AppException(:final message) => message,
    FirebaseException(:final message?) => message,
    PlatformException(:final message?) => message,
    _ => null,
  };
  if (raw == null) return null;
  final message = raw.trim();
  if (message.isEmpty || message.length > 120) return null;
  if (!_hangul.hasMatch(message)) return null;
  if (message.contains('\n')) return null;
  if (message.contains('Stacktrace') ||
      message.contains('Exception:') ||
      message.contains('firebase_')) {
    return null;
  }
  return message;
}

final RegExp _hangul = RegExp(r'[가-힣]');

bool _isNetworkError(Object error) {
  if (error is TimeoutException) return true;
  if (error is SocketException) return true;
  if (const {
    'unavailable',
    'deadline-exceeded',
    'internal',
    'aborted',
    'unknown',
    'network-error',
    'network-request-failed',
  }.contains(_codeOf(error))) {
    return true;
  }
  final text = error.toString().toLowerCase();
  return text.contains('socketexception') ||
      text.contains('network is unreachable') ||
      text.contains('connection closed') ||
      text.contains('failed host lookup');
}

/// 사용자 오류 문구 원본입니다.
///
/// 시험이 문자열 리터럴을 복사하지 않도록 여기 한곳에만 둡니다.
abstract final class UserErrorCopy {
  static const String noPermission = '이 방에 대한 권한이 없습니다. 방 상태를 다시 확인해주세요.';
  static const String leaveRoomNetwork =
      '네트워크 상태가 불안정해 방에서 나가지 못했습니다. 연결을 확인한 뒤 다시 시도해주세요.';
  static const String leaveGameNetwork =
      '네트워크 상태가 불안정해 게임에서 나가지 못했습니다. 연결을 확인한 뒤 다시 시도해주세요.';
  static const String leaveRoomFailed = '방에서 나가지 못했습니다. 잠시 후 다시 시도해주세요.';
  static const String leaveGameFailed = '게임에서 나가지 못했습니다. 잠시 후 다시 시도해주세요.';
  static const String unstableConnection = '연결이 불안정합니다. 네트워크 상태를 확인해주세요.';
  static const String serverUnreachable = '서버에 연결하지 못했습니다. 잠시 후 다시 시도해주세요.';
  static const String requestFailed = '요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.';
  static const String roomNotFound = '방을 찾을 수 없습니다.';
  static const String signInExpired = '로그인이 만료되었습니다. 앱을 다시 실행해주세요.';
  static const String roomFull = '방 인원이 가득 찼습니다.';
}
