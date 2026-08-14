import 'package:flutter/material.dart';
import 'package:project00/platform/theme/platform_theme.dart';

class GameSearchBar extends StatelessWidget {
  const GameSearchBar({super.key, required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return SizedBox(
      height: 46,
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: '게임 검색',
          hintStyle: TextStyle(color: colors.textMuted, fontSize: 15),
          prefixIcon: Icon(Icons.search, size: 20, color: colors.textMuted),
          filled: true,
          fillColor: colors.surfaceMuted,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: colors.border),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }
}
