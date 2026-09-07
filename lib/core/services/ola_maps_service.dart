import 'dart:convert';
import 'package:http/http.dart' as http;

class OlaMapsService {
  static final OlaMapsService _instance = OlaMapsService._internal();
  factory OlaMapsService() => _instance;
  OlaMapsService._internal();

  static const String _clientId = 'cc52a296-c2a2-4edf-9225-b829ecbaf8ca';
  static const String _clientSecret = 'bf62c2a043404ab885ce7c3580a2f193';
  static const String _authUrl = 'https://account.olamaps.io/realms/olamaps/protocol/openid-connect/token';

  String? _accessToken;
  DateTime? _tokenExpiry;

  /// Fetch or return cached OAuth Access Token
  Future<String?> _getAccessToken() async {
    if (_accessToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
      return _accessToken;
    }

    try {
      final response = await http.post(
        Uri.parse(_authUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'client_credentials',
          'client_id': _clientId,
          'client_secret': _clientSecret,
          'scope': 'openid',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'] as String?;
        final expiresIn = data['expires_in'] as int? ?? 3600;
        // Buffer by 5 minutes
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 300));
        return _accessToken;
      } else {
        print("Ola Maps Auth failed: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Ola Maps Auth Error: $e");
    }
    return null;
  }

  /// Autocomplete search for Indian bus stops, colleges, landmarks & addresses
  Future<List<Map<String, dynamic>>> searchPlaces({
    required String query,
    double? latitude,
    double? longitude,
  }) async {
    if (query.trim().isEmpty) return [];

    final token = await _getAccessToken();
    if (token == null) return [];

    try {
      final lat = latitude ?? 11.0168; // Default Coimbatore / Tamil Nadu
      final lng = longitude ?? 76.9558;

      final url = Uri.parse(
        'https://api.olamaps.io/places/v1/autocomplete?input=${Uri.encodeComponent(query)}&location=$lat,$lng',
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'X-Request-Id': 'mavio-${DateTime.now().millisecondsSinceEpoch}',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final predictions = data['predictions'] as List? ?? [];
        final List<Map<String, dynamic>> results = [];

        for (var p in predictions) {
          final description = p['description']?.toString() ?? '';
          final structured = p['structured_formatting'] as Map<String, dynamic>?;
          final mainText = structured?['main_text']?.toString() ?? description.split(', ').first;
          final secondaryText = structured?['secondary_text']?.toString() ?? 
              (description.contains(', ') ? description.substring(description.indexOf(', ') + 2) : '');

          final location = p['geometry']?['location'] as Map<String, dynamic>?;
          final latVal = (location?['lat'] as num?)?.toDouble();
          final lngVal = (location?['lng'] as num?)?.toDouble();

          if (latVal != null && lngVal != null) {
            results.add({
              'title': mainText,
              'subtitle': secondaryText,
              'lat': latVal,
              'lon': lngVal,
            });
          }
        }
        return results;
      } else {
        print("Ola Maps Places failed: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Ola Maps Autocomplete Error: $e");
    }
    return [];
  }
}
