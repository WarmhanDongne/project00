import 'package:flutter/material.dart';
import 'package:project00/games/liars_bar/screens/liars_bar_game_screen.dart';
import 'package:project00/games/liars_bar/screens/liars_bar_result_screen.dart';
import 'package:project00/games/liars_bar/screens/liars_bar_room_screen.dart';
import 'package:project00/platform/auth/screens/login_screen.dart';
import 'package:project00/platform/hub/screens/game_detail_screen.dart';
import 'package:project00/platform/hub/screens/game_store_screen.dart';
import 'package:project00/platform/hub/screens/home_screen.dart';
import 'package:project00/platform/router/route_names.dart';
import 'package:project00/platform/settings/screens/settings_screen.dart';

abstract final class AppRouter {
  static Route<void> onGenerateRoute(RouteSettings settings) {
    final builder = switch (settings.name) {
      RouteNames.login => (_) => const LoginScreen(),
      RouteNames.store => (_) => const GameStoreScreen(),
      RouteNames.gameDetail => (_) => const GameDetailScreen(),
      RouteNames.settings => (_) => const SettingsScreen(),
      RouteNames.liarsBarRoom => (_) => const LiarsBarRoomScreen(),
      RouteNames.liarsBarGame => (_) => const LiarsBarGameScreen(),
      RouteNames.liarsBarResult => (_) => const LiarsBarResultScreen(),
      _ => (_) => const HomeScreen(),
    };
    return MaterialPageRoute<void>(builder: builder, settings: settings);
  }
}
