import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/local/ride_db.dart';
import '../widgets/trip_format.dart';

// Same soft palette as the other screens
const Color _bgTop = Color(0xFFF4F8EE);
const Color _bgBottom = Color(0xFFDDE9D1);
const Color _ink = Color(0xFF1E2B1C);
const Color _muted = Color(0xFF6F7D6A);
const Color _sage = Color(0xFFBFD4AC);
const Color _accent = Color(0xFFB6E35C);
const Color _danger = Color(0xFFD64545);

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.trip});
  final Trip trip;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  List<TripPoint>? _points;
  bool _mph = false;

  @override
  void initState() {
    super.initState();
    RideDb.instance.points(widget.trip.id).then((p) {
      if (mounted) setState(() => _points = p);
    });
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _mph = p.getInt('pref_units') == 1);
    });
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete this trip?',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w800)),
        content: const Text('This cannot be undone.',
            style: TextStyle(color: _muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: _muted),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: _danger, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await RideDb.instance.deleteTrip(widget.trip.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final pts = _points;

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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              // Header
              Row(
                children: [
                  _RoundButton(
                    icon: Icons.arrow_back,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Trip',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${TripFmt.fullDate(t.start)} · ${TripFmt.timeRange(t)}',
                          style: const TextStyle(color: _muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  _RoundButton(
                    icon: Icons.delete_outline,
                    color: _danger,
                    onTap: _delete,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Map
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: SizedBox(
                  height: 280,
                  child: pts == null
                      ? Container(
                          color: Colors.white.withValues(alpha: 0.6),
                          child: const Center(
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: _ink),
                          ),
                        )
                      : _RouteMap(points: pts),
                ),
              ),
              const SizedBox(height: 14),

              // Stats
              Row(
                children: [
                  Expanded(
                    child: _Tile(
                      icon: Icons.route,
                      label: 'Distance',
                      value: TripFmt.distance(t.distanceM, _mph),
                      unit: TripFmt.distanceUnit(_mph),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _Tile(
                      icon: Icons.timer_outlined,
                      label: 'Duration',
                      value: TripFmt.duration(t.duration),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _Tile(
                      icon: Icons.speed,
                      label: 'Average speed',
                      value: TripFmt.speed(t.avgKmh, _mph),
                      unit: TripFmt.speedUnit(_mph),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _Tile(
                      icon: Icons.bolt,
                      label: 'Max speed',
                      value: TripFmt.speed(t.maxKmh, _mph),
                      unit: TripFmt.speedUnit(_mph),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Chart
              if (pts != null && pts.length >= 2)
                _ChartCard(points: pts, mph: _mph),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Map
// ===========================================================================

class _RouteMap extends StatelessWidget {
  const _RouteMap({required this.points});
  final List<TripPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Container(
        color: Colors.white.withValues(alpha: 0.6),
        child: const Center(
          child: Text('No points', style: TextStyle(color: _muted)),
        ),
      );
    }

    final latlngs = points.map((p) => LatLng(p.lat, p.lng)).toList();
    final minLat = latlngs.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    final maxLat = latlngs.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    final minLng =
        latlngs.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    final maxLng =
        latlngs.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);
    final spread = (maxLat - minLat) + (maxLng - minLng);

    return FlutterMap(
      options: MapOptions(
        initialCenter: latlngs.first,
        initialZoom: 16,
        // Fit the whole route (a single spot cannot be fitted).
        initialCameraFit: spread > 0.0001
            ? CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(latlngs),
                padding: const EdgeInsets.all(40),
              )
            : null,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.bike_tracker',
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: latlngs,
              strokeWidth: 4,
              color: _ink,
              borderStrokeWidth: 3,
              borderColor: _accent,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: latlngs.first,
              width: 26,
              height: 26,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: _ink, width: 3),
                ),
              ),
            ),
            Marker(
              point: latlngs.last,
              width: 36,
              height: 36,
              child: Container(
                decoration: BoxDecoration(
                  color: _ink,
                  shape: BoxShape.circle,
                  border: Border.all(color: _accent, width: 2.5),
                ),
                child: const Icon(Icons.flag, color: _accent, size: 18),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ===========================================================================
// Speed chart
// ===========================================================================

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.points, required this.mph});
  final List<TripPoint> points;
  final bool mph;

  @override
  Widget build(BuildContext context) {
    // At most ~160 values: enough for the eye, light to draw.
    final n = points.length;
    final step = (n / 160).ceil().clamp(1, n);
    final values = <double>[
      for (var i = 0; i < n; i += step)
        mph ? points[i].speedKmh * 0.621371 : points[i].speedKmh,
    ];
    final last = mph ? points.last.speedKmh * 0.621371 : points.last.speedKmh;
    if ((n - 1) % step != 0) values.add(last);

    final maxV = values.reduce((a, b) => a > b ? a : b);
    final top = (maxV <= 0 ? 10 : maxV * 1.15);

    final start = DateTime.fromMillisecondsSinceEpoch(points.first.ts * 1000);
    final end = DateTime.fromMillisecondsSinceEpoch(points.last.ts * 1000);

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
              const Text(
                'Speed over time',
                style: TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                'max ${maxV.toStringAsFixed(1)} ${TripFmt.speedUnit(mph)}',
                style: const TextStyle(color: _muted, fontSize: 12.5),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 130,
            width: double.infinity,
            child: CustomPaint(painter: _ChartPainter(values, top.toDouble())),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(TripFmt.clock(start),
                  style: const TextStyle(color: _muted, fontSize: 12)),
              Text(TripFmt.clock(end),
                  style: const TextStyle(color: _muted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter(this.values, this.maxV);
  final List<double> values;
  final double maxV;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final w = size.width;
    final h = size.height;

    // Grid
    final grid = Paint()
      ..color = _sage.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = h * i / 2;
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
    }

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = w * i / (values.length - 1);
      final y = h * (1 - (values[i] / maxV).clamp(0.0, 1.0));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fill = Path.from(path)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_accent.withValues(alpha: 0.7), _accent.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.values != values || old.maxV != maxV;
}

// ===========================================================================
// Pieces
// ===========================================================================

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap, this.color});
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color ?? _ink, size: 20),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
                    fontSize: 26,
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