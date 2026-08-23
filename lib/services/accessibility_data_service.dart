import 'package:supabase_flutter/supabase_flutter.dart';

class AccessibilityDataService {
  final SupabaseClient supabase =
      Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getActiveRoutes() async {
    final response = await supabase
        .from('routes')
        .select()
        .eq('is_active', true)
        .order('id');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getRouteById(
      int routeId,
      ) async {
    final response = await supabase
        .from('routes')
        .select()
        .eq('id', routeId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(response);
  }

  Future<List<Map<String, dynamic>>> getRouteStops(
      int routeId,
      ) async {
    final response = await supabase
        .from('route_stops')
        .select()
        .eq('route_id', routeId)
        .order('stop_order');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getStopsByIds(
      List<int> stopIds,
      ) async {
    if (stopIds.isEmpty) {
      return [];
    }

    final response = await supabase
        .from('stops')
        .select()
        .inFilter('id', stopIds);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getStopsForRoute(
      int routeId,
      ) async {
    final routeStops =
    await getRouteStops(routeId);

    if (routeStops.isEmpty) {
      return [];
    }

    final stopIds = routeStops
        .map(
          (routeStop) =>
          (routeStop['stop_id'] as num).toInt(),
    )
        .toList();

    final stops =
    await getStopsByIds(stopIds);

    final stopMap =
    <int, Map<String, dynamic>>{};

    for (final stop in stops) {
      final id =
      (stop['id'] as num).toInt();

      stopMap[id] = stop;
    }

    final result =
    <Map<String, dynamic>>[];

    for (final routeStop in routeStops) {
      final stopId =
      (routeStop['stop_id'] as num).toInt();

      final stop = stopMap[stopId];

      if (stop == null) {
        continue;
      }

      result.add({
        'route_stop': routeStop,
        'stop': stop,
      });
    }

    return result;
  }
}