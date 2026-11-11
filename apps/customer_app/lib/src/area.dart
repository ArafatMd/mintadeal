import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mintadeal_core/mintadeal_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AreaController extends Notifier<Area> {
  static const _key = 'mintadeal.area';

  final _restored = Completer<void>();

  /// True when the person picked an area from the list themselves: the app then leaves it alone until they tap
  /// "Use my location", so browsing another neighbourhood is not undone every time the app opens.
  bool pickedByHand = false;

  /// True once a location or area has ever been saved on this device.
  bool hasSaved = false;

  @override
  Area build() {
    _restore().whenComplete(() {
      if (!_restored.isCompleted) _restored.complete();
    });
    return bengaluruAreas.first;
  }

  /// Moves to where the device is now, if location is already allowed (or, with [ask], after asking). Does nothing
  /// when the person picked an area by hand, or has moved less than about 200 m. Returns false when the location
  /// could not be read.
  Future<bool> refreshFromDevice({bool ask = false}) async {
    await _restored.future;
    if (pickedByHand && !ask) return true;
    final GeoPoint? p;
    try {
      p = ask ? await currentLocation() : await currentLocationIfAllowed();
    } on LocationProblem {
      return false;
    }
    if (p == null || !inBengaluru(p)) return false;
    if (state.precise && distanceKm(state.point, p) < 0.2) return true;
    await useLocation(p);
    return true;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == null) return;
    hasSaved = true;
    // Saved as JSON since the location update; earlier versions saved just the area's name.
    if (saved.startsWith('{')) {
      try {
        final j = jsonDecode(saved) as Map<String, dynamic>;
        state = Area(j['name'] as String, (j['lat'] as num).toDouble(), (j['lng'] as num).toDouble(),
            precise: j['precise'] == true, pincode: j['pincode'] as String?);
        pickedByHand = j['precise'] != true;
        return;
      } on Object {
        // Fall through to the default area.
      }
    }
    final match = bengaluruAreas.where((a) => a.name == saved);
    state = match.isNotEmpty ? match.first : bengaluruAreas.first;
    pickedByHand = true;
  }

  Future<void> choose(Area area) async {
    state = area;
    hasSaved = true;
    pickedByHand = !area.precise;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode({
      'name': area.name,
      'lat': area.lat,
      'lng': area.lng,
      'precise': area.precise,
      'pincode': area.pincode,
    }));
  }

  /// Browses from the device's position. It is named after its neighbourhood and pincode from OpenStreetMap
  /// ("RT Nagar", 560032), or the nearest listed area when that is not known. Shops shown still depend only on
  /// the distance from this point, not on the name.
  Future<void> useLocation(GeoPoint p) async {
    // Switch straight away with the nearest area's name, then put the real name in when it arrives.
    await choose(Area(nearestArea(p).name, p.lat, p.lng, precise: true));
    final place = await ref.read(apiProvider).place(p);
    if (place?.name != null && state.lat == p.lat && state.lng == p.lng) {
      await choose(Area(place!.name!, p.lat, p.lng, precise: true, pincode: place.pincode));
    }
  }
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
              subtitle: Text(current.precise
                  ? 'Using it now: ${[current.name, ?current.pincode].join(' · ')} · tap to refresh'
                  : 'For distances from where you are'),
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
