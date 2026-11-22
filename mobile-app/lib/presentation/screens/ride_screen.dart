import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/ble/bike_connection.dart';
import 'pair_device_screen.dart';

// Same soft palette as the other screens
const Color _bgTop = Color(0xFFF4F8EE);
const Color _bgBottom = Color(0xFFDDE9D1);
const Color _ink = Color(0xFF1E2B1C);
const Color _muted = Color(0xFF6F7D6A);
const Color _sage = Color(0xFFBFD4AC);
const Color _accent = Color(0xFFB6E35C);
const Color _ok = Color(0xFF3FA34D);
const Color _warn = Color(0xFFE0A31A);
const Color _danger = Color(0xFFD64545);

class RideScreen extends StatefulWidget {
  const RideScreen({super.key});

  @override
  State<RideScreen> createState() => _RideScreenState();
}

class _RideScreenState extends State<RideScreen>
    with TickerProviderStateMixin {
  final _conn = BikeConnection.instance;

  late final AnimationController _intro;
  late final AnimationController _pulse;
  Timer? _tick;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..forward();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // Refresh once a second: "GPS OK" -> "Searching..." after 5 s, "x s ago",
    // and the units chosen in Settings.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _prefs = p);
    });

    _conn.init(); // loads the saved bike and connects (safe to call again)
  }

  @override
  void dispose() {
    _tick?.cancel();
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Animation<double> _step(double begin, double end) => CurvedAnimation(
        parent: _intro,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      );

  Future<void> _openPair() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PairDeviceScreen()),
      );

  // ------------------------------------------------------------- formatting

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _duration(Duration? d) {
    if (d == null) return '--:--:--';
    return '${_two(d.inHours)}:${_two(d.inMinutes % 60)}:${_two(d.inSeconds % 60)}';
  }

  static String _clock(DateTime t) =>
      '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';

  static String _ago(DateTime t) {
    final s = DateTime.now().difference(t).inSeconds;
    if (s < 1) return 'just now';
    if (s < 60) return '${s}s ago';
    return '${s ~/ 60} min ago';
  }

  static String _lat(double v) =>
      '${v.abs().toStringAsFixed(5)}° ${v >= 0 ? 'N' : 'S'}';
  static String _lng(double v) =>
      '${v.abs().toStringAsFixed(5)}° ${v >= 0 ? 'E' : 'W'}';

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
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
            builder: (context, _) => _content(),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    final c = _conn;
    final r = c.last;
    final mph = _prefs?.getInt('pref_units') == 1; // 0 = km/h, 1 = mph
    final live = c.link == BikeLink.connected && c.gpsOk;

    final speed =
        r == null ? null : (mph ? r.speedKmh * 0.621371 : r.speedKmh);
    final distKm = c.distanceM == null ? null : c.distanceM! / 1000.0;
    final dist = distKm == null
        ? '--'
        : (mph ? distKm * 0.621371 : distKm).toStringAsFixed(2);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        // Header
        _Reveal(
          animation: _step(0.0, 0.4),
          dy: -0.15,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ride',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (c.bikeName != null)
                        Text(
                          c.bikeName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 13),
                        ),
                    ],
                  ),
                ),
                _StatusChip(link: c.link, pulse: _pulse),
              ],
            ),
          ),
        ),

        // Problems and empty states
        if (_banner(c) case final banner?) ...[
          _Reveal(animation: _step(0.05, 0.5), child: banner),
          const SizedBox(height: 14),
        ],

        // Speed
        _Reveal(
          animation: _step(0.1, 0.6),
          child: _SpeedCard(
            speed: speed,
            unit: mph ? 'mph' : 'km/h',
            connected: c.link == BikeLink.connected,
            live: live,
            hasData: r != null,
            pulse: _pulse,
          ),
        ),
        const SizedBox(height: 14),

        // Distance + ride time
        _Reveal(
          animation: _step(0.2, 0.7),
          child: Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.route,
                  label: 'Distance',
                  value: dist,
                  unit: mph ? 'mi' : 'km',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _StatTile(
                  icon: Icons.timer_outlined,
                  label: 'Ride time',
                  value: _duration(c.rideTime),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Position
        _Reveal(
          animation: _step(0.3, 0.8),
          child: _PositionCard(
            lat: r == null ? null : _lat(r.lat),
            lng: r == null ? null : _lng(r.lng),
            updated: c.lastArrival == null
                ? null
                : '${_clock(c.lastArrival!)}  ·  ${_ago(c.lastArrival!)}',
          ),
        ),

        // Reconnect
        if (c.link == BikeLink.disconnected &&
            c.hasBike &&
            c.problem == BikeProblem.none) ...[
          const SizedBox(height: 20),
          _Reveal(
            animation: _step(0.4, 0.9),
            child: _BigButton(
              icon: Icons.bluetooth_searching,
              label: 'Reconnect',
              onTap: c.connect,
            ),
          ),
        ],
        if (c.error != null && c.link != BikeLink.connected) ...[
          const SizedBox(height: 12),
          Center(
            child: Text(
              c.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _danger, fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }

  /// The card shown instead of data when something blocks the connection.
  Widget? _banner(BikeConnection c) {
    switch (c.problem) {
      case BikeProblem.bluetoothOff:
        return _Banner(
          icon: Icons.bluetooth_disabled,
          title: 'Bluetooth is off',
          text: 'Turn it on to receive your bike\'s live data.',
          action: 'Turn on',
          onAction: c.fixProblem,
        );
      case BikeProblem.permissionDenied:
        return _Banner(
          icon: Icons.bluetooth_connected,
          title: 'Bluetooth permission needed',
          text: 'Allow nearby devices so the app can find your bike.',
          action: 'Allow',
          onAction: c.fixProblem,
        );
      case BikeProblem.permissionBlocked:
        return _Banner(
          icon: Icons.lock_outline,
          title: 'Permission blocked',
          text: 'Open the app settings and allow "Nearby devices".',
          action: 'Open settings',
          onAction: c.fixProblem,
        );
      case BikeProblem.unsupported:
        return const _Banner(
          icon: Icons.bluetooth_disabled,
          title: 'Bluetooth not available',
          text: 'This phone does not support Bluetooth Low Energy.',
        );
      case BikeProblem.none:
        break;
    }
    if (c.link == BikeLink.noBike) {
      return _Banner(
        icon: Icons.pedal_bike,
        title: 'No bike paired',
        text: 'Pair your tracker to see your ride live.',
        action: 'Pair bike',
        onAction: _openPair,
      );
    }
    return null;
  }
}

// ===========================================================================
// Pieces
// ===========================================================================

class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.animation,
    required this.child,
    this.dy = 0.08,
  });

  final Animation<double> animation;
  final Widget child;
  final double dy;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: Offset(0, dy), end: Offset.zero)
            .animate(animation),
        child: child,
      ),
    );
  }
}

/// Searching / Connected / Disconnected / No bike.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.link, required this.pulse});
  final BikeLink link;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (link) {
      BikeLink.connected => ('Connected', _ok),
      BikeLink.connecting => ('Searching', _warn),
      BikeLink.disconnected => ('Disconnected', _danger),
      BikeLink.noBike => ('No bike', _muted),
    };
    final blink = link == BikeLink.connecting;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (_, __) => Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color.withValues(
                    alpha: blink ? 0.35 + 0.65 * pulse.value : 1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Big dark card with the speed and the GPS state.
class _SpeedCard extends StatelessWidget {
  const _SpeedCard({
    required this.speed,
    required this.unit,
    required this.connected,
    required this.live,
    required this.hasData,
    required this.pulse,
  });

  final double? speed;
  final String unit;
  final bool connected;
  final bool live; // connected and a record arrived in the last 5 s
  final bool hasData;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final gpsColor = live ? _ok : _warn;

    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: Container(
        color: _ink,
        child: Stack(
          children: [
            Positioned(
              right: -50,
              top: -50,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'SPEED',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const Spacer(),
                      if (connected)
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedBuilder(
                                  animation: pulse,
                                  builder: (_, __) => Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: gpsColor.withValues(
                                          alpha:
                                              live ? 1 : 0.35 + 0.65 * pulse.value),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    live
                                        ? 'GPS OK'
                                        : 'Searching for satellites',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: speed ?? 0),
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeOut,
                          builder: (_, v, __) => FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              speed == null ? '--' : v.toStringAsFixed(1),
                              style: TextStyle(
                                color: _accent.withValues(
                                    alpha: live ? 1 : 0.45),
                                fontSize: 88,
                                height: 1,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -3,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        unit,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (hasData && !live) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Last known speed',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _sage.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: _ink),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 5),
                  Text(
                    unit!,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({
    required this.lat,
    required this.lng,
    required this.updated,
  });

  final String? lat;
  final String? lng;
  final String? updated;

  Widget _coord(String label, String? value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: _muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value ?? '--',
              style: const TextStyle(
                color: _ink,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _sage.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.place_outlined, size: 18, color: _ink),
              ),
              const SizedBox(width: 14),
              _coord('Latitude', lat),
              _coord('Longitude', lng),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(
                height: 1, color: _sage.withValues(alpha: 0.5)),
          ),
          Row(
            children: [
              const Icon(Icons.update, size: 16, color: _muted),
              const SizedBox(width: 8),
              const Text(
                'Last update',
                style: TextStyle(color: _muted, fontSize: 13.5),
              ),
              const Spacer(),
              Text(
                updated ?? '--',
                style: const TextStyle(
                  color: _ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.title,
    required this.text,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
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
                  color: _ink,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      text,
                      style: const TextStyle(
                          color: _muted, fontSize: 13.5, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            _BigButton(label: action!, onTap: onAction),
          ],
        ],
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({required this.label, required this.onTap, this.icon});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: _ink,
        foregroundColor: _accent,
        minimumSize: const Size.fromHeight(54),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 19), const SizedBox(width: 8)],
          Text(label),
        ],
      ),
    );
  }
}