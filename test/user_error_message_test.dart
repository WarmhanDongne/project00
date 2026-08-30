import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/core/error/user_error_message.dart';
import 'package:project00/platform/home/room/services/room_common.dart';

void main() {
  group('권한 거부', () {
    test('정상 퇴장과 구독 종료에서는 표시하지 않는다', () {
      for (final context in const [
        UserErrorContext.leaveRoom,
        UserErrorContext.leaveGame,
        UserErrorContext.roomSubscription,
        UserErrorContext.gameSubscription,
      ]) {
        expect(
          userErrorMessage(_permissionDenied(), context: context),
          isNull,
          reason: '$context에서 permission-denied는 사용자 오류가 아닙니다',
        );
      }
    });

    test('명령이 거부된 경우에는 한국어로 알린다', () {
      final message = userErrorMessage(
        _permissionDenied(),
        context: UserErrorContext.roomCommand,
      );
      expect(message, UserErrorCopy.noPermission);
    });

    test('밑줄 표기와 원문 문자열도 권한 거부로 본다', () {
      final underscore = FirebaseException(
        plugin: 'firebase_database',
        code: 'permission_denied',
      );
      expect(
        userErrorMessage(underscore, context: UserErrorContext.leaveRoom),
        isNull,
      );
      expect(
        userErrorMessage(
          StateError('Listen at /rooms failed: permission_denied'),
          context: UserErrorContext.gameSubscription,
        ),
        isNull,
      );
    });
  });

  group('네이티브 잡음', () {
    test('firebase_database/unknown과 native stack trace는 표시하지 않는다', () {
      final unknown = FirebaseException(
        plugin: 'firebase_database',
        code: 'unknown',
        message: 'Stacktrace: \n#0 MethodChannelDatabase.get',
      );
      for (final context in UserErrorContext.values) {
        expect(userErrorMessage(unknown, context: context), isNull);
      }
    });

    test('cancelled는 어떤 문맥에서도 표시하지 않는다', () {
      final cancelled = FirebaseFunctionsException(
        code: 'cancelled',
        message: 'The operation was cancelled.',
      );
      for (final context in UserErrorContext.values) {
        expect(userErrorMessage(cancelled, context: context), isNull);
      }
    });
  });

  group('우리 서버가 준 한국어 안내', () {
    test('Cloud Functions의 상황별 문구를 그대로 통과시킨다', () {
      final error = FirebaseFunctionsException(
        code: 'failed-precondition',
        message: '게임 중에는 게임별 퇴장 기능을 사용해주세요.',
      );
      expect(
        userErrorMessage(error, context: UserErrorContext.leaveRoom),
        '게임 중에는 게임별 퇴장 기능을 사용해주세요.',
      );
    });

    test('RoomCommandException의 문구를 그대로 통과시킨다', () {
      expect(
        userErrorMessage(
          const RoomCommandException('이미 종료된 방입니다.'),
          context: UserErrorContext.roomCommand,
        ),
        '이미 종료된 방입니다.',
      );
    });

    test('영어 SDK 문구는 통과시키지 않는다', () {
      final error = FirebaseFunctionsException(
        code: 'unavailable',
        message: 'INTERNAL',
      );
      final message = userErrorMessage(
        error,
        context: UserErrorContext.leaveGame,
      );
      expect(message, UserErrorCopy.leaveGameNetwork);
      expect(message, isNot(contains('INTERNAL')));
    });

    test('native stack trace가 붙은 오류는 아예 표시하지 않는다', () {
      final error = FirebaseException(
        plugin: 'firebase_database',
        code: 'write-failed',
        message: '쓰기에 실패했습니다.\nStacktrace: #0 ...',
      );
      // 사용자가 할 수 있는 일이 없고 스스로 복구되므로 문구 대신 침묵합니다.
      expect(
        userErrorMessage(error, context: UserErrorContext.roomCommand),
        isNull,
      );
    });

    test('여러 줄 문구는 원문 대신 일반 안내로 덮는다', () {
      final error = FirebaseException(
        plugin: 'firebase_database',
        code: 'write-failed',
        message: '쓰기에 실패했습니다.\n경로: rooms/ABCDE/players',
      );
      final message = userErrorMessage(
        error,
        context: UserErrorContext.roomCommand,
      );
      expect(message, UserErrorCopy.requestFailed);
      expect(message, isNot(contains('rooms/')));
    });
  });

  group('코드별 매핑', () {
    test('네트워크 오류는 문맥에 맞는 재시도 안내를 붙인다', () {
      final error = FirebaseFunctionsException(
        code: 'unavailable',
        message: 'The service is currently unavailable.',
      );
      expect(
        userErrorMessage(error, context: UserErrorContext.leaveRoom),
        UserErrorCopy.leaveRoomNetwork,
      );
      expect(
        userErrorMessage(error, context: UserErrorContext.leaveGame),
        UserErrorCopy.leaveGameNetwork,
      );
      expect(
        userErrorMessage(error, context: UserErrorContext.roomSubscription),
        UserErrorCopy.unstableConnection,
      );
      expect(
        userErrorMessage(error, context: UserErrorContext.gameCommand),
        UserErrorCopy.serverUnreachable,
      );
    });

    test('타임아웃과 소켓 오류도 네트워크 오류로 본다', () {
      expect(
        userErrorMessage(
          TimeoutException('no response'),
          context: UserErrorContext.leaveRoom,
        ),
        UserErrorCopy.leaveRoomNetwork,
      );
      expect(
        userErrorMessage(
          const SocketException('failed host lookup'),
          context: UserErrorContext.leaveGame,
        ),
        UserErrorCopy.leaveGameNetwork,
      );
    });

    test('인증·인원·방 없음 코드를 각각 안내한다', () {
      expect(
        userErrorMessage(
          FirebaseFunctionsException(code: 'not-found', message: 'not found'),
          context: UserErrorContext.roomCommand,
        ),
        UserErrorCopy.roomNotFound,
      );
      expect(
        userErrorMessage(
          FirebaseFunctionsException(
            code: 'unauthenticated',
            message: 'Unauthenticated',
          ),
          context: UserErrorContext.roomCommand,
        ),
        UserErrorCopy.signInExpired,
      );
      expect(
        userErrorMessage(
          FirebaseFunctionsException(
            code: 'resource-exhausted',
            message: 'Too many players',
          ),
          context: UserErrorContext.roomCommand,
        ),
        UserErrorCopy.roomFull,
      );
    });

    test('PlatformException의 영어 원문을 노출하지 않는다', () {
      final message = userErrorMessage(
        PlatformException(
          code: 'error',
          message: 'Unable to establish connection on channel.',
        ),
        context: UserErrorContext.gameCommand,
      );
      expect(message, isNotNull);
      expect(message, isNot(contains('Unable')));
    });

    test('null은 표시하지 않는다', () {
      expect(
        userErrorMessage(null, context: UserErrorContext.roomCommand),
        isNull,
      );
      expect(
        isSilentUserError(null, context: UserErrorContext.roomCommand),
        isTrue,
      );
    });
  });

  // 앞으로 매핑을 추가할 때도 영어 원문·stack trace가 새지 않게 강제합니다.
  test('표시하는 문구에는 영어 단어와 긴 원문이 들어가지 않는다', () {
    final latinWord = RegExp(r'[A-Za-z]{3,}');
    for (final error in _fixtures) {
      for (final context in UserErrorContext.values) {
        final message = userErrorMessage(error, context: context);
        if (message == null) continue;
        expect(
          message,
          isNot(matches(latinWord)),
          reason: '${error.runtimeType} / $context 문구에 영어 원문이 남았습니다: $message',
        );
        expect(
          message.length,
          lessThanOrEqualTo(80),
          reason: '${error.runtimeType} / $context 문구가 너무 깁니다',
        );
        expect(message, isNot(contains('\n')));
      }
    }
  });
}

FirebaseException _permissionDenied() => FirebaseException(
  plugin: 'firebase_database',
  code: 'permission-denied',
  message: 'Client does not have permission to access the desired data.',
);

final List<Object> _fixtures = [
  _permissionDenied(),
  FirebaseException(
    plugin: 'firebase_database',
    code: 'permission_denied',
    message: 'permission_denied at /rooms/ABCDE',
  ),
  FirebaseException(
    plugin: 'firebase_database',
    code: 'unknown',
    message: 'Stacktrace: \n#0 MethodChannelDatabase.get',
  ),
  FirebaseFunctionsException(code: 'unavailable', message: 'INTERNAL'),
  FirebaseFunctionsException(code: 'internal', message: 'internal error'),
  FirebaseFunctionsException(code: 'aborted', message: '게임에서 퇴장하지 못했습니다.'),
  FirebaseFunctionsException(code: 'not-found', message: 'Room not found'),
  FirebaseFunctionsException(code: 'unauthenticated', message: 'no token'),
  FirebaseFunctionsException(
    code: 'resource-exhausted',
    message: 'room is full',
  ),
  FirebaseFunctionsException(
    code: 'failed-precondition',
    message: '게임 중에는 게임별 퇴장 기능을 사용해주세요.',
  ),
  PlatformException(
    code: 'error',
    message: 'Unable to establish connection on channel.',
  ),
  const RoomCommandException('인증 정보가 없습니다.'),
  TimeoutException('no response'),
  const SocketException('Failed host lookup: firebasedatabase.app'),
  StateError('Bad state: stream already listened to'),
  Exception('a very long native error ${'x' * 4000}'),
];
