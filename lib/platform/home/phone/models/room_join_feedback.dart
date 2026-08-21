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
    return const RoomJoinFeedback(
      message: '이 그룹은 정원을 초과했습니다.',
      tone: RoomJoinFeedbackTone.warning,
    );
  }
  if (message.contains('진행 중인 게임')) {
    return const RoomJoinFeedback(
      message: '이미 게임이 진행 중인 그룹입니다.',
      tone: RoomJoinFeedbackTone.warning,
    );
  }
  if (message.contains('게임 준비') || message.contains('준비가 시작')) {
    return const RoomJoinFeedback(
      message: '이미 게임 준비가 시작된 방입니다.',
      tone: RoomJoinFeedbackTone.warning,
    );
  }
  if (message.contains('방을 찾을 수 없') ||
      message.contains('존재하지 않는') ||
      normalized.contains('not-found')) {
    return const RoomJoinFeedback(
      message: '존재하지 않는 참여 코드입니다.',
      tone: RoomJoinFeedbackTone.danger,
    );
  }
  if (message.contains('종료된 방') || message.contains('이미 종료')) {
    return const RoomJoinFeedback(
      message: '이미 종료된 그룹입니다.',
      tone: RoomJoinFeedbackTone.danger,
    );
  }
  if (message.contains('인증 정보') || message.contains('로그인 정보')) {
    return const RoomJoinFeedback(
      message: '로그인 정보를 확인할 수 없습니다.',
      tone: RoomJoinFeedbackTone.danger,
    );
  }
  if (normalized.contains('network') ||
      normalized.contains('unavailable') ||
      normalized.contains('deadline') ||
      normalized.contains('socket') ||
      normalized.contains('connection')) {
    return const RoomJoinFeedback(
      message: '네트워크 연결을 확인한 후 다시 시도해 주세요.',
      tone: RoomJoinFeedbackTone.danger,
    );
  }
  return const RoomJoinFeedback(
    message: '그룹에 참여하지 못했습니다. 잠시 후 다시 시도해 주세요.',
    tone: RoomJoinFeedbackTone.danger,
  );
}
