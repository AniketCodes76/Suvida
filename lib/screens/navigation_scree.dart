import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../data/geopulse_locations.dart';
import '../services/geopulse_service.dart';
import '../models/alert_model.dart';
import '../services/alert_service.dart';
import 'alerts_screen.dart';

class NavigationScreen extends StatefulWidget {
  final String destination;

  const NavigationScreen({
    super.key,
    required this.destination,
  });

  @override
  State<NavigationScreen> createState() =>
      _NavigationScreenState();
}

class _NavigationScreenState
    extends State<NavigationScreen> {
  final MapController mapController =
  MapController();

  LatLng? currentLocation;
  LatLng? destinationLocation;

  List<LatLng> routePoints = [];

  // ==========================================================
  // GEOPULSE
  // ==========================================================

  List<GeopulseNearbyLocation>
  nearbyLocations = [];

  double? remainingDistance;
  double? estimatedDuration;

  // ==========================================================
  // NAVIGATION
  // ==========================================================

  String currentInstruction =
      'Preparing navigation...';

  double? instructionDistance;

  bool loading = true;
  bool navigationStarted = false;

  // ==========================================================
  // GEOFENCE
  // ==========================================================

  bool? insideGeofence;

  bool geofenceChecking = false;

  bool? previousGeofenceState;

  // ==========================================================
  // LIVE LOCATION
  // ==========================================================

  StreamSubscription<Position>?
  positionSubscription;

  // ==========================================================
  // ALERT SYSTEM
  // ==========================================================

  final AlertService alertService =
      AlertService.instance;

  DateTime? lastGpsAlertTime;

  LatLng? previousTrackedLocation;

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    startNavigation();
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    positionSubscription?.cancel();

    super.dispose();
  }

  // ==========================================================
  // START NAVIGATION
  // ==========================================================

  Future<void> startNavigation() async {
    try {
      final permission =
      await checkLocationPermission();

      if (!permission) {
        if (!mounted) return;

        setState(() {
          loading = false;

          currentInstruction =
          'Location permission required';
        });

        return;
      }

      final position =
      await Geolocator.getCurrentPosition(
        locationSettings:
        const LocationSettings(
          accuracy:
          LocationAccuracy.high,
        ),
      );

      currentLocation = LatLng(
        position.latitude,
        position.longitude,
      );

      // ========================================================
      // INITIAL ROUTE
      // ========================================================

      await calculateRoute();

      // ========================================================
      // GEOPULSE NEARBY
      // ========================================================

      await updateNearbyLocations(
        currentLocation!,
      );

      // ========================================================
      // GEOPULSE GEOFENCE
      // ========================================================

      await checkKiitGeofence(
        currentLocation!,
      );

      // ========================================================
      // LIVE TRACKING
      // ========================================================

      startLiveTracking();

      if (!mounted) return;

      setState(() {
        loading = false;

        navigationStarted = true;
      });
    } catch (e) {
      debugPrint(
        'Navigation start error: $e',
      );

      if (!mounted) return;

      setState(() {
        loading = false;

        currentInstruction =
        'Unable to start navigation';
      });
    }
  }

  // ==========================================================
  // LOCATION PERMISSION
  // ==========================================================

  Future<bool> checkLocationPermission() async {
    final serviceEnabled =
    await Geolocator
        .isLocationServiceEnabled();

    if (!serviceEnabled) {
      await Geolocator
          .openLocationSettings();

      return false;
    }

    LocationPermission permission =
    await Geolocator.checkPermission();

    if (permission ==
        LocationPermission.denied) {
      permission =
      await Geolocator.requestPermission();
    }

    if (permission ==
        LocationPermission.denied ||
        permission ==
            LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // ==========================================================
  // GEOPULSE DISTANCE
  // ==========================================================

  Future<double?>
  calculateGeopulseDistance(
      LatLng origin,
      LatLng destination,
      ) async {
    try {
      final distanceKm =
      await GeopulseService
          .calculateDistance(
        originLatitude:
        origin.latitude,
        originLongitude:
        origin.longitude,
        destinationLatitude:
        destination.latitude,
        destinationLongitude:
        destination.longitude,
      );

      debugPrint(
        'GEOPulse distance: '
            '$distanceKm km',
      );

      return distanceKm;
    } catch (e) {
      debugPrint(
        'GEOPulse distance error: $e',
      );

      return null;
    }
  }

  // ==========================================================
  // GEOPULSE NEARBY
  // ==========================================================

  Future<void> updateNearbyLocations(
      LatLng center,
      ) async {
    try {
      final candidates =
      geopulseKiiTLocations
          .map(
            (poi) => GeopulseLocation(
          latitude:
          poi.location.latitude,
          longitude:
          poi.location.longitude,
        ),
      )
          .toList();

      final results =
      await GeopulseService
          .findNearbyLocations(
        centerLatitude:
        center.latitude,
        centerLongitude:
        center.longitude,
        radiusKm: 1,
        locations:
        candidates,
      );

      if (!mounted) return;

      setState(() {
        nearbyLocations =
            results;
      });

      debugPrint(
        'GEOPulse nearby count: '
            '${results.length}',
      );
    } catch (e) {
      debugPrint(
        'GEOPulse nearby error: $e',
      );
    }
  }

  // ==========================================================
  // GEOPULSE GEOFENCE + ALERTS
  // ==========================================================

  Future<void> checkKiitGeofence(
      LatLng location,
      ) async {
    if (geofenceChecking) {
      return;
    }

    geofenceChecking = true;

    try {
      final result =
      await GeopulseService
          .checkGeofence(
        latitude:
        location.latitude,
        longitude:
        location.longitude,
      );

      if (!mounted) {
        return;
      }

      if (result != null) {
        final bool currentState =
            result.inside;

        setState(() {
          insideGeofence =
              currentState;
        });

        debugPrint(
          'GEOPulse Geofence: '
              '${currentState ? "INSIDE" : "OUTSIDE"}',
        );

        // ======================================================
        // FIRST RESULT
        // ======================================================

        if (previousGeofenceState ==
            null) {
          previousGeofenceState =
              currentState;

          return;
        }

        // ======================================================
        // ENTERED CAMPUS
        // ======================================================

        if (!previousGeofenceState! &&
            currentState) {
          if (!alertService
              .hasRecentAlert(
            type:
            AlertType.geopulseZone,
            source:
            AlertSource.geopulse,
          )) {
            alertService.addAlert(
              type:
              AlertType.geopulseZone,
              severity:
              AlertSeverity.info,
              title:
              'Entered KIIT Campus',
              message:
              'You have entered the monitored KIIT campus zone.',
              source:
              AlertSource.geopulse,
              latitude:
              location.latitude,
              longitude:
              location.longitude,
              metadata: {
                'event':
                'geofence_enter',
                'zone':
                'KIIT Campus',
              },
            );
          }
        }

        // ======================================================
        // LEFT CAMPUS
        // ======================================================

        if (previousGeofenceState! &&
            !currentState) {
          if (!alertService
              .hasRecentAlert(
            type:
            AlertType.geopulseZone,
            source:
            AlertSource.geopulse,
          )) {
            alertService.addAlert(
              type:
              AlertType.geopulseZone,
              severity:
              AlertSeverity.warning,
              title:
              'Left KIIT Campus',
              message:
              'You have moved outside the monitored KIIT campus zone.',
              source:
              AlertSource.geopulse,
              latitude:
              location.latitude,
              longitude:
              location.longitude,
              metadata: {
                'event':
                'geofence_exit',
                'zone':
                'KIIT Campus',
              },
            );
          }
        }

        previousGeofenceState =
            currentState;
      }
    } catch (e) {
      debugPrint(
        'GEOPulse geofence error: $e',
      );
    } finally {
      geofenceChecking =
      false;
    }
  }

  // ==========================================================
  // INITIAL ROUTE
  // ==========================================================

  Future<void> calculateRoute() async {
    if (currentLocation ==
        null) {
      return;
    }

    final destination =
    await geocodeDestination(
      widget.destination,
    );

    if (destination == null) {
      throw Exception(
        'Destination not found',
      );
    }

    destinationLocation =
        destination;

    final route =
    await getOsrmRoute(
      currentLocation!,
      destination,
    );

    if (route == null ||
        route.points.isEmpty) {
      throw Exception(
        'Route not found',
      );
    }

    routePoints =
        route.points;

    remainingDistance =
        route.distance;

    estimatedDuration =
        route.duration;

    final geopulseDistance =
    await calculateGeopulseDistance(
      currentLocation!,
      destination,
    );

    if (geopulseDistance !=
        null) {
      remainingDistance =
          geopulseDistance * 1000;
    }

    if (route.steps.isNotEmpty) {
      updateInstruction(
        route.steps.first,
      );
    }

    fitRouteOnMap();
  }

  // ==========================================================
  // GEOCODING
  // ==========================================================

  Future<LatLng?>
  geocodeDestination(
      String destination,
      ) async {
    final encoded =
    Uri.encodeQueryComponent(
      destination,
    );

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
          '?q=$encoded'
          '&format=json'
          '&limit=1',
    );

    final response =
    await http.get(
      url,
      headers: {
        'User-Agent':
        'AccessibleRoutePlanner/1.0',
      },
    );

    if (response.statusCode !=
        200) {
      return null;
    }

    final List<dynamic> results =
    jsonDecode(
      response.body,
    );

    if (results.isEmpty) {
      return null;
    }

    final result =
        results.first;

    final latitude =
    double.tryParse(
      result['lat'].toString(),
    );

    final longitude =
    double.tryParse(
      result['lon'].toString(),
    );

    if (latitude == null ||
        longitude == null) {
      return null;
    }

    return LatLng(
      latitude,
      longitude,
    );
  }

  // ==========================================================
  // OSRM ROUTE
  // ==========================================================

  Future<RouteData?>
  getOsrmRoute(
      LatLng start,
      LatLng destination,
      ) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/'
          'route/v1/driving/'
          '${start.longitude},'
          '${start.latitude};'
          '${destination.longitude},'
          '${destination.latitude}'
          '?overview=full'
          '&geometries=geojson'
          '&steps=true',
    );

    final response =
    await http.get(url);

    if (response.statusCode !=
        200) {
      return null;
    }

    final data =
    jsonDecode(
      response.body,
    );

    if (data['code'] !=
        'Ok') {
      return null;
    }

    final routes =
    data['routes'];

    if (routes == null ||
        routes.isEmpty) {
      return null;
    }

    final route =
        routes.first;

    final coordinates =
    route['geometry']
    ['coordinates'];

    final points =
    coordinates.map<LatLng>(
          (coordinate) {
        return LatLng(
          coordinate[1]
              .toDouble(),
          coordinate[0]
              .toDouble(),
        );
      },
    ).toList();

    final List<RouteStep>
    steps = [];

    final legs =
    route['legs'];

    if (legs != null &&
        legs.isNotEmpty) {
      final leg =
          legs.first;

      final rawSteps =
      leg['steps'];

      if (rawSteps != null) {
        for (final step
        in rawSteps) {
          final maneuver =
          step['maneuver'];

          final type =
              maneuver?['type']
                  ?.toString() ??
                  '';

          final modifier =
              maneuver?['modifier']
                  ?.toString() ??
                  '';

          final name =
              step['name']
                  ?.toString() ??
                  '';

          final distance =
              (step['distance']
              as num?)
                  ?.toDouble() ??
                  0;

          steps.add(
            RouteStep(
              type:
              type,
              modifier:
              modifier,
              name:
              name,
              distance:
              distance,
            ),
          );
        }
      }
    }

    return RouteData(
      points:
      points,
      distance:
      (route['distance']
      as num)
          .toDouble(),
      duration:
      (route['duration']
      as num)
          .toDouble(),
      steps:
      steps,
    );
  }

  // ==========================================================
  // NAVIGATION INSTRUCTION
  // ==========================================================

  void updateInstruction(
      RouteStep step,
      ) {
    String instruction;

    if (step.type ==
        'depart') {
      instruction =
      'Start your journey';
    } else if (step.type ==
        'arrive') {
      instruction =
      'You have arrived';
    } else if (step.type ==
        'roundabout') {
      instruction =
      'Enter the roundabout';
    } else if (step.type ==
        'merge') {
      instruction =
      'Merge';
    } else if (step.type ==
        'fork') {
      instruction =
      'Take the ${step.modifier} fork';
    } else if (step.modifier
        .isNotEmpty) {
      instruction =
      '${capitalize(step.modifier)} on '
          '${step.name.isEmpty ? 'the road' : step.name}';
    } else if (step.type
        .isNotEmpty) {
      instruction =
          capitalize(
            step.type,
          );
    } else {
      instruction =
      'Continue';
    }

    if (!mounted) return;

    setState(() {
      currentInstruction =
          instruction;

      instructionDistance =
          step.distance;
    });
  }

  String capitalize(
      String value,
      ) {
    if (value.isEmpty) {
      return value;
    }

    return value[0]
        .toUpperCase() +
        value.substring(1);
  }

  // ==========================================================
  // LIVE TRACKING
  // ==========================================================

  void startLiveTracking() {
    const settings =
    LocationSettings(
      accuracy:
      LocationAccuracy.high,
      distanceFilter: 5,
    );

    positionSubscription =
        Geolocator
            .getPositionStream(
          locationSettings:
          settings,
        ).listen(
              (
              Position position,
              ) async {
            final newLocation =
            LatLng(
              position.latitude,
              position.longitude,
            );

            // ======================================================
            // GPS ACCURACY ALERT
            // ======================================================

            if (position.accuracy >
                50) {
              final now =
              DateTime.now();

              if (lastGpsAlertTime ==
                  null ||
                  now
                      .difference(
                    lastGpsAlertTime!,
                  ) >
                      const Duration(
                        minutes: 5,
                      )) {
                alertService.addAlert(
                  type:
                  AlertType.gpsAccuracy,
                  severity:
                  AlertSeverity.warning,
                  title:
                  'Low GPS Accuracy',
                  message:
                  'Your current GPS accuracy is low. Navigation may be less precise.',
                  source:
                  AlertSource.gps,
                  latitude:
                  position.latitude,
                  longitude:
                  position.longitude,
                  metadata: {
                    'accuracy_m':
                    position.accuracy,
                  },
                );

                lastGpsAlertTime =
                    now;
              }
            }

            if (!mounted) {
              return;
            }

            // ======================================================
            // UPDATE LOCATION
            // ======================================================

            setState(() {
              currentLocation =
                  newLocation;
            });

            // ======================================================
            // ROUTE DEVIATION
            // ======================================================

            if (routePoints
                .isNotEmpty) {
              final distanceFromRoute =
              _distanceToRoute(
                newLocation,
                routePoints,
              );

              if (distanceFromRoute >
                  80) {
                if (!alertService
                    .hasRecentAlert(
                  type:
                  AlertType.routeDeviation,
                  source:
                  AlertSource.route,
                )) {
                  alertService.addAlert(
                    type:
                    AlertType.routeDeviation,
                    severity:
                    AlertSeverity.warning,
                    title:
                    'Route Deviation',
                    message:
                    'You appear to have moved away from the planned route. Recalculating your route.',
                    source:
                    AlertSource.route,
                    latitude:
                    newLocation.latitude,
                    longitude:
                    newLocation.longitude,
                    metadata: {
                      'distance_from_route_m':
                      distanceFromRoute,
                    },
                  );
                }
              }
            }

            previousTrackedLocation =
                newLocation;

            // ======================================================
            // CENTER MAP
            // ======================================================

            mapController.move(
              newLocation,
              17,
            );

            // ======================================================
            // RECALCULATE ROUTE
            // ======================================================

            await updateRemainingRoute(
              newLocation,
            );

            // ======================================================
            // UPDATE GEOPULSE NEARBY
            // ======================================================

            await updateNearbyLocations(
              newLocation,
            );

            // ======================================================
            // UPDATE GEOFENCE
            // ======================================================

            await checkKiitGeofence(
              newLocation,
            );
          },
        );
  }

  // ==========================================================
  // DISTANCE TO ROUTE
  // ==========================================================

  double _distanceToRoute(
      LatLng location,
      List<LatLng> route,
      ) {
    if (route.isEmpty) {
      return double.infinity;
    }

    const Distance distance =
    Distance();

    double minimumDistance =
        double.infinity;

    for (final point
    in route) {
      final meters =
      distance.as(
        LengthUnit.Meter,
        location,
        point,
      );

      if (meters <
          minimumDistance) {
        minimumDistance =
            meters;
      }
    }

    return minimumDistance;
  }

  // ==========================================================
  // UPDATE REMAINING ROUTE
  // ==========================================================

  Future<void>
  updateRemainingRoute(
      LatLng location,
      ) async {
    if (destinationLocation ==
        null) {
      return;
    }

    final route =
    await getOsrmRoute(
      location,
      destinationLocation!,
    );

    if (route == null) {
      return;
    }

    final geopulseDistance =
    await calculateGeopulseDistance(
      location,
      destinationLocation!,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      routePoints =
          route.points;

      estimatedDuration =
          route.duration;

      if (geopulseDistance !=
          null) {
        remainingDistance =
            geopulseDistance *
                1000;
      } else {
        remainingDistance =
            route.distance;
      }
    });

    if (route.steps
        .isNotEmpty) {
      updateInstruction(
        route.steps.first,
      );
    }
  }

  // ==========================================================
  // FIT ROUTE ON MAP
  // ==========================================================

  void fitRouteOnMap() {
    if (routePoints.isEmpty) {
      return;
    }

    double minLat =
        routePoints.first.latitude;

    double maxLat =
        routePoints.first.latitude;

    double minLng =
        routePoints.first.longitude;

    double maxLng =
        routePoints.first.longitude;

    for (final point
    in routePoints) {
      if (point.latitude <
          minLat) {
        minLat =
            point.latitude;
      }

      if (point.latitude >
          maxLat) {
        maxLat =
            point.latitude;
      }

      if (point.longitude <
          minLng) {
        minLng =
            point.longitude;
      }

      if (point.longitude >
          maxLng) {
        maxLng =
            point.longitude;
      }
    }

    final center =
    LatLng(
      (minLat + maxLat) /
          2,
      (minLng + maxLng) /
          2,
    );

    mapController.move(
      center,
      14,
    );
  }

  // ==========================================================
  // FORMAT DISTANCE
  // ==========================================================

  String formatDistance(
      double meters,
      ) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }

    return '${meters.round()} m';
  }

  // ==========================================================
  // FORMAT DURATION
  // ==========================================================

  String formatDuration(
      double seconds,
      ) {
    final minutes =
    (seconds / 60).round();

    if (minutes < 60) {
      return '$minutes min';
    }

    final hours =
        minutes ~/ 60;

    final remaining =
        minutes % 60;

    if (remaining == 0) {
      return '$hours hr';
    }

    return '$hours hr $remaining min';
  }

  // ==========================================================
  // UI
  // ==========================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      body: Stack(
        children: [
          // ====================================================
          // MAP
          // ====================================================

          FlutterMap(
            mapController:
            mapController,

            options:
            MapOptions(
              initialCenter:
              currentLocation ??
                  const LatLng(
                    22.5726,
                    88.3639,
                  ),

              initialZoom: 16,

              minZoom: 3,

              maxZoom: 19,
            ),

            children: [
              TileLayer(
                urlTemplate:
                'https://tile.openstreetmap.org/'
                    '{z}/{x}/{y}.png',

                userAgentPackageName:
                'com.example.accessible_route_planner',
              ),

              // =================================================
              // ROUTE
              // =================================================

              if (routePoints
                  .isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points:
                      routePoints,

                      strokeWidth: 7,
                    ),
                  ],
                ),

              // =================================================
              // MARKERS
              // =================================================

              MarkerLayer(
                markers: [
                  // CURRENT LOCATION

                  if (currentLocation !=
                      null)
                    Marker(
                      point:
                      currentLocation!,

                      width: 55,

                      height: 55,

                      child:
                      const Icon(
                        Icons.navigation,
                        size: 42,
                      ),
                    ),

                  // DESTINATION

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

                  // =================================================
                  // GEOPULSE NEARBY LOCATIONS
                  // =================================================

                  ...nearbyLocations.map(
                        (location) {
                      return Marker(
                        point:
                        LatLng(
                          location.latitude,
                          location.longitude,
                        ),

                        width: 50,

                        height: 50,

                        child:
                        const Icon(
                          Icons.place,
                          size: 38,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),

          // ====================================================
          // TOP BAR
          // ====================================================

          SafeArea(
            child: Padding(
              padding:
              const EdgeInsets.all(
                16,
              ),

              child: Row(
                children: [
                  // BACK

                  Container(
                    decoration:
                    const BoxDecoration(
                      color:
                      Colors.white,

                      shape:
                      BoxShape.circle,
                    ),

                    child:
                    IconButton(
                      onPressed: () {
                        positionSubscription
                            ?.cancel();

                        Navigator.pop(
                          context,
                        );
                      },

                      icon:
                      const Icon(
                        Icons.arrow_back,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  // DESTINATION

                  Expanded(
                    child:
                    Container(
                      padding:
                      const EdgeInsets
                          .all(
                        14,
                      ),

                      decoration:
                      BoxDecoration(
                        color:
                        Colors.white,

                        borderRadius:
                        BorderRadius
                            .circular(
                          14,
                        ),

                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 8,
                            color:
                            Colors.black26,
                          ),
                        ],
                      ),

                      child: Text(
                        widget.destination,

                        style:
                        const TextStyle(
                          fontWeight:
                          FontWeight
                              .bold,

                          fontSize: 16,
                        ),

                        maxLines: 1,

                        overflow:
                        TextOverflow
                            .ellipsis,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  // ALERTS

                  Container(
                    decoration:
                    const BoxDecoration(
                      color:
                      Colors.white,

                      shape:
                      BoxShape.circle,
                    ),

                    child:
                    IconButton(
                      tooltip:
                      'Alerts',

                      icon:
                      const Icon(
                        Icons
                            .notifications_outlined,
                      ),

                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                            const AlertsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ====================================================
          // LOADING
          // ====================================================

          if (loading)
            Center(
              child: Card(
                child: Padding(
                  padding:
                  const EdgeInsets
                      .all(
                    20,
                  ),

                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,

                    children: [
                      const CircularProgressIndicator(),

                      const SizedBox(
                        height: 14,
                      ),

                      Text(
                        currentInstruction,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ====================================================
          // NAVIGATION INSTRUCTION
          // ====================================================

          if (!loading &&
              navigationStarted)
            Positioned(
              top: 90,

              left: 16,

              right: 16,

              child: Card(
                elevation: 6,

                child: Padding(
                  padding:
                  const EdgeInsets
                      .all(
                    16,
                  ),

                  child: Row(
                    children: [
                      const Icon(
                        Icons.navigation,
                        size: 36,
                      ),

                      const SizedBox(
                        width: 14,
                      ),

                      Expanded(
                        child:
                        Column(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                          children: [
                            Text(
                              currentInstruction,

                              style:
                              const TextStyle(
                                fontWeight:
                                FontWeight
                                    .bold,

                                fontSize: 17,
                              ),
                            ),

                            const SizedBox(
                              height: 5,
                            ),

                            if (instructionDistance !=
                                null)
                              Text(
                                'in ${formatDistance(instructionDistance!)}',
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ====================================================
          // GEOFENCE STATUS
          // ====================================================

          if (!loading &&
              navigationStarted &&
              insideGeofence != null)
            Positioned(
              top: 205,

              left: 16,

              right: 16,

              child: Container(
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),

                decoration:
                BoxDecoration(
                  color:
                  insideGeofence!
                      ? Colors
                      .green
                      .shade50
                      : Colors
                      .white,

                  borderRadius:
                  BorderRadius
                      .circular(
                    12,
                  ),

                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 6,
                      color:
                      Colors.black26,
                    ),
                  ],
                ),

                child: Row(
                  children: [
                    Icon(
                      insideGeofence!
                          ? Icons
                          .location_on
                          : Icons
                          .location_off,

                      color:
                      insideGeofence!
                          ? Colors.green
                          : Colors.grey,
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    Expanded(
                      child: Text(
                        insideGeofence!
                            ? 'Inside KIIT Campus'
                            : 'Outside KIIT Campus',

                        style:
                        const TextStyle(
                          fontWeight:
                          FontWeight
                              .bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ====================================================
          // GEOPULSE NEARBY PANEL
          // ====================================================

          if (!loading &&
              navigationStarted &&
              nearbyLocations.isNotEmpty)
            Positioned(
              left: 16,

              right: 16,

              bottom: 175,

              child: Card(
                elevation: 6,

                child: Padding(
                  padding:
                  const EdgeInsets
                      .all(
                    14,
                  ),

                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

                    children: [
                      // HEADER

                      Row(
                        children: [
                          const Icon(
                            Icons
                                .location_searching,
                            size: 24,
                          ),

                          const SizedBox(
                            width: 8,
                          ),

                          Expanded(
                            child: Text(
                              '${nearbyLocations.length} GEOPulse location${nearbyLocations.length == 1 ? '' : 's'} nearby',

                              style:
                              const TextStyle(
                                fontWeight:
                                FontWeight
                                    .bold,

                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      // NEARBY LOCATIONS

                      ...nearbyLocations
                          .take(3)
                          .map(
                            (location) {
                          return Padding(
                            padding:
                            const EdgeInsets
                                .only(
                              bottom: 6,
                            ),

                            child: Row(
                              children: [
                                const Icon(
                                  Icons.place,
                                  size: 20,
                                ),

                                const SizedBox(
                                  width: 8,
                                ),

                                Expanded(
                                  child:
                                  Text(
                                    '${location.latitude.toStringAsFixed(5)}, '
                                        '${location.longitude.toStringAsFixed(5)}',

                                    maxLines:
                                    1,

                                    overflow:
                                    TextOverflow
                                        .ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ====================================================
          // BOTTOM INFORMATION CARD
          // ====================================================

          if (!loading &&
              navigationStarted)
            Positioned(
              left: 16,

              right: 16,

              bottom: 24,

              child: Card(
                elevation: 6,

                child: Padding(
                  padding:
                  const EdgeInsets
                      .all(
                    16,
                  ),

                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment
                            .spaceAround,

                        children: [
                          // DISTANCE

                          Column(
                            children: [
                              const Icon(
                                Icons.route,
                              ),

                              const SizedBox(
                                height: 5,
                              ),

                              Text(
                                remainingDistance ==
                                    null
                                    ? '--'
                                    : formatDistance(
                                  remainingDistance!,
                                ),

                                style:
                                const TextStyle(
                                  fontWeight:
                                  FontWeight
                                      .bold,

                                  fontSize: 17,
                                ),
                              ),

                              const Text(
                                'remaining',
                              ),
                            ],
                          ),

                          // ETA

                          Column(
                            children: [
                              const Icon(
                                Icons
                                    .access_time,
                              ),

                              const SizedBox(
                                height: 5,
                              ),

                              Text(
                                estimatedDuration ==
                                    null
                                    ? '--'
                                    : formatDuration(
                                  estimatedDuration!,
                                ),

                                style:
                                const TextStyle(
                                  fontWeight:
                                  FontWeight
                                      .bold,

                                  fontSize: 17,
                                ),
                              ),

                              const Text(
                                'ETA',
                              ),
                            ],
                          ),

                          // NEARBY

                          Column(
                            children: [
                              const Icon(
                                Icons
                                    .location_searching,
                              ),

                              const SizedBox(
                                height: 5,
                              ),

                              Text(
                                '${nearbyLocations.length}',

                                style:
                                const TextStyle(
                                  fontWeight:
                                  FontWeight
                                      .bold,

                                  fontSize: 17,
                                ),
                              ),

                              const Text(
                                'nearby',
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      // END NAVIGATION

                      SizedBox(
                        width:
                        double.infinity,

                        height: 48,

                        child:
                        ElevatedButton
                            .icon(
                          onPressed: () {
                            positionSubscription
                                ?.cancel();

                            Navigator.pop(
                              context,
                            );
                          },

                          icon:
                          const Icon(
                            Icons.stop,
                          ),

                          label:
                          const Text(
                            'END NAVIGATION',

                            style:
                            TextStyle(
                              fontWeight:
                              FontWeight
                                  .bold,
                            ),
                          ),
                        ),
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

// ==========================================================
// ROUTE DATA
// ==========================================================

class RouteData {
  final List<LatLng> points;

  final double distance;

  final double duration;

  final List<RouteStep> steps;

  RouteData({
    required this.points,
    required this.distance,
    required this.duration,
    required this.steps,
  });
}

// ==========================================================
// ROUTE STEP
// ==========================================================

class RouteStep {
  final String type;

  final String modifier;

  final String name;

  final double distance;

  RouteStep({
    required this.type,
    required this.modifier,
    required this.name,
    required this.distance,
  });
}