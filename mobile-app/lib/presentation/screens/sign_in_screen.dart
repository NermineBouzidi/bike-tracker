import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api/api_exception.dart';
import '../providers/auth_provider.dart';
import '../widgets/soft_field.dart';
import 'main_shell.dart';
import 'sign_up_screen.dart';
import 'verify_email_screen.dart';
import 'forgot_password_screen.dart';

// Same soft palette as the splash, onboarding and sign up screens
const Color _bgTop = Color(0xFFF4F8EE);
const Color _bgBottom = Color(0xFFDDE9D1);
const Color _ink = Color(0xFF1E2B1C);
const Color _muted = Color(0xFF6F7D6A);
const Color _accent = Color(0xFFB6E35C);

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Animation<double> _step(double begin, double end) => CurvedAnimation(
        parent: _intro,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final email = _email.text.trim();
    try {
      await ref
          .read(authRepositoryProvider)
          .login(email: email, password: _password.text);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'EMAIL_NOT_VERIFIED') {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                VerifyEmailScreen(email: email, sendCodeOnOpen: true)));
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      _Reveal(
                        animation: _step(0.0, 0.45),
                        dy: -0.15,
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: 34,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1,
                                  color: _ink,
                                ),
                                children: [
                                  TextSpan(text: 'Welcome\n'),
                                  TextSpan(
                                    text: 'back',
                                    style:
                                        TextStyle(backgroundColor: _accent),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Sign in to see your rides.',
                              style: TextStyle(
                                fontSize: 15,
                                color: _muted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Fields
                      _Reveal(
                        animation: _step(0.2, 0.75),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SoftField(
                              label: 'Email',
                              icon: Icons.mail_outline,
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              validator: (v) {
                                final t = v?.trim() ?? '';
                                if (t.isEmpty) return 'Enter your email';
                                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                    .hasMatch(t)) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            SoftField(
                              label: 'Password',
                              icon: Icons.lock_outline,
                              controller: _password,
                              isPassword: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) {
                                if (!_loading) _submit();
                              },
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Enter your password'
                                  : null,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: _ink,
                                  textStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                // TODO: open your forgot password screen here
                                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
  builder: (_) => ForgotPasswordScreen(initialEmail: _email.text.trim()),
)),
                                child: const Text('Forgot password?'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Button + sign up link
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
                                    fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              onPressed: _loading ? null : _submit,
                              child: _loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5, color: _accent),
                                    )
                                  : const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Sign in'),
                                        SizedBox(width: 8),
                                        Icon(Icons.arrow_forward, size: 18),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 18),
                            Center(
                              child: TextButton(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const SignUpScreen()),
                                ),
                                style: TextButton.styleFrom(
                                    foregroundColor: _muted),
                                child: const Text.rich(
                                  TextSpan(
                                    style: TextStyle(fontSize: 14.5),
                                    children: [
                                      TextSpan(text: 'New here? '),
                                      TextSpan(
                                        text: 'Create account',
                                        style: TextStyle(
                                          color: _ink,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
        ),
      ),
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