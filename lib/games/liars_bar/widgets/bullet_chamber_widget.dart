import 'package:flutter/material.dart';

class BulletChamberWidget extends StatelessWidget {
  const BulletChamberWidget({this.chambers = 6, super.key});
  final int chambers;
  @override
  Widget build(BuildContext context) =>
      Icon(Icons.album, size: 24.0 * chambers.clamp(1, 6));
}
