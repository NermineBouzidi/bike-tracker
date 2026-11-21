import 'package:flutter/material.dart';
import '../widgets/bike_ui.dart';

const Color _lime = Color(0xFFB4FF39);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _interval = 1; // 0 = 1s, 1 = 5s, 2 = 30s
  bool _offlineLog = true;
  bool _autoArm = true;
  bool _buzzer = true;
  int _sens = 2;

  static const _sensLabels = ['Low', 'Medium', 'High', 'Paranoiac'];
  static const _sensHelp = [
    'Triggers only on strong, sustained movement.',
    'Triggers on moderate vibration or lifting.',
    'Triggers on frame tilt, heavy jostling, or lock cable tampering.',
    'Triggers on the slightest touch. May cause false alarms.',
  ];

  String get _intervalLabel =>
      ['1s Live', '5s Balanced', '30s Eco'][_interval.round()];
  String get _drain => ['High (~5 days standby)', 'Moderate (~14 days standby)',
      'Low (~40 days standby)'][_interval.round()];

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
                Image.asset(
                  'assets/images/logo.jpg',
                  height: 36,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.pedal_bike, color: _lime, size: 32), // Fixed BT.ink
                ),
                const Spacer(),
                const BTChip('', icon: Icons.bluetooth, dot: true),
                const SizedBox(width: 8),
                const BTChip('94%', icon: Icons.battery_5_bar),
                const SizedBox(width: 8),
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: _lime, // Fixed BT.green
                  child: Icon(Icons.person, size: 18, color: BT.onGreen),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Device card
            BTPanel(
              child: Column(
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 48,
                          height: 48,
                          color: BT.panel2,
                          child: const Icon(Icons.pedal_bike,
                              color: BT.muted),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Flexible(
                                  child: Text('My Canyon Grail',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: BT.text,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800)),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.edit,
                                    size: 15, color: BT.muted),
                              ],
                            ),
                            const SizedBox(height: 3),
                            const BTMono('BIKETRACK PRO BT-900', size: 10),
                          ],
                        ),
                      ),
                      const BTChip('-44 dBm'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Meta(Icons.verified_outlined, 'Firmware v2.1.4'),
                      _Meta(Icons.bluetooth, 'BLE 5.3'),
                      _Meta(Icons.satellite_alt, 'GPS active'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Tracking
            BTPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.track_changes,
                          color: _lime, size: 20), // Fixed BT.ink
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Tracking & Telemetry',
                            style: TextStyle(
                                color: BT.text,
                                fontSize: 17,
                                fontWeight: FontWeight.w800)),
                      ),
                      const BTChip('Active Lock'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: BT.panel2, // Fixed BT.inset
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text('GPS Update Interval',
                                  style: TextStyle(
                                      color: BT.text,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                            ),
                            BTChip(_intervalLabel),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: _lime, // Fixed BT.green
                            inactiveTrackColor: BT.border, // Fixed BT.track
                            thumbColor: _lime, // Fixed BT.ink
                            overlayColor: _lime.withAlpha(90), // Fixed BT.green
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: _interval,
                            min: 0,
                            max: 2,
                            divisions: 2,
                            onChanged: (v) => setState(() => _interval = v),
                          ),
                        ),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            BTMono('1s Live', size: 10),
                            BTMono('5s Balanced', size: 10),
                            BTMono('30s Eco', size: 10),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.battery_alert,
                                size: 14, color: BT.blue),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  style: const TextStyle(
                                      color: BT.muted, fontSize: 12),
                                  children: [
                                    const TextSpan(text: 'Battery Drain: '),
                                    TextSpan(
                                        text: _drain,
                                        style: const TextStyle(
                                            color: BT.text,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _switchRow(
                    'Offline Ride Logging',
                    'Sync onboard cache (up to 48h) upon next BLE reconnect.',
                    _offlineLog,
                    (v) => setState(() => _offlineLog = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Anti-theft
            BTPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield, color: BT.red, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Anti-Theft & Sensors',
                            style: TextStyle(
                                color: BT.text,
                                fontSize: 17,
                                fontWeight: FontWeight.w800)),
                      ),
                      const BTChip('Guard On', color: BT.red),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Alert Sensitivity',
                      style: TextStyle(
                          color: BT.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: BT.panel2, // Fixed BT.inset
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: List.generate(4, (i) {
                        final on = i == _sens;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _sens = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: on ? _lime : Colors.transparent, // Fixed BT.green
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Center(
                                child: Text(
                                  _sensLabels[i],
                                  style: TextStyle(
                                    fontFamily: kMono,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: on ? BT.onGreen : BT.muted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(_sensHelp[_sens],
                      style: const TextStyle(
                          color: BT.muted, fontSize: 12.5, height: 1.4)),
                  const SizedBox(height: 14),
                  _switchRow(
                    'Auto-Arm When Disconnected',
                    'Arms beacon 45 seconds after leaving phone BLE perimeter.',
                    _autoArm,
                    (v) => setState(() => _autoArm = v),
                  ),
                  const SizedBox(height: 12),
                  _switchRow(
                    'Hardware Buzzer Siren',
                    'Emits rapid pulse burst when violent unauthorized movement detected.',
                    _buzzer,
                    (v) => setState(() => _buzzer = v),
                    badge: '105 dB',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            OutlinedButton.icon(
              onPressed: () {}, // TODO: forget device
              icon: const Icon(Icons.link_off, size: 18),
              label: const Text('Forget device'),
              style: OutlinedButton.styleFrom(
                foregroundColor: BT.red,
                side: BorderSide(color: BT.red.withAlpha(90)),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchRow(String title, String sub, bool v, ValueChanged<bool> cb,
          {String? badge}) =>
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(title,
                          style: const TextStyle(
                              color: BT.text,
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      BTChip(badge, color: BT.red),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(sub,
                    style: const TextStyle(
                        color: BT.muted, fontSize: 12, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          BTSwitch(value: v, onChanged: cb),
        ],
      );
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _lime), // Fixed BT.ink
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(color: BT.text, fontSize: 11.5)),
        ],
      );
}