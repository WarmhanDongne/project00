import 'package:flutter/material.dart';
import 'package:project00/core/sound/provider.dart/sound_provider.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';
import 'package:project00/platform/home/tablet/widgets/player_list.dart';
import 'package:provider/provider.dart';

class Setting extends StatelessWidget {
  const Setting({super.key, required this.provider});

  final RoomProvider provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1300,
      height: 900,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Padding(
        padding: EdgeInsetsGeometry.all(60),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "설정",
              style: TextStyle(fontSize: 50, fontWeight: FontWeight(900)),
            ),
            SizedBox(height: 40),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 1, child: GameInfo(provider: provider)),
                  Expanded(flex: 1, child: RoomInfo(provider: provider)),
                  const Expanded(flex: 1, child: Sound()),
                ],
              ),
            ),
            const Buttons(),
          ],
        ),
      ),
    );
  }
}

class GameInfo extends StatelessWidget {
  const GameInfo({super.key, required this.provider});

  final RoomProvider provider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "게임",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight(900)),
            ),
            Text(
              provider.selectedGame!.name,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight(900)),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                provider.selectedGame!.imageUrl,
                width: 280,
                height: 280,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      color: const Color(0xfff5f5f5),
                      border: Border.all(color: Colors.black26, width: 2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.broken_image, size: 64),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoomInfo extends StatelessWidget {
  const RoomInfo({super.key, required this.provider});

  final RoomProvider provider;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "현재 방 정보",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 20),
            const Text(
              "플레이어 목록",
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: MemberListView(
                provider: provider,
                members: provider.players,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "방코드",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
            ),
            Center(
              child: Text(
                provider.roomCode ?? "",
                style: const TextStyle(
                  fontSize: 50,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Sound extends StatefulWidget {
  const Sound({super.key});

  @override
  State<Sound> createState() => _SoundState();
}

class _SoundState extends State<Sound> {
  @override
  Widget build(BuildContext context) {
    final soundProvider = context.watch<SoundProvider>();

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
          SoundSlider(
            title: '전체',
            icon: Icons.volume_up_rounded,
            value: soundProvider.masterVolume,
            onChanged: (value) {
              context.read<SoundProvider>().setMasterVolume(value);
            },
          ),
          SoundSlider(
            title: '효과',
            icon: Icons.graphic_eq,
            value: soundProvider.effectVolume,
            onChanged: (value) {
              context.read<SoundProvider>().setEffectVolume(value);
            },
          ),
          SoundSlider(
            title: '배경',
            icon: Icons.music_note,
            value: soundProvider.bgmVolume,
            onChanged: (value) {
              context.read<SoundProvider>().setBgmVolume(value);
            },
          ),
        ],
      ),
    );
  }
}

class SoundSlider extends StatelessWidget {
  const SoundSlider({
    super.key,
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

class Buttons extends StatelessWidget {
  const Buttons({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Button(
          text: "닫기",
          color: Colors.black,
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: const [
            Button(text: "게임 재시작", color: Colors.green, onPressed: null),
            SizedBox(width: 30),
            Button(text: "게임 종료", color: Colors.red, onPressed: null),
          ],
        ),
      ],
    );
  }
}

class Button extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color color;

  const Button({
    super.key,
    required this.text,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size(270, 70),
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      onPressed: onPressed,
      child: Text(
        text,
        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
      ),
    );
  }
}
