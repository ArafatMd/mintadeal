import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'install_stub.dart' if (dart.library.js_interop) 'install_web.dart' as platform;

/// Installing the website as an app on the home screen, until the store apps are out.
///
/// On Android and computers the browser installs it from a button here; on iPhone and iPad it is added from Safari's
/// Share menu, so the steps are shown instead.
class Install {
  Install._();

  static const _dismissedKey = 'mintadeal.installDismissed';

  /// 'installed', 'prompt', 'ios' or 'none'.
  static String get kind => platform.installKind();

  static bool get canOffer => kind == 'prompt' || kind == 'ios';

  static Future<bool> dismissed() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_dismissedKey) ?? false;
  }

  static Future<void> dismiss() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_dismissedKey, true);
  }

  /// Installs, or explains how to on iPhone. Returns true when the app was installed.
  static Future<bool> start(BuildContext context) async {
    if (kind == 'prompt') return platform.promptInstall();
    if (kind == 'ios') await showIosSteps(context);
    return false;
  }

  static Future<void> showIosSteps(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) {
          final theme = Theme.of(context);
          Widget step(int n, IconData icon, String text) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text('$n', style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w800)),
                ),
                title: Text(text),
                trailing: Icon(icon, color: theme.colorScheme.primary),
              );
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text('Add Mintadeal to your Home Screen',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                ),
                step(1, Icons.ios_share, 'Tap the Share button in Safari\'s toolbar'),
                step(2, Icons.add_box_outlined, 'Scroll down and tap "Add to Home Screen"'),
                step(3, Icons.check_circle_outline, 'Tap "Add". Mintadeal opens from its icon like an app'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text('In Chrome on iPhone, the Share button is in the address bar.',
                      style: theme.textTheme.bodySmall),
                ),
              ]),
            ),
          );
        },
      );
}

/// A small card on the home screen offering to install the app. Hidden once installed or dismissed.
class InstallCard extends StatefulWidget {
  const InstallCard({super.key});

  @override
  State<InstallCard> createState() => _InstallCardState();
}

class _InstallCardState extends State<InstallCard> {
  bool _show = false;
  Timer? _again;

  @override
  void initState() {
    super.initState();
    _check();
    // Chrome says it can install a little after the page loads, so look again shortly.
    _again = Timer(const Duration(seconds: 4), _check);
  }

  @override
  void dispose() {
    _again?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    final show = Install.canOffer && !await Install.dismissed();
    if (mounted && show != _show) setState(() => _show = show);
  }

  Future<void> _install() async {
    final installed = await Install.start(context);
    if (installed && mounted) setState(() => _show = false);
  }

  Future<void> _dismiss() async {
    setState(() => _show = false);
    await Install.dismiss();
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 0, 2),
        child: Row(children: [
          Icon(Icons.install_mobile, color: scheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Get the Mintadeal app on your home screen',
                style: TextStyle(color: scheme.onSecondaryContainer, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: _install,
            style: TextButton.styleFrom(foregroundColor: scheme.primary, visualDensity: VisualDensity.compact),
            child: const Text('Install', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          IconButton(tooltip: 'Not now', onPressed: _dismiss, icon: const Icon(Icons.close)),
        ]),
      ),
    );
  }
}

/// "Install the app" in the Account tab, for anyone who dismissed the card. Hidden where it cannot be offered.
class InstallTile extends StatelessWidget {
  const InstallTile({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Install.canOffer) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.install_mobile),
      title: const Text('Install the app'),
      subtitle: const Text('Open Mintadeal from your home screen, like any app'),
      onTap: () => Install.start(context),
    );
  }
}
