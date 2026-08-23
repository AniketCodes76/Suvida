import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'accessibility_service.dart';
import 'accessibility_route_service.dart';

class RouteService {
  Future<RouteResult?> findRoute({
    required LatLng start,
    required LatLng destination,
    required AccessibilityPreferences preferences,
  }) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
          '${start.longitude},${start.latitude};'
          '${destination.longitude},${destination.latitude}'
          '?overview=full'
          '&geometries=geojson'
          '&steps=true',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      return null;
    }

    final data = jsonDecode(response.body);

    if (data['code'] != 'Ok') {
      return null;
    }

    final routes = data['routes'];

    if (routes == null || routes.isEmpty) {
      return null;
    }

    final route = routes.first;

    final coordinates =
    route['geometry']['coordinates'];

    final points =
    coordinates.map<LatLng>((coordinate) {
      return LatLng(
        coordinate[1].toDouble(),
        coordinate[0].toDouble(),
      );
    }).toList();

    final accessibilityService =
    AccessibilityRouteService();

    final score =
    accessibilityService.calculateScore(
      wheelchair: preferences.wheelchair,
      lowVision: preferences.lowVision,
      hearing: false,
    );

    final summary =
    accessibilityService.getAccessibilitySummary(
      score: score,
    );

    return RouteResult(
      points: points,
      distance:
      (route['distance'] as num).toDouble(),
      duration:
      (route['duration'] as num).toDouble(),
      accessibilitySummary: summary,
      accessibilityScore: score,
    );
  }
}

class RouteResult {
  final List<LatLng> points;
  final double distance;
  final double duration;
  final String accessibilitySummary;
  final int accessibilityScore;

  RouteResult({
    required this.points,
    required this.distance,
    required this.duration,
    required this.accessibilitySummary,
    required this.accessibilityScore,
  });
}