import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api/api_exception.dart';
import '../providers/auth_provider.dart';
import '../widgets/soft_field.dart';
import 'sign_in_screen.dart';

// Same soft palette as the other screens
const Color _bgTop = Color(0xFFF4F8EE);
const Color _bgBottom = Color(0xFFDDE9D1);
const Color _ink = Color(0xFF1E2B1C);
const Color _muted = Color(0xFF6F7D6A);
const Color _accent = Color(0xFFB6E35C);

/// Forgot password flow in one screen, 3 steps:
///   0. enter email      -> backend sends a 6-digit code
///   1. enter the code
///   2. choose a new password -> backend checks code + saves the password
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  /// Optional: pre-fill the email typed on the sign in screen.
  final String? initialEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  int _step = 0; // 0 email, 1 code, 2 new password
  bool _loading = false;
  Timer? _timer;
  int _cooldown = 0;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown <= 1) t.cancel();
      if (mounted) setState(() => _cooldown = _cooldown - 1);
    });
  }

  // Step 0 -> 1: ask the backend to send the code.
  Future<void> _sendCode({bool resend = false}) async {
    if (!resend && !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      // TODO: adapt to the name used in your AuthRepository.
      await ref.read(authRepositoryProvider).forgotPassword(_email.text.trim());
      if (!mounted) return;
      if (resend) {
        _toast('If the account exists, a new code was sent.');
      } else {
        setState(() => _step = 1);
      }
      _startCooldown();
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Step 1 -> 2: the code is checked by the backend together with the new password.
  void _continueWithCode() {
    if (_code.text.length != 6) {
      _toast('Enter the 6-digit code.');
      return;
    }
    setState(() => _step = 2);
  }

  // Step 2: save the new password.
  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      // TODO: adapt to the name/parameters used in your AuthRepository.
      await ref.read(authRepositoryProvider).resetPassword(
            email: _email.text.trim(),
            code: _code.text,
            newPassword: _password.text,
          );
      if (!mounted) return;
      _toast('Password updated. Please sign in.');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      _toast(e.message);
      // Wrong or expired code: let the user retype it.
      if (e.code == 'INVALID_CODE' || e.code == 'CODE_EXPIRED') {
        _code.clear();
        setState(() => _step = 1);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onBack() {
    if (_step > 0) {
      setState(() => _step -= 1);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _onPrimary() {
    switch (_step) {
      case 0:
        _sendCode();
      case 1:
        _continueWithCode();
      default:
        _resetPassword();
    }
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  static const _titles = [
    ['Forgot your\n', 'password?'],
    ['Enter the\n', 'code'],
    ['Create a new\n', 'password'],
  ];

  String get _subtitle {
    switch (_step) {
      case 0:
        return 'Enter your email and we will send you a 6-digit code.';
      case 1:
        return 'We sent a 6-digit code to ${_email.text.trim()}. It expires in 10 minutes.';
      default:
        return 'Choose a password with at least 8 characters.';
    }
  }

  String get _buttonLabel =>
      const ['Send code', 'Continue', 'Update password'][_step];

  Widget _switcher(Widget child) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (c, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.06, 0),
              end: Offset.zero,
            ).animate(anim),
            child: c,
          ),
        ),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topLeft,
          children: [...previous, if (current != null) current],
        ),
        child: child,
      );

  Widget _header() {
    final t = _titles[_step];
    return Column(
      key: ValueKey('header$_step'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: const TextStyle(
              fontSize: 34,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              color: _ink,
            ),
            children: [
              TextSpan(text: t[0]),
              TextSpan(
                text: t[1],
                style: const TextStyle(backgroundColor: _accent),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _subtitle,
          style: const TextStyle(fontSize: 15, color: _muted, height: 1.4),
        ),
      ],
    );
  }

  Widget _content() {
    switch (_step) {
      case 0:
        return Column(
          key: const ValueKey('step0'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SoftField(
              label: 'Email',
              icon: Icons.mail_outline,
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!_loading) _sendCode();
              },
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return 'Enter your email';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
          ],
        );
      case 1:
        return Column(
          key: const ValueKey('step1'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CodeBoxes(controller: _code),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: _ink,
                  disabledForegroundColor: _muted,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  textStyle: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                onPressed: (_cooldown > 0 || _loading)
                    ? null
                    : () => _sendCode(resend: true),
                child: Text(_cooldown > 0
                    ? 'Resend code in $_cooldown s'
                    : 'Resend code'),
              ),
            ),
          ],
        );
      default:
        return Column(
          key: const ValueKey('step2'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SoftField(
              label: 'New password',
              icon: Icons.lock_outline,
              controller: _password,
              isPassword: true,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.length < 8) ? 'At least 8 characters' : null,
            ),
            const SizedBox(height: 14),
            SoftField(
              label: 'Confirm password',
              icon: Icons.lock_outline,
              controller: _confirm,
              isPassword: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!_loading) _resetPassword();
              },
              validator: (v) =>
                  v != _password.text ? 'Passwords do not match' : null,
            ),
          ],
        );
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
          child: Column(
            children: [
              // Back button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: SizedBox(
                  height: 44,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: _onBack,
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

              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _switcher(_header()),
                          const SizedBox(height: 32),
                          Form(key: _formKey, child: _switcher(_content())),
                          const SizedBox(height: 20),
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
                            onPressed: _loading ? null : _onPrimary,
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5, color: _accent),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_buttonLabel),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward, size: 18),
                                    ],
                                  ),
                          ),
                          if (_step == 0) ...[
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
                                      TextSpan(text: 'Remembered it? '),
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

/// Six separated square boxes. A hidden TextField underneath receives the
/// typing (and the paste); the boxes only display the digits.
class _CodeBoxes extends StatefulWidget {
  const _CodeBoxes({required this.controller});
  final TextEditingController controller;

  @override
  State<_CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<_CodeBoxes> {
  static const int _length = 6;
  final _focus = FocusNode();

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    _focus.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final activeIndex = text.length >= _length ? _length - 1 : text.length;

    return Stack(
      children: [
        Positioned.fill(
          child: TextField(
            controller: widget.controller,
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