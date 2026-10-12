import 'package:flutter/material.dart';
import 'package:game_kit/core/assets/game_asset_store.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/template_game.dart';

/// 게임 진입 직전에 캐시를 검증하고, 다운로드 게임이면 사용자 진입 동작을
/// 계기로 필요한 파일을 설치한 뒤 다시 검증합니다.
Future<void> prepareGameAssetsForPlay(TemplateGame game) async {
  final store = GameAssetStore.instance;
  try {
    await store.prepareGame(game.id);
    return;
  } catch (_) {
    if (game.requiredAssetVersion <= 0) rethrow;
  }

  await store.downloadGame(game.id);
  await store.prepareGame(game.id);
}

/// Recovery uses verified cached assets. Only proven missing/corrupt files offer repair.
Future<bool> prepareGameAssetsForRecovery(
  TemplateGame game,
  BuildContext context,
) async {
  final store = GameAssetStore.instance;
  try {
    await store.prepareGame(game.id);
    return true;
  } catch (error) {
    if (game.requiredAssetVersion <= 0 ||
        error is! StateError ||
        error.message != '게임 에셋을 먼저 다운로드해야 합니다.') {
      rethrow;
    }
  }
  if (!context.mounted) return false;
  final repair = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(
        GameLocale.select(
          ko: '게임 파일을 복구할까요?',
          en: 'Recover the game files?',
          zhHans: '要修复游戏文件吗？',
          zhHant: '要修復遊戲檔案嗎？',
        ),
      ),
      content: Text(
        GameLocale.select(
          ko: '필요한 게임 파일이 없거나 손상되었습니다. 파일을 다시 받아야 게임을 이어갈 수 있습니다.',
          en: 'Required game files are missing or damaged. Download them again to continue the game.',
          zhHans: '所需的游戏文件缺失或损坏。请重新下载后继续游戏。',
          zhHant: '所需的遊戲檔案缺失或損壞。請重新下載後繼續遊戲。',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            GameLocale.select(
              ko: '게임과 그룹 나가기',
              en: 'Leave game and room',
              zhHans: '退出游戏和房间',
              zhHant: '退出遊戲和房間',
            ),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            GameLocale.select(
              ko: '파일 복구',
              en: 'Recover files',
              zhHans: '修复文件',
              zhHant: '修復檔案',
            ),
          ),
        ),
      ],
    ),
  );
  if (repair != true || !context.mounted) return false;
  await store.downloadGame(game.id);
  await store.prepareGame(game.id);
  return true;
}
