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
  /// **'모시 게임 미술관'**
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
  /// **'액자를 눌러 게임을 골라 보세요'**
  String get chooseFrame;

  /// No description provided for @ownedDot.
  ///
  /// In ko, this message translates to:
  /// **'빨간 점 = 소장 중'**
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
