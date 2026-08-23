import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl =
      'https://unmlcvopevwwozfewawg.supabase.co';

  static const String supabaseKey =
      'sb_publishable_G0IGJsKOwvNqSYtw3TjpNw_p5_HFWzt';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
    );
  }

  static SupabaseClient get client =>
      Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getRoutes() async {
    final response = await client
        .from('routes')
        .select()
        .eq('is_active', true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getRouteStops(
      int routeId,
      ) async {
    final response = await client
        .from('route_stops')
        .select()
        .eq('route_id', routeId)
        .order('stop_order');

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getStops(
      List<int> stopIds,
      ) async {
    if (stopIds.isEmpty) {
      return [];
    }

    final response = await client
        .from('stops')
        .select()
        .inFilter('id', stopIds);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getRouteWithStops(
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

    final stops = await getStops(stopIds);

    final stopMap = <int, Map<String, dynamic>>{};

    for (final stop in stops) {
      final id = (stop['id'] as num).toInt();
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