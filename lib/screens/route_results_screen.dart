import 'package:flutter/material.dart';

import '../services/accessibility_service.dart';
import 'navigation_screen.dart';
import 'map_screen.dart';

class RouteResultsScreen extends StatefulWidget {
  final String destination;
  final bool wheelchair;
  final bool lowVision;
  final bool hearing;
  final String transportMode;

  const RouteResultsScreen({
    super.key,
    required this.destination,
    required this.wheelchair,
    required this.lowVision,
    required this.hearing,
    required this.transportMode,
  });

  @override
  State<RouteResultsScreen> createState() =>
      _RouteResultsScreenState();
}

class _RouteResultsScreenState
    extends State<RouteResultsScreen> {
  List<RouteData> routes = [];

  Map<String, dynamic>? accessibilityData;

  bool loadingAccessibility = true;

  String? accessibilityError;

  int? currentStopId;

  @override
  void initState() {
    super.initState();
  }

  // ============================================================
  // ACCESSIBILITY DATA FROM MAP
  // ============================================================

  void updateAccessibilityStop(
      Map<String, dynamic>? data,
      ) {
    if (!mounted) {
      return;
    }

    if (data == null) {
      setState(() {
        accessibilityData = null;
        currentStopId = null;
        loadingAccessibility = false;
        accessibilityError =
        'No accessibility stop found near this route.';
      });

      return;
    }

    final stopId =
    int.tryParse(data['stop_id']?.toString() ?? '');

    setState(() {
      accessibilityData = data;
      currentStopId = stopId;
      loadingAccessibility = false;
      accessibilityError = null;
    });
  }

  int _calculateAccessibilityScore() {
    if (accessibilityData == null) {
      return 0;
    }

    final service = AccessibilityService();

    return service.calculateScore(
      accessibilityData!,
    );
  }

  String _scoreDescription(int score) {
    if (score >= 90) {
      return 'Excellent accessibility';
    }

    if (score >= 75) {
      return 'Highly accessible';
    }

    if (score >= 50) {
      return 'Moderately accessible';
    }

    if (score >= 25) {
      return 'Limited accessibility';
    }

    return 'Poor accessibility';
  }

  // ============================================================
  // TRANSPORT MODE
  // ============================================================

  IconData _transportIcon() {
    final mode = widget.transportMode.toLowerCase();

    if (mode.contains('walk')) {
      return Icons.directions_walk;
    }

    if (mode.contains('bus') ||
        mode.contains('public')) {
      return Icons.directions_bus;
    }

    if (mode.contains('auto') ||
        mode.contains('rickshaw') ||
        mode.contains('taxi')) {
      return Icons.local_taxi;
    }

    if (mode.contains('car') ||
        mode.contains('private')) {
      return Icons.directions_car;
    }

    if (mode.contains('bike') ||
        mode.contains('cycle')) {
      return Icons.directions_bike;
    }

    if (mode.contains('train') ||
        mode.contains('metro')) {
      return Icons.train;
    }

    return Icons.directions;
  }

  String _transportDisplayName() {
    final mode = widget.transportMode.trim();

    if (mode.isEmpty) {
      return 'Driving';
    }

    return mode;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final accessibilityScore =
    _calculateAccessibilityScore();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),

      appBar: AppBar(
        title: const Text(
          'Accessible Routes',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      body: Column(
        children: [
          // ======================================================
          // MAP
          // ======================================================

          Expanded(
            flex: 6,
            child: Container(
              margin: const EdgeInsets.fromLTRB(
                16,
                4,
                16,
                12,
              ),
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius:
                BorderRadius.circular(20),
              ),

              child: MapScreen(
                destination: widget.destination,
                transportMode: widget.transportMode,

                onRoutesFound: (foundRoutes) {
                  if (!mounted) {
                    return;
                  }

                  setState(() {
                    routes = foundRoutes;
                  });
                },

                // NEW:
                // MapScreen will find the most relevant
                // accessibility stop dynamically.
                onAccessibilityStopFound:
                updateAccessibilityStop,
              ),
            ),
          ),

          // ======================================================
          // INFORMATION PANEL
          // ======================================================

          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                16,
                0,
                16,
                20,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recommended route',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  _transportModeCard(),

                  const SizedBox(height: 12),

                  _accessibilityScoreCard(
                    accessibilityScore,
                  ),

                  const SizedBox(height: 12),

                  _databaseAccessibilityCard(),

                  const SizedBox(height: 12),

                  // ==================================================
                  // ROUTES
                  // ==================================================

                  if (routes.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child:
                              CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 14),
                            Text(
                              'Calculating route...',
                            ),
                          ],
                        ),
                      ),
                    ),

                  for (
                  int i = 0;
                  i < routes.length;
                  i++
                  ) ...[
                    _routeCard(
                      title: i == 0
                          ? 'Recommended Route'
                          : i == 1
                          ? 'Alternative Route'
                          : 'Route ${i + 1}',
                      time: formatDuration(
                        routes[i].duration,
                      ),
                      distance: formatDistance(
                        routes[i].distance,
                      ),
                      icon: _transportIcon(),
                      recommended: i == 0,
                      score: i == 0
                          ? accessibilityScore
                          : (accessibilityScore -
                          (i * 8))
                          .clamp(0, 100),
                    ),

                    if (i < routes.length - 1)
                      const SizedBox(height: 10),
                  ],

                  const SizedBox(height: 16),

                  // ==================================================
                  // ACCESSIBILITY PREFERENCES
                  // ==================================================

                  const Text(
                    'Accessibility preferences',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  if (widget.wheelchair)
                    _infoRow(
                      Icons.accessible,
                      'Wheelchair accessible',
                    ),

                  if (widget.lowVision)
                    _infoRow(
                      Icons.visibility,
                      'Low vision support',
                    ),

                  if (widget.hearing)
                    _infoRow(
                      Icons.hearing,
                      'Hearing assistance',
                    ),

                  if (!widget.wheelchair &&
                      !widget.lowVision &&
                      !widget.hearing)
                    _infoRow(
                      Icons.route,
                      'Standard accessibility',
                    ),

                  const SizedBox(height: 10),

                  // ==================================================
                  // ROUTE ACCESSIBILITY
                  // ==================================================

                  const Text(
                    'Route accessibility',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  _infoRow(
                    Icons.stairs,
                    'Stairs avoided',
                  ),

                  if (widget.wheelchair)
                    _infoRow(
                      Icons.accessible,
                      'Wheelchair-friendly preference applied',
                    ),

                  if (widget.lowVision)
                    _infoRow(
                      Icons.visibility,
                      'Low-vision friendly path prioritized',
                    ),

                  if (widget.hearing)
                    _infoRow(
                      Icons.hearing,
                      'Hearing assistance considered',
                    ),

                  _infoRow(
                    _transportIcon(),
                    '${_transportDisplayName()} route selected',
                  ),

                  const SizedBox(height: 14),

                  // ==================================================
                  // START NAVIGATION
                  // ==================================================

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: routes.isEmpty
                          ? null
                          : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                NavigationScreen(
                                  destination:
                                  widget.destination,
                                ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.navigation,
                      ),
                      label: const Text(
                        'START NAVIGATION',
                        style: TextStyle(
                          fontWeight:
                          FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TRANSPORT MODE CARD
  // ============================================================

  Widget _transportModeCard() {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius:
                BorderRadius.circular(14),
              ),
              child: Icon(
                _transportIcon(),
                size: 28,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transport mode',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    _transportDisplayName(),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    'Using ${_transportDisplayName().toLowerCase()} routing',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DATABASE ACCESSIBILITY CARD
  // ============================================================

  Widget _databaseAccessibilityCard() {
    if (loadingAccessibility) {
      return const Card(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Finding nearby accessibility information...',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (accessibilityError != null) {
      return Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 25,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Unable to load accessibility information.',
                      style: TextStyle(
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                accessibilityError!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (accessibilityData == null) {
      return const Card(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No accessibility information available '
                'near this route.',
          ),
        ),
      );
    }

    final data = accessibilityData!;

    final score =
    _calculateAccessibilityScore();

    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.accessibility_new,
                  size: 25,
                ),

                const SizedBox(width: 10),

                const Expanded(
                  child: Text(
                    'Accessibility Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),

                Text(
                  '$score/100',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Text(
              'Live data from Supabase • '
                  'Stop ${data['stop_id'] ?? 'Unknown'}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              _scoreDescription(score),
              style: const TextStyle(
                fontSize: 13,
                fontWeight:
                FontWeight.w600,
              ),
            ),

            const SizedBox(height: 12),

            _databaseInfoRow(
              Icons.accessible,
              'Wheelchair accessible',
              data['wheelchair_accessible'] == true,
            ),

            _databaseInfoRow(
              Icons.elevator,
              'Elevator available',
              data['elevator_available'] == true,
            ),

            _databaseInfoRow(
              Icons.escalator,
              'Ramp available',
              data['ramp_available'] == true,
            ),

            _databaseInfoRow(
              Icons.directions_walk,
              'Tactile path',
              data['tactile_path'] == true,
            ),

            _databaseInfoRow(
              Icons.volume_up,
              'Audio announcements',
              data['audio_announcements'] == true,
            ),

            _databaseInfoRow(
              Icons.menu_book,
              'Braille signage',
              data['braille_signage'] == true,
            ),

            _databaseInfoRow(
              Icons.wc,
              'Accessible toilet',
              data['accessible_toilet'] == true,
            ),

            if (data['accessibility_notes'] != null) ...[
              const SizedBox(height: 12),

              Text(
                data['accessibility_notes'].toString(),
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DATABASE INFO ROW
  // ============================================================

  Widget _databaseInfoRow(
      IconData icon,
      String title,
      bool available,
      ) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 21,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),

          Icon(
            available
                ? Icons.check_circle
                : Icons.cancel,
            size: 20,
          ),

          const SizedBox(width: 4),

          Text(
            available ? 'Yes' : 'No',
            style: const TextStyle(
              fontSize: 13,
              fontWeight:
              FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACCESSIBILITY SCORE CARD
  // ============================================================

  Widget _accessibilityScoreCard(
      int score,
      ) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child:
                    CircularProgressIndicator(
                      value: score / 100,
                      strokeWidth: 7,
                      backgroundColor:
                      Colors.black12,
                    ),
                  ),

                  Text(
                    '$score',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Accessibility Score',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    _scoreDescription(score),
                    style: const TextStyle(
                      color: Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    currentStopId == null
                        ? 'Based on nearby accessibility data'
                        : 'Based on Supabase data for Stop $currentStopId',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ROUTE CARD
  // ============================================================

  Widget _routeCard({
    required String title,
    required String time,
    required String distance,
    required IconData icon,
    required bool recommended,
    required int score,
  }) {
    final safeScore =
    score.clamp(0, 100);

    return Card(
      elevation: recommended ? 3 : 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(16),
        side: BorderSide(
          color: recommended
              ? Colors.blue
              : Colors.black12,
          width: recommended ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 30,
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style:
                          const TextStyle(
                            fontSize: 16,
                            fontWeight:
                            FontWeight.bold,
                          ),
                        ),
                      ),

                      if (recommended) ...[
                        const SizedBox(width: 8),

                        Container(
                          padding:
                          const EdgeInsets
                              .symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration:
                          BoxDecoration(
                            color: Colors.blue
                                .withOpacity(0.1),
                            borderRadius:
                            BorderRadius
                                .circular(8),
                          ),
                          child:
                          const Text(
                            'BEST',
                            style:
                            TextStyle(
                              fontSize: 10,
                              fontWeight:
                              FontWeight
                                  .bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 5),

                  Text(
                    '$time • $distance',
                    style:
                    const TextStyle(
                      color: Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    'Accessibility: '
                        '$safeScore/100',
                    style:
                    const TextStyle(
                      fontSize: 13,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget _infoRow(
      IconData icon,
      String text,
      ) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 21,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FORMATTING
  // ============================================================

  String formatDistance(
      double meters,
      ) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }

    return '${meters.round()} m';
  }

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
}