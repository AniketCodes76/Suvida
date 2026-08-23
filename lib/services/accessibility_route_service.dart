import 'accessibility_data.dart';

class AccessibilityRouteService {
  final List<AccessibilityPoint> accessibilityPoints;

  AccessibilityRouteService({
    this.accessibilityPoints = const [],
  });

  int calculateScore({
    required bool wheelchair,
    required bool lowVision,
    required bool hearing,
  }) {
    int score = 100;

    if (accessibilityPoints.isEmpty) {
      return score;
    }

    for (final point in accessibilityPoints) {
      if (wheelchair) {
        if (point.hasStairs) {
          score -= 15;
        }

        if (point.hasRamp) {
          score += 5;
        }

        if (point.wheelchairAccessible) {
          score += 5;
        }
      }

      if (lowVision) {
        if (point.hasTactilePath) {
          score += 5;
        } else {
          score -= 5;
        }

        if (point.hasAudioSupport) {
          score += 5;
        }
      }

      if (hearing && point.hasAudioSupport) {
        score += 3;
      }
    }

    if (score < 0) {
      score = 0;
    }

    if (score > 100) {
      score = 100;
    }

    return score;
  }

  String getAccessibilitySummary({
    required int score,
  }) {
    if (score >= 85) {
      return 'Highly accessible route';
    }

    if (score >= 70) {
      return 'Good accessibility';
    }

    if (score >= 50) {
      return 'Moderate accessibility';
    }

    return 'Limited accessibility';
  }
}