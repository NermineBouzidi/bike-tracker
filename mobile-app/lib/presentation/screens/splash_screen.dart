import 'package:flutter/material.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Color _lime = Color(0xFFB4FF00);
  static const Color _dark = Color(0xFF0F1A0A);

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    // Later: check here whether the user is already signed in.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: _dark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image (logo, phone and tracker are already in it)
          Image.asset(
  'assets/images/splash_bg.png',
  fit: BoxFit.cover,
  alignment: Alignment.topCenter,
  errorBuilder: (context, error, stackTrace) {
    debugPrint('IMAGE ERROR: $error');
    return Container(color: _dark);
  },
),

          // Soft dark-green gradient at the bottom for text readability
          const Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.38,
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00101A08), Color(0xE6101A08)],
                  ),
                ),
              ),
            ),
          ),

          // Headline + button
          SafeArea(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text.rich(
                          TextSpan(
                            style: TextStyle(
                              fontSize: 32,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            children: [
                              TextSpan(text: 'Revolutionizing Your\nRide, One '),
                              TextSpan(
                                text: 'Smart Bike',
                                style: TextStyle(color: _lime),
                              ),
                              TextSpan(text: '\nat a Time.'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        _StartButton(width: width * 0.62, onTap: _start),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.width, required this.onTap});

  final double width;
  final VoidCallback onTap;

  static const Color _lime = Color(0xFFB4FF00);
  static const Color _dark = Color(0xFF0F1A0A);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: 64,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _lime,
          borderRadius: BorderRadius.circular(40),
        ),
        child: Row(
          children: [
            // Dark circle with bike + "Go"
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: _dark,
                shape: BoxShape.circle,
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pedal_bike, size: 16, color: _lime),
                  Text(
                    'Go',
                    style: TextStyle(
                      color: _lime,
                      fontSize: 14,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'Start now',
                  style: TextStyle(
                    color: _dark,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: Icon(Icons.keyboard_double_arrow_right, color: _dark),
            ),
          ],
        ),
      ),
    );
  }
}