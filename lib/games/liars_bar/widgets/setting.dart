import 'package:flutter/material.dart';

class Setting extends StatelessWidget {
  const Setting({super.key});

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
                children: const [
                  Expanded(flex: 1, child: GameInfo()),
                  Expanded(flex: 1, child: RoomInfo()),
                  Expanded(flex: 1, child: Sound()),
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
  const GameInfo({super.key});

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
              "Liar's Bar",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight(900)),
            ),
            Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                color: const Color(0xfff5f5f5),
                border: Border.all(color: Colors.black26, width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoomInfo extends StatelessWidget {
  const RoomInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "현재 방 정보",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight(900)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "플레이어 목록",
                  style: TextStyle(fontSize: 25, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),

                ...["맥도날드 감자튀김 도둑", "김하준", "윤유원", "배워져 남주자"].map(
                  (name) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 18,
                          backgroundImage: AssetImage(
                            "assets/images/profile.png",
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(name, style: const TextStyle(fontSize: 22)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 50),
            Text(
              "방코드",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight(600)),
            ),
            Center(
              child: Text(
                "J3KL4K",
                style: TextStyle(fontSize: 50, fontWeight: FontWeight(800)),
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

class SoundSlider extends StatelessWidget {
  final String title;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;

  const SoundSlider({
    super.key,
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

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
            label: value.toInt().toString(),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value.toInt().toString(),
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _SoundState extends State<Sound> {
  double masterVolume = 50;
  double effectVolume = 80;
  double bgmVolume = 30;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "소리",
              style: TextStyle(fontSize: 30, fontWeight: FontWeight(900)),
            ),
            Column(
              children: [
                SoundSlider(
                  title: '전체',
                  icon: Icons.volume_up_rounded,
                  value: masterVolume,
                  onChanged: (value) {
                    setState(() {
                      masterVolume = value;
                    });
                  },
                ),
                SoundSlider(
                  title: '효과',
                  icon: Icons.graphic_eq,
                  value: effectVolume,
                  onChanged: (value) {
                    setState(() {
                      effectVolume = value;
                    });
                  },
                ),
                SoundSlider(
                  title: '배경',
                  icon: Icons.music_note,
                  value: bgmVolume,
                  onChanged: (value) {
                    setState(() {
                      bgmVolume = value;
                    });
                  },
                ),
              ],
            ),
            //  Image.asset("null"),
          ],
        ),
      ),
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
