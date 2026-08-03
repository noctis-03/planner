import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/planner_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const WeeklyPlannerApp());
}

class WeeklyPlannerApp extends StatelessWidget {
  const WeeklyPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlannerProvider()..init()),
        ChangeNotifierProvider<ThemeController>.value(
          value: ThemeController.instance,
        ),
      ],
      child: AnimatedBuilder(
        animation: ThemeController.instance,
        builder: (context, _) {
          final dark = ThemeController.instance.isDark;
          return MaterialApp(
            title: '주간 일정 계획표',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(dark: false),
            darkTheme: buildAppTheme(dark: true),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
