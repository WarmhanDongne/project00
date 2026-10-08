import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ko, this message translates to:
  /// **'Mosigame'**
  String get appTitle;

  /// No description provided for @regionLanguage.
  ///
  /// In ko, this message translates to:
  /// **'국가/지역 및 언어'**
  String get regionLanguage;

  /// No description provided for @language.
  ///
  /// In ko, this message translates to:
  /// **'언어'**
  String get language;

  /// No description provided for @region.
  ///
  /// In ko, this message translates to:
  /// **'국가/지역'**
  String get region;

  /// No description provided for @regionHint.
  ///
  /// In ko, this message translates to:
  /// **'이 기기의 표시 설정이에요. 계정이나 결제 국가는 바뀌지 않아요.'**
  String get regionHint;

  /// No description provided for @translationScope.
  ///
  /// In ko, this message translates to:
  /// **'주요 메뉴에 적용돼요. 게임 설명·규칙·이미지와 일부 안내는 아직 한국어로 표시돼요.'**
  String get translationScope;

  /// No description provided for @save.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get close;

  /// No description provided for @saveFailed.
  ///
  /// In ko, this message translates to:
  /// **'저장하지 못했어요. 다시 시도해 주세요.'**
  String get saveFailed;

  /// No description provided for @regionKR.
  ///
  /// In ko, this message translates to:
  /// **'대한민국'**
  String get regionKR;

  /// No description provided for @regionUS.
  ///
  /// In ko, this message translates to:
  /// **'미국'**
  String get regionUS;

  /// No description provided for @regionCN.
  ///
  /// In ko, this message translates to:
  /// **'중국 본토'**
  String get regionCN;

  /// No description provided for @regionTW.
  ///
  /// In ko, this message translates to:
  /// **'대만'**
  String get regionTW;

  /// No description provided for @regionHK.
  ///
  /// In ko, this message translates to:
  /// **'홍콩'**
  String get regionHK;

  /// No description provided for @gameStore.
  ///
  /// In ko, this message translates to:
  /// **'게임 상점'**
  String get gameStore;

  /// No description provided for @shelf.
  ///
  /// In ko, this message translates to:
  /// **'선반'**
  String get shelf;

  /// No description provided for @details.
  ///
  /// In ko, this message translates to:
  /// **'자세히 보기'**
  String get details;

  /// No description provided for @login.
  ///
  /// In ko, this message translates to:
  /// **'로그인'**
  String get login;

  /// No description provided for @signUp.
  ///
  /// In ko, this message translates to:
  /// **'회원가입'**
  String get signUp;

  /// No description provided for @email.
  ///
  /// In ko, this message translates to:
  /// **'이메일'**
  String get email;

  /// No description provided for @password.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호'**
  String get password;

  /// No description provided for @googleLogin.
  ///
  /// In ko, this message translates to:
  /// **'Google 로그인'**
  String get googleLogin;

  /// No description provided for @appleLogin.
  ///
  /// In ko, this message translates to:
  /// **'Apple로 로그인'**
  String get appleLogin;

  /// No description provided for @checkCredentials.
  ///
  /// In ko, this message translates to:
  /// **'이메일과 비밀번호를 확인해주세요.'**
  String get checkCredentials;

  /// No description provided for @invalidCredentials.
  ///
  /// In ko, this message translates to:
  /// **'이메일 또는 비밀번호가 올바르지 않습니다.'**
  String get invalidCredentials;

  /// No description provided for @invalidEmail.
  ///
  /// In ko, this message translates to:
  /// **'이메일 형식이 올바르지 않습니다.'**
  String get invalidEmail;

  /// No description provided for @checkNetwork.
  ///
  /// In ko, this message translates to:
  /// **'네트워크 연결을 확인해주세요.'**
  String get checkNetwork;

  /// No description provided for @myProfile.
  ///
  /// In ko, this message translates to:
  /// **'내 프로필'**
  String get myProfile;

  /// No description provided for @editProfile.
  ///
  /// In ko, this message translates to:
  /// **'내 프로필 수정'**
  String get editProfile;

  /// No description provided for @openProfile.
  ///
  /// In ko, this message translates to:
  /// **'내 프로필 열기'**
  String get openProfile;

  /// No description provided for @nickname.
  ///
  /// In ko, this message translates to:
  /// **'닉네임'**
  String get nickname;

  /// No description provided for @account.
  ///
  /// In ko, this message translates to:
  /// **'계정'**
  String get account;

  /// No description provided for @logout.
  ///
  /// In ko, this message translates to:
  /// **'로그아웃'**
  String get logout;

  /// No description provided for @deleteAccount.
  ///
  /// In ko, this message translates to:
  /// **'회원탈퇴'**
  String get deleteAccount;

  /// No description provided for @checkingDeletion.
  ///
  /// In ko, this message translates to:
  /// **'탈퇴 확인 중…'**
  String get checkingDeletion;

  /// No description provided for @changePhoto.
  ///
  /// In ko, this message translates to:
  /// **'사진 변경'**
  String get changePhoto;

  /// No description provided for @tapPhoto.
  ///
  /// In ko, this message translates to:
  /// **'사진을 누르면 바꿀 수 있어요'**
  String get tapPhoto;

  /// No description provided for @nicknameHint.
  ///
  /// In ko, this message translates to:
  /// **'계정에 표시돼요. 지금 들어가 있는 방의 닉네임은 그대로예요.'**
  String get nicknameHint;

  /// No description provided for @howToPlay.
  ///
  /// In ko, this message translates to:
  /// **'플레이 방법'**
  String get howToPlay;

  /// No description provided for @joinGroup.
  ///
  /// In ko, this message translates to:
  /// **'그룹 참여'**
  String get joinGroup;

  /// No description provided for @reconnecting.
  ///
  /// In ko, this message translates to:
  /// **'재접속 중'**
  String get reconnecting;

  /// No description provided for @retry.
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get retry;

  /// No description provided for @comingSoon.
  ///
  /// In ko, this message translates to:
  /// **'준비 중'**
  String get comingSoon;

  /// No description provided for @checking.
  ///
  /// In ko, this message translates to:
  /// **'확인 중'**
  String get checking;

  /// No description provided for @checkFailed.
  ///
  /// In ko, this message translates to:
  /// **'확인 실패'**
  String get checkFailed;

  /// No description provided for @owned.
  ///
  /// In ko, this message translates to:
  /// **'보유 중'**
  String get owned;

  /// No description provided for @free.
  ///
  /// In ko, this message translates to:
  /// **'무료'**
  String get free;

  /// No description provided for @purchaseSoon.
  ///
  /// In ko, this message translates to:
  /// **'구매 준비 중'**
  String get purchaseSoon;

  /// No description provided for @checkingProgress.
  ///
  /// In ko, this message translates to:
  /// **'확인 중…'**
  String get checkingProgress;

  /// No description provided for @checkAgain.
  ///
  /// In ko, this message translates to:
  /// **'다시 확인'**
  String get checkAgain;

  /// No description provided for @playFromShelf.
  ///
  /// In ko, this message translates to:
  /// **'선반에서 하기'**
  String get playFromShelf;

  /// No description provided for @releaseSoon.
  ///
  /// In ko, this message translates to:
  /// **'공개 준비 중'**
  String get releaseSoon;

  /// No description provided for @galleryTitle.
  ///
  /// In ko, this message translates to:
  /// **'모시 서점'**
  String get galleryTitle;

  /// No description provided for @restorePurchases.
  ///
  /// In ko, this message translates to:
  /// **'구매 내역 복원'**
  String get restorePurchases;

  /// No description provided for @restoreSoon.
  ///
  /// In ko, this message translates to:
  /// **'구매 내역 복원은 준비 중이에요.'**
  String get restoreSoon;

  /// No description provided for @chooseFrame.
  ///
  /// In ko, this message translates to:
  /// **'표지를 눌러 게임을 골라 보세요'**
  String get chooseFrame;

  /// No description provided for @ownedDot.
  ///
  /// In ko, this message translates to:
  /// **'책갈피 = 소장 중'**
  String get ownedDot;

  /// No description provided for @purchaseNotice.
  ///
  /// In ko, this message translates to:
  /// **'결제 기능은 준비 중이에요. 곧 열어 드릴게요.'**
  String get purchaseNotice;

  /// No description provided for @next.
  ///
  /// In ko, this message translates to:
  /// **'다음'**
  String get next;

  /// No description provided for @passwordAgain.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호 재입력'**
  String get passwordAgain;

  /// No description provided for @uploadPhoto.
  ///
  /// In ko, this message translates to:
  /// **'사진 올리기'**
  String get uploadPhoto;

  /// No description provided for @removePhoto.
  ///
  /// In ko, this message translates to:
  /// **'사진 지우기'**
  String get removePhoto;

  /// No description provided for @useGooglePhoto.
  ///
  /// In ko, this message translates to:
  /// **'Google 사진 쓰기'**
  String get useGooglePhoto;

  /// No description provided for @waitingPlayers.
  ///
  /// In ko, this message translates to:
  /// **'플레이어를 기다리는 중'**
  String get waitingPlayers;

  /// No description provided for @members.
  ///
  /// In ko, this message translates to:
  /// **'구성원 목록'**
  String get members;

  /// No description provided for @noPlayers.
  ///
  /// In ko, this message translates to:
  /// **'아직 아무도 없습니다'**
  String get noPlayers;

  /// No description provided for @invite.
  ///
  /// In ko, this message translates to:
  /// **'초대하기'**
  String get invite;

  /// No description provided for @creating.
  ///
  /// In ko, this message translates to:
  /// **'생성 중...'**
  String get creating;

  /// No description provided for @reset.
  ///
  /// In ko, this message translates to:
  /// **'초기화'**
  String get reset;

  /// No description provided for @resetting.
  ///
  /// In ko, this message translates to:
  /// **'초기화 중...'**
  String get resetting;

  /// No description provided for @ready.
  ///
  /// In ko, this message translates to:
  /// **'준비 완료'**
  String get ready;

  /// No description provided for @connectionLost.
  ///
  /// In ko, this message translates to:
  /// **'연결 끊김'**
  String get connectionLost;

  /// No description provided for @ownedGames.
  ///
  /// In ko, this message translates to:
  /// **'보유 중인 게임'**
  String get ownedGames;

  /// No description provided for @phonePlayHint.
  ///
  /// In ko, this message translates to:
  /// **'모바일에서는 방에 참여해 플레이합니다.'**
  String get phonePlayHint;

  /// No description provided for @roomInviteHint.
  ///
  /// In ko, this message translates to:
  /// **'방을 열면 친구들이 휴대폰 카메라로\nQR을 찍어 바로 들어와요.'**
  String get roomInviteHint;

  /// No description provided for @startWithPlayers.
  ///
  /// In ko, this message translates to:
  /// **'{count}명으로 시작하기'**
  String startWithPlayers(int count);

  /// No description provided for @previewSara.
  ///
  /// In ko, this message translates to:
  /// **'사라'**
  String get previewSara;

  /// No description provided for @previewMinjun.
  ///
  /// In ko, this message translates to:
  /// **'민준'**
  String get previewMinjun;

  /// No description provided for @previewHarin.
  ///
  /// In ko, this message translates to:
  /// **'하린'**
  String get previewHarin;

  /// No description provided for @previewJiwoo.
  ///
  /// In ko, this message translates to:
  /// **'지우'**
  String get previewJiwoo;

  /// No description provided for @previewTableAce.
  ///
  /// In ko, this message translates to:
  /// **'기준 카드 · A'**
  String get previewTableAce;

  /// No description provided for @previewNextMinjun.
  ///
  /// In ko, this message translates to:
  /// **'사라 → 다음은 민준'**
  String get previewNextMinjun;

  /// No description provided for @previewYourTurn.
  ///
  /// In ko, this message translates to:
  /// **'내 차례'**
  String get previewYourTurn;

  /// No description provided for @previewTwoAces.
  ///
  /// In ko, this message translates to:
  /// **'A 두 장!'**
  String get previewTwoAces;

  /// No description provided for @previewCaught.
  ///
  /// In ko, this message translates to:
  /// **'들켰다… 룰렛으로'**
  String get previewCaught;

  /// No description provided for @previewLiarClaim.
  ///
  /// In ko, this message translates to:
  /// **'LIAR! 거짓말'**
  String get previewLiarClaim;

  /// No description provided for @previewWatching.
  ///
  /// In ko, this message translates to:
  /// **'지켜보는 중'**
  String get previewWatching;

  /// No description provided for @previewCallReveal.
  ///
  /// In ko, this message translates to:
  /// **'CALL! 모두 공개'**
  String get previewCallReveal;

  /// No description provided for @previewDrawSwap.
  ///
  /// In ko, this message translates to:
  /// **'가져오기 · 교체'**
  String get previewDrawSwap;

  /// No description provided for @previewTeamAskSara.
  ///
  /// In ko, this message translates to:
  /// **'사라, 숫자 좀 됐어?'**
  String get previewTeamAskSara;

  /// No description provided for @previewTeamSaraScore.
  ///
  /// In ko, this message translates to:
  /// **'7 들어왔어! 지금 14'**
  String get previewTeamSaraScore;

  /// No description provided for @previewTeamAskJiwoo.
  ///
  /// In ko, this message translates to:
  /// **'지우야, 우리 이 정도면 충분해?'**
  String get previewTeamAskJiwoo;

  /// No description provided for @previewTeamJiwooScore.
  ///
  /// In ko, this message translates to:
  /// **'난 12! 꼴찌는 아냐, 콜 가자'**
  String get previewTeamJiwooScore;

  /// No description provided for @previewSaraRedTeam.
  ///
  /// In ko, this message translates to:
  /// **'사라 · 레드팀'**
  String get previewSaraRedTeam;

  /// No description provided for @previewRed.
  ///
  /// In ko, this message translates to:
  /// **'빨강'**
  String get previewRed;

  /// No description provided for @previewBlue.
  ///
  /// In ko, this message translates to:
  /// **'파랑'**
  String get previewBlue;

  /// No description provided for @previewYellow.
  ///
  /// In ko, this message translates to:
  /// **'노랑'**
  String get previewYellow;

  /// No description provided for @previewSameColor.
  ///
  /// In ko, this message translates to:
  /// **'같은 색 7 + 3 = 10'**
  String get previewSameColor;

  /// No description provided for @previewSameRank.
  ///
  /// In ko, this message translates to:
  /// **'같은 숫자 7 + 7 = 14'**
  String get previewSameRank;

  /// No description provided for @previewMyScore.
  ///
  /// In ko, this message translates to:
  /// **'내 점수'**
  String get previewMyScore;

  /// No description provided for @previewNight.
  ///
  /// In ko, this message translates to:
  /// **'밤이 되었습니다'**
  String get previewNight;

  /// No description provided for @previewChoosePrivately.
  ///
  /// In ko, this message translates to:
  /// **'각자 휴대폰에서 몰래 고르세요'**
  String get previewChoosePrivately;

  /// No description provided for @previewMorning.
  ///
  /// In ko, this message translates to:
  /// **'아침이 밝았습니다'**
  String get previewMorning;

  /// No description provided for @previewNobodyDied.
  ///
  /// In ko, this message translates to:
  /// **'아무도 죽지 않았어요'**
  String get previewNobodyDied;

  /// No description provided for @previewCitizen.
  ///
  /// In ko, this message translates to:
  /// **'시민'**
  String get previewCitizen;

  /// No description provided for @previewWaitMorning.
  ///
  /// In ko, this message translates to:
  /// **'눈 감고\n아침을 기다려요'**
  String get previewWaitMorning;

  /// No description provided for @previewDiscussion.
  ///
  /// In ko, this message translates to:
  /// **'토론 시작'**
  String get previewDiscussion;

  /// No description provided for @previewMafiaPrivate.
  ///
  /// In ko, this message translates to:
  /// **'마피아 · 나만 보여요'**
  String get previewMafiaPrivate;

  /// No description provided for @previewNightTarget.
  ///
  /// In ko, this message translates to:
  /// **'오늘 밤 누구를?'**
  String get previewNightTarget;

  /// No description provided for @previewTargetChosen.
  ///
  /// In ko, this message translates to:
  /// **'지목 완료'**
  String get previewTargetChosen;

  /// No description provided for @previewDoctorSave.
  ///
  /// In ko, this message translates to:
  /// **'의사 · 한 명 살리기'**
  String get previewDoctorSave;

  /// No description provided for @previewSaved.
  ///
  /// In ko, this message translates to:
  /// **'휴, 살았다…!'**
  String get previewSaved;

  /// No description provided for @previewBlinds.
  ///
  /// In ko, this message translates to:
  /// **'블라인드 10/20'**
  String get previewBlinds;

  /// No description provided for @previewFlopTurn.
  ///
  /// In ko, this message translates to:
  /// **'FLOP · 사라 차례'**
  String get previewFlopTurn;

  /// No description provided for @previewTurnRiver.
  ///
  /// In ko, this message translates to:
  /// **'TURN · RIVER'**
  String get previewTurnRiver;

  /// No description provided for @previewShowdown.
  ///
  /// In ko, this message translates to:
  /// **'SHOWDOWN'**
  String get previewShowdown;

  /// No description provided for @previewRaiseClaim.
  ///
  /// In ko, this message translates to:
  /// **'400 레이즈!'**
  String get previewRaiseClaim;

  /// No description provided for @previewFlushWin.
  ///
  /// In ko, this message translates to:
  /// **'플러시로 +830'**
  String get previewFlushWin;

  /// No description provided for @previewThinking.
  ///
  /// In ko, this message translates to:
  /// **'고민 중'**
  String get previewThinking;

  /// No description provided for @previewCallClaim.
  ///
  /// In ko, this message translates to:
  /// **'콜! 따라갈게'**
  String get previewCallClaim;

  /// No description provided for @previewFolded.
  ///
  /// In ko, this message translates to:
  /// **'이번 판 폴드'**
  String get previewFolded;

  /// No description provided for @previewFoldClaim.
  ///
  /// In ko, this message translates to:
  /// **'폴드…'**
  String get previewFoldClaim;

  /// No description provided for @previewWin.
  ///
  /// In ko, this message translates to:
  /// **'WIN'**
  String get previewWin;

  /// No description provided for @previewSpadeFlush.
  ///
  /// In ko, this message translates to:
  /// **'스페이드 플러시'**
  String get previewSpadeFlush;

  /// No description provided for @previewRaise.
  ///
  /// In ko, this message translates to:
  /// **'Raise'**
  String get previewRaise;

  /// No description provided for @previewCall.
  ///
  /// In ko, this message translates to:
  /// **'Call'**
  String get previewCall;

  /// No description provided for @previewFold.
  ///
  /// In ko, this message translates to:
  /// **'Fold'**
  String get previewFold;

  /// No description provided for @previewPot.
  ///
  /// In ko, this message translates to:
  /// **'POT {chips}'**
  String previewPot(String chips);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hans':
            return AppLocalizationsZhHans();
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
