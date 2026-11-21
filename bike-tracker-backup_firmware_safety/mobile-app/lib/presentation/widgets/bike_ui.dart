import 'package:flutter/material.dart';

/// Shared colors + small widgets used by all BikeTrack screens.
class BT {
  static const bg = Color(0xFFF5F2E8); // beige background
  static const panel = Color(0xFFFFFFFF); // white blocks
  static const panel2 = Color(0xFFF1EFE4); // soft beige (buttons, wells)
  static const inset = Color(0xFFF4F2E8); // inner stat boxes
  static const border = Color(0xFFE7E4D6);
  static const track = Color(0x1F000000); // dividers / empty tracks
  static const green = Color(0xFFB4FF00); // lime fills (= AppColors.lime)
  static const ink = Color(0xFF3D6600); // dark green for icons & text on light
  static const paleLime = Color(0xFFF1FFC2);
  static const red = Color(0xFFD92D20);
  static const salmon = Color(0xFFFFB4A8);
  static const blue = Color(0xFF2F6FDE);
  static const muted = Color(0xFF6B7263);
  static const text = Color(0xFF1B2412);
  static const onGreen = Color(0xFF1B2E00);
}

const String kMono = 'monospace';

class BTMono extends StatelessWidget {
  const BTMono(this.text,
      {super.key,
      this.size = 10.5,
      this.color = BT.muted,
      this.weight = FontWeight.w600});
  final String text;
  final double size;
  final Color color;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontFamily: kMono,
          fontSize: size,
          color: color,
          fontWeight: weight,
          letterSpacing: 0.4,
        ),
      );
}

class BTPanel extends StatelessWidget {
  const BTPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = BT.panel,
    this.borderColor = BT.border,
    this.radius = 20,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor),
        ),
        child: child,
      );
}

class BTChip extends StatelessWidget {
  const BTChip(this.text,
      {super.key,
      this.dot = false,
      this.icon,
      this.color = BT.green,
      this.bg});
  final String text;
  final bool dot;
  final IconData? icon;
  final Color color;
  final Color? bg;

  @override
  Widget build(BuildContext context) {
    final isLime = color == BT.green;
    final fg = isLime ? BT.ink : color;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg ?? (isLime ? BT.green.withAlpha(90) : color.withAlpha(28)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: fg.withAlpha(45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            if (icon != null) ...[
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 5),
            ],
            BTMono(text, color: fg, weight: FontWeight.w700),
          ],
        ),
      );
  }
}

class BTRoundButton extends StatelessWidget {
  const BTRoundButton(
      {super.key,
      required this.icon,
      required this.onTap,
      this.color = BT.panel2,
      this.iconColor = BT.text,
      this.size = 40});
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final Color iconColor;
  final double size;

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: size * 0.5, color: iconColor),
          ),
        ),
      );
}

class BTGlowButton extends StatelessWidget {
  const BTGlowButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.leading,
    this.color = BT.green,
    this.textColor = BT.onGreen,
    this.height = 60,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Widget? leading;
  final Color color;
  final Color textColor;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(110),
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: SizedBox(
              height: height,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 12)],
                  Text(
                    label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 10),
                    Icon(icon, size: 20, color: textColor),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}

class BTSwitch extends StatelessWidget {
  const BTSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Switch(
        value: value,
        onChanged: onChanged,
        activeColor: BT.ink,
        activeTrackColor: BT.green,
        inactiveThumbColor: Colors.white,
        inactiveTrackColor: const Color(0xFFD5D2C4),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      );
}

/// Fake map (roads + blocks) so no map package is needed yet.
/// Replace with google_maps_flutter / flutter_map later.
class MapPainter extends CustomPainter {
  MapPainter({this.light = true, this.route = false});
  final bool light;
  final bool route;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final base = light ? const Color(0xFFEAE6DB) : const Color(0xFF1B2638);
    final roadColor = light ? Colors.white : const Color(0xFF2B3A52);
    final blockColor = light ? const Color(0xFFDAD4C6) : const Color(0xFF223049);

    canvas.drawRect(Offset.zero & size, Paint()..color = base);

    final block = Paint()..color = blockColor;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.05, h * 0.1, w * 0.25, h * 0.3),
            const Radius.circular(6)),
        block);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.62, h * 0.5, w * 0.3, h * 0.35),
            const Radius.circular(6)),
        block);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.36, h * 0.62, w * 0.18, h * 0.25),
            const Radius.circular(6)),
        block);

    final road = Paint()
      ..color = roadColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final thin = Paint()
      ..color = roadColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(0, h * 0.5), Offset(w, h * 0.45), road);
    canvas.drawLine(Offset(w * 0.33, 0), Offset(w * 0.4, h), road);
    canvas.drawLine(Offset(w * 0.75, 0), Offset(w * 0.6, h), thin);
    canvas.drawLine(Offset(0, h * 0.85), Offset(w, h * 0.9), thin);
    canvas.drawLine(Offset(0, h * 0.2), Offset(w * 0.6, h * 0.25), thin);

    if (route) {
      final p = Path()
        ..moveTo(w * 0.1, h * 0.8)
        ..quadraticBezierTo(w * 0.3, h * 0.55, w * 0.5, h * 0.5)
        ..quadraticBezierTo(w * 0.7, h * 0.45, w * 0.85, h * 0.2);
      canvas.drawPath(
        p,
        Paint()
          ..color = BT.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}