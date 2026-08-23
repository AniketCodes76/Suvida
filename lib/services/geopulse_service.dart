import 'dart:convert';
import 'package:http/http.dart' as http;

class GeopulseService {
  static const String baseUrl = 'http://10.21.36.88:8000';

  // ==========================================================
  // DISTANCE
  // ==========================================================

  static Future<double?> calculateDistance({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/distance'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'origin': {
            'latitude': originLatitude,
            'longitude': originLongitude,
          },
          'destination': {
            'latitude': destinationLatitude,
            'longitude': destinationLongitude,
          },
        }),
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body);

      return (data['distance_km'] as num?)?.toDouble();
    } catch (e) {
      print('GEOPulse distance error: $e');
      return null;
    }
  }

  // ==========================================================
  // NEARBY
  // ==========================================================

  static Future<List<GeopulseNearbyLocation>>
  findNearbyLocations({
    required double centerLatitude,
    required double centerLongitude,
    required double radiusKm,
    required List<GeopulseLocation> locations,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/nearby'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'center': {
            'latitude': centerLatitude,
            'longitude': centerLongitude,
          },
          'radius_km': radiusKm,
          'locations': locations
              .map(
                (location) => {
              'latitude': location.latitude,
              'longitude': location.longitude,
            },
          )
              .toList(),
        }),
      );

      if (response.statusCode != 200) {
        return [];
      }

      final data = jsonDecode(response.body);

      final rawLocations =
          data['locations'] as List<dynamic>? ?? [];

      return rawLocations.map((location) {
        return GeopulseNearbyLocation(
          latitude:
          (location['latitude'] as num).toDouble(),
          longitude:
          (location['longitude'] as num).toDouble(),
          distanceKm:
          (location['distance_km'] as num?)
              ?.toDouble() ??
              0,
        );
      }).toList();
    } catch (e) {
      print('GEOPulse nearby error: $e');
      return [];
    }
  }

  // ==========================================================
  // GEOFENCE
  // ==========================================================

  static Future<GeopulseGeofenceResult?>
  checkGeofence({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/geofence/check'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'location': {
            'latitude': latitude,
            'longitude': longitude,
          },
        }),
      );

      if (response.statusCode != 200) {
        print(
          'GEOPulse geofence status: '
              '${response.statusCode}',
        );
        return null;
      }

      final data = jsonDecode(response.body);

      return GeopulseGeofenceResult(
        inside: data['inside'] == true,
        latitude:
        (data['location']['latitude'] as num)
            .toDouble(),
        longitude:
        (data['location']['longitude'] as num)
            .toDouble(),
      );
    } catch (e) {
      print('GEOPulse geofence error: $e');
      return null;
    }
  }
}

// ==========================================================
// LOCATION
// ==========================================================

class GeopulseLocation {
  final double latitude;
  final double longitude;

  GeopulseLocation({
    required this.latitude,
    required this.longitude,
  });
}

// ==========================================================
// NEARBY RESULT
// ==========================================================

class GeopulseNearbyLocation {
  final double latitude;
  final double longitude;
  final double distanceKm;

  GeopulseNearbyLocation({
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
  });
}

// ==========================================================
// GEOFENCE RESULT
// ==========================================================

class GeopulseGeofenceResult {
  final bool inside;
  final double latitude;
  final double longitude;

  GeopulseGeofenceResult({
    required this.inside,
    required this.latitude,
    required this.longitude,
  });
}