import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../widgets/bike_ui.dart';

const Color _lime = Color(0xFFB4FF39);

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  StreamSubscription<Position>? _positionSubscription;

  // Tunis is only the initial map center.
  // It is NOT displayed as the phone's real GPS position.
  static const LatLng _initialCenter = LatLng(36.8065, 10.1815);

  LatLng? _currentPosition;

  double _speed = 0;
  double? _accuracy;

  bool _follow = true;
  bool _mapReady = false;
  bool _locationLoading = true;
  String _locationStatus = 'Getting phone location...';

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // PHONE GPS
  // ------------------------------------------------------------

  Future<void> _startLocationTracking() async {
    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _setLocationError('Location services are disabled');
        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _setLocationError('Location permission denied');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _setLocationError(
          'Location permission permanently denied. Enable it in Settings.',
        );
        return;
      }

      // Get the current position first.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _updatePosition(position);

      // Continue receiving GPS updates.
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );

      _positionSubscription =
          Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _updatePosition,
        onError: (error) {
          _setLocationError('GPS error: $error');
        },
      );
    } catch (e) {
      _setLocationError('Unable to get location');
      debugPrint('LOCATION ERROR: $e');
    }
  }

  void _updatePosition(Position position) {
    if (!mounted) return;

    final newPosition = LatLng(
      position.latitude,
      position.longitude,
    );

    setState(() {
      _currentPosition = newPosition;
      _speed = position.speed >= 0
          ? position.speed * 3.6
          : 0;
      _accuracy = position.accuracy;
      _locationLoading = false;
      _locationStatus = 'Phone GPS active';
    });

    // Move the map when follow mode is enabled.
    if (_follow && _mapReady) {
      _mapController.move(newPosition, 16);
    }
  }

  void _setLocationError(String message) {
    if (!mounted) return;

    setState(() {
      _locationLoading = false;
      _locationStatus = message;
    });

    debugPrint('LOCATION ERROR: $message');
  }

  void _recenterMap() {
    if (_currentPosition == null || !_mapReady) {
      return;
    }

    setState(() {
      _follow = true;
    });

    _mapController.move(_currentPosition!, 16);
  }

  void _toggleFollow() {
    if (_follow) {
      setState(() {
        _follow = false;
      });
    } else {
      _recenterMap();
    }
  }

  String _formatLatitude(double latitude) {
    final direction = latitude >= 0 ? 'N' : 'S';
    return '${latitude.abs().toStringAsFixed(5)}° $direction';
  }

  String _formatLongitude(double longitude) {
    final direction = longitude >= 0 ? 'E' : 'W';
    return '${longitude.abs().toStringAsFixed(5)}° $direction';
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final mapCenter = _currentPosition ?? _initialCenter;

    return Stack(
      children: [
        // REAL OPENSTREETMAP MAP
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: mapCenter,
              initialZoom: 14,
              onMapReady: () {
                _mapReady = true;

                if (_follow && _currentPosition != null) {
                  _mapController.move(_currentPosition!, 16);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.bike_tracker',
              ),

              // Display a marker only after receiving a real GPS fix.
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentPosition!,
                      width: 64,
                      height: 64,
                      child: _buildLocationMarker(),
                    ),
                  ],
                ),

              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),

        // TOP HEADER
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/images/logo.jpg',
                      height: 36,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.pedal_bike,
                        color: _lime,
                        size: 32,
                      ),
                    ),
                    const Spacer(),
                    const BTChip(
                      '',
                      icon: Icons.bluetooth,
                      dot: true,
                    ),
                    const SizedBox(width: 8),
                    const BTChip(
                      '94%',
                      icon: Icons.battery_5_bar,
                    ),
                    const SizedBox(width: 8),
                    const CircleAvatar(
                      radius: 16,
                      backgroundColor: _lime,
                      child: Icon(
                        Icons.person,
                        size: 18,
                        color: BT.onGreen,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: BT.bg.withAlpha(230),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: BT.border),
                            ),
                            child: BTMono(
                              _locationLoading
                                  ? 'WAITING FOR GPS'
                                  : _currentPosition != null
                                      ? 'PHONE GPS ACTIVE'
                                      : 'GPS UNAVAILABLE',
                              color: _currentPosition != null
                                  ? _lime
                                  : BT.muted,
                              size: 10.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          BTMono(
                            _locationStatus.toUpperCase(),
                            color: BT.text,
                            size: 9,
                          ),
                        ],
                      ),
                    ),

                    Column(
                      children: [
                        _mapBtn(
                          Icons.my_location,
                          active: _follow,
                          onTap: _toggleFollow,
                        ),
                        const SizedBox(height: 10),
                        _mapBtn(
                          Icons.add,
                          onTap: () {
                            if (_mapReady) {
                              _mapController.move(
                                mapCenter,
                                (_mapController.camera.zoom + 1)
                                    .clamp(2.0, 18.0),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        _mapBtn(
                          Icons.remove,
                          onTap: () {
                            if (_mapReady) {
                              _mapController.move(
                                mapCenter,
                                (_mapController.camera.zoom - 1)
                                    .clamp(2.0, 18.0),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // BOTTOM INFORMATION PANEL
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(26),
              ),
              border: Border(
                top: BorderSide(color: BT.border),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: BT.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: _lime,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'BikeTrack Pro',
                          style: TextStyle(
                            color: BT.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const BTChip(
                        'PHONE GPS',
                        icon: Icons.gps_fixed,
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  BTMono(
                    _currentPosition == null
                        ? 'WAITING FOR LOCATION'
                        : 'LIVE PHONE LOCATION',
                    color: BT.muted,
                    size: 10,
                  ),

                  const SizedBox(height: 14),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // LOCATION TILE
                      Expanded(
                        child: _tile(
                          'LOCATION',
                          Icons.explore_outlined,
                          BT.muted,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentPosition == null
                                    ? '--'
                                    : _formatLatitude(
                                        _currentPosition!.latitude,
                                      ),
                                style: const TextStyle(
                                  color: BT.text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _currentPosition == null
                                    ? '--'
                                    : _formatLongitude(
                                        _currentPosition!.longitude,
                                      ),
                                style: const TextStyle(
                                  fontFamily: kMono,
                                  color: BT.text,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _currentPosition == null
                                    ? 'No GPS fix'
                                    : '±${_accuracy?.toStringAsFixed(0) ?? '--'} m accuracy',
                                style: const TextStyle(
                                  color: BT.muted,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // SPEED TILE
                      Expanded(
                        child: _tile(
                          'PHONE SPEED',
                          Icons.speed,
                          _lime,
                          highlight: true,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _speed.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: BT.text,
                                      fontSize: 25,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 4),
                                    child: BTMono(
                                      'km/h',
                                      size: 10,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'From phone GPS',
                                style: TextStyle(
                                  color: BT.muted,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // GPS STATUS TILE
                      Expanded(
                        child: _tile(
                          'GPS STATUS',
                          Icons.satellite_alt,
                          BT.blue,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentPosition != null
                                    ? 'Active'
                                    : 'Waiting',
                                style: const TextStyle(
                                  color: BT.text,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                _follow ? 'Following' : 'Paused',
                                style: const TextStyle(
                                  color: BT.blue,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _currentPosition != null
                                    ? 'GPS received'
                                    : 'No position yet',
                                style: const TextStyle(
                                  color: BT.muted,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // PHONE LOCATION MARKER
  // ------------------------------------------------------------

  Widget _buildLocationMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _lime.withAlpha(65),
          ),
        ),
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.blue,
              width: 3,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
              ),
            ],
          ),
          child: const Icon(
            Icons.person,
            color: Colors.blue,
            size: 16,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // REUSABLE UI WIDGETS
  // ------------------------------------------------------------

  Widget _mapBtn(
    IconData icon, {
    bool active = false,
    required VoidCallback onTap,
  }) {
    return Material(
      color: BT.bg.withAlpha(230),
      shape: CircleBorder(
        side: BorderSide(
          color: active ? _lime.withAlpha(120) : BT.border,
        ),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: active ? _lime : BT.text,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _tile(
    String label,
    IconData icon,
    Color iconColor, {
    required Widget child,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? _lime.withAlpha(40) : BT.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight ? _lime.withAlpha(60) : BT.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: BTMono(
                  label,
                  size: 9,
                  color: highlight ? _lime : BT.muted,
                ),
              ),
              Icon(
                icon,
                size: 15,
                color: iconColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}