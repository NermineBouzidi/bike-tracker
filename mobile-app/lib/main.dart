import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'presentation/screens/splash_screen.dart';
// remove the sign_in_screen.dart import if it is now unused

      
void main() => runApp(const BikeTrackerApp());

class BikeTrackerApp extends StatelessWidget {
  const BikeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bike Tracker',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const SplashScreen(),
    );
  }
}