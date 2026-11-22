import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api/api_exception.dart';
import '../providers/auth_provider.dart';
import '../widgets/soft_field.dart';
import 'verify_email_screen.dart';

// Same soft palette as the splash and onboarding screens
const Color _bgTop = Color(0xFFF4F8EE);
const Color _bgBottom = Color(0xFFDDE9D1);
const Color _ink = Color(0xFF1E2B1C);
const Color _muted = Color(0xFF6F7D6A);
const Color _accent = Color(0xFFB6E35C);
const Color _error = Color(0xFFD64545);

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _accepted = false;
  bool _showTermsError = false;
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
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Animation<double> _step(double begin, double end) => CurvedAnimation(
        parent: _intro,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      );

  Future<void> _submit() async {
    final valid = _formKey.currentState!.validate();
    setState(() => _showTermsError = !_accepted);
    if (!valid || !_accepted) return;
    setState(() => _loading = true);
    final email = _email.text.trim();
    try {
      final emailSent = await ref.read(authRepositoryProvider).register(
            name: _name.text.trim(),
            email: email,
            password: _password.text,
          );
      if (!mounted) return;
      if (!emailSent) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("We couldn't send the email. Try Resend in a minute.")));
      }
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(email: email)));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleAccepted() => setState(() {
        _accepted = !_accepted;
        _showTermsError = false;
      });

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
                      child: Form(
                        key: _formKey,
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
                                        TextSpan(text: 'Create your\n'),
                                        TextSpan(
                                          text: 'account',
                                          style: TextStyle(
                                              backgroundColor: _accent),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'One minute and you are riding.',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: _muted,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Fields
                            _Reveal(
                              animation: _step(0.2, 0.75),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SoftField(
                                    label: 'Full name',
                                    icon: Icons.person_outline,
                                    controller: _name,
                                    textInputAction: TextInputAction.next,
                                    validator: (v) =>
                                        (v == null || v.trim().length < 2)
                                            ? 'Enter your name'
                                            : null,
                                  ),
                                  const SizedBox(height: 14),
                                  SoftField(
                                    label: 'Email',
                                    icon: Icons.mail_outline,
                                    controller: _email,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    validator: (v) {
                                      final t = v?.trim() ?? '';
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
                                    textInputAction: TextInputAction.next,
                                    validator: (v) =>
                                        (v == null || v.length < 8)
                                            ? 'At least 8 characters'
                                            : null,
                                  ),
                                  const SizedBox(height: 14),
                                  SoftField(
                                    label: 'Confirm password',
                                    icon: Icons.lock_outline,
                                    controller: _confirm,
                                    isPassword: true,
                                    textInputAction: TextInputAction.done,
                                    validator: (v) => v != _password.text
                                        ? 'Passwords do not match'
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Terms + button
                            _Reveal(
                              animation: _step(0.4, 0.95),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: _toggleAccepted,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: Checkbox(
                                            value: _accepted,
                                            onChanged: (_) =>
                                                _toggleAccepted(),
                                            activeColor: _ink,
                                            checkColor: _accent,
                                            side: const BorderSide(
                                                color: _muted, width: 1.5),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Expanded(
                                          child: Text.rich(
                                            TextSpan(
                                              style: TextStyle(
                                                color: _muted,
                                                fontSize: 14,
                                                height: 1.35,
                                              ),
                                              children: [
                                                TextSpan(text: 'I agree to the '),
                                                TextSpan(
                                                  text: 'Terms',
                                                  style: TextStyle(
                                                    color: _ink,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                TextSpan(text: ' and the '),
                                                TextSpan(
                                                  text: 'Privacy Policy',
                                                  style: TextStyle(
                                                    color: _ink,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                TextSpan(text: '.'),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_showTermsError)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 38, top: 6),
                                      child: Text(
                                        'Please accept to continue',
                                        style: TextStyle(
                                            color: _error, fontSize: 12.5),
                                      ),
                                    ),
                                  const SizedBox(height: 22),
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
                                    onPressed: _loading ? null : _submit,
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
                                              Text('Create account'),
                                              SizedBox(width: 8),
                                              Icon(Icons.arrow_forward,
                                                  size: 18),
                                            ],
                                          ),
                                  ),
                                  if (canPop) ...[
                                    const SizedBox(height: 14),
                                    Center(
                                      child: TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).maybePop(),
                                        style: TextButton.styleFrom(
                                            foregroundColor: _muted),
                                        child: const Text.rich(
                                          TextSpan(
                                            style: TextStyle(fontSize: 14.5),
                                            children: [
                                              TextSpan(
                                                  text:
                                                      'Already have an account? '),
                                              TextSpan(
                                                text: 'Sign in',
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
            ],
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