import 'package:flutter/material.dart';
import 'package:project00/platform/settings/widgets/settings_tile.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('설정')),
    body: ListView(
      children: const [
        SettingsTile(icon: Icons.language, title: '언어'),
        SettingsTile(icon: Icons.notifications_outlined, title: '알림'),
      ],
    ),
  );
}
