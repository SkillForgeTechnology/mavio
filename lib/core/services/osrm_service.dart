import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// OSRM (Open Source Routing Machine) Service
/// Provides 100% free enterprise-grade Road Snapping, Distance Calculation,
/// and ETA estimation using OpenStreetMap road network geometry.
class OsrmMatchResult {
  final double distanceKm;
  final double durationMinutes;
  final List<LatLng> snappedPoints;

  OsrmMatchResult({
    required this.distanceKm,
    required this.durationMinutes,
    required this.snappedPoints,
  });
}

class OsrmService {
  static const String _osrmBaseUrl = 'https://router.project-osrm.org';

  /// Snap raw GPS coordinates to actual road lanes and calculate 100% exact road distance
  static Future<OsrmMatchResult?> matchTripPath(List<LatLng> rawPoints) async {
    if (rawPoints.length < 2) return null;

    try {
      // Downsample to max 80 points to fit within HTTP GET URL length limit
      List<LatLng> sampledPoints = [];
      if (rawPoints.length <= 80) {
        sampledPoints = rawPoints;
      } else {
        final step = (rawPoints.length / 80).ceil();
        for (int i = 0; i < rawPoints.length; i += step) {
          sampledPoints.add(rawPoints[i]);
        }
        if (sampledPoints.last != rawPoints.last) {
          sampledPoints.add(rawPoints.last);
        }
      }

      final coords = sampledPoints
          .map((p) => '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}')
          .join(';');

      final url = Uri.parse(
        '$_osrmBaseUrl/match/v1/driving/$coords?overview=full&geometries=geojson&steps=false',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok' && data['matchings'] != null && (data['matchings'] as List).isNotEmpty) {
          double totalMeters = 0.0;
          double totalSeconds = 0.0;

          for (var match in data['matchings']) {
            totalMeters += (match['distance'] as num).toDouble();
            totalSeconds += (match['duration'] as num).toDouble();
          }

          final snappedPoints = <LatLng>[];
          final matchings = data['matchings'] as List;
          if (matchings.isNotEmpty && matchings.first['geometry'] != null) {
            final geom = matchings.first['geometry'];
            final coordsList = geom['coordinates'] as List?;
            if (coordsList != null) {
              for (var c in coordsList) {
                if (c is List && c.length >= 2) {
                  final lon = (c[0] as num).toDouble();
                  final lat = (c[1] as num).toDouble();
                  snappedPoints.add(LatLng(lat, lon));
                }
              }
            }
          }

          return OsrmMatchResult(
            distanceKm: totalMeters / 1000.0,
            durationMinutes: totalSeconds / 60.0,
            snappedPoints: snappedPoints.isNotEmpty ? snappedPoints : rawPoints,
          );
        }
      }
    } catch (e) {
      debugPrint("OSRM Match API error: $e");
    }
    return null;
  }

  /// Calculate exact road distance and driving duration (ETA) between two points
  static Future<Map<String, dynamic>?> getRouteEta({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final coords = '${origin.longitude.toStringAsFixed(6)},${origin.latitude.toStringAsFixed(6)};${destination.longitude.toStringAsFixed(6)},${destination.latitude.toStringAsFixed(6)}';
      final url = Uri.parse(
        '$_osrmBaseUrl/route/v1/driving/$coords?overview=false',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final meters = (route['distance'] as num).toDouble();
          final seconds = (route['duration'] as num).toDouble();

          return {
            'distanceKm': meters / 1000.0,
            'durationMinutes': seconds / 60.0,
            'durationSeconds': seconds,
          };
        }
      }
    } catch (e) {
      debugPrint("OSRM Route ETA error: $e");
    }
    return null;
  }
}
