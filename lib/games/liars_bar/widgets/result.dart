import 'package:flutter/material.dart';
import 'package:project00/platform/hub/screens/home_tablet.dart';

class Result extends StatelessWidget {
  const Result({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1000,
      height: 800,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Padding(
        padding: EdgeInsetsGeometry.all(60),
        child: Center(
          child: Column(
            children: [
              Text(
                "게임 종료",
                style: TextStyle(
                  fontSize: 80,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              Text(
                "플레이 시간:1h 34m",
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              Text(
                "Winner:",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              Align(alignment: AlignmentGeometry.bottomRight, child: Buttons()),
            ],
          ),
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
      children: [
        TextButton(
          onPressed: () {},
          child: const Text(
            '다시하기',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (_, animation, _) => const HomeTablet(),
                transitionDuration: const Duration(milliseconds: 350),
                transitionsBuilder: (_, animation, _, child) {
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  );

                  return FadeTransition(
                    opacity: curved,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.96, end: 1.0).animate(curved),
                      child: child,
                    ),
                  );
                },
              ),
            );
          },
          child: const Text(
            '로비로',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}
