import 'package:flutter/material.dart';

const Color _ink = Color(0xFF1E2B1C);
const Color _muted = Color(0xFF6F7D6A);
const Color _error = Color(0xFFD64545);

/// Soft rounded text field (white, no border, ink outline when focused).
/// Shared by all auth screens (sign in, sign up, ...).
class SoftField extends StatefulWidget {
  const SoftField({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
    required this.validator,
    this.keyboardType,
    this.textInputAction,
    this.isPassword = false,
    this.onSubmitted,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool isPassword;
  final ValueChanged<String>? onSubmitted;

  @override
  State<SoftField> createState() => _SoftFieldState();
}

class _SoftFieldState extends State<SoftField> {
  bool _obscure = true;

  OutlineInputBorder _border(Color color, [double width = 0]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: width == 0
            ? BorderSide.none
            : BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: widget.isPassword && _obscure,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmitted,
      cursorColor: _ink,
      style: const TextStyle(
        color: _ink,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: const TextStyle(color: _muted, fontWeight: FontWeight.w500),
        floatingLabelStyle:
            const TextStyle(color: _ink, fontWeight: FontWeight.w700),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.85),
        prefixIcon: Icon(widget.icon, color: _muted, size: 20),
        suffixIcon: widget.isPassword
            ? IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _muted,
                  size: 20,
                ),
              )
            : null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: _border(Colors.transparent),
        enabledBorder: _border(Colors.transparent),
        focusedBorder: _border(_ink, 1.5),
        errorBorder: _border(_error, 1),
        focusedErrorBorder: _border(_error, 1.5),
        errorStyle: const TextStyle(color: _error, fontSize: 12.5),
      ),
    );
  }
}