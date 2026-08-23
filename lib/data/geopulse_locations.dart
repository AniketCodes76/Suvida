import 'package:latlong2/latlong.dart';

class GeopulsePoi {
  final String name;
  final String type;
  final LatLng location;

  const GeopulsePoi({
    required this.name,
    required this.type,
    required this.location,
  });
}

const List<GeopulsePoi> geopulseKiiTLocations = [
  GeopulsePoi(
    name: 'KIIT Main Gate',
    type: 'Entrance',
    location: LatLng(20.3538, 85.8170),
  ),
  GeopulsePoi(
    name: 'KIIT Central Library',
    type: 'Library',
    location: LatLng(20.3547, 85.8182),
  ),
  GeopulsePoi(
    name: 'KIIT Auditorium',
    type: 'Public Facility',
    location: LatLng(20.3553, 85.8174),
  ),
  GeopulsePoi(
    name: 'KIIT Hospital',
    type: 'Hospital',
    location: LatLng(20.3527, 85.8156),
  ),
  GeopulsePoi(
    name: 'KIIT Campus Bus Stop',
    type: 'Transport',
    location: LatLng(20.3560, 85.8190),
  ),
];