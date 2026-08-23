import 'package:supabase_flutter/supabase_flutter.dart';

class AccessibilityPreferences {
  final bool wheelchair;
  final bool avoidStairs;
  final bool lowVision;
  final bool hearingImpaired;
  final bool avoidRoughSurfaces;

  const AccessibilityPreferences({
    this.wheelchair = false,
    this.avoidStairs = false,
    this.lowVision = false,
    this.hearingImpaired = false,
    this.avoidRoughSurfaces = false,
  });

  AccessibilityPreferences copyWith({
    bool? wheelchair,
    bool? avoidStairs,
    bool? lowVision,
    bool? hearingImpaired,
    bool? avoidRoughSurfaces,
  }) {
    return AccessibilityPreferences(
      wheelchair: wheelchair ?? this.wheelchair,
      avoidStairs: avoidStairs ?? this.avoidStairs,
      lowVision: lowVision ?? this.lowVision,
      hearingImpaired: hearingImpaired ?? this.hearingImpaired,
      avoidRoughSurfaces:
      avoidRoughSurfaces ?? this.avoidRoughSurfaces,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'wheelchair': wheelchair,
      'avoidStairs': avoidStairs,
      'lowVision': lowVision,
      'hearingImpaired': hearingImpaired,
      'avoidRoughSurfaces': avoidRoughSurfaces,
    };
  }
}

class AccessibilityService {
  AccessibilityPreferences preferences =
  const AccessibilityPreferences();

  final SupabaseClient _supabase =
      Supabase.instance.client;

  void setPreferences(
      AccessibilityPreferences newPreferences,
      ) {
    preferences = newPreferences;
  }

  bool isAccessibleRoute() {
    return preferences.wheelchair ||
        preferences.avoidStairs ||
        preferences.lowVision ||
        preferences.hearingImpaired ||
        preferences.avoidRoughSurfaces;
  }

  List<String> getActivePreferences() {
    final active = <String>[];

    if (preferences.wheelchair) {
      active.add('Wheelchair accessible');
    }

    if (preferences.avoidStairs) {
      active.add('Avoid stairs');
    }

    if (preferences.lowVision) {
      active.add('Low vision support');
    }

    if (preferences.hearingImpaired) {
      active.add('Hearing assistance');
    }

    if (preferences.avoidRoughSurfaces) {
      active.add('Avoid rough surfaces');
    }

    return active;
  }

  Future<Map<String, dynamic>?> getAccessibilityInfo(
      int stopId,
      ) async {
    try {
      final response = await _supabase
          .from('accessibility_info')
          .select(
        'id,'
            'stop_id,'
            'wheelchair_accessible,'
            'ramp_available,'
            'elevator_available,'
            'tactile_path,'
            'audio_announcements,'
            'braille_signage,'
            'accessible_toilet,'
            'accessibility_notes,'
            'updated_at',
      )
          .eq('stop_id', stopId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw Exception(
        'Failed to load accessibility data: $e',
      );
    }
  }

  Future<List<Map<String, dynamic>>>
  getAllAccessibilityInfo() async {
    try {
      final response = await _supabase
          .from('accessibility_info')
          .select(
        'id,'
            'stop_id,'
            'wheelchair_accessible,'
            'ramp_available,'
            'elevator_available,'
            'tactile_path,'
            'audio_announcements,'
            'braille_signage,'
            'accessible_toilet,'
            'accessibility_notes,'
            'updated_at',
      )
          .order('stop_id');

      return List<Map<String, dynamic>>.from(
        response,
      );
    } catch (e) {
      throw Exception(
        'Failed to load accessibility data: $e',
      );
    }
  }

  int calculateScore(
      Map<String, dynamic> data,
      ) {
    int score = 0;

    if (data['wheelchair_accessible'] == true) {
      score += 20;
    }

    if (data['ramp_available'] == true) {
      score += 15;
    }

    if (data['elevator_available'] == true) {
      score += 15;
    }

    if (data['tactile_path'] == true) {
      score += 15;
    }

    if (data['audio_announcements'] == true) {
      score += 10;
    }

    if (data['braille_signage'] == true) {
      score += 10;
    }

    if (data['accessible_toilet'] == true) {
      score += 15;
    }

    return score.clamp(0, 100);
  }
}