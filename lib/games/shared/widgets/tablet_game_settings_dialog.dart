import 'package:flutter/material.dart';
import 'package:project00/core/sound/provider.dart/sound_provider.dart';
import 'package:project00/games/shared/widgets/tablet_game_modal_frame.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/tablet/widgets/player_list.dart';
import 'package:provider/provider.dart';

/// 모든 태블릿 게임이 재사용하는 반응형 설정 화면입니다.
class TabletGameSettingsDialog extends StatelessWidget {
  const TabletGameSettingsDialog({
    super.key,
    required this.provider,
    this.onRestartGame,
    this.onEndGame,
  });

  final RoomProvider provider;
  final VoidCallback? onRestartGame;
  final VoidCallback? onEndGame;

  @override
  Widget build(BuildContext context) {
    return TabletGameModalFrame(
      child: Padding(
        padding: const EdgeInsets.all(60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '설정',
              style: TextStyle(fontSize: 50, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _GameInfo(provider: provider)),
                  Expanded(child: _RoomInfo(provider: provider)),
                  const Expanded(child: _SoundSettings()),
                ],
              ),
            ),
            _SettingsActions(
              onRestartGame: onRestartGame,
              onEndGame: onEndGame,
            ),
          ],
        ),
      ),
    );
  }
}

class _GameInfo extends StatelessWidget {
  const _GameInfo({required this.provider});

  final RoomProvider provider;

  @override
  Widget build(BuildContext context) {
    final game = provider.selectedGame;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '게임',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          Text(
            game?.name ?? '게임 정보 불러오는 중',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: game != null && game.imageUrl.isNotEmpty
                ? Image.network(
                    game.imageUrl,
                    width: 280,
                    height: 280,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _ImagePlaceholder(),
                  )
                : const _ImagePlaceholder(),
          ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        color: const Color(0xfff5f5f5),
        border: Border.all(color: Colors.black26, width: 2),
      ),
      child: const Icon(Icons.broken_image, size: 64),
    );
  }
}

class _RoomInfo extends StatelessWidget {
  const _RoomInfo({required this.provider});

  final RoomProvider provider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '현재 방 정보',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),
          const Text(
            '플레이어 목록',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SizedBox(
            // 네 명이 참가하는 게임에서 스크롤 없이 전원이 보이도록 최소
            // 네 줄을 고정 확보합니다. 5명부터는 이 영역 안에서 스크롤합니다.
            height: 4 * 56,
            child: PlayerListView(
              provider: provider,
              players: provider.players,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '방코드',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
          ),
          Center(
            child: Text(
              provider.roomCode ?? '',
              style: const TextStyle(fontSize: 50, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoundSettings extends StatelessWidget {
  const _SoundSettings();

  @override
  Widget build(BuildContext context) {
    final sound = context.watch<SoundProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '소리',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),
          _SoundSlider(
            title: '전체',
            icon: Icons.volume_up_rounded,
            value: sound.masterVolume,
            onChanged: context.read<SoundProvider>().setMasterVolume,
          ),
          _SoundSlider(
            title: '효과',
            icon: Icons.graphic_eq,
            value: sound.effectVolume,
            onChanged: context.read<SoundProvider>().setEffectVolume,
          ),
          _SoundSlider(
            title: '배경',
            icon: Icons.music_note,
            value: sound.bgmVolume,
            onChanged: context.read<SoundProvider>().setBgmVolume,
          ),
        ],
      ),
    );
  }
}

class _SoundSlider extends StatelessWidget {
  const _SoundSlider({
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
        ),
        Icon(icon, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 100,
            divisions: 100,
            label: value.round().toString(),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value.round().toString(),
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _SettingsActions extends StatelessWidget {
  const _SettingsActions({this.onRestartGame, this.onEndGame});

  final VoidCallback? onRestartGame;
  final VoidCallback? onEndGame;

  void _closeAndRun(BuildContext context, VoidCallback? action) {
    if (action == null) return;
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TabletGameDialogButton(
          text: '닫기',
          color: Colors.black,
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TabletGameDialogButton(
              text: '게임 재시작',
              color: Colors.green,
              onPressed: onRestartGame == null
                  ? null
                  : () => _closeAndRun(context, onRestartGame),
            ),
            const SizedBox(width: 30),
            TabletGameDialogButton(
              text: '게임 종료',
              color: Colors.red,
              onPressed: onEndGame == null
                  ? null
                  : () => _closeAndRun(context, onEndGame),
            ),
          ],
        ),
      ],
    );
  }
}
