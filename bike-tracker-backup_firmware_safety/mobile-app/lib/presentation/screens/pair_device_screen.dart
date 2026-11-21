import 'package:flutter/material.dart';
import '../widgets/bike_ui.dart';

const Color _lime = Color(0xFFB4FF39);

class _Tracker {
  const _Tracker(this.name, this.rssi, this.quality, this.bars, this.icon,
      {this.mac, this.battery, this.distance, this.weak = false});
  final String name;
  final int rssi;
  final String quality;
  final int bars;
  final IconData icon;
  final String? mac;
  final int? battery;
  final String? distance;
  final bool weak;
}

class PairDeviceScreen extends StatefulWidget {
  const PairDeviceScreen({super.key});

  @override
  State<PairDeviceScreen> createState() => _PairDeviceScreenState();
}

class _PairDeviceScreenState extends State<PairDeviceScreen> {
  bool _scanning = true;
  String? _connecting = 'BikeTrack Pro #8492';

  // TODO: replace with real BLE scan results (flutter_blue_plus).
  static const _found = [
    _Tracker('BikeTrack Pro #8492', -42, 'Excellent', 4, Icons.directions_bike,
        mac: 'C4:7D:E2:84:92:01', battery: 94, distance: '< 1.2 m'),
    _Tracker('BikeTrack Core #1042', -68, 'Good', 2, Icons.pedal_bike),
    _Tracker('BT-Beacon_Guest', -89, 'Weak', 1, Icons.cell_tower, weak: true),
  ];

  void _scan() async {
    setState(() => _scanning = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _scanning = false);
  }

  void _connect(_Tracker t) async {
    setState(() => _connecting = t.name);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _connecting = null);
    Navigator.of(context).pop(t.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BT.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // Header
            Row(
              children: [
                BTRoundButton(
                  icon: Icons.arrow_back,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const Expanded(
                  child: Column(
                    children: [
                      BTMono('STEP 1 OF 2', color: BT.blue, size: 10),
                      SizedBox(height: 2),
                      Text('Pair New Device',
                          style: TextStyle(
                              color: BT.text,
                              fontSize: 19,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const BTChip('BLE 5.2', dot: true),
              ],
            ),
            const SizedBox(height: 18),

            // Bike hero
            BTPanel(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
              child: Column(
                children: [
                  SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: CustomPaint(painter: _BikeLinePainter()),
                  ),
                  const SizedBox(height: 10),
                  const BTChip('LOC: LAC 2, TUNIS (TN)', icon: Icons.place),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Scan button
            BTGlowButton(
              label: _scanning ? 'Scanning...' : 'Scan for your tracker',
              icon: Icons.bluetooth_searching,
              leading: _scanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: BT.onGreen))
                  : Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                          color: BT.onGreen, shape: BoxShape.circle)),
              onTap: _scanning ? null : _scan,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                        color: _lime, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Scanning nearby (2.4 GHz BLE)',
                      style: TextStyle(color: BT.muted, fontSize: 12)),
                ),
                const BTChip('3 trackers detected', bg: BT.paleLime),
              ],
            ),
            const SizedBox(height: 16),

            for (final t in _found) ...[
              t.battery != null ? _primaryCard(t) : _simpleCard(t),
              const SizedBox(height: 12),
            ],

            // Tip
            BTPanel(
              color: const Color(0xFFEAF2FF),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: BT.blue.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.lightbulb_outline,
                        color: BT.blue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BTMono('PAIRING TIP', color: BT.blue, size: 10),
                        SizedBox(height: 6),
                        Text.rich(
                          TextSpan(
                            style: TextStyle(
                                color: BT.text, fontSize: 13, height: 1.45),
                            children: [
                              TextSpan(text: 'Make sure your bike is within '),
                              TextSpan(
                                  text: '10 meters',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w800)),
                              TextSpan(
                                  text:
                                      '. Spin the front wheel once to wake up the internal dynamo sensor and transmit telemetry bursts.'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBox(IconData i, {bool weak = false}) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: BT.panel2,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(i, color: weak ? BT.muted : _lime, size: 22),
      );

  Widget _signal(int bars, {bool weak = false}) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(4, (i) {
          final on = i < bars;
          return Container(
            width: 3.5,
            height: 5.0 + i * 3,
            margin: const EdgeInsets.only(right: 2),
            decoration: BoxDecoration(
              color: on ? (weak ? BT.muted : _lime) : BT.track,
              borderRadius: BorderRadius.circular(1),
            ),
          );
        }),
      );

  Widget _primaryCard(_Tracker t) {
    final connecting = _connecting == t.name;
    return BTPanel(
      color: const Color(0xFFF6FFD6),
      borderColor: _lime.withAlpha(60),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _iconBox(t.icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.name,
                        style: const TextStyle(
                            color: BT.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    BTMono('MAC: ${t.mac}', size: 10),
                  ],
                ),
              ),
              if (connecting)
                const BTChip('Connecting...', dot: true)
              else
                _connectBtn(t),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: BT.inset,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _stat(_signal(t.bars), '${t.rssi} dBm', t.quality),
                _div(),
                _stat(const Icon(Icons.bolt, color: _lime, size: 16),
                    '${t.battery}%', 'Dynamo charged'),
                _div(),
                _stat(const Icon(Icons.navigation, color: BT.blue, size: 15),
                    t.distance!, ''),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(Widget lead, String top, String sub) => Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            lead,
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(top,
                    style: const TextStyle(
                        color: BT.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
                if (sub.isNotEmpty)
                  Text(sub,
                      style: const TextStyle(
                          color: BT.muted, // Fixed: was BT.ink
                          fontSize: 9.5)),
              ],
            ),
          ],
        ),
      );

  Widget _div() => Container(width: 1, height: 28, color: BT.track);

  Widget _simpleCard(_Tracker t) => BTPanel(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _iconBox(t.icon, weak: t.weak),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name,
                      style: TextStyle(
                          color: t.weak ? BT.muted : BT.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _signal(t.bars, weak: t.weak),
                      const SizedBox(width: 8),
                      BTMono('${t.rssi} dBm • ${t.quality}', size: 10),
                    ],
                  ),
                ],
              ),
            ),
            _connectBtn(t),
          ],
        ),
      );

  Widget _connectBtn(_Tracker t) => TextButton(
        onPressed: t.weak ? null : () => _connect(t),
        style: TextButton.styleFrom(
          backgroundColor: BT.panel2,
          foregroundColor: BT.text,
          disabledForegroundColor: BT.muted,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
        ),
        child: const Text('Connect',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      );
}

class _BikeLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.height * 0.36;
    final lw = Offset(c.dx - size.width * 0.27, c.dy + r * 0.3);
    final rw = Offset(c.dx + size.width * 0.27, c.dy + r * 0.3);

    final ring = Paint()
      ..color = Colors.black.withAlpha(30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(lw, r, ring);
    canvas.drawCircle(rw, r, ring);

    final frame = Paint()
      ..color = BT.text
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final bb = Offset(c.dx, c.dy + r * 0.3);
    final seat = Offset(c.dx - size.width * 0.1, c.dy - r * 0.7);
    final head = Offset(c.dx + size.width * 0.17, c.dy - r * 0.7);
    final path = Path()
      ..moveTo(lw.dx, lw.dy)
      ..lineTo(seat.dx, seat.dy)
      ..lineTo(head.dx, head.dy)
      ..lineTo(rw.dx, rw.dy)
      ..moveTo(seat.dx, seat.dy)
      ..lineTo(bb.dx, bb.dy)
      ..lineTo(head.dx, head.dy)
      ..moveTo(bb.dx, bb.dy)
      ..lineTo(lw.dx, lw.dy);
    canvas.drawPath(path, frame);

    final blue = Paint()
      ..color = BT.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(seat.dx - 12, seat.dy - 8),
        Offset(seat.dx + 8, seat.dy - 8), blue);
    canvas.drawLine(Offset(head.dx - 4, head.dy - 10),
        Offset(head.dx + 14, head.dy - 16), blue);

    // Tracker node
    canvas.drawCircle(bb, 14, Paint()..color = _lime.withAlpha(150));
    canvas.drawCircle(bb, 6, Paint()..color = BT.text); // Fixed: was BT.ink
    canvas.drawCircle(bb, 2.5, Paint()..color = BT.bg);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}