import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../services/accessibility_data_service.dart';

class MapScreen extends StatefulWidget {
  final String destination;
  final String transportMode;

  final void Function(List<RouteData> routes)? onRoutesFound;

  final void Function(Map<String, dynamic>? stop)?
  onAccessibilityStopFound;

  const MapScreen({
    super.key,
    required this.destination,
    required this.transportMode,
    this.onRoutesFound,
    this.onAccessibilityStopFound,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController mapController = MapController();

  final AccessibilityDataService accessibilityDataService =
  AccessibilityDataService();

  final Distance distanceCalculator = const Distance();

  LatLng? currentLocation;
  LatLng? destinationLocation;

  List<RouteData> routes = [];

  int selectedRouteIndex = 0;

  List<Map<String, dynamic>> accessibilityStops = [];

  StreamSubscription<Position>? positionSubscription;

  bool loadingLocation = true;
  bool loadingRoute = false;
  bool loadingAccessibility = true;

  bool navigationStarted = false;
  bool followLocation = true;

  double remainingDistance = 0;
  double remainingDuration = 0;

  double currentHeading = 0;

  double distanceFromRoute = 0;

  String statusMessage = 'Getting your location...';

  DateTime? lastRouteRecalculation;

  @override
  void initState() {
    super.initState();
    initialize();
  }

  @override
  void dispose() {
    positionSubscription?.cancel();
    super.dispose();
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  Future<void> initialize() async {
    await loadAccessibilityData();
    await initializeLocation();
  }

  // ============================================================
  // TRANSPORT PROFILE
  // ============================================================

  String get routingProfile {
    final mode = widget.transportMode.toLowerCase().trim();

    if (mode.contains('walk') ||
        mode.contains('foot') ||
        mode.contains('pedestrian')) {
      return 'pedestrian';
    }

    if (mode.contains('bike') ||
        mode.contains('cycle') ||
        mode.contains('bicycle')) {
      return 'bicycle';
    }

    return 'auto';
  }

  String get transportLabel {
    final mode = widget.transportMode.trim();

    if (mode.isEmpty) {
      return 'Driving';
    }

    return mode;
  }

  // ============================================================
  // LOCATION PERMISSION
  // ============================================================

  Future<bool> checkLocationPermission() async {
    final serviceEnabled =
    await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          statusMessage = 'Location service is disabled';
        });
      }

      await Geolocator.openLocationSettings();
      return false;
    }

    LocationPermission permission =
    await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // ============================================================
  // INITIAL LOCATION
  // ============================================================

  Future<void> initializeLocation() async {
    final permission = await checkLocationPermission();

    if (!permission) {
      if (!mounted) return;

      setState(() {
        loadingLocation = false;
        statusMessage = 'Location permission required';
      });

      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final location = LatLng(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      setState(() {
        currentLocation = location;

        if (position.heading >= 0) {
          currentHeading = position.heading;
        }

        loadingLocation = false;

        statusMessage = 'Finding $transportLabel route...';
      });

      await Future.delayed(
        const Duration(milliseconds: 300),
      );

      mapController.move(
        location,
        16,
      );

      await findRoutes();

      startLiveLocation();
    } catch (e) {
      debugPrint('LOCATION ERROR: $e');

      if (!mounted) return;

      setState(() {
        loadingLocation = false;
        statusMessage = 'Unable to get current location';
      });
    }
  }

  // ============================================================
  // LIVE GPS
  // ============================================================

  void startLiveLocation() {
    positionSubscription?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2,
    );

    positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen(
              (Position position) {
            if (!mounted) return;

            final newLocation = LatLng(
              position.latitude,
              position.longitude,
            );

            double newHeading = currentHeading;

            if (position.heading >= 0 &&
                position.heading.isFinite) {
              newHeading = position.heading;
            }

            setState(() {
              currentLocation = newLocation;
              currentHeading = newHeading;
            });

            if (navigationStarted) {
              updateNavigation(newLocation);
            }

            if (followLocation) {
              mapController.move(
                newLocation,
                navigationStarted ? 18 : 17,
              );
            }
          },
          onError: (error) {
            debugPrint(
              'LOCATION STREAM ERROR: $error',
            );
          },
        );
  }

  // ============================================================
  // FIND ROUTE
  // ============================================================

  Future<void> findRoutes() async {
    if (currentLocation == null) {
      return;
    }

    if (!mounted) return;

    setState(() {
      loadingRoute = true;
      statusMessage =
      'Finding $transportLabel route...';
    });

    try {
      final destination =
      await geocodeDestination(widget.destination);

      if (destination == null) {
        if (!mounted) return;

        setState(() {
          loadingRoute = false;
          statusMessage =
          'Destination could not be found';
        });

        return;
      }

      destinationLocation = destination;

      // ========================================================
      // ACCESSIBILITY STOP
      // ========================================================

      findNearestAccessibilityStop(destination);

      // ========================================================
      // VALHALLA ROUTING
      // ========================================================

      final routeData = await getValhallaRoutes(
        currentLocation!,
        destination,
      );

      if (routeData.isEmpty) {
        if (!mounted) return;

        setState(() {
          loadingRoute = false;
          statusMessage = 'No route found';
        });

        return;
      }

      if (!mounted) return;

      setState(() {
        routes = routeData;
        selectedRouteIndex = 0;

        remainingDistance =
            routeData[0].distance;

        remainingDuration =
            routeData[0].duration;

        loadingRoute = false;

        statusMessage =
        '$transportLabel route ready';
      });

      widget.onRoutesFound?.call(routeData);

      fitRouteOnMap(
        routeData[0].points,
      );
    } catch (e) {
      debugPrint('ROUTE ERROR: $e');

      if (!mounted) return;

      setState(() {
        loadingRoute = false;
        statusMessage =
        'Unable to calculate route';
      });
    }
  }

  // ============================================================
  // FIND NEAREST ACCESSIBILITY STOP
  // ============================================================

  void findNearestAccessibilityStop(
      LatLng target,
      ) {
    if (accessibilityStops.isEmpty) {
      widget.onAccessibilityStopFound?.call(null);
      return;
    }

    Map<String, dynamic>? nearest;

    double nearestDistance = double.infinity;

    for (final data in accessibilityStops) {
      final stop = data['stop'];

      if (stop is! Map<String, dynamic>) {
        continue;
      }

      final latitude = double.tryParse(
        stop['latitude']?.toString() ?? '',
      );

      final longitude = double.tryParse(
        stop['longitude']?.toString() ?? '',
      );

      if (latitude == null || longitude == null) {
        continue;
      }

      final stopLocation = LatLng(
        latitude,
        longitude,
      );

      final distance = distanceCalculator.as(
        LengthUnit.Meter,
        target,
        stopLocation,
      );

      if (distance < nearestDistance) {
        nearestDistance = distance;

        final accessibility =
        Map<String, dynamic>.from(stop);

        accessibility['stop_id'] =
            stop['id'] ?? stop['stop_id'];

        accessibility['distance_from_destination'] =
            distance;

        nearest = accessibility;
      }
    }

    if (nearest == null) {
      widget.onAccessibilityStopFound?.call(null);
      return;
    }

    debugPrint(
      'NEAREST ACCESSIBILITY STOP: '
          '${nearest['stop_id']} '
          '(${nearest['distance_from_destination']}m)',
    );

    widget.onAccessibilityStopFound?.call(nearest);
  }

  // ============================================================
  // GEOCODING
  // ============================================================

  Future<LatLng?> geocodeDestination(
      String destination,
      ) async {
    final encodedDestination =
    Uri.encodeQueryComponent(destination);

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
          '?q=$encodedDestination'
          '&format=json'
          '&limit=1',
    );

    final response = await http.get(
      url,
      headers: {
        'User-Agent':
        'AccessibleRoutePlanner/1.0',
      },
    );

    if (response.statusCode != 200) {
      debugPrint(
        'NOMINATIM ERROR: '
            '${response.statusCode}',
      );

      return null;
    }

    final data = jsonDecode(response.body);

    if (data is! List || data.isEmpty) {
      return null;
    }

    final result = data[0];

    final latitude = double.tryParse(
      result['lat'].toString(),
    );

    final longitude = double.tryParse(
      result['lon'].toString(),
    );

    if (latitude == null || longitude == null) {
      return null;
    }

    return LatLng(
      latitude,
      longitude,
    );
  }

  // ============================================================
  // VALHALLA ROUTING
  // ============================================================

  Future<List<RouteData>> getValhallaRoutes(
      LatLng start,
      LatLng destination,
      ) async {
    final profile = routingProfile;

    debugPrint(
      'ROUTING PROFILE: $profile',
    );

    final url = Uri.parse(
      'https://valhalla1.openstreetmap.de/route',
    );

    final requestBody = {
      'locations': [
        {
          'lat': start.latitude,
          'lon': start.longitude,
        },
        {
          'lat': destination.latitude,
          'lon': destination.longitude,
        },
      ],
      'costing': profile,
      'units': 'kilometers',
      'directions_options': {
        'units': 'kilometers',
      },
    };

    debugPrint(
      'VALHALLA REQUEST: '
          '${jsonEncode(requestBody)}',
    );

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'User-Agent':
        'AccessibleRoutePlanner/1.0',
      },
      body: jsonEncode(requestBody),
    );

    debugPrint(
      'VALHALLA STATUS: '
          '${response.statusCode}',
    );

    if (response.statusCode != 200) {
      debugPrint(
        'VALHALLA ERROR: ${response.body}',
      );

      return [];
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      return [];
    }

    final trip = data['trip'];

    if (trip is! Map<String, dynamic>) {
      debugPrint(
        'VALHALLA ERROR: trip missing',
      );

      return [];
    }

    final summary = trip['summary'];

    if (summary is! Map<String, dynamic>) {
      debugPrint(
        'VALHALLA ERROR: summary missing',
      );

      return [];
    }

    final legs = trip['legs'];

    if (legs is! List || legs.isEmpty) {
      return [];
    }

    // ==========================================================
    // VALHALLA SUMMARY
    //
    // length = kilometres because units = kilometers
    // time   = SECONDS
    //
    // IMPORTANT:
    // Valhalla returns "time" in seconds.
    // ==========================================================

    final routeDistanceKm =
        (summary['length'] as num?)?.toDouble() ?? 0;

    final routeTimeSeconds =
        (summary['time'] as num?)?.toDouble() ?? 0;

    final List<LatLng> points = [];

    for (final leg in legs) {
      if (leg is! Map<String, dynamic>) {
        continue;
      }

      final shape = leg['shape'];

      if (shape is! String) {
        continue;
      }

      final decodedPoints =
      decodeValhallaPolyline(shape);

      if (points.isEmpty) {
        points.addAll(decodedPoints);
      } else {
        // Avoid duplicating the connection point.
        if (decodedPoints.isNotEmpty) {
          points.addAll(
            decodedPoints.skip(1),
          );
        }
      }
    }

    if (points.length < 2) {
      debugPrint(
        'VALHALLA ERROR: insufficient route geometry',
      );

      return [];
    }

    // ==========================================================
    // CREATE ROUTE
    //
    // distance is stored in meters.
    // duration is stored in seconds.
    // ==========================================================

    final route = RouteData(
      points: points,
      distance: routeDistanceKm * 1000,
      duration: routeTimeSeconds,
    );

    debugPrint(
      'VALHALLA ROUTE: '
          '${routeDistanceKm.toStringAsFixed(2)} km, '
          '${(routeTimeSeconds / 60).toStringAsFixed(1)} min, '
          'profile=$profile',
    );

    return [route];
  }

  // ============================================================
  // VALHALLA POLYLINE DECODER
  //
  // Valhalla uses Google's encoded polyline format with
  // precision 6.
  // ============================================================

  List<LatLng> decodeValhallaPolyline(
      String encoded,
      ) {
    final List<LatLng> coordinates = [];

    int index = 0;
    int latitude = 0;
    int longitude = 0;

    while (index < encoded.length) {
      int result = 0;
      int shift = 0;

      while (true) {
        if (index >= encoded.length) {
          return coordinates;
        }

        final byte =
            encoded.codeUnitAt(index++) - 63;

        result |=
            (byte & 0x1f) << shift;

        shift += 5;

        if (byte < 0x20) {
          break;
        }
      }

      final deltaLatitude =
      (result & 1) != 0
          ? ~(result >> 1)
          : (result >> 1);

      latitude += deltaLatitude;

      result = 0;
      shift = 0;

      while (true) {
        if (index >= encoded.length) {
          return coordinates;
        }

        final byte =
            encoded.codeUnitAt(index++) - 63;

        result |=
            (byte & 0x1f) << shift;

        shift += 5;

        if (byte < 0x20) {
          break;
        }
      }

      final deltaLongitude =
      (result & 1) != 0
          ? ~(result >> 1)
          : (result >> 1);

      longitude += deltaLongitude;

      coordinates.add(
        LatLng(
          latitude / 1000000.0,
          longitude / 1000000.0,
        ),
      );
    }

    return coordinates;
  }

  // ============================================================
  // START NAVIGATION
  // ============================================================

  void startNavigation() {
    if (currentLocation == null ||
        routes.isEmpty) {
      return;
    }

    final route = routes[selectedRouteIndex];

    setState(() {
      navigationStarted = true;
      followLocation = true;

      remainingDistance = route.distance;
      remainingDuration = route.duration;

      distanceFromRoute = 0;

      statusMessage =
      'Navigating by $transportLabel';
    });

    mapController.move(
      currentLocation!,
      18,
    );
  }

  // ============================================================
  // STOP NAVIGATION
  // ============================================================

  void stopNavigation() {
    if (!mounted) return;

    setState(() {
      navigationStarted = false;
      followLocation = false;

      statusMessage = 'Navigation stopped';
    });
  }

  // ============================================================
  // NAVIGATION UPDATE
  // ============================================================

  void updateNavigation(
      LatLng location,
      ) {
    if (!navigationStarted ||
        routes.isEmpty) {
      return;
    }

    final route = routes[selectedRouteIndex];

    final progressData =
    calculateRouteProgress(
      location,
      route.points,
    );

    final progress = progressData.progress;

    distanceFromRoute =
        progressData.distanceFromRoute;

    final destinationDistance =
    destinationLocation == null
        ? double.infinity
        : distanceCalculator.as(
      LengthUnit.Meter,
      location,
      destinationLocation!,
    );

    if (!mounted) return;

    setState(() {
      remainingDistance = max(
        0,
        route.distance * (1 - progress),
      );

      remainingDuration = max(
        0,
        route.duration * (1 - progress),
      );

      if (distanceFromRoute > 50) {
        statusMessage = 'You are off route';
      } else {
        statusMessage =
        'Following $transportLabel route';
      }
    });

    if (destinationDistance <= 25) {
      destinationReached();
      return;
    }

    if (distanceFromRoute > 70) {
      recalculateRouteIfNeeded();
    }
  }

  // ============================================================
  // ROUTE PROGRESS
  // ============================================================

  RouteProgress calculateRouteProgress(
      LatLng location,
      List<LatLng> points,
      ) {
    if (points.length < 2) {
      return const RouteProgress(
        progress: 0,
        distanceFromRoute: double.infinity,
      );
    }

    double totalDistance = 0;

    final segmentDistances = <double>[];

    for (
    int i = 0;
    i < points.length - 1;
    i++
    ) {
      final segmentDistance =
      distanceCalculator.as(
        LengthUnit.Meter,
        points[i],
        points[i + 1],
      );

      segmentDistances.add(segmentDistance);
      totalDistance += segmentDistance;
    }

    double travelledDistance = 0;

    double closestDistance = double.infinity;

    for (
    int i = 0;
    i < points.length - 1;
    i++
    ) {
      final projected =
      projectPointOnSegment(
        location,
        points[i],
        points[i + 1],
      );

      final distanceToProjection =
      distanceCalculator.as(
        LengthUnit.Meter,
        location,
        projected,
      );

      if (distanceToProjection <
          closestDistance) {
        closestDistance =
            distanceToProjection;

        double distanceBefore = 0;

        for (
        int j = 0;
        j < i;
        j++
        ) {
          distanceBefore +=
          segmentDistances[j];
        }

        final projectedFromStart =
        distanceCalculator.as(
          LengthUnit.Meter,
          points[i],
          projected,
        );

        travelledDistance =
            distanceBefore +
                projectedFromStart;
      }
    }

    if (totalDistance <= 0) {
      return const RouteProgress(
        progress: 0,
        distanceFromRoute: double.infinity,
      );
    }

    final progress =
    (travelledDistance / totalDistance)
        .clamp(0.0, 1.0);

    return RouteProgress(
      progress: progress,
      distanceFromRoute: closestDistance,
    );
  }

  // ============================================================
  // PROJECT POINT
  // ============================================================

  LatLng projectPointOnSegment(
      LatLng point,
      LatLng start,
      LatLng end,
      ) {
    final x = point.longitude;
    final y = point.latitude;

    final x1 = start.longitude;
    final y1 = start.latitude;

    final x2 = end.longitude;
    final y2 = end.latitude;

    final dx = x2 - x1;
    final dy = y2 - y1;

    if (dx == 0 && dy == 0) {
      return start;
    }

    final t =
        ((x - x1) * dx +
            (y - y1) * dy) /
            (dx * dx + dy * dy);

    final clamped = t.clamp(0.0, 1.0);

    return LatLng(
      y1 + dy * clamped,
      x1 + dx * clamped,
    );
  }

  // ============================================================
  // RECALCULATE ROUTE
  // ============================================================

  Future<void> recalculateRouteIfNeeded() async {
    if (!navigationStarted ||
        currentLocation == null ||
        destinationLocation == null) {
      return;
    }

    final now = DateTime.now();

    if (lastRouteRecalculation != null &&
        now.difference(
          lastRouteRecalculation!,
        ) <
            const Duration(seconds: 10)) {
      return;
    }

    lastRouteRecalculation = now;

    if (mounted) {
      setState(() {
        statusMessage =
        'Recalculating $transportLabel route...';
      });
    }

    try {
      final newRoutes =
      await getValhallaRoutes(
        currentLocation!,
        destinationLocation!,
      );

      if (newRoutes.isEmpty) {
        return;
      }

      if (!mounted) return;

      setState(() {
        routes = newRoutes;
        selectedRouteIndex = 0;

        remainingDistance =
            newRoutes[0].distance;

        remainingDuration =
            newRoutes[0].duration;

        statusMessage =
        '$transportLabel route recalculated';
      });

      widget.onRoutesFound?.call(newRoutes);
    } catch (e) {
      debugPrint(
        'RECALCULATE ERROR: $e',
      );
    }
  }

  // ============================================================
  // DESTINATION REACHED
  // ============================================================

  void destinationReached() {
    if (!navigationStarted) {
      return;
    }

    setState(() {
      navigationStarted = false;

      remainingDistance = 0;
      remainingDuration = 0;

      statusMessage = 'Destination reached';
    });

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Destination Reached',
          ),
          content: Text(
            'You have arrived at '
                '${widget.destination}.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // SELECT ROUTE
  // ============================================================

  void selectRoute(int index) {
    if (index < 0 ||
        index >= routes.length) {
      return;
    }

    setState(() {
      selectedRouteIndex = index;

      remainingDistance =
          routes[index].distance;

      remainingDuration =
          routes[index].duration;
    });

    fitRouteOnMap(
      routes[index].points,
    );
  }

  // ============================================================
  // FIT ROUTE
  // ============================================================

  void fitRouteOnMap(
      List<LatLng> points,
      ) {
    if (points.isEmpty) {
      return;
    }

    double minLatitude =
        points.first.latitude;

    double maxLatitude =
        points.first.latitude;

    double minLongitude =
        points.first.longitude;

    double maxLongitude =
        points.first.longitude;

    for (final point in points) {
      minLatitude = min(
        minLatitude,
        point.latitude,
      );

      maxLatitude = max(
        maxLatitude,
        point.latitude,
      );

      minLongitude = min(
        minLongitude,
        point.longitude,
      );

      maxLongitude = max(
        maxLongitude,
        point.longitude,
      );
    }

    final center = LatLng(
      (minLatitude + maxLatitude) / 2,
      (minLongitude + maxLongitude) / 2,
    );

    final difference = max(
      maxLatitude - minLatitude,
      maxLongitude - minLongitude,
    );

    double zoom = 15;

    if (difference > 0.5) {
      zoom = 8;
    } else if (difference > 0.2) {
      zoom = 10;
    } else if (difference > 0.08) {
      zoom = 12;
    } else if (difference > 0.03) {
      zoom = 13;
    }

    mapController.move(
      center,
      zoom,
    );
  }

  // ============================================================
  // LOAD ACCESSIBILITY DATA
  // ============================================================

  Future<void> loadAccessibilityData() async {
    try {
      final activeRoutes =
      await accessibilityDataService
          .getActiveRoutes();

      final allStops =
      <Map<String, dynamic>>[];

      for (final route in activeRoutes) {
        final routeId =
        (route['id'] as num).toInt();

        final routeStops =
        await accessibilityDataService
            .getStopsForRoute(routeId);

        for (final routeStop in routeStops) {
          allStops.add({
            'route': route,
            'route_stop':
            routeStop['route_stop'],
            'stop':
            routeStop['stop'],
          });
        }
      }

      if (!mounted) return;

      setState(() {
        accessibilityStops = allStops;
        loadingAccessibility = false;
      });
    } catch (e) {
      debugPrint(
        'ACCESSIBILITY ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        loadingAccessibility = false;
      });
    }
  }

  // ============================================================
  // ACCESSIBILITY COLOR
  // ============================================================

  Color accessibilityColor(
      Map<String, dynamic> stop,
      ) {
    final wheelchair =
        stop['wheelchair_accessible'] == true;

    final lighting =
    stop['lighting_level']
        ?.toString()
        .toLowerCase();

    if (wheelchair &&
        lighting != 'low' &&
        lighting != 'poor') {
      return Colors.green;
    }

    if (wheelchair) {
      return Colors.orange;
    }

    return Colors.red;
  }

  // ============================================================
  // STOP INFORMATION
  // ============================================================

  void showStopInformation(
      Map<String, dynamic> data,
      ) {
    final stop =
    data['stop'] as Map<String, dynamic>;

    final route =
    data['route'] as Map<String, dynamic>;

    final routeStop =
    data['route_stop'] as Map<String, dynamic>;

    final wheelchair =
        stop['wheelchair_accessible'] == true;

    final lighting =
    stop['lighting_level']?.toString();

    final arrival =
    routeStop['estimated_arrival_minutes'];

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  stop['name']?.toString() ??
                      'Accessibility Stop',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  route['route_name']?.toString() ??
                      'Route',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      wheelchair
                          ? Icons.accessible
                          : Icons.accessible_forward,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        wheelchair
                            ? 'Wheelchair accessible'
                            : 'Wheelchair accessibility unavailable',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.light_mode),
                    const SizedBox(width: 10),
                    Text(
                      'Lighting: '
                          '${lighting ?? 'Not specified'}',
                    ),
                  ],
                ),
                if (arrival != null)
                  Padding(
                    padding:
                    const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time),
                        const SizedBox(width: 10),
                        Text(
                          'Estimated arrival: '
                              '$arrival min',
                        ),
                      ],
                    ),
                  ),
                if (stop['description'] != null)
                  Padding(
                    padding:
                    const EdgeInsets.only(top: 14),
                    child: Text(
                      stop['description'].toString(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // FORMATTING
  // ============================================================

  String formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }

    return '${meters.round()} m';
  }

  String formatDuration(double seconds) {
    final minutes = (seconds / 60).round();

    if (minutes < 60) {
      return '$minutes min';
    }

    final hours = minutes ~/ 60;

    final remaining = minutes % 60;

    if (remaining == 0) {
      return '$hours hr';
    }

    return '$hours hr $remaining min';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final center =
        currentLocation ??
            const LatLng(
              22.5726,
              88.3639,
            );

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15,
              minZoom: 3,
              maxZoom: 19,
              onPositionChanged:
                  (
                  position,
                  hasGesture,
                  ) {
                if (hasGesture &&
                    navigationStarted) {
                  followLocation = false;
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                'com.example.accessible_route_planner',
              ),

              // =================================================
              // ROUTES
              // =================================================

              if (routes.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    for (
                    int i = 0;
                    i < routes.length;
                    i++
                    )
                      Polyline(
                        points:
                        routes[i].points,
                        strokeWidth:
                        i == selectedRouteIndex
                            ? 6
                            : 3,
                      ),
                  ],
                ),

              // =================================================
              // ACCESSIBILITY STOPS
              // =================================================

              if (accessibilityStops.isNotEmpty)
                MarkerLayer(
                  markers:
                  accessibilityStops
                      .map(
                        (data) {
                      final stop =
                      data['stop']
                      as Map<String,
                          dynamic>;

                      final latitude =
                      double.tryParse(
                        stop['latitude']
                            ?.toString() ??
                            '',
                      );

                      final longitude =
                      double.tryParse(
                        stop['longitude']
                            ?.toString() ??
                            '',
                      );

                      if (latitude == null ||
                          longitude == null) {
                        return Marker(
                          point: center,
                          width: 0,
                          height: 0,
                          child:
                          const SizedBox(),
                        );
                      }

                      return Marker(
                        point: LatLng(
                          latitude,
                          longitude,
                        ),
                        width: 45,
                        height: 45,
                        child:
                        GestureDetector(
                          onTap: () {
                            showStopInformation(
                              data,
                            );
                          },
                          child: Icon(
                            Icons.accessible,
                            size: 34,
                            color:
                            accessibilityColor(
                              stop,
                            ),
                          ),
                        ),
                      );
                    },
                  )
                      .toList(),
                ),

              // =================================================
              // USER + DESTINATION
              // =================================================

              MarkerLayer(
                markers: [
                  if (currentLocation != null)
                    Marker(
                      point:
                      currentLocation!,
                      width: 60,
                      height: 60,
                      child:
                      Transform.rotate(
                        angle:
                        currentHeading *
                            pi /
                            180,
                        child:
                        const Icon(
                          Icons.navigation,
                          size: 44,
                        ),
                      ),
                    ),
                  if (destinationLocation !=
                      null)
                    Marker(
                      point:
                      destinationLocation!,
                      width: 55,
                      height: 55,
                      child:
                      const Icon(
                        Icons.location_on,
                        size: 48,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // =====================================================
          // DESTINATION HEADER
          // =====================================================

          Positioned(
            top: 40,
            left: 12,
            right: 12,
            child: Card(
              child: Padding(
                padding:
                const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.destination,
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style:
                        const TextStyle(
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // =====================================================
          // LOADING
          // =====================================================

          if (loadingLocation ||
              loadingRoute)
            const Center(
              child: Card(
                child: Padding(
                  padding:
                  EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text(
                        'Loading map and route...',
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // =====================================================
          // PRE-NAVIGATION PANEL
          // =====================================================

          if (!loadingLocation &&
              !loadingRoute &&
              routes.isNotEmpty &&
              !navigationStarted)
            Positioned(
              left: 12,
              right: 12,
              bottom: 20,
              child: Card(
                elevation: 8,
                child: Padding(
                  padding:
                  const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment
                            .spaceAround,
                        children: [
                          Column(
                            children: [
                              const Icon(
                                Icons.route,
                              ),
                              const SizedBox(
                                height: 4,
                              ),
                              Text(
                                formatDistance(
                                  routes[
                                  selectedRouteIndex]
                                      .distance,
                                ),
                                style:
                                const TextStyle(
                                  fontWeight:
                                  FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Icon(
                                Icons.access_time,
                              ),
                              const SizedBox(
                                height: 4,
                              ),
                              Text(
                                formatDuration(
                                  routes[
                                  selectedRouteIndex]
                                      .duration,
                                ),
                                style:
                                const TextStyle(
                                  fontWeight:
                                  FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child:
                        ElevatedButton.icon(
                          onPressed:
                          startNavigation,
                          icon: const Icon(
                            Icons.navigation,
                          ),
                          label: Text(
                            'Start '
                                '$transportLabel Navigation',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // =====================================================
          // NAVIGATION PANEL
          // =====================================================

          if (navigationStarted)
            Positioned(
              left: 12,
              right: 12,
              bottom: 20,
              child: Card(
                elevation: 10,
                child: Padding(
                  padding:
                  const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.navigation,
                            size: 30,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              statusMessage,
                              style:
                              const TextStyle(
                                fontWeight:
                                FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment
                            .spaceAround,
                        children: [
                          Column(
                            children: [
                              const Icon(
                                Icons.route,
                              ),
                              const SizedBox(
                                height: 4,
                              ),
                              Text(
                                formatDistance(
                                  remainingDistance,
                                ),
                                style:
                                const TextStyle(
                                  fontWeight:
                                  FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Icon(
                                Icons.access_time,
                              ),
                              const SizedBox(
                                height: 4,
                              ),
                              Text(
                                formatDuration(
                                  remainingDuration,
                                ),
                                style:
                                const TextStyle(
                                  fontWeight:
                                  FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (distanceFromRoute >
                          50) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'You appear to be away from the planned route.',
                          textAlign:
                          TextAlign.center,
                          style: TextStyle(
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child:
                        OutlinedButton(
                          onPressed:
                          stopNavigation,
                          child:
                          const Text(
                            'Stop Navigation',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // =====================================================
          // RECENTER
          // =====================================================

          Positioned(
            right: 16,
            bottom:
            navigationStarted
                ? 240
                : 100,
            child: FloatingActionButton(
              onPressed: () {
                if (currentLocation !=
                    null) {
                  setState(() {
                    followLocation = true;
                  });

                  mapController.move(
                    currentLocation!,
                    navigationStarted
                        ? 18
                        : 17,
                  );
                } else {
                  initializeLocation();
                }
              },
              child:
              const Icon(
                Icons.my_location,
              ),
            ),
          ),

          // =====================================================
          // STATUS
          // =====================================================

          Positioned(
            left: 12,
            top: 105,
            child: Card(
              child: Padding(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Text(
                  statusMessage,
                  style:
                  const TextStyle(
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          // =====================================================
          // ACCESSIBILITY LOADING
          // =====================================================

          if (loadingAccessibility)
            const Positioned(
              top: 145,
              right: 12,
              child: Card(
                child: Padding(
                  padding:
                  EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  child: Row(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 15,
                        height: 15,
                        child:
                        CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Accessibility data',
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ================================================================
// ROUTE DATA
// ================================================================

class RouteData {
  final List<LatLng> points;
  final double distance;

  // Stored in SECONDS.
  final double duration;

  RouteData({
    required this.points,
    required this.distance,
    required this.duration,
  });
}

// ================================================================
// ROUTE PROGRESS
// ================================================================

class RouteProgress {
  final double progress;
  final double distanceFromRoute;

  const RouteProgress({
    required this.progress,
    required this.distanceFromRoute,
  });
}