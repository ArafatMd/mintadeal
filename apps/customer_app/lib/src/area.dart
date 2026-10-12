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
    final match = bengaluruAreas.where((a) => a.name == saved);
    if (match.isNotEmpty) state = match.first;
  }

  Future<void> choose(Area area) async {
    state = area;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, area.name);
  }
}

final areaProvider = NotifierProvider<AreaController, Area>(AreaController.new);

Future<void> pickArea(BuildContext context, WidgetRef ref) async {
  final current = ref.read(areaProvider);
  final chosen = await showModalBottomSheet<Area>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Choose your area', style: TextStyle(fontWeight: FontWeight.w600))),
            for (final a in bengaluruAreas)
              ListTile(
                leading: Icon(a.name == current.name ? Icons.radio_button_checked : Icons.radio_button_off),
                title: Text(a.name),
                onTap: () => Navigator.pop(context, a),
              ),
          ],
        ),
      ),
    ),
  );
  if (chosen != null) await ref.read(areaProvider.notifier).choose(chosen);
}
