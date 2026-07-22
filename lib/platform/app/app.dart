import 'package:flutter/material.dart';
import 'package:project00/platform/router/app_router.dart';
import 'package:project00/platform/router/route_names.dart';
import 'package:project00/platform/theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Project 00',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    initialRoute: RouteNames.home,
    onGenerateRoute: AppRouter.onGenerateRoute,
  );
}
