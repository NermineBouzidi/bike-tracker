import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'presentation/screens/sign_in_screen.dart';

void main() => runApp(const BikeTrackerApp());

class BikeTrackerApp extends StatelessWidget {
  const BikeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bike Tracker',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const SignInScreen(),
    );
  }
}