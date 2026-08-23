import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'route_results_screen.dart';
import 'chatbot_screen.dart';
import 'alerts_screen.dart';
import '../sos/screens/sos_screen.dart';
import '../services/alert_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState
    extends State<HomeScreen> {
  bool wheelchair = true;
  bool lowVision = false;
  bool hearing = false;

  String destination =
      'Search for a place';

  String currentLocation =
      'Use my current location';

  bool gettingLocation = false;

  // ============================================================
  // TRANSPORT MODE
  // ============================================================

  String selectedTransport = 'Walking';

  final List<Map<String, dynamic>>
  transportModes = [
    {
      'name': 'Walking',
      'icon': Icons.directions_walk,
    },
    {
      'name': 'Public Transport',
      'icon': Icons.directions_bus,
    },
    {
      'name': 'Private Car',
      'icon': Icons.directions_car,
    },
    {
      'name': 'Auto / Taxi',
      'icon': Icons.local_taxi,
    },
    {
      'name': 'Bicycle',
      'icon': Icons.directions_bike,
    },
  ];

  // ============================================================
  // CURRENT LOCATION
  // ============================================================

  Future<void> getCurrentLocation() async {
    setState(() {
      gettingLocation = true;
    });

    try {
      final serviceEnabled =
      await Geolocator
          .isLocationServiceEnabled();

      if (!serviceEnabled) {
        await Geolocator
            .openLocationSettings();

        if (!mounted) return;

        setState(() {
          gettingLocation = false;
        });

        return;
      }

      LocationPermission permission =
      await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
        await Geolocator
            .requestPermission();
      }

      if (permission ==
          LocationPermission.denied ||
          permission ==
              LocationPermission
                  .deniedForever) {
        if (!mounted) return;

        setState(() {
          currentLocation =
          'Location permission denied';

          gettingLocation = false;
        });

        return;
      }

      final position =
      await Geolocator
          .getCurrentPosition(
        locationSettings:
        const LocationSettings(
          accuracy:
          LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        currentLocation =
        '${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)}';

        gettingLocation = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        currentLocation =
        'Unable to get location';

        gettingLocation = false;
      });
    }
  }

  // ============================================================
  // DESTINATION SEARCH
  // ============================================================

  Future<void>
  openDestinationSearch() async {
    final result =
    await showSearch<String>(
      context: context,
      delegate:
      DestinationSearchDelegate(),
    );

    if (result != null &&
        result.isNotEmpty) {
      setState(() {
        destination = result;
      });
    }
  }

  // ============================================================
  // FIND ROUTE
  // ============================================================

  void findRoute() {
    if (destination ==
        'Search for a place') {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a destination first',
          ),
        ),
      );

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            RouteResultsScreen(
              destination:
              destination,

              wheelchair:
              wheelchair,

              lowVision:
              lowVision,

              hearing:
              hearing,

              transportMode:
              selectedTransport,
            ),
      ),
    );
  }

  // ============================================================
  // CHATBOT
  // ============================================================

  void openChatbot() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
        const ChatbotScreen(),
      ),
    );
  }

  // ============================================================
  // SOS
  // ============================================================

  void openSOS() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
        const SosScreen(),
      ),
    );
  }

  // ============================================================
  // ALERTS
  // ============================================================

  void openAlerts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
        const AlertsScreen(),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFF7F9FC),

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor:
        Colors.transparent,

        elevation: 0,

        title: const Text(
          'Accessible Route Planner',
          style: TextStyle(
            fontWeight:
            FontWeight.bold,
            fontSize: 21,
          ),
        ),

        actions: [
          StreamBuilder(
            stream: AlertService
                .instance
                .alertsStream,

            initialData:
            AlertService
                .instance
                .alerts,

            builder:
                (context, snapshot) {
              final unread =
                  AlertService
                      .instance
                      .unreadCount;

              return Stack(
                children: [
                  IconButton(
                    tooltip:
                    'Alerts',

                    icon:
                    const Icon(
                      Icons
                          .notifications_outlined,
                      size: 28,
                    ),

                    onPressed:
                    openAlerts,
                  ),

                  if (unread > 0)
                    Positioned(
                      right: 5,
                      top: 5,

                      child:
                      Container(
                        padding:
                        const EdgeInsets
                            .all(4),

                        constraints:
                        const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),

                        decoration:
                        const BoxDecoration(
                          color: Colors.red,
                          shape:
                          BoxShape.circle,
                        ),

                        child: Text(
                          unread > 99
                              ? '99+'
                              : '$unread',

                          textAlign:
                          TextAlign
                              .center,

                          style:
                          const TextStyle(
                            color:
                            Colors.white,
                            fontSize: 10,
                            fontWeight:
                            FontWeight
                                .bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          const SizedBox(
            width: 8,
          ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: SafeArea(
        child:
        SingleChildScrollView(
          padding:
          const EdgeInsets.all(20),

          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              const SizedBox(
                height: 10,
              ),

              const Text(
                'Where are you going?',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              const Text(
                'Find a route that matches your accessibility needs.',
                style: TextStyle(
                  fontSize: 16,
                  color:
                  Colors.black54,
                ),
              ),

              const SizedBox(
                height: 28,
              ),

              // =================================================
              // CURRENT LOCATION
              // =================================================

              _locationBox(
                icon:
                Icons.my_location,

                title:
                'Current location',

                subtitle:
                gettingLocation
                    ? 'Getting your location...'
                    : currentLocation,

                onTap:
                getCurrentLocation,
              ),

              const SizedBox(
                height: 12,
              ),

              // =================================================
              // DESTINATION
              // =================================================

              _locationBox(
                icon: Icons.search,

                title:
                'Destination',

                subtitle:
                destination,

                onTap:
                openDestinationSearch,
              ),

              const SizedBox(
                height: 26,
              ),

              // =================================================
              // TRANSPORT MODE
              // =================================================

              const Text(
                'How are you travelling?',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              const Text(
                'Choose your mode of transport for a more accurate route and travel time.',
                style: TextStyle(
                  fontSize: 14,
                  color:
                  Colors.black54,
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              _transportSelector(),

              const SizedBox(
                height: 28,
              ),

              // =================================================
              // ACCESSIBILITY
              // =================================================

              const Text(
                'Accessibility preferences',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              _preference(
                icon:
                Icons.accessible,

                title:
                'Wheelchair accessible',

                value:
                wheelchair,

                onChanged: (value) {
                  setState(() {
                    wheelchair =
                        value;
                  });
                },
              ),

              _preference(
                icon:
                Icons.visibility,

                title:
                'Low vision',

                value:
                lowVision,

                onChanged: (value) {
                  setState(() {
                    lowVision =
                        value;
                  });
                },
              ),

              _preference(
                icon:
                Icons.hearing,

                title:
                'Hearing assistance',

                value:
                hearing,

                onChanged: (value) {
                  setState(() {
                    hearing =
                        value;
                  });
                },
              ),

              const SizedBox(
                height: 25,
              ),

              // =================================================
              // FIND ROUTE
              // =================================================

              SizedBox(
                width:
                double.infinity,

                height: 56,

                child:
                ElevatedButton.icon(
                  onPressed:
                  findRoute,

                  icon:
                  const Icon(
                    Icons.route,
                  ),

                  label:
                  const Text(
                    'FIND ACCESSIBLE ROUTE',
                    style:
                    TextStyle(
                      fontSize: 16,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 15,
              ),

              // =================================================
              // AI ASSISTANT
              // =================================================

              SizedBox(
                width:
                double.infinity,

                height: 56,

                child:
                OutlinedButton.icon(
                  onPressed:
                  openChatbot,

                  icon:
                  const Icon(
                    Icons.smart_toy,
                  ),

                  label:
                  const Text(
                    'AI ASSISTANT',
                    style:
                    TextStyle(
                      fontSize: 16,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 15,
              ),

              // =================================================
              // SOS
              // =================================================

              SizedBox(
                width:
                double.infinity,

                height: 56,

                child:
                OutlinedButton.icon(
                  onPressed:
                  openSOS,

                  icon:
                  const Icon(
                    Icons.sos,
                  ),

                  label:
                  const Text(
                    'SOS / EMERGENCY',
                    style:
                    TextStyle(
                      fontSize: 16,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TRANSPORT SELECTOR
  // ============================================================

  Widget _transportSelector() {
    return Card(
      elevation: 0,

      color: Colors.white,

      shape:
      RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(
          16,
        ),
      ),

      child: Padding(
        padding:
        const EdgeInsets.all(12),

        child: Column(
          children:
          transportModes
              .map(
                (mode) {
              final String name =
              mode['name'];

              final IconData icon =
              mode['icon'];

              final bool selected =
                  selectedTransport ==
                      name;

              return Padding(
                padding:
                const EdgeInsets.only(
                  bottom: 6,
                ),

                child: InkWell(
                  borderRadius:
                  BorderRadius
                      .circular(
                    12,
                  ),

                  onTap: () {
                    setState(() {
                      selectedTransport =
                          name;
                    });
                  },

                  child:
                  Container(
                    padding:
                    const EdgeInsets
                        .symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),

                    decoration:
                    BoxDecoration(
                      color: selected
                          ? Colors.blue
                          .withAlpha(
                        20,
                      )
                          : Colors
                          .transparent,

                      borderRadius:
                      BorderRadius
                          .circular(
                        12,
                      ),

                      border:
                      Border.all(
                        color: selected
                            ? Colors.blue
                            : Colors
                            .black12,

                        width: selected
                            ? 1.5
                            : 1,
                      ),
                    ),

                    child: Row(
                      children: [
                        Icon(
                          icon,
                          size: 27,
                        ),

                        const SizedBox(
                          width: 14,
                        ),

                        Expanded(
                          child: Text(
                            name,

                            style:
                            TextStyle(
                              fontSize: 15,
                              fontWeight:
                              selected
                                  ? FontWeight
                                  .bold
                                  : FontWeight
                                  .w500,
                            ),
                          ),
                        ),

                        if (selected)
                          const Icon(
                            Icons
                                .check_circle,
                            size: 22,
                          )
                        else
                          const Icon(
                            Icons
                                .radio_button_unchecked,
                            size: 22,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ).toList(),
        ),
      ),
    );
  }

  // ============================================================
  // LOCATION BOX
  // ============================================================

  Widget _locationBox({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius:
      BorderRadius.circular(
        16,
      ),

      onTap: onTap,

      child: Container(
        padding:
        const EdgeInsets.all(16),

        decoration:
        BoxDecoration(
          color: Colors.white,

          borderRadius:
          BorderRadius.circular(
            16,
          ),

          border: Border.all(
            color: Colors.black12,
          ),
        ),

        child: Row(
          children: [
            Icon(
              icon,
              size: 28,
            ),

            const SizedBox(
              width: 15,
            ),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,

                children: [
                  Text(
                    title,

                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  Text(
                    subtitle,

                    style:
                    const TextStyle(
                      color:
                      Colors.black54,
                    ),

                    maxLines: 1,

                    overflow:
                    TextOverflow
                        .ellipsis,
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
  // ACCESSIBILITY PREFERENCE
  // ============================================================

  Widget _preference({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool>
    onChanged,
  }) {
    return Card(
      elevation: 0,

      color: Colors.white,

      child:
      SwitchListTile(
        secondary:
        Icon(icon),

        title:
        Text(title),

        value:
        value,

        onChanged:
        onChanged,
      ),
    );
  }
}

// =================================================================
// DESTINATION SEARCH
// =================================================================

class DestinationSearchDelegate
    extends SearchDelegate<String> {
  final List<String> places = [
    'Airport',
    'Railway Station',
    'Hospital',
    'University',
    'Shopping Mall',
    'Bus Station',
    'Restaurant',
    'Park',
  ];

  @override
  List<Widget>? buildActions(
      BuildContext context,
      ) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon:
          const Icon(Icons.clear),

          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(
      BuildContext context,
      ) {
    return IconButton(
      icon:
      const Icon(Icons.arrow_back),

      onPressed: () {
        close(context, '');
      },
    );
  }

  @override
  Widget buildResults(
      BuildContext context,
      ) {
    return ListView(
      children: [
        ListTile(
          leading:
          const Icon(
            Icons.location_on,
          ),

          title:
          Text(query),

          subtitle:
          const Text(
            'Use this destination',
          ),

          onTap: () {
            close(
              context,
              query,
            );
          },
        ),
      ],
    );
  }

  @override
  Widget buildSuggestions(
      BuildContext context,
      ) {
    final suggestions =
    places
        .where(
          (place) => place
          .toLowerCase()
          .contains(
        query
            .toLowerCase(),
      ),
    )
        .toList();

    return ListView.builder(
      itemCount:
      suggestions.length,

      itemBuilder:
          (context, index) {
        final place =
        suggestions[index];

        return ListTile(
          leading:
          const Icon(
            Icons
                .location_on_outlined,
          ),

          title:
          Text(place),

          onTap: () {
            close(
              context,
              place,
            );
          },
        );
      },
    );
  }
}