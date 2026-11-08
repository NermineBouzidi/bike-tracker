import 'package:flutter/material.dart';
import '../widgets/bike_ui.dart';
import 'movement_alert_screen.dart';
import 'pair_device_screen.dart';

const Color _lime = Color(0xFFB4FF39);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _armed = true;

  // TODO: bind these to real BLE data.
  final double _speed = 0.0;
  final int _battery = 94;

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: BT.panel2,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final parked = _speed == 0;
    return Scaffold(
      backgroundColor: BT.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // Top bar
            Row(
              children: [
                Image.asset(
                  'mobile-app/assets/images/logo.jpg', // ✅ Modifié
                  height: 36,
                  color: Colors.black, // ✅ Force en noir pour le fond clair
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.pedal_bike, color: _lime, size: 32),
                ),
                const Spacer(),
                const BTChip('BLE ONLINE', dot: true),
                const SizedBox(width: 8),
                const BTChip('94%', icon: Icons.battery_5_bar),
                const SizedBox(width: 8),
                BTRoundButton(
                  icon: Icons.person_outline,
                  size: 34,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const PairDeviceScreen())),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Device row
            BTPanel(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: _lime, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('BikeTrack Pro #8492',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: BT.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ),
                  const BTMono('Synced 12s ago', size: 10.5),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Parked / moving
            BTPanel(
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _lime.withAlpha(40),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                        parked ? Icons.shield_outlined : Icons.directions_bike,
                        color: _lime),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(parked ? 'Bike is parked' : 'Bike is moving',
                            style: const TextStyle(
                                color: BT.text,
                                fontSize: 21,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                            parked
                                ? 'Stationary for 3h 42m'
                                : 'Ride in progress',
                            style: const TextStyle(
                                color: BT.muted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: BT.panel2,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        const BTMono('SPEED', size: 9.5),
                        Text(_speed.toStringAsFixed(1),
                            style: const TextStyle(
                                fontFamily: kMono,
                                color: _lime,
                                fontSize: 24,
                                fontWeight: FontWeight.w800)),
                        const BTMono('km/h', size: 9.5),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Anti-theft
            BTPanel(
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _lime.withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_armed ? Icons.lock : Icons.lock_open,
                        color: _lime, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Anti-Theft Shield',
                            style: TextStyle(
                                color: BT.text,
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                        const SizedBox(height: 3),
                        BTMono(
                            _armed ? 'ARMED & PROTECTING' : 'DISARMED',
                            color: _armed ? _lime : BT.muted,
                            size: 10),
                      ],
                    ),
                  ),
                  BTSwitch(
                    value: _armed,
                    onChanged: (v) => setState(() => _armed = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Battery
            BTPanel(
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: CircularProgressIndicator(
                            value: _battery / 100,
                            strokeWidth: 5,
                            backgroundColor: BT.border,
                            color: _lime,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Text('$_battery%',
                            style: const TextStyle(
                                color: BT.text,
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('E-Pack Battery',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: BT.text,
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                        SizedBox(height: 3),
                        Text('48 days standby',
                            style:
                                TextStyle(color: BT.muted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  const BTChip('Dynamo Ready', icon: Icons.bolt),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Map card
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                color: BT.panel,
                child: Column(
                  children: [
                    SizedBox(
                      height: 110,
                      width: double.infinity,
                      child: Stack(
                        children: [
                          Positioned.fill(
                              child: CustomPaint(painter: MapPainter())),
                          const Positioned(
                              top: 10,
                              left: 10,
                              child: BTChip('Tunis Center', dot: true)),
                          const Positioned(
                              top: 10,
                              right: 10,
                              child: BTChip('14 Sats',
                                  icon: Icons.satellite_alt)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.place, color: _lime, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Avenue Habib Bourguiba, Tunis',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: BT.text,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14)),
                                SizedBox(height: 3),
                                BTMono('36.8002° N, 10.1865° E',
                                    size: 10),
                              ],
                            ),
                          ),
                          const BTMono('GPS 3D Fix',
                              color: _lime, size: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            const BTMono('RAPID COUNTERMEASURES', size: 10),
            const SizedBox(height: 10),
            Row(
              children: [
                _action(Icons.volume_up, 'Siren', _lime,
                    () => _toast('Buzzer sounded')),
                const SizedBox(width: 10),
                _action(Icons.share_location, 'Share', BT.blue,
                    () => _toast('Live location link copied')),
                const SizedBox(width: 10),
                _action(Icons.notifications_active, 'Alert Test', BT.red,
                    () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const MovementAlertScreen()))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, Color c, VoidCallback onTap) {
    final lime = c == _lime;
    final fg = lime ? BT.text : c;
    final bg = lime ? _lime.withAlpha(40) : c.withAlpha(32);
    return Expanded(
        child: Material(
          color: BT.panel,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: BT.border),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: bg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: fg, size: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(label,
                      style: const TextStyle(
                          color: BT.text,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
    );
  }
}