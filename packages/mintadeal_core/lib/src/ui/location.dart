import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../api/mintadeal_api.dart';
import '../models/areas.dart';

/// Why the device location could not be read, in words for the person.
class LocationProblem implements Exception {
  const LocationProblem(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The centre of Bengaluru; locations further than [_cityRadiusKm] from it are outside the service.
const _cityCentre = GeoPoint(12.9716, 77.5946);
const _cityRadiusKm = 40.0;

/// Asks for permission if needed and reads the device's position once. Never tracks.
Future<GeoPoint> currentLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const LocationProblem('Location is switched off. Turn it on, or choose your area instead.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
  if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
    throw const LocationProblem('Mintadeal was not allowed to use your location. You can choose your area instead.');
  }
  try {
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
    );
    return GeoPoint(p.latitude, p.longitude);
  } on Exception {
    throw const LocationProblem('Could not find your location. Try again near a window, or choose your area.');
  }
}

/// Straight-line distance in km.
double distanceKm(GeoPoint a, GeoPoint b) {
  const r = 6371.0;
  double rad(double d) => d * pi / 180;
  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final h = sin(dLat / 2) * sin(dLat / 2) + cos(rad(a.lat)) * cos(rad(b.lat)) * sin(dLng / 2) * sin(dLng / 2);
  return 2 * r * asin(sqrt(h));
}

bool inBengaluru(GeoPoint p) => distanceKm(p, _cityCentre) <= _cityRadiusKm;

/// The listed area closest to [p], used to name a GPS position ("Near HSR Layout").
Area nearestArea(GeoPoint p) =>
    bengaluruAreas.reduce((best, a) => distanceKm(p, a.point) < distanceKm(p, best.point) ? a : best);

/// An OpenStreetMap map with a pin in the middle.
///
/// With [onMoved], the person moves the map under the pin and gets the new centre when they let go;
/// without it, the map is a fixed preview.
class PinMap extends StatefulWidget {
  const PinMap({super.key, required this.point, this.onMoved, this.height = 240, this.zoom = 17});

  final GeoPoint point;
  final ValueChanged<GeoPoint>? onMoved;
  final double height;
  final double zoom;

  @override
  State<PinMap> createState() => _PinMapState();
}

class _PinMapState extends State<PinMap> {
  final _controller = MapController();
  bool _ready = false;

  @override
  void didUpdateWidget(covariant PinMap old) {
    super.didUpdateWidget(old);
    // Follow a new point from outside (e.g. "use my location"), but not the one we just reported.
    final c = _ready ? _controller.camera.center : null;
    if (c != null && (c.latitude - widget.point.lat).abs() + (c.longitude - widget.point.lng).abs() > 1e-6) {
      _controller.move(LatLng(widget.point.lat, widget.point.lng), _controller.camera.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editable = widget.onMoved != null;
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: widget.height,
        child: Stack(alignment: Alignment.center, children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: LatLng(widget.point.lat, widget.point.lng),
              initialZoom: widget.zoom,
              minZoom: 11,
              maxZoom: 19,
              onMapReady: () => _ready = true,
              interactionOptions: InteractionOptions(
                flags: editable ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none,
              ),
              onMapEvent: editable
                  ? (e) {
                      if (e is MapEventMoveEnd || e is MapEventFlingAnimationEnd || e is MapEventDoubleTapZoomEnd) {
                        final c = e.camera.center;
                        widget.onMoved!(GeoPoint(c.latitude, c.longitude));
                      }
                    }
                  : null,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.mintadeal.app',
              ),
              const RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                showFlutterMapAttribution: false,
                attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
              ),
            ],
          ),
          // The pin's tip sits exactly on the map centre.
          IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Icon(Icons.location_on, size: 44, color: scheme.primary,
                  shadows: const [Shadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))]),
            ),
          ),
          if (editable)
            Positioned(
              top: 10,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Move the map to put the pin on your door',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
