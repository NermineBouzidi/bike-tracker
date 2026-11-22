import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/api/api_exception.dart';
import '../providers/auth_provider.dart';
import '../widgets/soft_field.dart';
import 'sign_in_screen.dart';

// Same soft palette as the other screens
const Color _bgTop = Color(0xFFF4F8EE);
const Color _bgBottom = Color(0xFFDDE9D1);
const Color _ink = Color(0xFF1E2B1C);
const Color _muted = Color(0xFF6F7D6A);
const Color _sage = Color(0xFFBFD4AC);
const Color _accent = Color(0xFFB6E35C);
const Color _danger = Color(0xFFD64545);
const Color _ok = Color(0xFF3FA34D);

// TODO: keep in sync with pubspec.yaml (or use the package_info_plus package).
const String _appVersion = '1.0.0';

// ===========================================================================
// BACKEND CALLS - the only place to adapt to your AuthRepository.
// ===========================================================================
class _SettingsApi {
  _SettingsApi(this.ref);
  final WidgetRef ref;

  /// GET /me
  Future<({String name, String email})> me() async {
    final u = await ref.read(authRepositoryProvider).me();
    return (name: u.displayName, email: u.email);
  }

  /// POST /me/change-password
  /// The server revokes every session, so the repository also clears the
  /// local tokens: the screen must then go back to sign in.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      ref.read(authRepositoryProvider).changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );

  /// POST /auth/logout (the repository also deletes the saved refresh token)
  Future<void> logout() => ref.read(authRepositoryProvider).logout();

  /// DELETE /me (the server deletes the user's rides too)
  Future<void> deleteAccount({required String password}) =>
      ref.read(authRepositoryProvider).deleteAccount(password: password);
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;
  _SettingsApi get _api => _SettingsApi(ref);

  // Account
  String _name = '';
  String _email = '';

  // Bike (TODO: connect these to your BLE service / saved paired device)
  String? _bikeName = 'BikeTracker';
  String? _bikeAddress = 'B4:52:A9:1A:B0:85';
  bool _connected = false;
  bool _reconnecting = false;

  // Preferences (saved on the phone with shared_preferences)
  int _units = 0; // 0 = km/h, 1 = mph
  int _mapStyle = 0; // 0 = standard, 1 = satellite, 2 = terrain
  bool _wifiOnly = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _loadProfile();
    _loadPrefs();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  Animation<double> _step(double begin, double end) => CurvedAnimation(
        parent: _intro,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      );

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _loadProfile() async {
    try {
      final me = await _api.me();
      if (!mounted) return;
      setState(() {
        _name = me.name;
        _email = me.email;
      });
    } catch (_) {
      // Keep the placeholders if the profile can't be loaded.
    }
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _units = p.getInt('pref_units') ?? 0;
      _mapStyle = p.getInt('pref_map_style') ?? 0;
      _wifiOnly = p.getBool('pref_wifi_only') ?? false;
    });
  }

  Future<void> _setUnits(int v) async {
    setState(() => _units = v);
    (await SharedPreferences.getInstance()).setInt('pref_units', v);
  }

  Future<void> _setMapStyle(int v) async {
    setState(() => _mapStyle = v);
    (await SharedPreferences.getInstance()).setInt('pref_map_style', v);
  }

  Future<void> _setWifiOnly(bool v) async {
    setState(() => _wifiOnly = v);
    (await SharedPreferences.getInstance()).setBool('pref_wifi_only', v);
  }

  void _goToSignIn() {
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignInScreen()),
      (route) => false,
    );
  }

  // ---------------------------------------------------------------- account

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Log out?',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w800)),
        content: const Text('You will need to sign in again.',
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
                backgroundColor: _ink, foregroundColor: _accent),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.logout();
    } on ApiException catch (_) {
      // Even if the server can't be reached, leave the session on this phone.
    }
    if (mounted) _goToSignIn();
  }

  Future<void> _openSheet(Widget sheet) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: _bgTop,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _sage,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    sheet,
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  // ------------------------------------------------------------------- bike

  // TODO: reconnect through your BLE service.
  Future<void> _reconnect() async {
    setState(() => _reconnecting = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() {
      _reconnecting = false;
      _connected = true;
    });
  }

  // TODO: open your BLE scan screen here, then save the chosen device.
  void _pairAnother() => _toast('Open the scan screen here.');

  Future<void> _forgetBike() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Forget this bike?',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w800)),
        content: Text(
          '${_bikeName ?? 'This bike'} will be unpaired from this phone. '
          'Your saved rides stay on your account.',
          style: const TextStyle(color: _muted),
        ),
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
            child: const Text('Forget'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // TODO: disconnect and delete the saved device in your BLE service.
    setState(() {
      _bikeName = null;
      _bikeAddress = null;
      _connected = false;
    });
  }

  // ------------------------------------------------------------------ about

  void _openLegal(String title, String body) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _LegalPage(title: title, body: body),
    ));
  }

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
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              _Reveal(
                animation: _step(0.0, 0.4),
                dy: -0.15,
                child: Padding(
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
                        'Settings',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ---------------------------------------------------- Account
              _Reveal(
                animation: _step(0.1, 0.55),
                child: _Section(
                  title: 'Account',
                  children: [
                    _ProfileBlock(name: _name, email: _email),
                    _Tile(
                      icon: Icons.lock_outline,
                      title: 'Change password',
                      chevron: true,
                      onTap: () => _openSheet(
                        _ChangePasswordSheet(
                          api: _api,
                          onChanged: () {
                            // The server logged out every device.
                            _toast('Password changed. Please sign in again.');
                            _goToSignIn();
                          },
                        ),
                      ),
                    ),
                    _Tile(
                      icon: Icons.logout,
                      title: 'Log out',
                      onTap: _logout,
                    ),
                    _Tile(
                      icon: Icons.delete_outline,
                      title: 'Delete account',
                      subtitle: 'Removes your account and all your rides.',
                      danger: true,
                      onTap: () => _openSheet(
                        _DeleteAccountSheet(
                          api: _api,
                          onDeleted: _goToSignIn,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // ------------------------------------------------------- Bike
              _Reveal(
                animation: _step(0.2, 0.65),
                child: _Section(
                  title: 'Bike',
                  children: _bikeName == null
                      ? [
                          const _Tile(
                            icon: Icons.pedal_bike,
                            title: 'No bike paired',
                            subtitle: 'Pair your tracker to see live data.',
                          ),
                          _Tile(
                            icon: Icons.add_link,
                            title: 'Pair a bike',
                            chevron: true,
                            onTap: _pairAnother,
                          ),
                        ]
                      : [
                          _BikeBlock(
                            name: _bikeName!,
                            address: _bikeAddress ?? '',
                            connected: _connected,
                          ),
                          _Tile(
                            icon: Icons.bluetooth,
                            title: 'Connection',
                            subtitle: _connected ? 'Connected' : 'Disconnected',
                            trailing: _PillButton(
                              label: 'Reconnect',
                              loading: _reconnecting,
                              onTap: _reconnecting ? null : _reconnect,
                            ),
                          ),
                          const _Tile(
                            icon: Icons.memory,
                            title: 'Firmware',
                            // TODO: read it from the bike once a firmware
                            // characteristic exists.
                            subtitle: 'Not available yet',
                          ),
                          _Tile(
                            icon: Icons.add_link,
                            title: 'Pair another bike',
                            chevron: true,
                            onTap: _pairAnother,
                          ),
                          _Tile(
                            icon: Icons.link_off,
                            title: 'Forget bike',
                            danger: true,
                            onTap: _forgetBike,
                          ),
                        ],
                ),
              ),
              const SizedBox(height: 22),

              // -------------------------------------------------- Preferences
              _Reveal(
                animation: _step(0.3, 0.75),
                child: _Section(
                  title: 'Preferences',
                  children: [
                    _ChoiceBlock(
                      icon: Icons.speed,
                      title: 'Units',
                      options: const ['km/h', 'mph'],
                      selected: _units,
                      onChanged: _setUnits,
                    ),
                    _ChoiceBlock(
                      icon: Icons.map_outlined,
                      title: 'Map style',
                      options: const ['Standard', 'Satellite', 'Terrain'],
                      selected: _mapStyle,
                      onChanged: _setMapStyle,
                    ),
                    _Tile(
                      icon: Icons.wifi,
                      title: 'Sync only on Wi-Fi',
                      subtitle: 'Saves your mobile data.',
                      trailing: _SoftSwitch(
                          value: _wifiOnly, onChanged: _setWifiOnly),
                      onTap: () => _setWifiOnly(!_wifiOnly),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // ------------------------------------------------------ About
              _Reveal(
                animation: _step(0.4, 0.85),
                child: _Section(
                  title: 'About',
                  children: [
                    _Tile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy policy',
                      chevron: true,
                      onTap: () => _openLegal('Privacy policy', _privacyText),
                    ),
                    _Tile(
                      icon: Icons.description_outlined,
                      title: 'Terms of use',
                      chevron: true,
                      onTap: () => _openLegal('Terms of use', _termsText),
                    ),
                    const _Tile(
                      icon: Icons.info_outline,
                      title: 'App version',
                      trailing: Text(
                        _appVersion,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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

// TODO: replace these placeholders with your real texts (or open a web page).
const String _privacyText =
    'Replace this text with your privacy policy.\n\n'
    'Explain which data the app collects (account details, GPS rides sent by '
    'your bike), why it is collected, where it is stored and how a user can '
    'delete it (Settings > Delete account).';

const String _termsText =
    'Replace this text with your terms of use.\n\n'
    'The sign up checkbox "I agree to the Terms and the Privacy Policy" '
    'should open these two pages.';

// ===========================================================================
// Bottom sheets
// ===========================================================================

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet({required this.api, required this.onChanged});
  final _SettingsApi api;
  final VoidCallback onChanged;

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.api.changePassword(
        currentPassword: _current.text,
        newPassword: _new.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onChanged();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Change password',
              style: TextStyle(
                  color: _ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          const SizedBox(height: 6),
          const Text('Choose a password with at least 8 characters.',
              style: TextStyle(color: _muted, fontSize: 14.5)),
          const SizedBox(height: 20),
          SoftField(
            label: 'Current password',
            icon: Icons.lock_outline,
            controller: _current,
            isPassword: true,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Enter your current password' : null,
          ),
          const SizedBox(height: 14),
          SoftField(
            label: 'New password',
            icon: Icons.lock_outline,
            controller: _new,
            isPassword: true,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.length < 8) ? 'At least 8 characters' : null,
          ),
          const SizedBox(height: 14),
          SoftField(
            label: 'Confirm new password',
            icon: Icons.lock_outline,
            controller: _confirm,
            isPassword: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!_loading) _submit();
            },
            validator: (v) => v != _new.text ? 'Passwords do not match' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: _danger, fontSize: 13.5)),
          ],
          const SizedBox(height: 20),
          _SheetButton(
            label: 'Update password',
            loading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet({required this.api, required this.onDeleted});
  final _SettingsApi api;
  final VoidCallback onDeleted;

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.api.deleteAccount(password: _password.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onDeleted();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Delete account',
              style: TextStyle(
                  color: _ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          const SizedBox(height: 6),
          const Text(
            'This permanently deletes your account and all your rides. '
            'It cannot be undone. Type your password to confirm.',
            style: TextStyle(color: _muted, fontSize: 14.5, height: 1.4),
          ),
          const SizedBox(height: 20),
          SoftField(
            label: 'Password',
            icon: Icons.lock_outline,
            controller: _password,
            isPassword: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!_loading) _submit();
            },
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Enter your password' : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: _danger, fontSize: 13.5)),
          ],
          const SizedBox(height: 20),
          _SheetButton(
            label: 'Delete my account',
            loading: _loading,
            danger: true,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.loading,
    required this.onPressed,
    this.danger = false,
  });

  final String label;
  final bool loading;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final bg = danger ? _danger : _ink;
    final fg = danger ? Colors.white : _accent;
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: bg.withValues(alpha: 0.6),
        disabledForegroundColor: fg,
        minimumSize: const Size.fromHeight(58),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      onPressed: loading ? null : onPressed,
      child: loading
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
            )
          : Text(label),
    );
  }
}

// ===========================================================================
// Legal page (privacy policy / terms)
// ===========================================================================

class _LegalPage extends StatelessWidget {
  const _LegalPage({required this.title, required this.body});
  final String title;
  final String body;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.75),
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.arrow_back, color: _ink, size: 20),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 32,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        body,
                        style: const TextStyle(
                            color: _muted, fontSize: 15, height: 1.55),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Building blocks
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

/// Small label + a white rounded card holding the rows.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        rows.add(Divider(
          height: 1,
          indent: 68,
          endIndent: 16,
          color: _sage.withValues(alpha: 0.45),
        ));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(26),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: rows),
        ),
      ],
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge(this.icon, {this.danger = false});
  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: danger
            ? _danger.withValues(alpha: 0.12)
            : _sage.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 19, color: danger ? _danger : _ink),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.chevron = false,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _IconBadge(icon, danger: danger),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: danger ? _danger : _ink,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                          color: _muted, fontSize: 12.5, height: 1.3),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing!,
            ],
            if (chevron)
              const Icon(Icons.chevron_right, color: _muted, size: 22),
          ],
        ),
      ),
    );
  }
}

class _ProfileBlock extends StatelessWidget {
  const _ProfileBlock({required this.name, required this.email});
  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty
        ? name.trim()[0].toUpperCase()
        : (email.isNotEmpty ? email[0].toUpperCase() : '?');
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration:
                const BoxDecoration(color: _ink, shape: BoxShape.circle),
            child: Text(
              initial,
              style: const TextStyle(
                color: _accent,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Your account' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email.isEmpty ? '...' : email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 13.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BikeBlock extends StatelessWidget {
  const _BikeBlock({
    required this.name,
    required this.address,
    required this.connected,
  });

  final String name;
  final String address;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _ink,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.pedal_bike, color: _accent, size: 26),
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
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  address,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12.5,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (connected ? _ok : _muted).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: connected ? _ok : _muted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  connected ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: connected ? _ok : _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: _ink,
          borderRadius: BorderRadius.circular(20),
        ),
        child: loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: _accent),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: _accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

/// Icon + title, then a segmented selector below (units, map style).
class _ChoiceBlock extends StatelessWidget {
  const _ChoiceBlock({
    required this.icon,
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(icon),
              const SizedBox(width: 14),
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _sage.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: List.generate(options.length, (i) {
                final on = i == selected;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: on ? _ink : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          options[i],
                          style: TextStyle(
                            color: on ? _accent : _muted,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftSwitch extends StatelessWidget {
  const _SoftSwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? _ink : _sage),
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? _accent : Colors.white),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    );
  }
}