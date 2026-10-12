import 'package:game_kit/localization/game_locale.dart';

enum RoomJoinFeedbackTone { warning, danger }

class RoomJoinFeedback {
  const RoomJoinFeedback({required this.message, required this.tone});

  final String message;
  final RoomJoinFeedbackTone tone;
}

RoomJoinFeedback roomJoinFeedbackFor(String? rawMessage) {
  final message = rawMessage?.trim() ?? '';
  final normalized = message.toLowerCase();

  if (message.contains('인원이 초과') ||
      message.contains('정원을 초과') ||
      normalized.contains('resource-exhausted')) {
    return RoomJoinFeedback(
      message: GameLocale.select(
        ko: '이 그룹은 정원을 초과했습니다.',
        en: 'This room is full.',
        zhHans: '该房间已满。',
        zhHant: '該房間已滿。',
      ),
      tone: RoomJoinFeedbackTone.warning,
    );
  }
  if (message.contains('진행 중인 게임')) {
    return RoomJoinFeedback(
      message: GameLocale.select(
        ko: '이미 게임이 진행 중인 그룹입니다.',
        en: 'A game is already in progress in this room.',
        zhHans: '该房间的游戏已经开始。',
        zhHant: '該房間的遊戲已經開始。',
      ),
      tone: RoomJoinFeedbackTone.warning,
    );
  }
  if (message.contains('게임 준비') || message.contains('준비가 시작')) {
    return RoomJoinFeedback(
      message: GameLocale.select(
        ko: '이미 게임 준비가 시작된 방입니다.',
        en: 'Game setup has already started in this room.',
        zhHans: '该房间已开始游戏准备。',
        zhHant: '該房間已開始遊戲準備。',
      ),
      tone: RoomJoinFeedbackTone.warning,
    );
  }
  if (message.contains('방을 찾을 수 없') ||
      message.contains('존재하지 않는') ||
      normalized.contains('not-found')) {
    return RoomJoinFeedback(
      message: GameLocale.select(
        ko: '존재하지 않는 참여 코드입니다.',
        en: 'That room code does not exist.',
        zhHans: '该加入码不存在。',
        zhHant: '該加入碼不存在。',
      ),
      tone: RoomJoinFeedbackTone.danger,
    );
  }
  if (message.contains('종료된 방') || message.contains('이미 종료')) {
    return RoomJoinFeedback(
      message: GameLocale.select(
        ko: '이미 종료된 그룹입니다.',
        en: 'This room has already closed.',
        zhHans: '该房间已结束。',
        zhHant: '該房間已結束。',
      ),
      tone: RoomJoinFeedbackTone.danger,
    );
  }
  if (message.contains('인증 정보') || message.contains('로그인 정보')) {
    return RoomJoinFeedback(
      message: GameLocale.select(
        ko: '로그인 정보를 확인할 수 없습니다.',
        en: 'Could not verify your sign-in.',
        zhHans: '无法验证登录信息。',
        zhHant: '無法驗證登入資訊。',
      ),
      tone: RoomJoinFeedbackTone.danger,
    );
  }
  if (normalized.contains('network') ||
      normalized.contains('unavailable') ||
      normalized.contains('deadline') ||
      normalized.contains('socket') ||
      normalized.contains('connection')) {
    return RoomJoinFeedback(
      message: GameLocale.select(
        ko: '네트워크 연결을 확인한 후 다시 시도해 주세요.',
        en: 'Check your connection and try again.',
        zhHans: '请检查网络连接后重试。',
        zhHant: '請檢查網路連線後重試。',
      ),
      tone: RoomJoinFeedbackTone.danger,
    );
  }
  return RoomJoinFeedback(
    message: GameLocale.select(
      ko: '그룹에 참여하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      en: 'Could not join the room. Try again shortly.',
      zhHans: '无法加入房间，请稍后重试。',
      zhHant: '無法加入房間，請稍後重試。',
    ),
    tone: RoomJoinFeedbackTone.danger,
  );
}
