import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_colors.dart';
import '../../data/api/api_exception.dart';
import '../providers/auth_provider.dart';
import 'sign_in_screen.dart';

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

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _code = TextEditingController();
  Timer? _timer;
  int _cooldown = 60;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _startCooldown();
    if (widget.sendCodeOnOpen) {
      ref.read(authRepositoryProvider).resendVerification(widget.email).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

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
    if (_code.text.length != 6) {
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
    return Scaffold(
      backgroundColor: const Color(0xFFF1EFE4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Check your email',
                      style: TextStyle(
                          fontSize: 30, fontWeight: FontWeight.w800, color: Colors.black)),
                  const SizedBox(height: 8),
                  Text('We sent a 6-digit code to ${widget.email}. It expires in 10 minutes.',
                      style: const TextStyle(fontSize: 16, color: Colors.black54)),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 28, letterSpacing: 10),
                    decoration: const InputDecoration(counterText: '', hintText: '000000'),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.lime,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: AppColors.lime.withOpacity(0.6),
                      minimumSize: const Size.fromHeight(54),
                      shape: const StadiumBorder(),
                      textStyle:
                          const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    onPressed: _loading ? null : _verify,
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.black))
                        : const Text('Verify'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.black),
                    onPressed: _cooldown > 0 ? null : _resend,
                    child: Text(_cooldown > 0
                        ? 'Resend code in $_cooldown s'
                        : 'Resend code'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}