import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/toast_utils.dart';
import '../../models/models.dart';

class StudentStopGroup {
  final int stopIndex;
  final LatLng position;
  final List<MavioProfile> students;
  bool isVisited;

  StudentStopGroup({
    required this.stopIndex,
    required this.position,
    required this.students,
    this.isVisited = false,
  });

  String get displayName => 'Stop #$stopIndex';
}

class DriverLiveNavigationScreen extends StatefulWidget {
  final MavioVehicle vehicle;
  final MavioTrip? activeTrip;
  final VoidCallback onTripEnded;
  final VoidCallback? onStartTrip;
  final bool isEmbeddedTab;

  const DriverLiveNavigationScreen({
    super.key,
    required this.vehicle,
    this.activeTrip,
    required this.onTripEnded,
    this.onStartTrip,
    this.isEmbeddedTab = false,
  });

  @override
  State<DriverLiveNavigationScreen> createState() => _DriverLiveNavigationScreenState();
}

class _DriverLiveNavigationScreenState extends State<DriverLiveNavigationScreen> {
  final SupabaseService _db = SupabaseService();
  final MapController _mapController = MapController();

  StreamSubscription<Position>? _positionStream;
  LatLng? _currentBusLocation;
  double _currentSpeedKmH = 0.0;
  double _currentHeading = 0.0;
  bool _isLoadingStudents = true;
  bool _isEndingTrip = false;
  bool _autoCenter = true;

  List<StudentStopGroup> _stops = [];
  StudentStopGroup? _selectedStop;
  StudentStopGroup? _nextUpcomingStop;

  Timer? _etaTimer;

  @override
  void initState() {
    super.initState();
    _fetchAssignedStudents();
    _initLiveGpsTracking();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _etaTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAssignedStudents() async {
    setState(() => _isLoadingStudents = true);
    try {
      final students = await _db.getAssignedStudentsForVehicle(widget.vehicle.id);
      
      // Filter students with valid alert coordinates
      final studentsWithStops = students
          .where((s) => s.alertLatitude != null && s.alertLongitude != null)
          .toList();

      // Cluster students into distinct stops (threshold: ~80 meters)
      final List<StudentStopGroup> groupedStops = [];
      int stopNumber = 1;

      for (final student in studentsWithStops) {
        final studentPos = LatLng(student.alertLatitude!, student.alertLongitude!);
        
        bool addedToExisting = false;
        for (final group in groupedStops) {
          final dist = _calculateDistance(
            group.position.latitude,
            group.position.longitude,
            studentPos.latitude,
            studentPos.longitude,
          );
          if (dist <= 80) { // within 80 meters
            group.students.add(student);
            addedToExisting = true;
            break;
          }
        }

        if (!addedToExisting) {
          groupedStops.add(StudentStopGroup(
            stopIndex: stopNumber++,
            position: studentPos,
            students: [student],
          ));
        }
      }

      setState(() {
        _stops = groupedStops;
        _isLoadingStudents = false;
        _updateNextUpcomingStop();
      });

      // Fit map bounds if stops exist
      if (_stops.isNotEmpty && _currentBusLocation == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fitAllStopsOnMap();
        });
      }
    } catch (e) {
      setState(() => _isLoadingStudents = false);
    }
  }

  void _initLiveGpsTracking() async {
    try {
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null && mounted) {
        setState(() {
          _currentBusLocation = LatLng(lastPos.latitude, lastPos.longitude);
          _currentSpeedKmH = math.max(0, lastPos.speed * 3.6);
          _currentHeading = lastPos.heading;
          _updateNextUpcomingStop();
        });
      }

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      );

      _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
          .listen((Position pos) {
        if (!mounted) return;
        setState(() {
          _currentBusLocation = LatLng(pos.latitude, pos.longitude);
          _currentSpeedKmH = math.max(0, pos.speed * 3.6);
          _currentHeading = pos.heading;
          _updateNextUpcomingStop();
        });

        if (_autoCenter && _currentBusLocation != null) {
          _mapController.move(_currentBusLocation!, _mapController.camera.zoom);
        }
      });
    } catch (_) {}
  }

  void _updateNextUpcomingStop() {
    if (_currentBusLocation == null || _stops.isEmpty) return;

    StudentStopGroup? closest;
    double minDistance = double.infinity;

    for (final stop in _stops) {
      if (stop.isVisited) continue;
      final dist = _calculateDistance(
        _currentBusLocation!.latitude,
        _currentBusLocation!.longitude,
        stop.position.latitude,
        stop.position.longitude,
      );
      if (dist < minDistance) {
        minDistance = dist;
        closest = stop;
      }
    }

    _nextUpcomingStop = closest;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000; // meters
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final deltaPhi = (lat2 - lat1) * math.pi / 180;
    final deltaLambda = (lon2 - lon1) * math.pi / 180;

    final a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(phi1) * math.cos(phi2) *
        math.sin(deltaLambda / 2) * math.sin(deltaLambda / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  void _fitAllStopsOnMap() {
    if (_stops.isEmpty && _currentBusLocation == null) return;

    final List<LatLng> points = [];
    if (_currentBusLocation != null) points.add(_currentBusLocation!);
    for (final s in _stops) {
      points.add(s.position);
    }

    if (points.length == 1) {
      _mapController.move(points.first, 15.0);
      return;
    }

    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(70),
      ),
    );
  }

  Future<void> _openGoogleMapsNavigation(LatLng dest) async {
    final googleNavUri = Uri.parse('google.navigation:q=${dest.latitude},${dest.longitude}&mode=d');
    final webMapsUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${dest.latitude},${dest.longitude}&travelmode=driving');

    try {
      if (await canLaunchUrl(googleNavUri)) {
        await launchUrl(googleNavUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webMapsUri)) {
        await launchUrl(webMapsUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          AppToast.show(context, 'Could not open maps navigation.', isError: true);
        }
      }
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Could not open maps navigation.', isError: true);
      }
    }
  }

  Future<void> _callStudent(String? phone) async {
    if (phone == null || phone.trim().isEmpty) {
      AppToast.show(context, 'No phone number available for this student.', isError: true);
      return;
    }
    final telUri = Uri.parse('tel:${phone.trim()}');
    try {
      if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
      }
    } catch (_) {}
  }

  void _showStopDetailsSheet(StudentStopGroup stop) {
    setState(() {
      _selectedStop = stop;
    });

    double? distFromBus;
    if (_currentBusLocation != null) {
      distFromBus = _calculateDistance(
        _currentBusLocation!.latitude,
        _currentBusLocation!.longitude,
        stop.position.latitude,
        stop.position.longitude,
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle pill
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stop Title & Status
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: stop.isVisited ? AppColors.success.withOpacity(0.15) : AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              stop.isVisited ? Icons.check_circle_rounded : Icons.location_on_rounded,
                              size: 16,
                              color: stop.isVisited ? AppColors.success : AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              stop.displayName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: stop.isVisited ? AppColors.success : AppColors.primary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (distFromBus != null)
                        Text(
                          '~ ${_formatDistance(distFromBus)} away',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Student count & list
                  Text(
                    '${stop.students.length} Student${stop.students.length > 1 ? 's' : ''} Boarding Here',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // List of Students at this stop
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: stop.students.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderLight),
                      itemBuilder: (context, index) {
                        final s = stop.students[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.primaryLight,
                                child: Text(
                                  s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (s.rollNumber != null && s.rollNumber!.isNotEmpty)
                                      Text(
                                        'Roll: ${s.rollNumber}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (s.phone != null && s.phone!.isNotEmpty)
                                IconButton(
                                  onPressed: () => _callStudent(s.phone),
                                  icon: const Icon(Icons.phone_rounded, color: AppColors.primary, size: 20),
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.primaryLight,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Actions: Toggle visited & Navigate with Google Maps
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              stop.isVisited = !stop.isVisited;
                              _updateNextUpcomingStop();
                            });
                            setSheetState(() {});
                            Navigator.pop(ctx);
                          },
                          icon: Icon(
                            stop.isVisited ? Icons.replay_rounded : Icons.check_rounded,
                            size: 18,
                            color: stop.isVisited ? AppColors.textSecondary : AppColors.success,
                          ),
                          label: Text(
                            stop.isVisited ? 'Mark Unreached' : 'Mark Reached',
                            style: TextStyle(
                              color: stop.isVisited ? AppColors.textSecondary : AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: stop.isVisited ? AppColors.border : AppColors.success,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _openGoogleMapsNavigation(stop.position);
                          },
                          icon: const Icon(Icons.navigation_rounded, size: 18),
                          label: const Text(
                            'Navigate',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAllStopsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Route Stops (${_stops.length})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_stops.fold<int>(0, (sum, s) => sum + s.students.length)} Total Students',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: _stops.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Text(
                            'No student pickup stops have been set for this bus yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _stops.length,
                        itemBuilder: (context, index) {
                          final stop = _stops[index];
                          double? dist;
                          if (_currentBusLocation != null) {
                            dist = _calculateDistance(
                              _currentBusLocation!.latitude,
                              _currentBusLocation!.longitude,
                              stop.position.latitude,
                              stop.position.longitude,
                            );
                          }
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: stop.isVisited ? AppColors.success.withOpacity(0.3) : AppColors.border,
                                width: stop.isVisited ? 1.5 : 1,
                              ),
                            ),
                            child: ListTile(
                              onTap: () {
                                Navigator.pop(ctx);
                                _mapController.move(stop.position, 16.0);
                                _showStopDetailsSheet(stop);
                              },
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: stop.isVisited ? AppColors.success : AppColors.primary,
                                child: Text(
                                  '${stop.stopIndex}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              title: Text(
                                stop.displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  decoration: stop.isVisited ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              subtitle: Text(
                                '${stop.students.length} student${stop.students.length > 1 ? 's' : ''}${dist != null ? ' • ${_formatDistance(dist)}' : ''}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.navigation_rounded, color: AppColors.primary, size: 20),
                                onPressed: () => _openGoogleMapsNavigation(stop.position),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmEndTrip() async {
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('End Live Trip?'),
        content: const Text(
          'Are you sure you want to complete this trip? Live GPS streaming for students will be stopped.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('End Trip'),
          ),
        ],
      ),
    );

    if (shouldEnd == true && mounted) {
      setState(() => _isEndingTrip = true);
      widget.onTripEnded();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultPos = _currentBusLocation ?? const LatLng(11.0168, 76.9558);

    return Scaffold(
      body: Stack(
        children: [
          // 1. Fullscreen Interactive Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: defaultPos,
              initialZoom: 14.5,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture && _autoCenter) {
                  setState(() => _autoCenter = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                subdomains: const ['0', '1', '2', '3'],
                userAgentPackageName: 'app.skillforge.mavio',
                tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 100)),
                panBuffer: 1,
                keepBuffer: 3,
                maxZoom: 20,
              ),

              // Student Stop Markers & Live Bus Marker
              MarkerLayer(
                markers: [
                  // Stop Markers
                  ..._stops.map((stop) {
                    final isSelected = _selectedStop == stop;
                    return Marker(
                      point: stop.position,
                      width: 48,
                      height: 56,
                      child: GestureDetector(
                        onTap: () => _showStopDetailsSheet(stop),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: stop.isVisited
                                    ? AppColors.success
                                    : (isSelected ? Colors.black : AppColors.primary),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '#${stop.stopIndex}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Icon(
                                    Icons.person_rounded,
                                    size: 10,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                  Text(
                                    '${stop.students.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.location_on_rounded,
                              size: 32,
                              color: stop.isVisited
                                  ? AppColors.success
                                  : (isSelected ? Colors.black : AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // Bus Live Location Marker
                  if (_currentBusLocation != null)
                    Marker(
                      point: _currentBusLocation!,
                      width: 52,
                      height: 52,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Radar Pulse Ring
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withOpacity(0.2),
                            ),
                          ),
                          // Bus Icon Circle
                          Transform.rotate(
                            angle: (_currentHeading * math.pi / 180),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.directions_bus_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),

          // 2. Top Floating Navigation HUD
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Row(
                  children: [
                    // Back / Minimize button
                    if (!widget.isEmbeddedTab) ...[
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        elevation: 3,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(Icons.arrow_back_rounded, size: 22, color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],

                    // Next Stop Info Pill
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.flag_rounded, size: 16, color: AppColors.primary),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _nextUpcomingStop != null
                                        ? 'Next: ${_nextUpcomingStop!.displayName}'
                                        : (_stops.isEmpty ? 'No stops assigned' : 'All stops completed!'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_nextUpcomingStop != null && _currentBusLocation != null)
                                    Text(
                                      '${_nextUpcomingStop!.students.length} students • ${_formatDistance(_calculateDistance(_currentBusLocation!.latitude, _currentBusLocation!.longitude, _nextUpcomingStop!.position.latitude, _nextUpcomingStop!.position.longitude))} away',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Speedometer Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentSpeedKmH.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const Text(
                            'km/h',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 3. Floating Quick Action Controls (Right side)
          Positioned(
            right: 16,
            bottom: 120,
            child: Column(
              children: [
                // Recenter / Lock to Bus Location
                FloatingActionButton.small(
                  heroTag: 'recenter_bus',
                  onPressed: () {
                    if (_currentBusLocation != null) {
                      setState(() => _autoCenter = true);
                      _mapController.move(_currentBusLocation!, 16.0);
                    }
                  },
                  backgroundColor: _autoCenter ? AppColors.primary : Colors.white,
                  foregroundColor: _autoCenter ? Colors.white : AppColors.textPrimary,
                  child: const Icon(Icons.my_location_rounded, size: 20),
                ),
                const SizedBox(height: 10),

                // Fit All Stops
                FloatingActionButton.small(
                  heroTag: 'fit_stops',
                  onPressed: _fitAllStopsOnMap,
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.textPrimary,
                  child: const Icon(Icons.map_rounded, size: 20),
                ),
              ],
            ),
          ),

          // 4. Bottom Navigation & Action Bar
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // View All Stops Button
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      onPressed: _showAllStopsModal,
                      icon: const Icon(Icons.format_list_bulleted_rounded, size: 18),
                      label: Text(
                        'Stops (${_stops.where((s) => !s.isVisited).length}/${_stops.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // End Trip Button
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: _isEndingTrip ? null : _confirmEndTrip,
                      icon: const Icon(Icons.stop_circle_rounded, size: 18, color: AppColors.error),
                      label: const Text(
                        'End Trip',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AppColors.error,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.error, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
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
