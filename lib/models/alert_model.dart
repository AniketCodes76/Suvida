enum AlertType {
  routeDeviation,
  accessibilityHazard,
  unsafeArea,
  geopulseZone,
  gpsAccuracy,
  emergency,
  system,
}

enum AlertSeverity {
  critical,
  warning,
  info,
}

enum AlertSource {
  gps,
  geopulse,
  route,
  accessibility,
  sos,
  system,
}

class AlertModel {
  final String id;
  final AlertType type;
  final AlertSeverity severity;
  final String title;
  final String message;
  final AlertSource source;
  final DateTime timestamp;

  final double? latitude;
  final double? longitude;

  final Map<String, dynamic> metadata;

  bool acknowledged;
  bool dismissed;

  AlertModel({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    required this.source,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.metadata = const {},
    this.acknowledged = false,
    this.dismissed = false,
  });
}