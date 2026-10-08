// [game_settings_dialog.dart] 는 태블릿 게임의 공통 설정 다이얼로그를 구성하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Widget] : 게임 화면에서 반복 사용하는 공통 UI를 구성함
//
// 즉, 같은 표시와 조작 방식을 여러 화면에서 재사용하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:game_kit/mosi_ui/mosi_game_art.dart';
import 'package:game_kit/mosi_ui/mosi_game_modal.dart';
import 'package:game_kit/sound/providers/sound_provider.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:provider/provider.dart';

// ============================================================

/// 모든 태블릿 게임이 재사용하는 설정 화면입니다(시안: 게임 · 현재 방 정보 · 소리).
class TabletGameSettingsDialog extends StatelessWidget {
  const TabletGameSettingsDialog({
    super.key,
    required this.provider,
    this.onRestartGame,
    this.onEndGame,
  });

  final GameRoomContext provider;
  final VoidCallback? onRestartGame;
  final VoidCallback? onEndGame;

  void _closeAndRun(BuildContext context, VoidCallback? action) {
    if (action == null) return;
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final theme = MosiGameModalTheme.fromName(provider.selectedGame?.name);
    final code = provider.roomCode ?? '';
    return MosiGameModalFrame(
      theme: theme,
      semanticLabel: '설정',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '설정',
                style: MosiFonts.sans(
                  size: 38,
                  weight: FontWeight.w700,
                  color: MosiColors.navy,
                  letterSpacing: -1.5,
                ),
              ),
              if (code.isNotEmpty) ...[
                const SizedBox(width: 20),
                MosiDashedBorder(
                  color: MosiColors.ink,
                  radius: 12,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                    decoration: BoxDecoration(
                      color: MosiColors.cream,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '방 코드',
                          style: MosiFonts.sans(
                            size: 13,
                            weight: FontWeight.w700,
                            color: MosiColors.muted,
                          ),
                        ),
                        for (final char in code.split('')) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 34,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: MosiColors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: MosiColors.ink,
                                width: 2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: MosiColors.ink,
                                  offset: Offset(2, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              char,
                              style: MosiFonts.grotesk(
                                size: 20,
                                color: MosiColors.navy,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              const Spacer(),
              MosiSquareCloseButton(
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 230, child: _GameInfo(provider: provider)),
                const SizedBox(width: 20),
                Expanded(flex: 115, child: _RoomInfo(provider: provider)),
                const SizedBox(width: 20),
                Expanded(flex: 100, child: _SoundSettings(theme: theme)),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              MosiButton(
                label: '게임 재시작',
                leading: const Icon(Icons.refresh_rounded),
                background: MosiColors.sky,
                foreground: MosiColors.white,
                shadowColor: MosiColors.ink,
                height: 60,
                fontSize: 18,
                radius: 12,
                onPressed: onRestartGame == null
                    ? null
                    : () => _closeAndRun(context, onRestartGame),
              ),
              const SizedBox(width: 12),
              MosiButton(
                label: '게임 종료',
                leading: const Icon(Icons.stop_rounded),
                background: MosiColors.red,
                foreground: MosiColors.white,
                shadowColor: MosiColors.ink,
                height: 60,
                fontSize: 18,
                radius: 12,
                onPressed: onEndGame == null
                    ? null
                    : () => _closeAndRun(context, onEndGame),
              ),
              const Spacer(),
              SizedBox(
                width: 220,
                child: MosiButton(
                  label: '계속하기',
                  background: theme.accent,
                  foreground: theme.accentFg,
                  shadowColor: MosiColors.ink,
                  height: 60,
                  fontSize: 20,
                  radius: 12,
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GameInfo extends StatelessWidget {
  const _GameInfo({required this.provider});

  final GameRoomContext provider;

  @override
  Widget build(BuildContext context) {
    final game = provider.selectedGame;
    final players = provider.players.where((p) => p.isPlayer).length;
    final gameId = _gameIdFromName(game?.name);
    return MosiCreamPanel(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '게임',
              style: MosiFonts.sans(
                size: 14,
                weight: FontWeight.w700,
                color: MosiColors.muted,
              ),
            ),
          ),
          const SizedBox(height: 12),
          MosiGameCover(
            gameId: gameId ?? '',
            width: 170,
            fallbackName: game?.name,
            fallbackImageUrl: game?.imageUrl,
          ),
          const SizedBox(height: 12),
          Text(
            gameId != null
                ? MosiGameArt.of(gameId).koreanName
                : game?.name ?? '게임 정보 불러오는 중',
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: MosiFonts.sans(
              size: 20,
              weight: FontWeight.w700,
              color: MosiColors.navy,
            ),
          ),
          const SizedBox(height: 12),
          MosiPill(
            label: '$players명',
            background: MosiColors.white,
            borderColor: MosiColors.ink,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          ),
        ],
      ),
    );
  }
}

/// 표지 그림을 고르려고 게임 이름에서 id를 추정합니다.
String? _gameIdFromName(String? name) {
  final lower = (name ?? '').toLowerCase();
  if (lower.contains('liar') || lower.contains('라이어')) return 'liars_poker';
  if (lower.contains('final') || lower.contains('파이널')) return 'final_call';
  if (lower.contains('mafia') || lower.contains('마피아')) return 'mafia';
  if (lower.contains('hold') || lower.contains('홀덤')) return 'holdem';
  return null;
}

class _RoomInfo extends StatelessWidget {
  const _RoomInfo({required this.provider});

  final GameRoomContext provider;

  @override
  Widget build(BuildContext context) {
    final players = provider.players;
    final online = players.where((player) => player.isConnected).length;
    return MosiCreamPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '현재 방 정보 · 플레이어',
                  style: MosiFonts.sans(
                    size: 14,
                    weight: FontWeight.w700,
                    color: MosiColors.muted,
                  ),
                ),
              ),
              Text(
                '$online / ${players.length} 연결',
                style: MosiFonts.grotesk(size: 14, color: MosiColors.navy),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _GamePlayerList(provider: provider, players: players),
          ),
          const SizedBox(height: 12),
          Text(
            '연결이 끊긴 사람은 30초 동안 자리를 지켜 둬요.',
            style: MosiFonts.sans(size: 12, color: MosiColors.muted),
          ),
        ],
      ),
    );
  }
}

class _GamePlayerList extends StatelessWidget {
  const _GamePlayerList({required this.provider, required this.players});

  final GameRoomContext provider;
  final List<GameRoomPlayer> players;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: players.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final player = players[index];
        final connected = player.isConnected;
        return Opacity(
          opacity: connected ? 1 : 0.8,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: MosiColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: MosiColors.ink, width: 2),
            ),
            child: Row(
              children: [
                MosiFace(characterId: player.characterId, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    player.nickname,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MosiFonts.sans(
                      size: 16,
                      weight: FontWeight.w700,
                      color: MosiColors.navy,
                    ),
                  ),
                ),
                Semantics(
                  label: connected ? '연결됨' : '연결 끊김',
                  excludeSemantics: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: connected
                          ? const Color(0xFFE4F5E2)
                          : const Color(0xFFFDE3E6),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: connected
                                ? const Color(0xFF3BAA4E)
                                : MosiColors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          connected ? '연결됨' : '연결 끊김',
                          style: MosiFonts.sans(
                            size: 12,
                            weight: FontWeight.w700,
                            color: connected
                                ? const Color(0xFF23722F)
                                : const Color(0xFFA82E40),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: '강퇴',
                  child: Semantics(
                    button: true,
                    label: '${player.nickname} 강퇴',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => unawaited(provider.removePlayer(player.uid)),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: MosiColors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: MosiColors.ink, width: 2),
                        ),
                        child: Text(
                          '강퇴',
                          style: MosiFonts.sans(
                            size: 12,
                            weight: FontWeight.w700,
                            color: const Color(0xFFA82E40),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SoundSettings extends StatefulWidget {
  const _SoundSettings({required this.theme});

  final MosiGameModalTheme theme;

  @override
  State<_SoundSettings> createState() => _SoundSettingsState();
}

// 모달을 닫아도 같은 사운드 인스턴스의 복원값을 유지합니다.
// weak key이므로 provider가 사라지면 복원값도 정리됩니다.
final _volumeBeforeMute = Expando<double>('settings mute volume');

class _SoundSettingsState extends State<_SoundSettings> {
  @override
  Widget build(BuildContext context) {
    final sound = context.watch<SoundProvider>();
    final muted = sound.masterVolume == 0;
    return MosiCreamPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '소리',
            style: MosiFonts.sans(
              size: 14,
              weight: FontWeight.w700,
              color: MosiColors.muted,
            ),
          ),
          const SizedBox(height: 14),
          _SoundSlider(
            title: '전체',
            icon: Icons.volume_up_rounded,
            iconBackground: MosiColors.sun,
            value: sound.masterVolume,
            onChanged: sound.setMasterVolume,
            accent: widget.theme.deep,
          ),
          _SoundSlider(
            title: '효과',
            icon: Icons.auto_awesome_rounded,
            iconBackground: MosiColors.lime,
            value: sound.effectVolume,
            onChanged: sound.setEffectVolume,
            accent: widget.theme.deep,
          ),
          _SoundSlider(
            title: '배경',
            icon: Icons.music_note_rounded,
            iconBackground: const Color(0xFF9CC3FF),
            value: sound.bgmVolume,
            onChanged: sound.setBgmVolume,
            accent: widget.theme.deep,
          ),
          const Spacer(),
          MosiButton(
            label: muted ? '소리 다시 켜기' : '모두 음소거',
            leading: Icon(
              muted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
            ),
            background: muted ? const Color(0xFFFDE3E6) : MosiColors.white,
            borderWidth: 2,
            shadowOffset: 0,
            height: 48,
            fontSize: 15,
            radius: 10,
            expand: true,
            onPressed: () {
              if (muted) {
                sound.setMasterVolume(_volumeBeforeMute[sound] ?? 50);
              } else {
                _volumeBeforeMute[sound] = sound.masterVolume;
                sound.setMasterVolume(0);
              }
            },
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
    required this.iconBackground,
    required this.value,
    required this.onChanged,
    required this.accent,
  });

  final String title;
  final IconData icon;
  final Color iconBackground;
  final double value;
  final ValueChanged<double> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: MosiColors.ink, width: 2),
                ),
                child: Icon(icon, size: 18, color: MosiColors.ink),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: MosiFonts.sans(
                  size: 17,
                  weight: FontWeight.w700,
                  color: MosiColors.navy,
                ),
              ),
              const Spacer(),
              Text(
                '${value.round()}%',
                style: MosiFonts.grotesk(size: 17, color: MosiColors.navy),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accent,
              inactiveTrackColor: const Color(0x330E0A3D),
              thumbColor: MosiColors.white,
              overlayColor: accent.withValues(alpha: 0.12),
              trackHeight: 6,
              thumbShape: const _BorderedThumb(),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 100,
              divisions: 100,
              label: '$title ${value.round()}',
              semanticFormatterCallback: (v) => '$title 소리 ${v.round()}',
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _BorderedThumb extends SliderComponentShape {
  const _BorderedThumb();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(24, 24);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(center, 11, Paint()..color = MosiColors.white);
    canvas.drawCircle(
      center,
      11,
      Paint()
        ..color = MosiColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }
}
