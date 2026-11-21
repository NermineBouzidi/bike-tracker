import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../widgets/auth_text_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api/api_exception.dart';
import '../providers/auth_provider.dart';
import 'verify_email_screen.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _accepted = false;
  bool _showTermsError = false;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1EFE4), // ✅ Fond beige
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black), // ✅ Icône retour noire
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 80,
                        color: Colors.black, // ✅ Logo en noir (si c'est un logo simple)
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.pedal_bike,
                          size: 56,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Create account',
                        style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Colors.black)), // ✅ Texte noir
                    const SizedBox(height: 8),
                    const Text('One minute and you are riding.',
                        style: TextStyle(fontSize: 16, color: Colors.black54)), // ✅ Texte gris foncé
                    const SizedBox(height: 28),
                    AuthTextField(
                      label: 'Full name',
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().length < 2)
                          ? 'Enter your name'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      label: 'Email',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      label: 'Password',
                      controller: _password,
                      isPassword: true,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.length < 8)
                          ? 'At least 8 characters'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      label: 'Confirm password',
                      controller: _confirm,
                      isPassword: true,
                      textInputAction: TextInputAction.done,
                      validator: (v) =>
                          v != _password.text ? 'Passwords do not match' : null,
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: _accepted,
                      activeColor: AppColors.lime,
                      checkColor: Colors.black,
                      side: const BorderSide(color: Colors.black54, width: 1.5), // ✅ Bordure noire
                      onChanged: (v) => setState(() {
                        _accepted = v ?? false;
                        _showTermsError = false;
                      }),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'I agree to the Terms and the Privacy Policy.',
                        style: TextStyle(color: Colors.black54), // ✅ Texte noir
                      ),
                    ),
                    if (_showTermsError)
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 8),
                        child: Text('Please accept to continue',
                            style: TextStyle(color: AppColors.error)),
                      ),
                    const SizedBox(height: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.lime,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor:
                            AppColors.lime.withOpacity(0.6),
                        minimumSize: const Size.fromHeight(54),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.black))
                          : const Text('Create account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}