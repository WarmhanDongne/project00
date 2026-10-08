// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Mosigame';

  @override
  String get regionLanguage => 'Region and language';

  @override
  String get language => 'Language';

  @override
  String get region => 'Country / region';

  @override
  String get regionHint =>
      'Display preferences for this device. Account and billing region stay unchanged.';

  @override
  String get translationScope =>
      'Applies to main menus. Game descriptions, rules, images and some messages are still in Korean.';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get saveFailed => 'Could not save. Please try again.';

  @override
  String get regionKR => 'South Korea';

  @override
  String get regionUS => 'United States';

  @override
  String get regionCN => 'Mainland China';

  @override
  String get regionTW => 'Taiwan';

  @override
  String get regionHK => 'Hong Kong';

  @override
  String get gameStore => 'Game store';

  @override
  String get shelf => 'Shelf';

  @override
  String get details => 'Details';

  @override
  String get login => 'Log in';

  @override
  String get signUp => 'Sign up';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get googleLogin => 'Continue with Google';

  @override
  String get appleLogin => 'Continue with Apple';

  @override
  String get checkCredentials => 'Check your email and password.';

  @override
  String get invalidCredentials => 'Incorrect email or password.';

  @override
  String get invalidEmail => 'Enter a valid email address.';

  @override
  String get checkNetwork => 'Check your internet connection.';

  @override
  String get myProfile => 'My profile';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get openProfile => 'Open profile';

  @override
  String get nickname => 'Nickname';

  @override
  String get account => 'Account';

  @override
  String get logout => 'Log out';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get checkingDeletion => 'Checking…';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get tapPhoto => 'Tap the photo to change it';

  @override
  String get nicknameHint =>
      'Shown on your account. Your nickname in the current room stays unchanged.';

  @override
  String get howToPlay => 'How to play';

  @override
  String get joinGroup => 'Join room';

  @override
  String get reconnecting => 'Reconnecting';

  @override
  String get retry => 'Try again';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get checking => 'Checking';

  @override
  String get checkFailed => 'Check failed';

  @override
  String get owned => 'Owned';

  @override
  String get free => 'Free';

  @override
  String get purchaseSoon => 'Coming soon';

  @override
  String get checkingProgress => 'Checking…';

  @override
  String get checkAgain => 'Retry';

  @override
  String get playFromShelf => 'Play from shelf';

  @override
  String get releaseSoon => 'Coming soon';

  @override
  String get galleryTitle => 'Mosi Game Gallery';

  @override
  String get restorePurchases => 'Restore purchases';

  @override
  String get restoreSoon => 'Purchase restoration is coming soon.';

  @override
  String get chooseFrame => 'Select a frame to choose a game';

  @override
  String get ownedDot => 'Red dot = owned';

  @override
  String get purchaseNotice => 'Purchases are not available yet.';

  @override
  String get next => 'Next';

  @override
  String get passwordAgain => 'Confirm password';

  @override
  String get uploadPhoto => 'Upload photo';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get useGooglePhoto => 'Use Google photo';

  @override
  String get waitingPlayers => 'Waiting for players';

  @override
  String get members => 'Players';

  @override
  String get noPlayers => 'No players yet';

  @override
  String get invite => 'Invite players';

  @override
  String get creating => 'Creating…';

  @override
  String get reset => 'Reset';

  @override
  String get resetting => 'Resetting…';

  @override
  String get ready => 'Ready';

  @override
  String get connectionLost => 'Disconnected';

  @override
  String get ownedGames => 'Your games';

  @override
  String get phonePlayHint => 'Join a room to play on your phone.';

  @override
  String get roomInviteHint =>
      'Open a room so friends can join\nby scanning the QR code.';

  @override
  String startWithPlayers(int count) {
    return 'Start with $count players';
  }
}
