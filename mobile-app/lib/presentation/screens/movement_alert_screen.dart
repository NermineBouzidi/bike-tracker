import 'package:flutter/material.dart';
import '../widgets/bike_ui.dart';

const Color _lime = Color(0xFFB4FF39);

class MovementAlertScreen extends StatefulWidget {
  const MovementAlertScreen({super.key});

  @override
  State<MovementAlertScreen> createState() => _MovementAlertScreenState();
}

class _MovementAlertScreenState extends State<MovementAlertScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BT.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back, color: BT.text),
                ),
                Image.asset(
                  'assets/images/logo.jpg',
                  height: 28,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.pedal_bike, color: _lime, size: 24),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Stolen Mode Beacon',
                      style: TextStyle(
                          color: BT.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                ),
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: _lime,
                  child: Icon(Icons.person, size: 18, color: BT.onGreen),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Pulsing siren
            Center(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final t = _pulse.value;
                  return SizedBox(
                    width: 130,
                    height: 130,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 100 + 30 * t,
                          height: 100 + 30 * t,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: BT.red.withAlpha((60 * (1 - t)).round()),
                          ),
                        ),
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: BT.salmon,
                            boxShadow: [
                              BoxShadow(
                                  color: BT.red.withAlpha(110),
                                  blurRadius: 28),
                            ],
                          ),
                          child: const Icon(Icons.emergency_share,
                              color: Color(0xFF7A1D12), size: 40),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: BT.red.withAlpha(35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: BT.red.withAlpha(90)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 7, color: BT.red),
                    SizedBox(width: 6),
                    BTMono('CRITICAL SYSTEM BREACH',
                        color: BT.red, size: 10, weight: FontWeight.w800),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text('MOVEMENT DETECTED!',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: BT.text,
                    fontSize: 27,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Anti-theft armed mode triggered 42s ago. Accelerometer detected unauthorized vibration & rolling motion.',
                textAlign: TextAlign.center,
                style: TextStyle(color: BT.muted, fontSize: 13, height: 1.45),
              ),
            ),
            const SizedBox(height: 18),

            // Map + info
            BTPanel(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: 130,
                      width: double.infinity,
                      child: Stack(
                        children: [
                          Positioned.fill(
                              child: CustomPaint(
                                  painter: MapPainter(light: true))),
                          Center(
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: BT.red.withAlpha(60),
                                border: Border.all(color: BT.red),
                              ),
                              child: const Icon(Icons.circle,
                                  size: 10, color: BT.red),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const BTMono(
                                  'TUNIS GPS RELAY ACTIVE',
                                  color: _lime,
                                  size: 9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BTMono('CURRENT BEARING', size: 9.5),
                            SizedBox(height: 4),
                            Text('Corner of Rue de Palestine',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: BT.text,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800)),
                            SizedBox(height: 2),
                            Text('Tunis, Gouvernorat de Tunis',
                                style: TextStyle(
                                    color: BT.muted, fontSize: 11.5)),
                          ],
                        ),
                      ),
                      SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          BTMono('VELOCITY', size: 9.5),
                          SizedBox(height: 4),
                          Text('14 km/h',
                              style: TextStyle(
                                  fontFamily: kMono,
                                  color: BT.red,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800)),
                          SizedBox(height: 2),
                          Text('Heading East',
                              style: TextStyle(
                                  color: BT.muted, fontSize: 11.5)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _miniStat(Icons.battery_charging_full,
                            'BATTERY', '93% • Optimal', _lime,
                            BT.panel2),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _miniStat(Icons.volume_up, 'SIREN STATUS',
                            '105 dB Blaring', BT.red,
                            BT.red.withAlpha(35)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            BTGlowButton(
              label: 'Open Live Map & Track',
              icon: null,
              leading: const Icon(Icons.my_location,
                  color: Color(0xFF5A1A10), size: 20),
              color: BT.salmon,
              textColor: const Color(0xFF3A0E08),
              onTap: () {}, // TODO: open live map tab
            ),
            const SizedBox(height: 12),
            Material(
              color: BT.panel2,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.of(context).maybePop(),
                child: const SizedBox(
                  height: 54,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fingerprint, color: BT.muted, size: 20),
                      SizedBox(width: 10),
                      Text("I'm moving it, dismiss alert",
                          style: TextStyle(
                              color: BT.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_police, size: 14, color: BT.red),
                  SizedBox(width: 6),
                  BTMono('CALL POLICE / LOCAL DISPATCH (197)',
                      color: BT.red, size: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(
          IconData i, String label, String value, Color c, Color bg) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(i, color: c, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BTMono(label, size: 9, color: BT.muted),
                  const SizedBox(height: 3),
                  Text(value,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: kMono,
                          color: c == BT.red ? BT.red : BT.text,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
      );
}