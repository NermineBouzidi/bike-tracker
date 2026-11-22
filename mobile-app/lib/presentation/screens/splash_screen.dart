import 'package:flutter/material.dart';
import 'onboarding_screen.dart';

// Soft, calm palette
const Color _bgTop = Color(0xFFF4F8EE);
const Color _bgBottom = Color(0xFFDDE9D1);
const Color _ink = Color(0xFF1E2B1C);
const Color _muted = Color(0xFF6F7D6A);
const Color _sage = Color(0xFFBFD4AC);
const Color _accent = Color(0xFFB6E35C);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _pulse;
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    _float.dispose();
    super.dispose();
  }

  Animation<double> _step(double begin, double end,
          [Curve curve = Curves.easeOutCubic]) =>
      CurvedAnimation(parent: _intro, curve: Interval(begin, end, curve: curve));

  void _start() {
    // Later: check here whether the user is already signed in.
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const OnboardingScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 14, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                _Reveal(
                  animation: _step(0.0, 0.4),
                  dy: -0.3,
                  child: const Row(
                    children: [
                      Icon(Icons.pedal_bike, color: _ink, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'BikeTrack',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // Hero
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: FadeTransition(
                          opacity: _step(0.1, 0.6),
                          child: CustomPaint(painter: _RingsPainter(_pulse)),
                        ),
                      ),
                      Center(
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.6, end: 1).animate(
                              _step(0.1, 0.7, Curves.easeOutBack)),
                          child: FadeTransition(
                            opacity: _step(0.1, 0.5),
                            child: AnimatedBuilder(
                              animation: _float,
                              builder: (_, child) => Transform.translate(
                                offset: Offset(0, -6 * _float.value),
                                child: child,
                              ),
                              child: Container(
                                width: 124,
                                height: 124,
                                decoration: BoxDecoration(
                                  color: _ink,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: _ink.withValues(alpha: 0.18),
                                      blurRadius: 30,
                                      offset: const Offset(0, 14),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.pedal_bike,
                                    color: _accent, size: 56),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: const Alignment(-0.95, -0.5),
                        child: _FloatingChip(
                          icon: Icons.satellite_alt,
                          label: 'GPS locked',
                          float: _float,
                          reverse: false,
                          reveal: _step(0.5, 0.9),
                        ),
                      ),
                      Align(
                        alignment: const Alignment(0.95, 0.55),
                        child: _FloatingChip(
                          icon: Icons.battery_5_bar,
                          label: '94%',
                          float: _float,
                          reverse: true,
                          reveal: _step(0.6, 1.0),
                        ),
                      ),
                    ],
                  ),
                ),

                // Headline
                _Reveal(
                  animation: _step(0.45, 0.8),
                  dy: 0.2,
                  child: const Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 34,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        color: _ink,
                      ),
                      children: [
                        TextSpan(text: 'Your bike,\nalways '),
                        TextSpan(
                          text: 'in sight.',
                          style: TextStyle(backgroundColor: _accent),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _Reveal(
                  animation: _step(0.55, 0.9),
                  dy: 0.2,
                  child: const Text(
                    'Live position, speed and trip history,\nstraight from your tracker.',
                    style: TextStyle(color: _muted, fontSize: 14.5, height: 1.4),
                  ),
                ),
                const SizedBox(height: 26),
                _Reveal(
                  animation: _step(0.65, 1.0),
                  dy: 0.3,
                  child: _SlideToStart(onComplete: _start),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.animation,
    required this.child,
    this.dy = 0.15,
  });

  final Animation<double> animation;
  final Widget child;
  final double dy;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: Offset(0, dy), end: Offset.zero)
            .animate(animation),
        child: child,
      ),
    );
  }
}

class _FloatingChip extends StatelessWidget {
  const _FloatingChip({
    required this.icon,
    required this.label,
    required this.float,
    required this.reverse,
    required this.reveal,
  });

  final IconData icon;
  final String label;
  final Animation<double> float;
  final bool reverse;
  final Animation<double> reveal;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: reveal,
      child: AnimatedBuilder(
        animation: float,
        builder: (_, child) {
          final v = reverse ? 1 - float.value : float.value;
          return Transform.translate(offset: Offset(0, -5 * v), child: child);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: _ink),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Soft expanding rings behind the bike badge.
class _RingsPainter extends CustomPainter {
  _RingsPainter(this.t) : super(repaint: t);
  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);

    canvas.drawCircle(
        c, 112, Paint()..color = Colors.white.withValues(alpha: 0.35));
    canvas.drawCircle(
        c, 84, Paint()..color = Colors.white.withValues(alpha: 0.35));

    for (var i = 0; i < 3; i++) {
      final p = (t.value + i / 3) % 1;
      canvas.drawCircle(
        c,
        70 + 100 * p,
        Paint()
          ..color = _sage.withValues(alpha: 0.7 * (1 - p))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter old) => false;
}

class _SlideToStart extends StatefulWidget {
  const _SlideToStart({required this.onComplete});
  final VoidCallback onComplete;

  @override
  State<_SlideToStart> createState() => _SlideToStartState();
}

class _SlideToStartState extends State<_SlideToStart> {
  static const double _knob = 56;
  static const double _pad = 4;

  double _dx = 0;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, cons) {
      final max = cons.maxWidth - _knob - _pad * 2;
      final progress = max <= 0 ? 0.0 : (_dx / max).clamp(0.0, 1.0);
      final dur =
          _dragging ? Duration.zero : const Duration(milliseconds: 220);

      return Container(
        height: _knob + _pad * 2,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(40),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: dur,
              left: _pad,
              top: _pad,
              width: _knob + _dx,
              height: _knob,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
            Center(
              child: Opacity(
                opacity: 1 - progress,
                child: const Padding(
                  padding: EdgeInsets.only(left: 40),
                  child: Text(
                    'Slide to start',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: dur,
              left: _pad + _dx,
              top: _pad,
              child: GestureDetector(
                onHorizontalDragStart: (_) => setState(() => _dragging = true),
                onHorizontalDragUpdate: (d) => setState(() =>
                    _dx = (_dx + d.delta.dx).clamp(0.0, max).toDouble()),
                onHorizontalDragEnd: (_) {
                  if (_dx > max * 0.85) {
                    setState(() {
                      _dragging = false;
                      _dx = max;
                    });
                    widget.onComplete();
                  } else {
                    setState(() {
                      _dragging = false;
                      _dx = 0;
                    });
                  }
                },
                child: Container(
                  width: _knob,
                  height: _knob,
                  decoration: const BoxDecoration(
                    color: _ink,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.keyboard_double_arrow_right,
                      color: _accent, size: 26),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}