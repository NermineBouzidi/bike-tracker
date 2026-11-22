import 'package:flutter/material.dart';
import 'sign_in_screen.dart';

// Same soft palette as the splash screen
const Color _bgTop = Color(0xFFF4F8EE);
const Color _bgBottom = Color(0xFFDDE9D1);
const Color _ink = Color(0xFF1E2B1C);
const Color _muted = Color(0xFF6F7D6A);
const Color _sage = Color(0xFFBFD4AC);
const Color _accent = Color(0xFFB6E35C);

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _controller = PageController();
  late final AnimationController _pulse;
  late final AnimationController _float;
  int _index = 0;

  bool get _isLast => _index == 2;

  @override
  void initState() {
    super.initState();
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
    _controller.dispose();
    _pulse.dispose();
    _float.dispose();
    super.dispose();
  }

  void _finish() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const SignInScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _back() {
    _controller.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _OnbPage(
        pulse: _pulse,
        float: _float,
        icon: Icons.route,
        title: 'See every kilometer you ride',
        highlight: 'kilometer',
        text:
            'Speed, route and distance are recorded automatically by your bike\'s smart hub.',
        chips: const [
          _ChipData(Icons.sensors, 'GPS lock 99.8%', Alignment(-0.95, -0.55),
              false),
          _ChipData(Icons.speed, '18.4 km/h', Alignment(0.95, 0.55), true),
        ],
      ),
      _OnbPage(
        pulse: _pulse,
        float: _float,
        icon: Icons.memory,
        square: true,
        title: 'Saved even when you are offline',
        highlight: 'offline',
        text:
            'Your bike keeps rides in its own memory, so nothing is lost when your phone is away.',
        chips: const [
          _ChipData(Icons.sd_storage_outlined, '64 MB memory',
              Alignment(-0.95, -0.55), false),
          _ChipData(Icons.bolt, 'Auto-log', Alignment(0.95, 0.55), true),
        ],
      ),
      _OnbPage(
        pulse: _pulse,
        float: _float,
        icon: Icons.shield_outlined,
        title: 'Your history & guard, anytime',
        highlight: 'guard',
        text:
            'Pick any date to review your route and speed, with 24/7 anti-theft alerts.',
        chips: const [
          _ChipData(Icons.history, '24/7 logs', Alignment(-0.95, -0.55), false),
          _ChipData(Icons.lock_outline, 'Anti-theft', Alignment(0.95, 0.55),
              true),
        ],
      ),
    ];

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
            padding: const EdgeInsets.fromLTRB(28, 12, 28, 28),
            child: Column(
              children: [
                // Header: back / step / skip
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 64,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            opacity: _index > 0 ? 1 : 0,
                            child: IgnorePointer(
                              ignoring: _index == 0,
                              child: GestureDetector(
                                onTap: _back,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_back,
                                      color: _ink, size: 20),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Container(
                              key: ValueKey(_index),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF6FCF4F),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    'Step ${_index + 1} of 3',
                                    style: const TextStyle(
                                      color: _ink,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 64,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            opacity: _isLast ? 0 : 1,
                            child: IgnorePointer(
                              ignoring: _isLast,
                              child: TextButton(
                                onPressed: _finish,
                                style: TextButton.styleFrom(
                                  foregroundColor: _muted,
                                  padding: EdgeInsets.zero,
                                  textStyle: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600),
                                ),
                                child: const Text('Skip'),
                              ),
                            ),
                          ),
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
                    children: pages,
                  ),
                ),
                const SizedBox(height: 20),

                // Dots + button
                Row(
                  children: [
                    ...List.generate(3, (i) {
                      final active = i == _index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.only(right: 6),
                        width: active ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: active ? _ink : _sage,
                        ),
                      );
                    }),
                    const Spacer(),
                    FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: _ink,
                        foregroundColor: _accent,
                        minimumSize: const Size(0, 58),
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_isLast ? 'Get started' : 'Next'),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One page: illustration (rings + badge + chips) and text
// ---------------------------------------------------------------------------

class _ChipData {
  const _ChipData(this.icon, this.label, this.alignment, this.reverse);
  final IconData icon;
  final String label;
  final Alignment alignment;
  final bool reverse;
}

class _OnbPage extends StatelessWidget {
  const _OnbPage({
    required this.pulse,
    required this.float,
    required this.icon,
    required this.title,
    required this.highlight,
    required this.text,
    required this.chips,
    this.square = false,
  });

  final Animation<double> pulse;
  final Animation<double> float;
  final IconData icon;
  final String title;
  final String highlight;
  final String text;
  final List<_ChipData> chips;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final i = title.indexOf(highlight);
    final before = i < 0 ? title : title.substring(0, i);
    final mid = i < 0 ? '' : highlight;
    final after = i < 0 ? '' : title.substring(i + highlight.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _RingsPainter(pulse)),
              ),
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutBack,
                  builder: (_, v, child) => Transform.scale(
                    scale: v,
                    child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
                  ),
                  child: AnimatedBuilder(
                    animation: float,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(0, -6 * float.value),
                      child: child,
                    ),
                    child: Container(
                      width: 116,
                      height: 116,
                      decoration: BoxDecoration(
                        color: _ink,
                        shape: square ? BoxShape.rectangle : BoxShape.circle,
                        borderRadius:
                            square ? BorderRadius.circular(34) : null,
                        boxShadow: [
                          BoxShadow(
                            color: _ink.withValues(alpha: 0.18),
                            blurRadius: 30,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: _accent, size: 52),
                    ),
                  ),
                ),
              ),
              for (final c in chips)
                Align(
                  alignment: c.alignment,
                  child: _FloatingChip(
                    icon: c.icon,
                    label: c.label,
                    float: float,
                    reverse: c.reverse,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, 18 * (1 - v)),
              child: child,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 32,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: _ink,
                  ),
                  children: [
                    TextSpan(text: before),
                    TextSpan(
                      text: mid,
                      style: const TextStyle(backgroundColor: _accent),
                    ),
                    TextSpan(text: after),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                text,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FloatingChip extends StatelessWidget {
  const _FloatingChip({
    required this.icon,
    required this.label,
    required this.float,
    required this.reverse,
  });

  final IconData icon;
  final String label;
  final Animation<double> float;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
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
    );
  }
}

/// Soft expanding rings behind the badge.
class _RingsPainter extends CustomPainter {
  _RingsPainter(this.t) : super(repaint: t);
  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);

    canvas.drawCircle(
        c, 108, Paint()..color = Colors.white.withValues(alpha: 0.35));
    canvas.drawCircle(
        c, 82, Paint()..color = Colors.white.withValues(alpha: 0.35));

    for (var i = 0; i < 3; i++) {
      final p = (t.value + i / 3) % 1;
      canvas.drawCircle(
        c,
        66 + 96 * p,
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