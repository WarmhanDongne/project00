import 'package:flutter/material.dart';

class GameSearchBar extends StatelessWidget {
  const GameSearchBar({this.onChanged, super.key});
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) =>
      SearchBar(leading: const Icon(Icons.search), onChanged: onChanged);
}
