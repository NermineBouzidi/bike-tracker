import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/bike_ui.dart';
import 'dashboard_screen.dart';
import 'map_screen.dart';
import 'trips_screen.dart';
import 'settings_screen.dart';

const Color _lime = Color(0xFFB4FF39);

/// Bottom navigation shell: Home / Map / Trips / Settings.
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
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.near_me_outlined, Icons.near_me, 'Map'),
    (Icons.route_outlined, Icons.route, 'Trips'),
    (Icons.tune, Icons.tune, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const DashboardScreen(),
      const MapScreen(),
      const TripsScreen(),
      const SettingsScreen(),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: BT.bg,
        body: IndexedStack(index: _tab, children: pages),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: BT.border)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: List.generate(_items.length, (i) {
                  final on = i == _tab;
                  final it = _items[i];
                  return Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _tab = i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 5),
                            decoration: BoxDecoration(
                              color: on ? _lime : Colors.transparent, // Fixed BT.green
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(on ? it.$2 : it.$1,
                                size: 22, color: on ? BT.onGreen : BT.muted),
                          ),
                          const SizedBox(height: 2),
                          Text(it.$3,
                              style: TextStyle(
                                fontFamily: kMono,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: on ? _lime : BT.muted, // Fixed BT.ink
                              )),
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