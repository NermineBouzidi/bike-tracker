import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api/api_exception.dart';
import '../providers/auth_provider.dart';
import 'sign_in_screen.dart';

// Same soft palette as the other screens
const Color _bgTop = Color(0xFFF4F8EE);
const Color _bgBottom = Color(0xFFDDE9D1);
const Color _ink = Color(0xFF1E2B1C);
const Color _muted = Color(0xFF6F7D6A);
const Color _accent = Color(0xFFB6E35C);

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    this.sendCodeOnOpen = false,
  });

  final String email;
  final bool sendCodeOnOpen; // true when coming from a sign-in of an unverified account

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen>
    with SingleTickerProviderStateMixin {
  static const int _length = 6;

  final _code = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  int _cooldown = 60;
  bool _loading = false;

  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _focus.addListener(() => setState(() {}));
    _startCooldown();
    if (widget.sendCodeOnOpen) {
      ref
          .read(authRepositoryProvider)
          .resendVerification(widget.email)
          .catchError((_) {});
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Animation<double> _step(double begin, double end) => CurvedAnimation(
        parent: _intro,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      );

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown <= 1) {
        t.cancel();
      }
      if (mounted) setState(() => _cooldown = _cooldown - 1);
    });
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _verify() async {
    if (_code.text.length != _length) {
      _toast('Enter the 6-digit code.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .verifyEmail(email: widget.email, code: _code.text);
      if (!mounted) return;
      _toast('Email verified. Please sign in.');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    try {
      await ref.read(authRepositoryProvider).resendVerification(widget.email);
      if (!mounted) return;
      _toast('If the account needs one, a new code was sent.');
      _startCooldown();
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Back button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: SizedBox(
                  height: 44,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: canPop
                        ? GestureDetector(
                            onTap: () => Navigator.of(context).maybePop(),
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
                          )
                        : null,
                  ),
                ),
              ),

              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header
                          _Reveal(
                            animation: _step(0.0, 0.45),
                            dy: -0.15,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text.rich(
                                  TextSpan(
                                    style: TextStyle(
                                      fontSize: 34,
                                      height: 1.15,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -1,
                                      color: _ink,
                                    ),
                                    children: [
                                      TextSpan(text: 'Check your\n'),
                                      TextSpan(
                                        text: 'email',
                                        style: TextStyle(
                                            backgroundColor: _accent),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text.rich(
                                  TextSpan(
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: _muted,
                                      height: 1.4,
                                    ),
                                    children: [
                                      const TextSpan(
                                          text: 'We sent a 6-digit code to '),
                                      TextSpan(
                                        text: widget.email,
                                        style: const TextStyle(
                                          color: _ink,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const TextSpan(
                                          text: '. It expires in 10 minutes.'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Code boxes
                          _Reveal(
                            animation: _step(0.2, 0.75),
                            child: _buildCodeBoxes(),
                          ),
                          const SizedBox(height: 28),

                          // Button + resend
                          _Reveal(
                            animation: _step(0.4, 0.95),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _ink,
                                    foregroundColor: _accent,
                                    disabledBackgroundColor:
                                        _ink.withValues(alpha: 0.6),
                                    disabledForegroundColor: _accent,
                                    minimumSize: const Size.fromHeight(58),
                                    shape: const StadiumBorder(),
                                    textStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  onPressed: _loading ? null : _verify,
                                  child: _loading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: _accent),
                                        )
                                      : const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('Verify'),
                                            SizedBox(width: 8),
                                            Icon(Icons.arrow_forward,
                                                size: 18),
                                          ],
                                        ),
                                ),
                                const SizedBox(height: 14),
                                Center(
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: _ink,
                                      disabledForegroundColor: _muted,
                                      textStyle: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    onPressed: _cooldown > 0 ? null : _resend,
                                    child: Text(_cooldown > 0
                                        ? 'Resend code in $_cooldown s'
                                        : 'Resend code'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Six separated square boxes. A hidden TextField underneath receives the
  /// typing (and the paste), the boxes only display the digits.
  Widget _buildCodeBoxes() {
    final text = _code.text;
    // Box that receives the next digit (the last one when the code is full).
    final activeIndex = text.length >= _length ? _length - 1 : text.length;

    return Stack(
      children: [
        Positioned.fill(
          child: TextField(
            controller: _code,
            focusNode: _focus,
            keyboardType: TextInputType.number,
            maxLength: _length,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofillHints: const [AutofillHints.oneTimeCode],
            showCursor: false,
            enableInteractiveSelection: false,
            cursorColor: Colors.transparent,
            style: const TextStyle(color: Colors.transparent),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _focus.requestFocus(),
          child: Row(
            children: List.generate(_length, (i) {
              final hasDigit = i < text.length;
              final isActive = _focus.hasFocus && i == activeIndex;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == _length - 1 ? 0 : 10),
                  child: AspectRatio(
                    aspectRatio: 0.85,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withValues(alpha: hasDigit ? 0.95 : 0.8),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isActive
                              ? _ink
                              : hasDigit
                                  ? _accent
                                  : Colors.transparent,
                          width: isActive ? 1.8 : 1.5,
                        ),
                      ),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutBack,
                        scale: hasDigit ? 1 : 0.6,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 160),
                          opacity: hasDigit ? 1 : 0,
                          child: Text(
                            hasDigit ? text[i] : '0',
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

/// Fade + small slide, driven by an animation.
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.animation,
    required this.child,
    this.dy = 0.12,
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