import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/toast_utils.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';

class StudentStopSelectionPage extends StatefulWidget {
  final MavioProfile profile;
  const StudentStopSelectionPage({super.key, required this.profile});

  @override
  State<StudentStopSelectionPage> createState() => _StudentStopSelectionPageState();
}

class _StudentStopSelectionPageState extends State<StudentStopSelectionPage> {
  double? _selectedLat;
  double? _selectedLng;
  int _selectedRadius = 500;
  bool _isSatellite = false;
  bool _isLoadingLocation = false;
  
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _selectedLat = widget.profile.alertLatitude;
    _selectedLng = widget.profile.alertLongitude;
    _selectedRadius = widget.profile.alertRadiusMeters;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Handle Search Input Debouncing
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (query.trim().isNotEmpty) {
        _performSearch(query.trim());
      } else {
        setState(() {
          _searchResults.clear();
        });
      }
    });
  }

  // Multi-Engine Free Geocoding with Local Proximity Bias
  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
    });

    final currentLat = _selectedLat ?? 11.0168; // Default Tamil Nadu / Coimbatore
    final currentLng = _selectedLng ?? 76.9558;

    final List<Map<String, dynamic>> combinedResults = [];
    final Set<String> seenCoords = {};

    try {
      // 1. Photon Geocoder (Fast, Typo-Tolerant, Location-Biased, 100% Free)
      final photonUri = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&lat=$currentLat&lon=$currentLng&limit=8',
      );
      final photonRes = await http.get(photonUri).timeout(const Duration(seconds: 4));
      if (photonRes.statusCode == 200) {
        final data = json.decode(photonRes.body);
        final features = data['features'] as List? ?? [];
        for (var f in features) {
          final props = f['properties'] ?? {};
          final coords = f['geometry']?['coordinates'] as List? ?? [];
          if (coords.length >= 2) {
            final double lon = (coords[0] as num).toDouble();
            final double lat = (coords[1] as num).toDouble();
            final coordKey = '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';

            if (!seenCoords.contains(coordKey)) {
              seenCoords.add(coordKey);

              final name = props['name'] ?? props['street'] ?? props['city'] ?? query;
              final List<String> subParts = [];
              if (props['street'] != null && props['street'] != name) subParts.add(props['street']);
              if (props['district'] != null) subParts.add(props['district']);
              if (props['city'] != null && props['city'] != name) subParts.add(props['city']);
              if (props['state'] != null) subParts.add(props['state']);

              combinedResults.add({
                'title': name.toString(),
                'subtitle': subParts.join(', '),
                'lat': lat,
                'lon': lon,
              });
            }
          }
        }
      }
    } catch (_) {}

    // 2. Nominatim India-Scoped Fallback if Photon gave few results
    if (combinedResults.length < 5) {
      try {
        final nomUri = Uri.parse(
          'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&countrycodes=in&limit=6&addressdetails=1',
        );
        final nomRes = await http.get(
          nomUri,
          headers: {'User-Agent': 'mavio_transit_app_free/2.0'},
        ).timeout(const Duration(seconds: 4));

        if (nomRes.statusCode == 200) {
          final list = json.decode(nomRes.body) as List? ?? [];
          for (var item in list) {
            final lat = double.tryParse(item['lat']?.toString() ?? '');
            final lon = double.tryParse(item['lon']?.toString() ?? '');
            if (lat != null && lon != null) {
              final coordKey = '${lat.toStringAsFixed(4)},${lon.toStringAsFixed(4)}';
              if (!seenCoords.contains(coordKey)) {
                seenCoords.add(coordKey);
                final displayName = item['display_name']?.toString() ?? '';
                final parts = displayName.split(', ');
                final title = parts.isNotEmpty ? parts.first : query;
                final subtitle = parts.length > 1 ? parts.sublist(1, parts.length > 4 ? 4 : parts.length).join(', ') : '';

                combinedResults.add({
                  'title': title,
                  'subtitle': subtitle,
                  'lat': lat,
                  'lon': lon,
                });
              }
            }
          }
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _searchResults = combinedResults;
        _isSearching = false;
      });
    }
  }

  // Get current device GPS and center map
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final target = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _selectedLat = pos.latitude;
          _selectedLng = pos.longitude;
        });

        _mapController.move(target, 15.5);
      } else {
        AppToast.show(
          context,
          "Location permission is required to target current position",
          isError: true,
        );
      }
    } catch (e) {
      print("GPS targeting error: $e");
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    // Choose correct Google tile layer style based on Normal/Satellite toggle
    final String layerStyle = _isSatellite ? 'y' : 'm'; 

    return Scaffold(
      body: Stack(
        children: [
          // 1. Map View
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLat != null && _selectedLng != null
                  ? LatLng(_selectedLat!, _selectedLng!)
                  : const LatLng(11.025, 76.98),
              initialZoom: 15.0,
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedLat = point.latitude;
                  _selectedLng = point.longitude;
                  _searchResults.clear();
                  FocusScope.of(context).unfocus();
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://mt1.google.com/vt/lyrs=$layerStyle&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.example.mavio',
              ),
              
              // Warning Proximity radius circle
              if (_selectedLat != null && _selectedLng != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: LatLng(_selectedLat!, _selectedLng!),
                      radius: _selectedRadius.toDouble(),
                      useRadiusInMeter: true,
                      color: AppColors.primary.withOpacity(0.12),
                      borderColor: AppColors.primary.withOpacity(0.5),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),

              // Stop Location marker pin
              if (_selectedLat != null && _selectedLng != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_selectedLat!, _selectedLng!),
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: AppColors.primary,
                        size: 38,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // 2. Custom Floating Search Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: "Search your stop or location...",
                        prefixIcon: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchResults.clear();
                                  });
                                },
                              )
                            : (_isSearching 
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Padding(
                                      padding: EdgeInsets.all(12.0),
                                      child: CircularProgressIndicator(strokeWidth: 2.0),
                                    ),
                                  )
                                : const Icon(Icons.search_rounded)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),

                  // Search Results List Card Overlay
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(maxHeight: 220),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _searchResults.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _searchResults[index];
                          final title = item['title']?.toString() ?? 'Location';
                          final subtitle = item['subtitle']?.toString() ?? '';
                          final lat = (item['lat'] as num).toDouble();
                          final lon = (item['lon'] as num).toDouble();

                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
                            title: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            subtitle: subtitle.isNotEmpty
                                ? Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  )
                                : null,
                            onTap: () {
                              final target = LatLng(lat, lon);
                              setState(() {
                                _selectedLat = lat;
                                _selectedLng = lon;
                                _searchResults.clear();
                                _searchController.text = subtitle.isNotEmpty ? '$title, $subtitle' : title;
                                FocusScope.of(context).unfocus();
                              });
                              _mapController.move(target, 16.0);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 3. Floating Action buttons (Map view switcher & Target GPS)
          Positioned(
            right: 16,
            bottom: 220,
            child: Column(
              children: [
                // Normal vs Satellite toggle
                FloatingActionButton.small(
                  heroTag: "styleBtn",
                  onPressed: () {
                    setState(() {
                      _isSatellite = !_isSatellite;
                    });
                  },
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.textPrimary,
                  child: Icon(_isSatellite ? Icons.map_rounded : Icons.satellite_alt_rounded),
                ),
                const SizedBox(height: 12),
                
                // Target Current GPS Button
                FloatingActionButton.small(
                  heroTag: "gpsBtn",
                  onPressed: _getCurrentLocation,
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  child: _isLoadingLocation
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0),
                        )
                      : const Icon(Icons.my_location_rounded),
                ),
              ],
            ),
          ),

          // 4. Custom Bottom Sheet Selection Panel
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 16,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Alert Radius Limit",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.borderLight, width: 1.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedRadius,
                            items: const [
                              DropdownMenuItem(value: 500, child: Text('500m (0.5 km)')),
                              DropdownMenuItem(value: 1000, child: Text('1.0 km')),
                              DropdownMenuItem(value: 2000, child: Text('2.0 km')),
                              DropdownMenuItem(value: 5000, child: Text('5.0 km')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedRadius = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Coordinate feedback display
                  Text(
                    _selectedLat != null && _selectedLng != null
                        ? 'Lat: ${_selectedLat!.toStringAsFixed(6)}, Lng: ${_selectedLng!.toStringAsFixed(6)}'
                        : 'Tap on the map to select your stop',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: _selectedLat != null ? AppColors.textSecondary : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Confirm button
                  ElevatedButton(
                    onPressed: _selectedLat == null
                        ? null
                        : () async {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const Center(child: CircularProgressIndicator()),
                            );

                            try {
                              final db = SupabaseService();
                              await db.updateProfileAlertStop(
                                id: widget.profile.id,
                                latitude: _selectedLat,
                                longitude: _selectedLng,
                                radiusMeters: _selectedRadius,
                              );
                              
                              // Reload profile local cache
                              await auth.initialize();

                              // Pop loading
                              Navigator.of(context).pop();
                              // Pop Page back
                              Navigator.of(context).pop();

                              AppToast.show(
                                context,
                                'Stop Alert Location configured successfully!',
                                isError: false,
                              );
                            } catch (e) {
                              Navigator.of(context).pop();
                              AppToast.show(
                                context,
                                'Error saving location: $e',
                                isError: true,
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "Confirm & Save Stop",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
