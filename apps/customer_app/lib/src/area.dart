import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AreaController extends Notifier<Area> {
  static const _key = 'mintadeal.area';

  @override
  Area build() {
    _restore();
    return bengaluruAreas.first;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == null) return;
    // Saved as JSON since the location update; earlier versions saved just the area's name.
    if (saved.startsWith('{')) {
      try {
        final j = jsonDecode(saved) as Map<String, dynamic>;
        state = Area(j['name'] as String, (j['lat'] as num).toDouble(), (j['lng'] as num).toDouble(),
            precise: j['precise'] == true);
        return;
      } on Object {
        // Fall through to the default area.
      }
    }
    final match = bengaluruAreas.where((a) => a.name == saved);
    state = match.isNotEmpty ? match.first : bengaluruAreas.first;
  }

  Future<void> choose(Area area) async {
    state = area;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode({'name': area.name, 'lat': area.lat, 'lng': area.lng, 'precise': area.precise}));
  }

  /// Browses from the device's position, named after the nearest listed area.
  Future<void> useLocation(GeoPoint p) => choose(Area(nearestArea(p).name, p.lat, p.lng, precise: true));
}

final areaProvider = NotifierProvider<AreaController, Area>(AreaController.new);

/// "Near HSR Layout" for a GPS position, otherwise the area's name.
String areaLabel(Area a) => a.precise ? 'Near ${a.name}' : a.name;

/// Reads the device location and switches to it. Returns false (after telling the person why) if it could not.
Future<bool> useMyLocation(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final p = await currentLocation();
    if (!inBengaluru(p)) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Mintadeal is only in Bengaluru for now. Choose an area to look around.'),
      ));
      return false;
    }
    await ref.read(areaProvider.notifier).useLocation(p);
    return true;
  } on LocationProblem catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return false;
  }
}

Future<void> pickArea(BuildContext context, WidgetRef ref) async {
  final current = ref.read(areaProvider);
  final chosen = await showModalBottomSheet<Object>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: Icon(Icons.my_location, color: Theme.of(context).colorScheme.primary),
              title: Text('Use my current location',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
              subtitle: Text(current.precise ? 'Using it now · tap to refresh' : 'For distances from where you are'),
              onTap: () => Navigator.pop(context, 'gps'),
            ),
            const Divider(height: 1),
            const ListTile(title: Text('Or choose your area', style: TextStyle(fontWeight: FontWeight.w600))),
            for (final a in bengaluruAreas)
              ListTile(
                leading: Icon(!current.precise && a.name == current.name
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off),
                title: Text(a.name),
                onTap: () => Navigator.pop(context, a),
              ),
          ],
        ),
      ),
    ),
  );
  if (chosen is Area) await ref.read(areaProvider.notifier).choose(chosen);
  if (chosen == 'gps' && context.mounted) await useMyLocation(context, ref);
}
