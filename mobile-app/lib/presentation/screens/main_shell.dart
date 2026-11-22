import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'map_screen.dart';
import 'ride_screen.dart';
import 'settings_screen.dart';
import 'trips_screen.dart';

// Same soft palette as the other screens
const Color _bgBottom = Color(0xFFDDE9D1);
const Color _ink = Color(0xFF1E2B1C);
const Color _muted = Color(0xFF6F7D6A);
const Color _accent = Color(0xFFB6E35C);

/// Bottom navigation shell: Ride / Map / Trips / Settings.
/// Navigate here after sign-in:
///   Navigator.of(context).pushReplacement(
///     MaterialPageRoute(builder: (_) => const MainShell()));
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  static const _items = [
    (Icons.speed_outlined, Icons.speed, 'Ride'),
    (Icons.near_me_outlined, Icons.near_me, 'Map'),
    (Icons.route_outlined, Icons.route, 'Trips'),
    (Icons.tune, Icons.tune, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const RideScreen(),
      const MapScreen(),
      const TripsScreen(),
      const SettingsScreen(),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bgBottom,
        body: IndexedStack(index: _tab, children: pages),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: _ink.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 72,
              child: Row(
                children: List.generate(_items.length, (i) {
                  final on = i == _tab;
                  final it = _items[i];
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _tab = i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 6),
                            decoration: BoxDecoration(
                              color: on ? _ink : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              on ? it.$2 : it.$1,
                              size: 22,
                              color: on ? _accent : _muted,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            it.$3,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                              color: on ? _ink : _muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}