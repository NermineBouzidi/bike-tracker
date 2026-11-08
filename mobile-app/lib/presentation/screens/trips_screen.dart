import 'package:flutter/material.dart';
import '../widgets/bike_ui.dart';

const Color _lime = Color(0xFFB4FF39);

class _Trip {
  const _Trip({
    required this.when,
    required this.title,
    required this.km,
    required this.min,
    required this.avg,
    required this.max,
    required this.tag,
    required this.points,
    this.badge,
    this.note,
    this.icon = Icons.verified,
  });
  final String when;
  final String title;
  final String km;
  final String min;
  final String avg;
  final String max;
  final String tag;
  final String? badge;
  final String? note;
  final IconData icon;
  final List<double> points;
}

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  bool _syncing = true;
  double _progress = 0.78;
  int _filter = 0;

  static const _filters = [
    (Icons.directions_bike, 'All Rides'),
    (Icons.calendar_view_week, 'This Week'),
    (Icons.work_outline, 'Commutes'),
    (Icons.route, 'Long'),
  ];

  static const _trips = [
    _Trip(
      when: 'TODAY • 08:30 AM',
      title: 'Downtown to Les Berges du Lac',
      km: '8.4',
      min: '24',
      avg: '21.0',
      max: '34.2',
      tag: '+18 Wh recovered',
      points: [0.3, 0.35, 0.4, 0.42, 0.5, 0.55, 0.6, 0.62, 0.66, 0.7],
    ),
    _Trip(
      when: 'YESTERDAY • 06:15 PM',
      title: 'Tunis Marina Evening Loop',
      km: '15.2',
      min: '46',
      avg: '19.8',
      max: '31.5',
      tag: '76 rpm avg',
      icon: Icons.nightlight_round,
      points: [0.5, 0.45, 0.5, 0.48, 0.52, 0.5, 0.55, 0.57, 0.6, 0.62],
    ),
    _Trip(
      when: 'SUNDAY • OCT 12',
      badge: 'Longest',
      title: 'Carthage Coast Ride',
      km: '42.7',
      min: '128',
      avg: '20.0',
      max: '38.9',
      tag: '+54 Wh recovered',
      icon: Icons.landscape,
      points: [0.2, 0.3, 0.45, 0.4, 0.55, 0.6, 0.5, 0.65, 0.7, 0.75],
    ),
  ];

  void _sync() async {
    setState(() {
      _syncing = true;
      _progress = 0.0;
    });
    for (var i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() => _progress = i / 10);
    }
    if (mounted) setState(() => _syncing = false);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Top bar
          Row(
            children: [
              Image.asset(
                'mobile-app/assets/images/logo.jpg', // ✅ Modifié
                height: 36,
                color: Colors.black, // ✅ Force en noir
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.pedal_bike, color: _lime, size: 32),
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
          const SizedBox(height: 14),

          // Sync card
          BTPanel(
            child: Column(
              children: [
                Row(
                  children: [
                    BTRoundButton(
                      icon: Icons.sync,
                      color: BT.panel2,
                      iconColor: _lime,
                      onTap: _syncing ? null : _sync,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_syncing ? 'Syncing Tracker' : 'Tracker synced',
                              style: const TextStyle(
                                  color: BT.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          const Text('Hardware BLE linked • 4 offline rides',
                              style:
                                  TextStyle(color: BT.muted, fontSize: 11.5)),
                        ],
                      ),
                    ),
                    BTChip('${(_progress * 100).round()}%', dot: true),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 5,
                    backgroundColor: BT.border,
                    color: _lime,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '142.6 km total • 8 trips saved on device',
                        style: TextStyle(color: BT.muted, fontSize: 11.5),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {},
                      child: const Row(
                        children: [
                          Text('Details',
                              style: TextStyle(
                                  color: BT.blue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                          Icon(Icons.chevron_right, size: 16, color: BT.blue),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Filters
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final on = i == _filter;
                final f = _filters[i];
                return GestureDetector(
                  onTap: () => setState(() => _filter = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: on ? _lime : BT.panel,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: on ? _lime : BT.border),
                    ),
                    child: Row(
                      children: [
                        Icon(f.$1,
                            size: 15, color: on ? BT.onGreen : BT.muted),
                        const SizedBox(width: 6),
                        Text(f.$2,
                            style: TextStyle(
                              fontFamily: kMono,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: on ? BT.onGreen : BT.muted,
                            )),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          for (final t in _trips) ...[
            _tripCard(t),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _tripCard(_Trip t) => BTPanel(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                BTMono(t.when, color: BT.muted, size: 10),
                if (t.badge != null) ...[
                  const SizedBox(width: 8),
                  BTChip(t.badge!, color: BT.blue),
                ],
                const Spacer(),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: BT.panel2,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(t.icon, size: 18, color: BT.blue),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(t.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: BT.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                color: BT.panel2,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  _stat('DISTANCE', t.km, 'km'),
                  _stat('DURATION', t.min, 'min'),
                  _stat('AVG SPD', t.avg, 'kph', hi: true),
                  _stat('MAX SPD', t.max, 'kph'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 64,
              width: double.infinity,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _SparkPainter(t.points)),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: BTChip(t.tag, icon: Icons.bolt),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.touch_app, size: 16, color: BT.blue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Tap to inspect telemetry & GPS export (.GPX / .KML)',
                    style: TextStyle(
                        color: BT.blue,
                        fontFamily: kMono,
                        fontSize: 10.5,
                        height: 1.4),
                  ),
                ),
                const Icon(Icons.north_east, size: 16, color: BT.muted),
              ],
            ),
          ],
        ),
      );

  Widget _stat(String label, String value, String unit, {bool hi = false}) =>
      Expanded(
        child: Column(
          children: [
            BTMono(label, size: 8.5),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(value,
                      style: TextStyle(
                          color: hi ? _lime : BT.text,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(width: 2),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: BTMono(unit, size: 9),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.pts);
  final List<double> pts;

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.length < 2) return;
    final w = size.width;
    final h = size.height;
    final step = w / (pts.length - 1);

    final line = Path()..moveTo(0, h * (1 - pts[0]));
    for (var i = 1; i < pts.length; i++) {
      final x0 = (i - 1) * step;
      final x1 = i * step;
      final y0 = h * (1 - pts[i - 1]);
      final y1 = h * (1 - pts[i]);
      line.cubicTo((x0 + x1) / 2, y0, (x0 + x1) / 2, y1, x1, y1);
    }

    final fill = Path.from(line)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_lime.withAlpha(150), _lime.withAlpha(0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = _lime
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    // Highlight points
    for (final i in [pts.length ~/ 3, pts.length - 1]) {
      canvas.drawCircle(
          Offset(i * step, h * (1 - pts[i])), 3.5, Paint()..color = _lime);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}