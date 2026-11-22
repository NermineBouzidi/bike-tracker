import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// One trip = points grouped together until a gap of more than 5 minutes.
class Trip {
  const Trip({
    required this.id,
    required this.startTs,
    required this.endTs,
    required this.distanceM,
    required this.maxKmh,
    required this.count,
  });

  final int id;
  final int startTs; // seconds since 1970 (UTC)
  final int endTs;
  final double distanceM;
  final double maxKmh;
  final int count; // number of points

  DateTime get start => DateTime.fromMillisecondsSinceEpoch(startTs * 1000);
  DateTime get end => DateTime.fromMillisecondsSinceEpoch(endTs * 1000);
  Duration get duration => Duration(seconds: endTs - startTs);

  /// Average speed over the whole trip: distance / duration.
  double get avgKmh {
    final s = duration.inSeconds;
    return s <= 0 ? 0 : (distanceM / s) * 3.6;
  }

  static Trip fromRow(Map<String, Object?> r) => Trip(
        id: r['id'] as int,
        startTs: r['start_ts'] as int,
        endTs: r['end_ts'] as int,
        distanceM: (r['distance_m'] as num).toDouble(),
        maxKmh: (r['max_dkmh'] as int) / 10.0,
        count: r['count'] as int,
      );
}

class TripPoint {
  const TripPoint(this.ts, this.lat, this.lng, this.speedKmh);
  final int ts;
  final double lat;
  final double lng;
  final double speedKmh;
}

/// Local database: every live record is saved here, the screens read from it
/// (so Trips works with no signal).
class RideDb {
  RideDb._();
  static final RideDb instance = RideDb._();

  /// A pause longer than this starts a new trip.
  static const tripGapSeconds = 300;

  /// Below 1 km/h the GPS is only drifting: no distance is added.
  static const _minMoveDkmh = 10;

  /// Goes up when a trip is created/deleted and every ~10 points,
  /// so screens know when to reload.
  final ValueNotifier<int> revision = ValueNotifier(0);

  Future<Database>? _opening;
  int _sinceBump = 0;

  Future<Database> _open() => _opening ??= _create();

  Future<Database> _create() async {
    final path = '${await getDatabasesPath()}/bike_tracker.db';
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE trips(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            start_ts INTEGER NOT NULL,
            end_ts INTEGER NOT NULL,
            distance_m REAL NOT NULL,
            max_dkmh INTEGER NOT NULL,
            count INTEGER NOT NULL,
            last_lat INTEGER NOT NULL,
            last_lng INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE points(
            ts INTEGER PRIMARY KEY,
            trip_id INTEGER NOT NULL,
            lat_e6 INTEGER NOT NULL,
            lng_e6 INTEGER NOT NULL,
            speed_dkmh INTEGER NOT NULL
          )''');
        await db.execute('CREATE INDEX idx_points_trip ON points(trip_id, ts)');
      },
    );
  }

  // ----------------------------------------------------------------- write

  /// Saves one record. A record with a timestamp already stored is ignored,
  /// so the same point can safely arrive twice (e.g. live, then history).
  Future<void> addPoint({
    required int ts,
    required double lat,
    required double lng,
    required double speedKmh,
  }) async {
    if (ts < 1600000000) return; // the board clock was not set yet
    final db = await _open();
    final latE6 = (lat * 1e6).round();
    final lngE6 = (lng * 1e6).round();
    final dk = (speedKmh * 10).round();
    var newTrip = false;

    await db.transaction((txn) async {
      final dup = await txn.query('points',
          columns: ['ts'], where: 'ts = ?', whereArgs: [ts], limit: 1);
      if (dup.isNotEmpty) return;

      // The trip this point belongs to: it starts or ends within 5 minutes.
      final rows = await txn.query(
        'trips',
        where: 'start_ts - ? <= ? AND end_ts + ? >= ?',
        whereArgs: [tripGapSeconds, ts, tripGapSeconds, ts],
        orderBy: 'end_ts DESC',
        limit: 1,
      );

      if (rows.isEmpty) {
        final id = await txn.insert('trips', {
          'start_ts': ts,
          'end_ts': ts,
          'distance_m': 0.0,
          'max_dkmh': dk,
          'count': 1,
          'last_lat': latE6,
          'last_lng': lngE6,
        });
        await txn.insert('points', {
          'ts': ts,
          'trip_id': id,
          'lat_e6': latE6,
          'lng_e6': lngE6,
          'speed_dkmh': dk,
        });
        newTrip = true;
        return;
      }

      final t = rows.first;
      final id = t['id'] as int;
      await txn.insert('points', {
        'ts': ts,
        'trip_id': id,
        'lat_e6': latE6,
        'lng_e6': lngE6,
        'speed_dkmh': dk,
      });

      if (ts > (t['end_ts'] as int)) {
        // Normal live case: append to the end of the trip.
        final step = _step(t['last_lat'] as int, t['last_lng'] as int, latE6,
            lngE6, dk);
        await txn.update(
          'trips',
          {
            'end_ts': ts,
            'distance_m': (t['distance_m'] as num).toDouble() + step,
            'max_dkmh': math.max(t['max_dkmh'] as int, dk),
            'count': (t['count'] as int) + 1,
            'last_lat': latE6,
            'last_lng': lngE6,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        // Older point (history download): recompute the whole trip.
        await _recompute(txn, id);
      }
    });

    _sinceBump++;
    if (newTrip || _sinceBump >= 10) {
      _sinceBump = 0;
      revision.value++;
    }
  }

  Future<void> _recompute(DatabaseExecutor txn, int tripId) async {
    final rows = await txn.query('points',
        where: 'trip_id = ?', whereArgs: [tripId], orderBy: 'ts');
    if (rows.isEmpty) {
      await txn.delete('trips', where: 'id = ?', whereArgs: [tripId]);
      return;
    }
    var dist = 0.0;
    var maxD = 0;
    int? pLat;
    int? pLng;
    for (final r in rows) {
      final la = r['lat_e6'] as int;
      final lo = r['lng_e6'] as int;
      final sp = r['speed_dkmh'] as int;
      if (pLat != null) dist += _step(pLat, pLng!, la, lo, sp);
      if (sp > maxD) maxD = sp;
      pLat = la;
      pLng = lo;
    }
    await txn.update(
      'trips',
      {
        'start_ts': rows.first['ts'],
        'end_ts': rows.last['ts'],
        'distance_m': dist,
        'max_dkmh': maxD,
        'count': rows.length,
        'last_lat': pLat,
        'last_lng': pLng,
      },
      where: 'id = ?',
      whereArgs: [tripId],
    );
  }

  /// Distance in meters between two points, or 0 when the bike is not
  /// moving (GPS drift) or the jump is not realistic (> 1 km in one step).
  static double _step(int lat1, int lng1, int lat2, int lng2, int dkmh) {
    if (dkmh < _minMoveDkmh) return 0;
    final d = _haversine(lat1 / 1e6, lng1 / 1e6, lat2 / 1e6, lng2 / 1e6);
    return d > 1000 ? 0 : d;
  }

  static double _haversine(double la1, double lo1, double la2, double lo2) {
    const r = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLa = rad(la2 - la1);
    final dLo = rad(lo2 - lo1);
    final a = math.pow(math.sin(dLa / 2), 2) +
        math.cos(rad(la1)) * math.cos(rad(la2)) * math.pow(math.sin(dLo / 2), 2);
    return 2 * r * math.asin(math.sqrt(a.toDouble()));
  }

  Future<void> deleteTrip(int id) async {
    final db = await _open();
    await db.transaction((txn) async {
      await txn.delete('points', where: 'trip_id = ?', whereArgs: [id]);
      await txn.delete('trips', where: 'id = ?', whereArgs: [id]);
    });
    revision.value++;
  }

  // ------------------------------------------------------------------ read

  /// Newest first. [from] and [to] are whole days (both included).
  Future<List<Trip>> trips({DateTime? from, DateTime? to}) async {
    final db = await _open();
    final where = <String>[];
    final args = <Object>[];
    if (from != null) {
      final s = DateTime(from.year, from.month, from.day);
      where.add('end_ts >= ?');
      args.add(s.millisecondsSinceEpoch ~/ 1000);
    }
    if (to != null) {
      final e = DateTime(to.year, to.month, to.day + 1);
      where.add('start_ts < ?');
      args.add(e.millisecondsSinceEpoch ~/ 1000);
    }
    final rows = await db.query(
      'trips',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'start_ts DESC',
    );
    return rows.map(Trip.fromRow).toList();
  }

  Future<List<TripPoint>> points(int tripId) async {
    final db = await _open();
    final rows = await db.query('points',
        where: 'trip_id = ?', whereArgs: [tripId], orderBy: 'ts');
    return rows
        .map((r) => TripPoint(
              r['ts'] as int,
              (r['lat_e6'] as int) / 1e6,
              (r['lng_e6'] as int) / 1e6,
              (r['speed_dkmh'] as int) / 10.0,
            ))
        .toList();
  }
}