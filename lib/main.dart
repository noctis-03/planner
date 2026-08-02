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
    return ChangeNotifierProvider(
      create: (_) => PlannerProvider()..init(),
      child: MaterialApp(
        title: '주간 일정 계획표',
        debugShowCheckedModeBanner: false,
        theme: buildMinimalTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}
