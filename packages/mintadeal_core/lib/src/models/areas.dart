import '../api/mintadeal_api.dart';

/// A Bengaluru neighbourhood the customer browses from. GPS location can replace this later.
class Area {
  const Area(this.name, this.lat, this.lng);

  final String name;
  final double lat;
  final double lng;

  GeoPoint get point => GeoPoint(lat, lng);
}

const bengaluruAreas = [
  Area('HSR Layout', 12.9116, 77.6474),
  Area('Koramangala', 12.9352, 77.6245),
  Area('BTM Layout', 12.9166, 77.6101),
  Area('Indiranagar', 12.9719, 77.6412),
  Area('Jayanagar', 12.9250, 77.5938),
  Area('JP Nagar', 12.9063, 77.5857),
  Area('Bellandur', 12.9304, 77.6784),
  Area('Marathahalli', 12.9569, 77.7011),
  Area('Whitefield', 12.9698, 77.7500),
  Area('Electronic City', 12.8452, 77.6602),
  Area('Malleshwaram', 13.0031, 77.5643),
  Area('Hebbal', 13.0358, 77.5970),
];
