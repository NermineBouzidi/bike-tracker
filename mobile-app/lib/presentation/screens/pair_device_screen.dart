import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../data/ble/bike_connection.dart';

// Same soft palette as the other screens
const Color _bgTop = Color(0xFFF4F8EE);
const Color _bgBottom = Color(0xFFDDE9D1);
const Color _ink = Color(0xFF1E2B1C);
const Color _muted = Color(0xFF6F7D6A);
const Color _sage = Color(0xFFBFD4AC);
const Color _accent = Color(0xFFB6E35C);
const Color _danger = Color(0xFFD64545);

/// Scans for nearby BLE devices and pairs the chosen one.
/// Pops `true` when the bike is paired and connected.
class PairDeviceScreen extends StatefulWidget {
  const PairDeviceScreen({super.key});

  @override
  State<PairDeviceScreen> createState() => _PairDeviceScreenState();
}

class _PairDeviceScreenState extends State<PairDeviceScreen> {
  final _conn = BikeConnection.instance;

  StreamSubscription<List<ScanResult>>? _resultsSub;
  StreamSubscription<bool>? _scanningSub;
  List<ScanResult> _results = [];
  bool _scanning = false;
  String? _connectingId;

  @override
  void initState() {
    super.initState();
    _resultsSub = FlutterBluePlus.scanResults.listen((list) {
  debugPrint('BLE: ${list.length} devices detected');

  for (final r in list) {
    debugPrint(
      'DEVICE: '
      'Name=${r.advertisementData.advName}, '
      'PlatformName=${r.device.platformName}, '
      'ID=${r.device.remoteId}, '
      'RSSI=${r.rssi}, '
      'Services=${r.advertisementData.serviceUuids}',
    );
  }

  if (mounted) {
    setState(() => _results = list);
  }
}, onError: (e) {
  debugPrint('BLE RESULTS ERROR: $e');
});
    _scanningSub = FlutterBluePlus.isScanning.listen((s) {
      if (mounted) setState(() => _scanning = s);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  @override
  void dispose() {
    _resultsSub?.cancel();
    _scanningSub?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _scan() async {
    if (_scanning || _connectingId != null) return;
    await _conn.startScan(); // asks the permission, checks Bluetooth is on
  }

  Future<void> _pair(ScanResult r) async {
    setState(() => _connectingId = r.device.remoteId.str);
    await _conn.pair(r.device, name: _nameOf(r));
    if (!mounted) return;
    if (_conn.link == BikeLink.connected) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _connectingId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not connect. Move closer and try again.'),
      ),
    );
  }

  // ---------------------------------------------------------------- helpers

  static String _nameOf(ScanResult r) => r.advertisementData.advName.isNotEmpty
      ? r.advertisementData.advName
      : (r.device.platformName.isNotEmpty
          ? r.device.platformName
          : 'Unnamed device (${r.device.remoteId.str.replaceAll(':', '').substring(r.device.remoteId.str.replaceAll(':', '').length - 4)})');

  static bool _looksLikeTracker(ScanResult r) {
    final n = _nameOf(r).toLowerCase();
    if (n.contains('bike') || n.contains('track')) return true;
    // The firmware's services start with d973f2e.
    return r.advertisementData.serviceUuids
        .any((u) => u.str128.toLowerCase().startsWith('d973f2e'));
  }

  static int _bars(int rssi) =>
      rssi > -60 ? 4 : (rssi > -70 ? 3 : (rssi > -80 ? 2 : 1));

  static String _quality(int rssi) => rssi > -60
      ? 'Excellent'
      : (rssi > -70 ? 'Good' : (rssi > -80 ? 'Fair' : 'Weak'));

  /// Every device, likely trackers first, then the strongest signal.
  List<ScanResult> get _visible {
    final list = _results.toList();
    list.sort((a, b) {
      final ta = _looksLikeTracker(a) ? 0 : 1;
      final tb = _looksLikeTracker(b) ? 0 : 1;
      if (ta != tb) return ta - tb;
      return b.rssi.compareTo(a.rssi);
    });
    return list;
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final devices = _visible;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: _conn,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.75),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back,
                              color: _ink, size: 20),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'Pair a bike',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                // Problem (Bluetooth off / permission) or scan status
                if (_problemCard() case final p?) ...[
                  p,
                  const SizedBox(height: 14),
                ] else
                  _ScanStatus(scanning: _scanning, count: devices.length),
                const SizedBox(height: 14),

                // Devices
                if (devices.isEmpty && !_scanning && _conn.problem == BikeProblem.none)
                  const _EmptyState()
                else
                  for (final r in devices) ...[
                    _DeviceCard(
                      name: _nameOf(r),
                      address: r.device.remoteId.str,
                      rssi: r.rssi,
                      bars: _bars(r.rssi),
                      quality: _quality(r.rssi),
                      likely: _looksLikeTracker(r),
                      connecting: _connectingId == r.device.remoteId.str,
                      enabled: _connectingId == null,
                      onConnect: () => _pair(r),
                    ),
                    const SizedBox(height: 12),
                  ],

                const SizedBox(height: 6),
                FilledButton(
                  onPressed: (_scanning || _connectingId != null) ? null : _scan,
                  style: FilledButton.styleFrom(
                    backgroundColor: _ink,
                    foregroundColor: _accent,
                    disabledBackgroundColor: _ink.withValues(alpha: 0.6),
                    disabledForegroundColor: _accent,
                    minimumSize: const Size.fromHeight(56),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_scanning)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.2, color: _accent),
                        )
                      else
                        const Icon(Icons.bluetooth_searching, size: 19),
                      const SizedBox(width: 10),
                      Text(_scanning ? 'Scanning...' : 'Scan again'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const _TipCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _problemCard() {
    final (title, text, action) = switch (_conn.problem) {
      BikeProblem.bluetoothOff => (
          'Bluetooth is off',
          'Turn it on to look for your bike.',
          'Turn on'
        ),
      BikeProblem.permissionDenied => (
          'Bluetooth permission needed',
          'Allow nearby devices so the app can find your bike.',
          'Allow'
        ),
      BikeProblem.permissionBlocked => (
          'Permission blocked',
          'Open the app settings and allow "Nearby devices".',
          'Open settings'
        ),
      BikeProblem.unsupported => (
          'Bluetooth not available',
          'This phone does not support Bluetooth Low Energy.',
          null
        ),
      BikeProblem.none => (null, null, null),
    };
    if (title == null) return null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                    color: _ink, shape: BoxShape.circle),
                child: const Icon(Icons.bluetooth_disabled,
                    color: _accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: _ink,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(text!,
                        style: const TextStyle(
                            color: _muted, fontSize: 13.5, height: 1.35)),
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await _conn.fixProblem();
                if (mounted && _conn.problem == BikeProblem.none) _scan();
              },
              style: FilledButton.styleFrom(
                backgroundColor: _ink,
                foregroundColor: _accent,
                minimumSize: const Size.fromHeight(50),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w700),
              ),
              child: Text(action),
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// Pieces
// ===========================================================================

class _ScanStatus extends StatelessWidget {
  const _ScanStatus({required this.scanning, required this.count});
  final bool scanning;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: scanning ? const Color(0xFF3FA34D) : _muted,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            scanning ? 'Looking for nearby devices...' : 'Scan finished',
            style: const TextStyle(color: _muted, fontSize: 13.5),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            count == 1 ? '1 device' : '$count devices',
            style: const TextStyle(
              color: _ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Column(
        children: [
          Icon(Icons.bluetooth_searching, color: _muted, size: 34),
          SizedBox(height: 12),
          Text('No device found',
              style: TextStyle(
                  color: _ink, fontSize: 16.5, fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text(
            'Wake your bike up, get close to it and scan again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 13.5, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.name,
    required this.address,
    required this.rssi,
    required this.bars,
    required this.quality,
    required this.likely,
    required this.connecting,
    required this.enabled,
    required this.onConnect,
  });

  final String name;
  final String address;
  final int rssi;
  final int bars;
  final String quality;
  final bool likely; // the name looks like our tracker
  final bool connecting;
  final bool enabled;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: likely ? 0.95 : 0.8),
        borderRadius: BorderRadius.circular(26),
        border: likely
            ? Border.all(color: _accent, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: likely ? _ink : _sage.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              likely ? Icons.pedal_bike : Icons.bluetooth,
              color: likely ? _accent : _ink,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  address,
                  style: const TextStyle(
                      color: _muted, fontSize: 11.5, letterSpacing: 0.3),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    _SignalBars(bars: bars),
                    const SizedBox(width: 8),
                    Text(
                      '$quality · $rssi dBm',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          connecting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: _ink),
                )
              : GestureDetector(
                  onTap: enabled ? onConnect : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: enabled ? _ink : _ink.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Pair',
                      style: TextStyle(
                        color: _accent,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.bars});
  final int bars;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        return Container(
          width: 3.5,
          height: 5.0 + i * 3,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: i < bars ? _ink : _sage,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: _ink, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(color: _ink, fontSize: 13.5, height: 1.45),
                children: [
                  TextSpan(
                    text: 'Pairing tip. ',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(
                    text:
                        'Stay within 10 meters of your bike. If it is asleep, move it a little to wake it up, then scan again.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}