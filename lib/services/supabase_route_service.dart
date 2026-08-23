import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRouteService {
  final SupabaseClient supabase =
      Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getRouteStops(
      int routeId,
      ) async {
    final routeStops = await supabase
        .from('route_stops')
        .select()
        .eq('route_id', routeId)
        .order('stop_order');

    final List<Map<String, dynamic>> result = [];

    for (final routeStop in routeStops) {
      final stopId = routeStop['stop_id'];

      final stop = await supabase
          .from('stops')
          .select()
          .eq('id', stopId)
          .maybeSingle();

      if (stop != null) {
        result.add({
          'route_stop_id': routeStop['id'],
          'route_id': routeStop['route_id'],
          'stop_id': routeStop['stop_id'],
          'stop_order': routeStop['stop_order'],
          'estimated_arrival_minutes':
          routeStop['estimated_arrival_minutes'],
          'name': stop['name'],
          'description': stop['description'],
          'latitude': stop['latitude'],
          'longitude': stop['longitude'],
          'wheelchair_accessible':
          stop['wheelchair_accessible'],
          'lighting_level':
          stop['lighting_level'],
          'is_active': stop['is_active'],
        });
      }
    }

    return result;
  }

  Future<Map<String, dynamic>?> getRoute(
      int routeId,
      ) async {
    return await supabase
        .from('routes')
        .select()
        .eq('id', routeId)
        .maybeSingle();
  }
}