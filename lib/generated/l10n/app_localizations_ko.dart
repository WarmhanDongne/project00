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
  String get galleryTitle => '모시 게임 미술관';

  @override
  String get restorePurchases => '구매 내역 복원';

  @override
  String get restoreSoon => '구매 내역 복원은 준비 중이에요.';

  @override
  String get chooseFrame => '액자를 눌러 게임을 골라 보세요';

  @override
  String get ownedDot => '빨간 점 = 소장 중';

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
}
