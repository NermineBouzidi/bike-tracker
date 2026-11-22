import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/ble/bike_connection.dart';
import '../../data/local/ride_db.dart';
import '../widgets/trip_format.dart';
import 'trip_detail_screen.dart';

// Same soft palette as the other screens
const Color _bgTop = Color(0xFFF4F8EE);
const Color _bgBottom = Color(0xFFDDE9D1);
const Color _ink = Color(0xFF1E2B1C);
const Color _muted = Color(0xFF6F7D6A);
const Color _sage = Color(0xFFBFD4AC);
const Color _accent = Color(0xFFB6E35C);

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen>
    with SingleTickerProviderStateMixin {
  final _db = RideDb.instance;

  late final AnimationController _intro;
  SharedPreferences? _prefs;
  List<Trip>? _trips;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _prefs = p);
    });
    _db.revision.addListener(_load); // new points / deleted trips
    _load();
  }

  @override
  void dispose() {
    _db.revision.removeListener(_load);
    _intro.dispose();
    super.dispose();
  }

  Animation<double> _step(double begin, double end) => CurvedAnimation(
        parent: _intro,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      );

  Future<void> _load() async {
    final t = await _db.trips(from: _from, to: _to);
    if (mounted) setState(() => _trips = t);
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickDate({required bool from}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to) ?? now,
      firstDate: DateTime(2024),
      lastDate: now.add(const Duration(days: 1)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _ink,
            onPrimary: _accent,
            surface: Colors.white,
            onSurface: _ink,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
      } else {
        _to = picked;
      }
      // Keep the range in the right order.
      if (_from != null && _to != null && _from!.isAfter(_to!)) {
        final t = _from;
        _from = _to;
        _to = t;
      }
    });
    _load();
  }

  void _clearDates() {
    setState(() {
      _from = null;
      _to = null;
    });
    _load();
  }

  // The firmware part (history on the SD card) is not delivered yet.
  void _downloadFromBike() {
    if (BikeConnection.instance.link != BikeLink.connected) {
      _toast('Connect your bike first.');
    } else {
      _toast('History download is not available in the firmware yet.');
    }
  }

  Future<void> _open(Trip t) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TripDetailScreen(trip: t)),
    );
    _load(); // the trip may have been deleted
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final mph = _prefs?.getInt('pref_units') == 1;
    final trips = _trips;
    final totalM = trips?.fold<double>(0, (s, t) => s + t.distanceM) ?? 0;

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
          child: RefreshIndicator(
            color: _ink,
            backgroundColor: Colors.white,
            onRefresh: _load, // later: also sync with the server
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                _Reveal(
                  animation: _step(0.0, 0.4),
                  dy: -0.15,
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(4, 0, 4, 18),
                    child: Text(
                      'Trips',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                // Summary
                _Reveal(
                  animation: _step(0.1, 0.6),
                  child: Row(
                    children: [
                      Expanded(
                        child: _SummaryTile(
                          icon: Icons.route,
                          label: 'Trips',
                          value: '${trips?.length ?? 0}',
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _SummaryTile(
                          icon: Icons.straighten,
                          label: 'Total distance',
                          value: TripFmt.distance(totalM, mph),
                          unit: TripFmt.distanceUnit(mph),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Date filters + download
                _Reveal(
                  animation: _step(0.2, 0.7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _DatePill(
                              label: 'Start date',
                              value: _from == null
                                  ? 'Any'
                                  : TripFmt.shortDate(_from!),
                              onTap: () => _pickDate(from: true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _DatePill(
                              label: 'End date',
                              value: _to == null
                                  ? 'Any'
                                  : TripFmt.shortDate(_to!),
                              onTap: () => _pickDate(from: false),
                            ),
                          ),
                          if (_from != null || _to != null) ...[
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: _clearDates,
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    size: 20, color: _ink),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _downloadFromBike,
                        style: FilledButton.styleFrom(
                          backgroundColor: _ink,
                          foregroundColor: _accent,
                          minimumSize: const Size.fromHeight(54),
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w700),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.download_rounded, size: 20),
                            SizedBox(width: 8),
                            Text('Download from bike'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // List
                if (trips == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: _ink),
                    ),
                  )
                else if (trips.isEmpty)
                  _EmptyState(filtered: _from != null || _to != null)
                else
                  for (final t in trips) ...[
                    _TripCard(trip: t, mph: mph, onTap: () => _open(t)),
                    const SizedBox(height: 14),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
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

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
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
        color: _ink,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: _accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                    color: _accent,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 5),
                  Text(
                    unit!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
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

class _DatePill extends StatelessWidget {
  const _DatePill({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final set = value != 'Any';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(22),
          border: set ? Border.all(color: _ink, width: 1.4) : null,
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 16, color: _muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                set ? value : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: set ? _ink : _muted,
                  fontSize: 13.5,
                  fontWeight: set ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.mph,
    required this.onTap,
  });

  final Trip trip;
  final bool mph;
  final VoidCallback onTap;

  Widget _stat(String label, String value, String unit) => Expanded(
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: _muted,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (unit.isNotEmpty) ...[
                    const SizedBox(width: 3),
                    Text(
                      unit,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11.5,
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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          TripFmt.dayLabel(trip.start),
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          TripFmt.timeRange(trip),
                          style: const TextStyle(color: _muted, fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _sage.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.north_east, size: 18, color: _ink),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                decoration: BoxDecoration(
                  color: _sage.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    _stat('Distance', TripFmt.distance(trip.distanceM, mph),
                        TripFmt.distanceUnit(mph)),
                    _stat('Time', TripFmt.duration(trip.duration), ''),
                    _stat('Avg', TripFmt.speed(trip.avgKmh, mph),
                        TripFmt.speedUnit(mph)),
                    _stat('Max', TripFmt.speed(trip.maxKmh, mph),
                        TripFmt.speedUnit(mph)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered});
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: _ink,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.route, color: _accent, size: 26),
          ),
          const SizedBox(height: 16),
          Text(
            filtered ? 'No trips in these dates' : 'No trips yet',
            style: const TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            filtered
                ? 'Try another start or end date.'
                : 'Your rides appear here after you ride with your bike connected.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 13.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}