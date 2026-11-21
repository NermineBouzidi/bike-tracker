import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/main_shell.dart';
import 'presentation/widgets/bike_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() => runApp(const ProviderScope(child: BikeTrackerApp()));

class BikeTrackerApp extends StatelessWidget {
  const BikeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BikeTrack',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme().copyWith(
        scaffoldBackgroundColor: BT.bg,
      ),
      home: const SplashScreen(),
      routes: {
        '/home': (_) => const MainShell(),
      },
    );
  }
}