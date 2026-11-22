import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One live record sent by the firmware (16 bytes, little-endian):
///   0  uint32  timestamp (seconds since 1970, UTC)
///   4  int32   latitude  (degrees x 10^6)
///   8  int32   longitude (degrees x 10^6)
///  12  uint16  speed     (0.1 km/h)
///  14  uint16  crc       (not checked here)
///
/// If you already have a `GpsRecord` class in gps_record.dart, you can call it
/// from [tryParse] instead and keep the rest of this file as it is.
class RideRecord {
  const RideRecord({
    required this.time,
    required this.lat,
    required this.lng,
    required this.speedKmh,
  });

  final DateTime time; // UTC, from the GPS
  final double lat;
  final double lng;
  final double speedKmh;

  static RideRecord? tryParse(List<int> bytes) {
    if (bytes.length < 14) return null;
    final d = ByteData.sublistView(Uint8List.fromList(bytes));
    final ts = d.getUint32(0, Endian.little);
    final lat = d.getInt32(4, Endian.little) / 1e6;
    final lng = d.getInt32(8, Endian.little) / 1e6;
    final speed = d.getUint16(12, Endian.little) / 10.0;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return RideRecord(
      time: DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true),
      lat: lat,
      lng: lng,
      speedKmh: speed,
    );
  }
}

enum BikeLink { noBike, connecting, connected, disconnected }

enum BikeProblem {
  none,
  bluetoothOff,
  permissionDenied,
  permissionBlocked, // "never ask again": the user must open the app settings
  unsupported,
}

/// Owns the Bluetooth connection to the bike and the live data.
/// One instance for the whole app, so the connection survives tab changes.
class BikeConnection extends ChangeNotifier {
  BikeConnection._();
  static final BikeConnection instance = BikeConnection._();

  // The firmware characteristics start with these 32 bits:
  // d973f2e1-... live record, d973f2e2-... distance (meters, uint32).
  static const _liveUuid = 'd973f2e1';
  static const _distUuid = 'd973f2e2';
  static const _kId = 'bike_id';
  static const _kName = 'bike_name';

  /// No record for this long = "Searching for satellites".
  static const gpsTimeout = Duration(seconds: 5);

  /// A pause longer than this between two records starts a new trip.
  static const _tripGap = Duration(seconds: 60);

  BikeLink link = BikeLink.noBike;
  BikeProblem problem = BikeProblem.none;
  String? bikeId;
  String? bikeName;
  String? error;

  RideRecord? last;
  DateTime? lastArrival; // phone clock, when the last record arrived
  DateTime? _tripStart; // GPS time of the first record of the current trip
  int? distanceM;

  bool _inited = false;
  bool _busy = false;
  BluetoothDevice? _device;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;

  bool get hasBike => bikeId != null;

  bool get gpsOk =>
      link == BikeLink.connected &&
      lastArrival != null &&
      DateTime.now().difference(lastArrival!) < gpsTimeout;

  /// Ride time = last record - first record of the current trip.
  Duration? get rideTime {
    final s = _tripStart;
    final l = last;
    if (s == null || l == null) return null;
    final d = l.time.difference(s);
    return d.isNegative ? Duration.zero : d;
  }

  // ----------------------------------------------------------------- start

  /// Safe to call many times.
  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    final p = await SharedPreferences.getInstance();
    bikeId = p.getString(_kId);
    bikeName = p.getString(_kName);
    link = hasBike ? BikeLink.disconnected : BikeLink.noBike;
    notifyListeners();

    if (!await FlutterBluePlus.isSupported) {
      problem = BikeProblem.unsupported;
      notifyListeners();
      return;
    }
    // Emits the current state right away, then every change.
    _adapterSub = FlutterBluePlus.adapterState.listen(_onAdapter);
  }

  void _onAdapter(BluetoothAdapterState s) {
    switch (s) {
      case BluetoothAdapterState.unavailable:
        problem = BikeProblem.unsupported;
      case BluetoothAdapterState.unauthorized:
        if (problem != BikeProblem.permissionBlocked) {
          problem = BikeProblem.permissionDenied;
        }
      case BluetoothAdapterState.off:
      case BluetoothAdapterState.turningOff:
        problem = BikeProblem.bluetoothOff;
        if (link == BikeLink.connected || link == BikeLink.connecting) {
          link = BikeLink.disconnected;
        }
      case BluetoothAdapterState.on:
        if (problem == BikeProblem.bluetoothOff) problem = BikeProblem.none;
      default:
        break;
    }
    notifyListeners();

    if (s == BluetoothAdapterState.on &&
        hasBike &&
        link == BikeLink.disconnected) {
      connect();
    }
  }

  // ----------------------------------------------------------- permissions

  Future<bool> ensurePermissions() async {
    final perms = defaultTargetPlatform == TargetPlatform.iOS
        ? [Permission.bluetooth]
        : [Permission.bluetoothScan, Permission.bluetoothConnect];
    final res = await perms.request();
    final ok = res.values.every((s) => s.isGranted);
    if (ok) {
      if (problem == BikeProblem.permissionDenied ||
          problem == BikeProblem.permissionBlocked) {
        problem = BikeProblem.none;
      }
    } else {
      problem = res.values.any((s) => s.isPermanentlyDenied)
          ? BikeProblem.permissionBlocked
          : BikeProblem.permissionDenied;
    }
    notifyListeners();
    return ok;
  }

  /// What the banner button does for the current problem.
  Future<void> fixProblem() async {
    switch (problem) {
      case BikeProblem.bluetoothOff:
        try {
          await FlutterBluePlus.turnOn(); // Android only
        } catch (_) {}
      case BikeProblem.permissionDenied:
        if (await ensurePermissions() && hasBike) await connect();
      case BikeProblem.permissionBlocked:
        await openAppSettings();
      case BikeProblem.unsupported:
      case BikeProblem.none:
        break;
    }
  }

  // ------------------------------------------------------------ connecting

  /// Connect to the saved bike (also used by the "Reconnect" button).
  Future<void> connect() async {
    if (!hasBike || _busy) return;
    _busy = true;
    error = null;
    try {
      if (!await ensurePermissions()) {
        link = BikeLink.disconnected;
        return;
      }
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        problem = BikeProblem.bluetoothOff;
        link = BikeLink.disconnected;
        return;
      }
      link = BikeLink.connecting;
      notifyListeners();
      await _attach(BluetoothDevice.fromId(bikeId!));
    } catch (e) {
      link = BikeLink.disconnected;
      error = 'Could not reach the bike. Is it nearby and awake?';
      try {
        await _device?.disconnect();
      } catch (_) {}
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _attach(BluetoothDevice device) async {
    await _connSub?.cancel();
    _device = device;
    _connSub = device.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected &&
          link == BikeLink.connected) {
        link = BikeLink.disconnected;
        notifyListeners();
      }
    });

    await device.connect(
  license: License.nonprofit,
  timeout: const Duration(seconds: 15),
);
    final services = await device.discoverServices();

    BluetoothCharacteristic? live;
    BluetoothCharacteristic? dist;
    for (final s in services) {
      for (final c in s.characteristics) {
        final id = c.uuid.str128.toLowerCase();
        if (id.startsWith(_liveUuid)) live = c;
        if (id.startsWith(_distUuid)) dist = c;
      }
    }
    if (live == null) throw StateError('live characteristic not found');

    // Listen first, then enable the notifications.
    final liveSub = live.onValueReceived.listen(_onLive);
    device.cancelWhenDisconnected(liveSub);
    await live.setNotifyValue(true);

    if (dist != null) {
      final distSub = dist.onValueReceived.listen(_onDistance);
      device.cancelWhenDisconnected(distSub);
      await dist.setNotifyValue(true);
    }

    _tripStart = null; // a new connection = a new trip
    link = BikeLink.connected;
  }

  void _onLive(List<int> bytes) {
    final r = RideRecord.tryParse(bytes);
    if (r == null) return;
    final prev = last;
    if (_tripStart == null ||
        prev == null ||
        r.time.difference(prev.time).abs() > _tripGap) {
      _tripStart = r.time;
    }
    last = r;
    lastArrival = DateTime.now();
    notifyListeners();
  }

  void _onDistance(List<int> bytes) {
    if (bytes.isEmpty) return;
    var m = 0;
    for (var i = 0; i < bytes.length && i < 4; i++) {
      m |= bytes[i] << (8 * i); // little-endian uint32
    }
    distanceM = m;
    notifyListeners();
  }

  // --------------------------------------------------------------- pairing

  /// For the pair screen: scan for nearby trackers, then read
  /// `FlutterBluePlus.scanResults`.
    Future<bool> startScan() async {
    try {
      debugPrint('BLE: Checking permissions...');

      if (!await ensurePermissions()) {
        debugPrint('BLE: Permissions denied');
        return false;
      }

      final state = FlutterBluePlus.adapterStateNow;

      debugPrint('BLE: Bluetooth state = $state');

      if (state != BluetoothAdapterState.on) {
        problem = BikeProblem.bluetoothOff;
        notifyListeners();
        return false;
      }

      debugPrint('BLE: Starting 30-second scan...');

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 30),
        androidScanMode: AndroidScanMode.lowLatency,
      );

      debugPrint('BLE: Scan started successfully');

      return true;
    } catch (e, stackTrace) {
      error = 'BLE scan error: $e';

      debugPrint('BLE SCAN ERROR: $e');
      debugPrint('$stackTrace');

      notifyListeners();
      return false;
    }
  }

  /// For the pair screen: remember this bike and connect to it.
  Future<void> pair(BluetoothDevice device, {String? name}) async {
    await FlutterBluePlus.stopScan();
    try {
      await _device?.disconnect();
    } catch (_) {}
    final p = await SharedPreferences.getInstance();
    bikeId = device.remoteId.str;
    bikeName = (name != null && name.isNotEmpty)
        ? name
        : (device.platformName.isNotEmpty ? device.platformName : 'My bike');
    await p.setString(_kId, bikeId!);
    await p.setString(_kName, bikeName!);
    _resetData();
    link = BikeLink.disconnected;
    notifyListeners();
    await connect();
  }

  /// Settings > Forget bike.
  Future<void> forget() async {
    try {
      await _device?.disconnect();
    } catch (_) {}
    await _connSub?.cancel();
    final p = await SharedPreferences.getInstance();
    await p.remove(_kId);
    await p.remove(_kName);
    bikeId = null;
    bikeName = null;
    _device = null;
    _resetData();
    link = BikeLink.noBike;
    error = null;
    notifyListeners();
  }

  void _resetData() {
    last = null;
    lastArrival = null;
    _tripStart = null;
    distanceM = null;
  }

  @override
  void dispose() {
    _adapterSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }
}