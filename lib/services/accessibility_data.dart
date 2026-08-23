class AccessibilityPoint {
  final double latitude;
  final double longitude;

  final bool wheelchairAccessible;
  final bool hasRamp;
  final bool hasStairs;
  final bool hasTactilePath;
  final bool hasAudioSupport;
  final bool hasAccessibleToilet;

  final String type;
  final String name;

  AccessibilityPoint({
    required this.latitude,
    required this.longitude,
    required this.wheelchairAccessible,
    required this.hasRamp,
    required this.hasStairs,
    required this.hasTactilePath,
    required this.hasAudioSupport,
    required this.hasAccessibleToilet,
    required this.type,
    required this.name,
  });
}