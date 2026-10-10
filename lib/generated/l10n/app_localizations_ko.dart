// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Mosigame';

  @override
  String get regionLanguage => '국가/지역 및 언어';

  @override
  String get language => '언어';

  @override
  String get region => '국가/지역';

  @override
  String get regionHint => '이 기기의 표시 설정이에요. 계정이나 결제 국가는 바뀌지 않아요.';

  @override
  String get translationScope =>
      '주요 메뉴에 적용돼요. 게임 설명·규칙·이미지와 일부 안내는 아직 한국어로 표시돼요.';

  @override
  String get save => '저장';

  @override
  String get cancel => '취소';

  @override
  String get close => '닫기';

  @override
  String get saveFailed => '저장하지 못했어요. 다시 시도해 주세요.';

  @override
  String get regionKR => '대한민국';

  @override
  String get regionUS => '미국';

  @override
  String get regionCN => '중국 본토';

  @override
  String get regionTW => '대만';

  @override
  String get regionHK => '홍콩';

  @override
  String get gameStore => '게임 상점';

  @override
  String get shelf => '선반';

  @override
  String get details => '자세히 보기';

  @override
  String get login => '로그인';

  @override
  String get signUp => '회원가입';

  @override
  String get email => '이메일';

  @override
  String get password => '비밀번호';

  @override
  String get googleLogin => 'Google 로그인';

  @override
  String get appleLogin => 'Apple로 로그인';

  @override
  String get checkCredentials => '이메일과 비밀번호를 확인해주세요.';

  @override
  String get invalidCredentials => '이메일 또는 비밀번호가 올바르지 않습니다.';

  @override
  String get invalidEmail => '이메일 형식이 올바르지 않습니다.';

  @override
  String get checkNetwork => '네트워크 연결을 확인해주세요.';

  @override
  String get myProfile => '내 프로필';

  @override
  String get editProfile => '내 프로필 수정';

  @override
  String get openProfile => '내 프로필 열기';

  @override
  String get nickname => '닉네임';

  @override
  String get account => '계정';

  @override
  String get logout => '로그아웃';

  @override
  String get deleteAccount => '회원탈퇴';

  @override
  String get checkingDeletion => '탈퇴 확인 중…';

  @override
  String get changePhoto => '사진 변경';

  @override
  String get tapPhoto => '사진을 누르면 바꿀 수 있어요';

  @override
  String get nicknameHint => '계정에 표시돼요. 지금 들어가 있는 방의 닉네임은 그대로예요.';

  @override
  String get howToPlay => '플레이 방법';

  @override
  String get joinGroup => '그룹 참여';

  @override
  String get reconnecting => '재접속 중';

  @override
  String get retry => '다시 시도';

  @override
  String get comingSoon => '준비 중';

  @override
  String get checking => '확인 중';

  @override
  String get checkFailed => '확인 실패';

  @override
  String get owned => '보유 중';

  @override
  String get free => '무료';

  @override
  String get purchaseSoon => '구매 준비 중';

  @override
  String get checkingProgress => '확인 중…';

  @override
  String get checkAgain => '다시 확인';

  @override
  String get playFromShelf => '선반에서 하기';

  @override
  String get releaseSoon => '공개 준비 중';

  @override
  String get galleryTitle => '모시 서점';

  @override
  String get restorePurchases => '구매 내역 복원';

  @override
  String get restoreSoon => '구매 내역 복원은 준비 중이에요.';

  @override
  String get chooseFrame => '표지를 눌러 게임을 골라 보세요';

  @override
  String get ownedDot => '책갈피 = 소장 중';

  @override
  String get purchaseNotice => '결제 기능은 준비 중이에요. 곧 열어 드릴게요.';

  @override
  String get next => '다음';

  @override
  String get passwordAgain => '비밀번호 재입력';

  @override
  String get uploadPhoto => '사진 올리기';

  @override
  String get removePhoto => '사진 지우기';

  @override
  String get useGooglePhoto => 'Google 사진 쓰기';

  @override
  String get waitingPlayers => '플레이어를 기다리는 중';

  @override
  String get members => '구성원 목록';

  @override
  String get noPlayers => '아직 아무도 없습니다';

  @override
  String get invite => '초대하기';

  @override
  String get creating => '생성 중...';

  @override
  String get reset => '초기화';

  @override
  String get resetting => '초기화 중...';

  @override
  String get ready => '준비 완료';

  @override
  String get connectionLost => '연결 끊김';

  @override
  String get ownedGames => '보유 중인 게임';

  @override
  String get phonePlayHint => '모바일에서는 방에 참여해 플레이합니다.';

  @override
  String get roomInviteHint => '방을 열면 친구들이 휴대폰 카메라로\nQR을 찍어 바로 들어와요.';

  @override
  String startWithPlayers(int count) {
    return '$count명으로 시작하기';
  }

  @override
  String get previewSara => '사라';

  @override
  String get previewMinjun => '민준';

  @override
  String get previewHarin => '하린';

  @override
  String get previewJiwoo => '지우';

  @override
  String get previewTableAce => '기준 카드 · A';

  @override
  String get previewNextMinjun => '사라 → 다음은 민준';

  @override
  String get previewYourTurn => '내 차례';

  @override
  String get previewTwoAces => 'A 두 장!';

  @override
  String get previewCaught => '들켰다… 룰렛으로';

  @override
  String get previewLiarClaim => 'LIAR! 거짓말';

  @override
  String get previewWatching => '지켜보는 중';

  @override
  String get previewCallReveal => 'CALL! 모두 공개';

  @override
  String get previewDrawSwap => '가져오기 · 교체';

  @override
  String get previewTeamAskSara => '사라, 숫자 좀 됐어?';

  @override
  String get previewTeamSaraScore => '7 들어왔어! 지금 14';

  @override
  String get previewTeamAskJiwoo => '지우야, 우리 이 정도면 충분해?';

  @override
  String get previewTeamJiwooScore => '난 12! 꼴찌는 아냐, 콜 가자';

  @override
  String get previewSaraRedTeam => '사라 · 레드팀';

  @override
  String get previewRed => '빨강';

  @override
  String get previewBlue => '파랑';

  @override
  String get previewYellow => '노랑';

  @override
  String get previewSameColor => '같은 색 7 + 3 = 10';

  @override
  String get previewSameRank => '같은 숫자 7 + 7 = 14';

  @override
  String get previewMyScore => '내 점수';

  @override
  String get previewNight => '밤이 되었습니다';

  @override
  String get previewChoosePrivately => '각자 휴대폰에서 몰래 고르세요';

  @override
  String get previewMorning => '아침이 밝았습니다';

  @override
  String get previewNobodyDied => '아무도 죽지 않았어요';

  @override
  String get previewCitizen => '시민';

  @override
  String get previewWaitMorning => '눈 감고\n아침을 기다려요';

  @override
  String get previewDiscussion => '토론 시작';

  @override
  String get previewMafiaPrivate => '마피아 · 나만 보여요';

  @override
  String get previewNightTarget => '오늘 밤 누구를?';

  @override
  String get previewTargetChosen => '지목 완료';

  @override
  String get previewDoctorSave => '의사 · 한 명 살리기';

  @override
  String get previewSaved => '휴, 살았다…!';

  @override
  String get previewBlinds => '블라인드 10/20';

  @override
  String get previewFlopTurn => 'FLOP · 사라 차례';

  @override
  String get previewTurnRiver => 'TURN · RIVER';

  @override
  String get previewShowdown => 'SHOWDOWN';

  @override
  String get previewRaiseClaim => '400 레이즈!';

  @override
  String get previewFlushWin => '플러시로 +830';

  @override
  String get previewThinking => '고민 중';

  @override
  String get previewCallClaim => '콜! 따라갈게';

  @override
  String get previewFolded => '이번 판 폴드';

  @override
  String get previewFoldClaim => '폴드…';

  @override
  String get previewWin => 'WIN';

  @override
  String get previewSpadeFlush => '스페이드 플러시';

  @override
  String get previewRaise => 'Raise';

  @override
  String get previewCall => 'Call';

  @override
  String get previewFold => 'Fold';

  @override
  String previewPot(String chips) {
    return 'POT $chips';
  }

  @override
  String get connectionBandLost => '연결이 끊겼어요 · 자동으로 다시 이어 볼게요';

  @override
  String get connectionBandReconnecting => '다시 연결하는 중… 화면은 그대로 두세요';

  @override
  String get connectionBandRestored => '다시 연결됐어요';

  @override
  String get profileSaved => '저장됐어요';

  @override
  String get gamePreparing => '게임 준비 중';
}
