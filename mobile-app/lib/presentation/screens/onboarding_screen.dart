import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import 'sign_in_screen.dart';

// --- NOUVELLES COULEURS ---
const _bg = Color(0xFFF1EFE4); // Fond beige
const _card = Colors.white; // Cartes blanches
const _textDark = Color(0xFF0F172A); // Texte foncé
const _textMuted = Colors.black54; // Texte secondaire
const _accent = AppColors.lime; // Vert citron

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _tags = ['BIKETRACK IOT', 'BLE V5.4 SYNC', 'STEP 3 OF 3'];
  bool get _isLast => _index == 2;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
    );
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  void _back() {
    _controller.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg, // ✅ Fond beige
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              // Header: back / tag / skip
              SizedBox(
                height: 40,
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: _index > 0
                          ? IconButton(
                              onPressed: _back,
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                              icon: const Icon(Icons.arrow_back,
                                  color: _textDark, size: 20), // ✅ Icône noire
                            )
                          : null,
                    ),
                    Expanded(
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _Pill(
                            key: ValueKey(_index),
                            text: _tags[_index],
                            dot: true,
                            mono: true,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 56,
                      child: _isLast
                          ? null
                          : TextButton(
                              onPressed: _finish,
                              style: TextButton.styleFrom(
                                  foregroundColor: _textDark, // ✅ Texte noir
                                  padding: EdgeInsets.zero),
                              child: const Text('Skip'),
                            ),
                    ),
                  ],
                ),
              ),

              // Pages
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _index = i),
                  children: const [
                    _OnbPage(
                      illustration: _RouteIllustration(),
                      title: 'See every kilometer you ride',
                      text:
                          'Speed, route, and distance automatically recorded by your bike\'s smart hub.',
                    ),
                    _OnbPage(
                      illustration: _MemoryIllustration(),
                      title: 'Saved even when you are offline',
                      text:
                          'Your bike keeps rides in its own memory, so nothing is lost when your phone is away.',
                    ),
                    _OnbPage(
                      illustration: _GuardIllustration(),
                      title: 'Your history & guard, anytime',
                      text:
                          'Pick any date to inspect detailed route telemetry, speed charts, and 24/7 anti-theft alerts.',
                    ),
                  ],
                ),
              ),

              // Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: active ? _accent : Colors.black12, // ✅ Points inactifs gris clair
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Button (Stylisé comme l'image)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withAlpha(70),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: _textDark, // ✅ Texte foncé sur bouton vert
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    textStyle: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_isLast ? 'Get started' : 'Next'),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared page layout
// ---------------------------------------------------------------------------

class _OnbPage extends StatelessWidget {
  const _OnbPage({
    required this.illustration,
    required this.title,
    required this.text,
  });

  final Widget illustration;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              illustration,
              const SizedBox(height: 28),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: _textDark, // ✅ Texte noir
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: _textMuted, // ✅ Texte gris foncé
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.text,
    this.dot = false,
    this.icon,
    this.mono = false,
    this.small = false,
  });

  final String text;
  final bool dot;
  final IconData? icon;
  final bool mono;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: small ? 6 : 7),
      decoration: BoxDecoration(
        color: _card, // ✅ Fond blanc
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12), // ✅ Bordure grise claire
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration:
                  const BoxDecoration(color: _accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[
            Icon(icon, size: 13, color: _textDark), // ✅ Icône noire
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: small ? 11 : 12,
              fontWeight: FontWeight.w600,
              letterSpacing: mono ? 0.8 : 0.2,
              fontFamily: mono ? 'monospace' : null,
              color: _textDark, // ✅ Texte noir
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 1: route + GPS lock
// ---------------------------------------------------------------------------

class _RouteIllustration extends StatelessWidget {
  const _RouteIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 270,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: const Size(260, 260), painter: _RoutePainter()),
          const Positioned(
            bottom: 18,
            child: _Pill(
              text: 'GPS LOCK \u2022 99.8%',
              icon: Icons.sensors,
              mono: true,
              small: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);

    // Glow disc (adapté pour fond clair)
    canvas.drawCircle(
      c,
      size.width * 0.42,
      Paint()
        ..shader = RadialGradient(colors: [
          _accent.withAlpha(35),
          _accent.withAlpha(0),
        ]).createShader(Rect.fromCircle(center: c, radius: size.width * 0.42)),
    );
    canvas.drawCircle(
      c,
      size.width * 0.38,
      Paint()
        ..color = Colors.black.withAlpha(15)
        ..style = PaintingStyle.stroke,
    );

    // Route
    final start = Offset(size.width * 0.28, size.height * 0.62);
    final end = Offset(size.width * 0.72, size.height * 0.28);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(size.width * 0.34, size.height * 0.45, size.width * 0.52,
          size.height * 0.62, size.width * 0.58, size.height * 0.42)
      ..cubicTo(size.width * 0.62, size.height * 0.30, size.width * 0.66,
          size.height * 0.34, end.dx, end.dy);

    canvas.drawPath(
      path,
      Paint()
        ..color = _accent.withAlpha(90)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Start (hollow)
    canvas.drawCircle(start, 6, Paint()..color = _bg);
    canvas.drawCircle(
      start,
      6,
      Paint()
        ..color = _accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // End (filled + glow)
    canvas.drawCircle(
      end,
      14,
      Paint()
        ..color = _accent.withAlpha(80)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(end, 7, Paint()..color = _textDark); // ✅ Centre noir
    canvas.drawCircle(end, 4, Paint()..color = _accent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Page 2: memory chip
// ---------------------------------------------------------------------------

class _MemoryIllustration extends StatelessWidget {
  const _MemoryIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: const Size(260, 260), painter: _ChipPainter()),
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: _textDark, // ✅ Fond de la puce en noir (comme sur l'image)
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _accent.withAlpha(120), width: 1.5),
              boxShadow: [
                BoxShadow(color: _accent.withAlpha(60), blurRadius: 20),
              ],
            ),
            child: Center(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _accent.withAlpha(35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _accent),
                ),
                child: const Icon(Icons.arrow_upward, color: _accent, size: 20),
              ),
            ),
          ),
          const Positioned(
            top: 12,
            right: 20,
            child: _Pill(text: '64MB ROM', dot: true, mono: true, small: true),
          ),
          const Positioned(
            bottom: 52,
            left: 18,
            child: _Pill(
                text: 'AUTO-LOG', icon: Icons.bolt, mono: true, small: true),
          ),
          const Positioned(
            bottom: 8,
            child: _Pill(
              text: 'ZERO-DATA LOSS ARCHITECTURE',
              icon: Icons.cloud_off,
              mono: true,
              small: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.42;

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(colors: [
          _accent.withAlpha(35),
          _accent.withAlpha(0),
        ]).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = Colors.black.withAlpha(15) // ✅ Cercle extérieur gris
        ..style = PaintingStyle.stroke,
    );

    final line = Paint()
      ..color = _accent.withAlpha(150)
      ..strokeWidth = 1.5;
    final dot = Paint()..color = _accent;

    for (final a in [0.0, math.pi / 2, math.pi, 3 * math.pi / 2]) {
      final dir = Offset(math.cos(a), math.sin(a));
      final p1 = c + dir * 44;
      final p2 = c + dir * (r - 10);
      canvas.drawLine(p1, p2, line);
      canvas.drawCircle(p2, 3.5, dot);
    }
    // Diagonal pins
    for (final a in [math.pi / 4, 3 * math.pi / 4, 5 * math.pi / 4, 7 * math.pi / 4]) {
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * 50, c + dir * (r - 34), line..color = _accent.withAlpha(70));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Page 3: shield + rings
// ---------------------------------------------------------------------------

class _GuardIllustration extends StatelessWidget {
  const _GuardIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: const Size(260, 260), painter: _RingsPainter()),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _card, // ✅ Cercle blanc
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black12), // ✅ Bordure grise
            ),
            child: const Icon(Icons.shield_outlined, color: _textDark, size: 32), // ✅ Icône noire
          ),
          const Positioned(
            bottom: 108,
            child: _Pill(text: '24/7 LOGS', dot: true, mono: true, small: true),
          ),
          const Positioned(
            bottom: 52,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Pill(text: 'Trip Archives', icon: Icons.lock_outline, small: true),
                SizedBox(width: 8),
                _Pill(text: 'Velocity Maps', icon: Icons.speed, small: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);

    final ring = Paint()
      ..color = Colors.black.withAlpha(15) // ✅ Anneaux gris clair
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(c, size.width * 0.46, ring);
    canvas.drawCircle(c, size.width * 0.36, ring);

    // Glow
    canvas.drawCircle(
      c,
      size.width * 0.30,
      Paint()
        ..shader = RadialGradient(colors: [
          _accent.withAlpha(30),
          _accent.withAlpha(0),
        ]).createShader(Rect.fromCircle(center: c, radius: size.width * 0.30)),
    );

    // Progress arc
    final arcRect = Rect.fromCircle(center: c, radius: size.width * 0.26);
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 1.5,
      false,
      Paint()
        ..color = _accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Small orbit dots
    final dot = Paint()..color = _accent;
    canvas.drawCircle(c + Offset(0, -size.width * 0.46), 4, dot);
    canvas.drawCircle(
        c + Offset(size.width * 0.36 * math.cos(-0.3), size.width * 0.36 * math.sin(-0.3)),
        3,
        Paint()..color = _textDark); // ✅ Point noir
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}