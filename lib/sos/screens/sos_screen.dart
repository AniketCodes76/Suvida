import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_service.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  bool sosActive = false;
  bool isCountingDown = false;
  bool isGettingLocation = false;

  int countdown = 3;

  double? latitude;
  double? longitude;

  String? emergencyContactName;
  String? emergencyContactNumber;

  @override
  void initState() {
    super.initState();
    loadEmergencyContact();
  }

  Future<void> loadEmergencyContact() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      emergencyContactName =
          prefs.getString('emergency_contact_name');
      emergencyContactNumber =
          prefs.getString('emergency_contact_number');
    });
  }

  Future<void> saveEmergencyContact(
    String name,
    String number,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('emergency_contact_name', name);
    await prefs.setString('emergency_contact_number', number);

    if (!mounted) return;

    setState(() {
      emergencyContactName = name;
      emergencyContactNumber = number;
    });
  }

  Future<void> showEmergencyContactDialog() async {
    final nameController = TextEditingController(
      text: emergencyContactName ?? '',
    );

    final numberController = TextEditingController(
      text: emergencyContactNumber ?? '',
    );

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            emergencyContactName == null
                ? 'Add Emergency Contact'
                : 'Change Emergency Contact',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Contact name',
                  hintText: 'e.g. Mom',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: numberController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: 'e.g. 9876543210',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final number = numberController.text.trim();

                if (name.isEmpty || number.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please enter both name and phone number.',
                      ),
                    ),
                  );
                  return;
                }

                await saveEmergencyContact(name, number);

                if (!mounted) return;

                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Emergency contact saved.',
                    ),
                  ),
                );
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    numberController.dispose();
  }

  Future<void> activateSOS() async {
    setState(() {
      sosActive = true;
      isGettingLocation = true;
      latitude = null;
      longitude = null;
    });

    try {
      final position =
          await LocationService.getCurrentLocation();

      if (!mounted) return;

      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
        isGettingLocation = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isGettingLocation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We could not get your location. '
            'You can still call emergency services.',
          ),
        ),
      );
    }
  }

  void startSOS() {
    if (sosActive || isCountingDown) return;

    setState(() {
      isCountingDown = true;
      countdown = 3;
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted || !isCountingDown) return;

      setState(() {
        countdown = 2;
      });

      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted || !isCountingDown) return;

        setState(() {
          countdown = 1;
        });

        Future.delayed(const Duration(seconds: 1), () {
          if (!mounted || !isCountingDown) return;

          setState(() {
            isCountingDown = false;
          });

          activateSOS();
        });
      });
    });
  }

  void cancelCountdown() {
    setState(() {
      isCountingDown = false;
      countdown = 3;
    });
  }

  Future<void> callEmergencyServices() async {
    final uri = Uri(
      scheme: 'tel',
      path: '112',
    );

    try {
      final launched = await launchUrl(uri);

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to open the phone dialer.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open the phone dialer.',
          ),
        ),
      );
    }
  }

  Future<void> callEmergencyContact() async {
    if (emergencyContactNumber == null ||
        emergencyContactNumber!.isEmpty) {
      await showEmergencyContactDialog();
      return;
    }

    final uri = Uri(
      scheme: 'tel',
      path: emergencyContactNumber!,
    );

    try {
      final launched = await launchUrl(uri);

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to open the phone dialer.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open the phone dialer.',
          ),
        ),
      );
    }
  }

  String getMapsUrl() {
    return 'https://www.google.com/maps/search/?api=1'
        '&query=$latitude,$longitude';
  }

  Future<void> sendAlert() async {
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your location is not available yet.',
          ),
        ),
      );
      return;
    }

    final contact =
        emergencyContactName == null
            ? 'No emergency contact configured.'
            : 'Emergency contact: $emergencyContactName\n'
              'Phone: $emergencyContactNumber';

    final message =
        '🚨 SAFE JOURNEY SOS ALERT 🚨\n\n'
        'I may be in danger and need assistance.\n\n'
        '$contact\n\n'
        '📍 My current location:\n'
        '${getMapsUrl()}\n\n'
        'Please contact me or emergency services if necessary.';

    await SharePlus.instance.share(
      ShareParams(
        text: message,
        subject: 'Safe Journey SOS Alert',
      ),
    );
  }

  Future<void> shareLocation() async {
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your location is not available yet.',
          ),
        ),
      );
      return;
    }

    await SharePlus.instance.share(
      ShareParams(
        text:
            '📍 My current location from Safe Journey:\n'
            '${getMapsUrl()}',
        subject: 'My Current Location',
      ),
    );
  }

  void deactivateSOS() {
    setState(() {
      sosActive = false;
      isGettingLocation = false;
      latitude = null;
      longitude = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Safe Journey',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: sosActive
            ? buildActiveSOS()
            : buildHomeScreen(),
      ),
    );
  }

  Widget buildHomeScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        24,
        30,
        24,
        40,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 48,
            color: Colors.red,
          ),
          const SizedBox(height: 12),
          const Text(
            'Need help?',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Press and hold the SOS button in an emergency.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 35),
          GestureDetector(
            onLongPress: startSOS,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCountingDown
                    ? Colors.orange
                    : Colors.red,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.25),
                    blurRadius: 25,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(
                      isCountingDown
                          ? Icons.timer
                          : Icons.sos,
                      color: Colors.white,
                      size: 52,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isCountingDown
                          ? '$countdown'
                          : 'SOS',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isCountingDown
                ? 'SOS will activate in $countdown seconds'
                : 'Press and hold to activate SOS',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isCountingDown
                  ? Colors.orange.shade800
                  : Colors.black87,
            ),
          ),
          if (isCountingDown) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: cancelCountdown,
              child: const Text('CANCEL'),
            ),
          ],
          const SizedBox(height: 35),
          buildEmergencyContactCard(),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.black12,
              ),
            ),
            child: const Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.red,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'SOS can help you access emergency services, '
                    'contact a trusted person, and share your current location.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEmergencyContactCard() {
    final hasContact =
        emergencyContactName != null &&
        emergencyContactNumber != null;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: showEmergencyContactDialog,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.black12,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.red,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Emergency Contact',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasContact
                        ? emergencyContactName!
                        : 'Not configured',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (hasContact) ...[
                    const SizedBox(height: 2),
                    Text(
                      emergencyContactNumber!,
                      style: const TextStyle(
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.black45,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildActiveSOS() {
    return Container(
      color: const Color(0xFFFFF5F5),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          24,
          28,
          24,
          40,
        ),
        child: Column(
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sos,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'SOS ACTIVE',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Emergency mode is active.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 25),
            buildLocationCard(),
            const SizedBox(height: 20),
            buildActionButton(
              icon: Icons.phone,
              title: 'CALL 112',
              subtitle: 'Emergency services',
              onPressed: callEmergencyServices,
              filled: true,
            ),
            const SizedBox(height: 12),
            buildActionButton(
              icon: Icons.person,
              title: emergencyContactName == null
                  ? 'SET EMERGENCY CONTACT'
                  : 'CALL ${emergencyContactName!.toUpperCase()}',
              subtitle: emergencyContactName == null
                  ? 'Add a trusted contact'
                  : emergencyContactNumber!,
              onPressed: callEmergencyContact,
            ),
            const SizedBox(height: 12),
            buildActionButton(
              icon: Icons.campaign,
              title: 'SEND SOS ALERT',
              subtitle: 'Share your emergency details',
              onPressed: sendAlert,
            ),
            const SizedBox(height: 12),
            buildActionButton(
              icon: Icons.location_on,
              title: 'SHARE MY LOCATION',
              subtitle: 'Send your current location',
              onPressed: shareLocation,
            ),
            const SizedBox(height: 25),
            TextButton.icon(
              onPressed: deactivateSOS,
              icon: const Icon(Icons.close),
              label: const Text(
                'CANCEL SOS',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildLocationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.red.withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            isGettingLocation
                ? Icons.location_searching
                : Icons.location_on,
            color: Colors.red,
            size: 30,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Location',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                if (isGettingLocation)
                  const Text(
                    'Getting your location...',
                    style: TextStyle(
                      color: Colors.black54,
                    ),
                  )
                else if (latitude != null &&
                    longitude != null)
                  Text(
                    '${latitude!.toStringAsFixed(6)}, '
                    '${longitude!.toStringAsFixed(6)}',
                    style: const TextStyle(
                      color: Colors.black54,
                    ),
                  )
                else
                  const Text(
                    'Location unavailable',
                    style: TextStyle(
                      color: Colors.orange,
                    ),
                  ),
              ],
            ),
          ),
          if (isGettingLocation)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
        ],
      ),
    );
  }

  Widget buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
    bool filled = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 17,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(16),
                ),
              ),
              child: buildButtonContent(
                icon,
                title,
                subtitle,
              ),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 17,
                ),
                side: const BorderSide(
                  color: Colors.black12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(16),
                ),
              ),
              child: buildButtonContent(
                icon,
                title,
                subtitle,
              ),
            ),
    );
  }

  Widget buildButtonContent(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 28,
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.chevron_right,
        ),
      ],
    );
  }
}