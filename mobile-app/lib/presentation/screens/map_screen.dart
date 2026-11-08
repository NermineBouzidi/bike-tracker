import 'package:flutter/material.dart';
import '../widgets/bike_ui.dart';

const Color _lime = Color(0xFFB4FF39);

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _follow = true;

  final double _speed = 18.4;
  final double _lat = 36.8065;
  final double _lng = 10.1815;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => CustomPaint(
              painter: _LiveMapPainter(_pulse.value),
            ),
          ),
        ),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Image.asset(
                      'mobile-app/assets/images/logo.jpg', // ✅ Modifié
                      height: 36,
                      color: Colors.black, // ✅ Force en noir
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.pedal_bike,
                          color: _lime,
                          size: 32),
                    ),
                    const Spacer(),
                    const BTChip('', icon: Icons.bluetooth, dot: true),
                    const SizedBox(width: 8),
                    const BTChip('94%', icon: Icons.battery_5_bar),
                    const SizedBox(width: 8),
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: _lime,
                      child: Icon(Icons.person, size: 18, color: BT.onGreen),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: BT.bg.withAlpha(220),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: BT.border),
                            ),
                            child: const BTMono('LIVE MESH 1.2S',
                                color: _lime, size: 10.5),
                          ),
                          const SizedBox(height: 8),
                          const BTMono('SECTOR: HABIB BOURGUIBA / LAC 1',
                              color: BT.text, size: 10),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        _mapBtn(Icons.my_location, active: _follow,
                            onTap: () => setState(() => _follow = !_follow)),
                        const SizedBox(height: 10),
                        _mapBtn(Icons.navigation, onTap: () {}),
                        const SizedBox(height: 10),
                        _mapBtn(Icons.layers_outlined, onTap: () {}),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        Positioned(
          left: 16,
          bottom: 250,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: BT.bg.withAlpha(235),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _lime.withAlpha(60)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.navigation, size: 14, color: _lime),
                SizedBox(width: 6),
                BTMono('HEADING 042° NE',
                    color: BT.text, size: 10.5, weight: FontWeight.w700),
              ],
            ),
          ),
        ),

        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              border: Border(top: BorderSide(color: BT.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: BT.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                          color: _lime, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('BikeTrack Pro',
                          style: TextStyle(
                              color: BT.text,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                    ),
                    const BTChip('16 Sats', icon: Icons.satellite_alt),
                    const SizedBox(width: 8),
                    const BTChip('12m', icon: Icons.swap_vert),
                  ],
                ),
                const SizedBox(height: 4),
                const BTMono('LIVE TRACKING ACTIVE • ULTRA-BAND',
                    color: BT.muted, size: 10),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _tile(
                        'LOCATION',
                        Icons.explore_outlined,
                        BT.muted,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_lat.toStringAsFixed(4)}° N',
                                style: const TextStyle(
                                    color: BT.text,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800)),
                            Text('${_lng.toStringAsFixed(4)}° E',
                                style: const TextStyle(
                                    fontFamily: kMono,
                                    color: BT.text,
                                    fontSize: 11)),
                            const SizedBox(height: 6),
                            const Text('Tunis Central',
                                style: TextStyle(
                                    color: BT.muted, fontSize: 10.5)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _tile(
                        'LIVE SPEED',
                        Icons.speed,
                        _lime,
                        highlight: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_speed.toStringAsFixed(1),
                                    style: const TextStyle(
                                        color: BT.text,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900)),
                                const SizedBox(width: 3),
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 4),
                                  child: BTMono('km/h', size: 10),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text('Active cruising',
                                style: TextStyle(
                                    color: BT.muted, fontSize: 10.5)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _tile(
                        'MESH SYNC',
                        Icons.sync,
                        BT.blue,
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Just now',
                                style: TextStyle(
                                    color: BT.text,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800)),
                            Text('1s refresh',
                                style: TextStyle(
                                    color: BT.blue, fontSize: 11)),
                            SizedBox(height: 6),
                            Text('Ping 28ms',
                                style: TextStyle(
                                    color: BT.muted, fontSize: 10.5)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _mapBtn(IconData icon,
          {bool active = false, required VoidCallback onTap}) =>
      Material(
        color: BT.bg.withAlpha(230),
        shape: CircleBorder(
          side: BorderSide(
              color: active ? _lime.withAlpha(120) : BT.border),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, color: active ? _lime : BT.text, size: 20),
          ),
        ),
      );

  Widget _tile(String label, IconData icon, Color iconColor,
          {required Widget child, bool highlight = false}) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: highlight ? _lime.withAlpha(40) : BT.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: highlight ? _lime.withAlpha(60) : BT.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: BTMono(label,
                      size: 9, color: highlight ? _lime : BT.muted),
                ),
                Icon(icon, size: 15, color: iconColor),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );
}

class _LiveMapPainter extends CustomPainter {
  _LiveMapPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFEAE6DB));

    final water = Path()
      ..moveTo(w * 0.55, h * 0.12)
      ..quadraticBezierTo(w * 1.05, h * 0.15, w, h * 0.45)
      ..lineTo(w, h * 0.7)
      ..quadraticBezierTo(w * 0.75, h * 0.62, w * 0.62, h * 0.45)
      ..quadraticBezierTo(w * 0.5, h * 0.28, w * 0.55, h * 0.12)
      ..close();
    canvas.drawPath(water, Paint()..color = const Color(0xFFBFD9EE));

    final block = Paint()..color = const Color(0xFFDAD4C6);
    for (final r in [
      Rect.fromLTWH(w * 0.05, h * 0.15, w * 0.22, h * 0.14),
      Rect.fromLTWH(w * 0.3, h * 0.2, w * 0.15, h * 0.12),
      Rect.fromLTWH(w * 0.08, h * 0.4, w * 0.2, h * 0.12),
      Rect.fromLTWH(w * 0.55, h * 0.6, w * 0.25, h * 0.1),
      Rect.fromLTWH(w * 0.12, h * 0.62, w * 0.2, h * 0.1),
    ]) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(6)), block);
    }

    final road = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final thin = Paint()
      ..color = const Color(0xFFF8F6EF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, h * 0.35), Offset(w * 0.7, h * 0.5), road);
    canvas.drawLine(Offset(w * 0.25, 0), Offset(w * 0.4, h * 0.8), road);
    canvas.drawLine(Offset(0, h * 0.55), Offset(w, h * 0.72), thin);
    canvas.drawLine(Offset(w * 0.6, 0), Offset(w * 0.5, h * 0.8), thin);
    canvas.drawLine(Offset(0, h * 0.2), Offset(w * 0.5, h * 0.25), thin);

    final start = Offset(w * 0.12, h * 0.68);
    final end = Offset(w * 0.62, h * 0.28);
    final route = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(w * 0.3, h * 0.6, w * 0.4, h * 0.45, end.dx, end.dy);
    canvas.drawPath(
      route,
      Paint()
        ..color = _lime.withAlpha(170)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      route,
      Paint()
        ..color = _lime
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(start, 6, Paint()..color = BT.bg);
    canvas.drawCircle(
      start,
      6,
      Paint()
        ..color = _lime
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final pr = 18 + 22 * t;
    canvas.drawCircle(
        end, pr, Paint()..color = _lime.withAlpha((70 * (1 - t)).round()));
    canvas.drawCircle(end, 17, Paint()..color = Colors.white);
    canvas.drawCircle(
      end,
      17,
      Paint()
        ..color = _lime
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    final icon = Icons.directions_bike;
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 18,
          color: _lime,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, end - Offset(tp.width / 2, tp.height / 2));

    final label = TextPainter(
      text: const TextSpan(
        text: 'KINETIC LOCK',
        style: TextStyle(
          fontFamily: kMono,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: BT.onGreen,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: end + const Offset(0, -34),
          width: label.width + 20,
          height: 22),
      const Radius.circular(11),
    );
    canvas.drawRRect(rect, Paint()..color = _lime);
    label.paint(canvas, rect.center - Offset(label.width / 2, label.height / 2));
  }

  @override
  bool shouldRepaint(covariant _LiveMapPainter old) => old.t != t;
}