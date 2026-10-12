import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_final_call/game_copy.dart';
import 'package:game_final_call/game_final_call.dart';
import 'package:game_holdem/game_copy.dart';
import 'package:game_holdem/game_holdem.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_liars_poker/game_copy.dart';
import 'package:game_liars_poker/game_liars_poker.dart';
import 'package:game_mafia/game_copy.dart';
import 'package:game_mafia/game_mafia.dart';
import 'package:project00/platform/auth/legal/signup_terms.dart';

void main() {
  test('공통 문구와 게임 문구가 현재 언어를 함께 따른다', () {
    final original = GameLocale.current;
    addTearDown(() => GameLocale.current = original);

    GameLocale.current = const Locale('en');
    expect('닫기'.localized, 'Close');
    expect(const LiarsPokerGame().title, 'Liars');
    expect(const FinalCallGame().title, 'Final Call');
    expect(const MafiaGame().title, 'Mafia');
    expect(const HoldemGame().title, "Texas Hold'em");
    expect(LiarsPokerCopy.waitingForOpponent, contains('Waiting'));
    expect(FinalCallCopy.myTurn, 'Your turn!');
    expect(HoldemCopy.myTurn, 'Your turn');
    expect(MafiaCopy.morningNotice, 'Morning has come');
    expect(termsOfService.title, 'Mosigame Terms of Service');

    GameLocale.current = const Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hant',
    );
    expect('닫기'.localized, '關閉');
    expect(const LiarsPokerGame().title, '說謊者');
    expect(const MafiaGame().title, '黑手黨');
    expect(MafiaCopy.morningNotice, '天亮了');
    expect(termsOfService.title, 'Mosigame 使用條款');
  });

  test('앱 시작 전 locale 선택도 간체와 번체를 구분한다', () {
    expect(
      GameLocale.selectFor(
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        ko: '한국어',
        en: 'English',
        zhHans: '简体',
        zhHant: '繁體',
      ),
      '简体',
    );
    expect(
      GameLocale.selectFor(
        const Locale.fromSubtags(languageCode: 'zh', countryCode: 'TW'),
        ko: '한국어',
        en: 'English',
        zhHans: '简体',
        zhHant: '繁體',
      ),
      '繁體',
    );
  });
}
