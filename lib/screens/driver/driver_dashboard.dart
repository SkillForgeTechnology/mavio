import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:intl/intl.dart' as intl;
import '../../providers/auth_provider.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/theme.dart';
import '../../models/models.dart';
import '../auth/splash_screen.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  final SupabaseService _db = SupabaseService();
  
  bool _isLoading = false;
  MavioVehicle? _assignedVehicle;
  List<MavioTrip> _tripHistory = [];
  String _thisMonthDuration = "0h 0m";

  MavioTrip? _activeTrip;

  // Tracking details
  bool _isTripActive = false;
  StreamSubscription<Position>? _gpsSubscription;
  StreamSubscription? _backgroundSubscription;
  double _currentSpeed = 0.0;
  int _pingsSent = 0;
  int _tripSeconds = 0;
  Timer? _tripDurationTimer;

  // Status Indicators
  bool _isGpsOn = false;
  bool _isInternetOn = true; // Assume online for demo

  @override
  void initState() {
    super.initState();
    _loadDriverDetails();
    _checkGpsStatus();
  }

  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }

  Future<void> _loadDriverDetails() async {
    setState(() {
      _isLoading = true;
    });

    final profile = Provider.of<AuthProvider>(context, listen: false).currentProfile;
    if (profile != null) {
      if (profile.assignedVehicleId != null) {
        // Mock / Fetch vehicle and route details
        final data = await _db.getStudentDashboardData(); // driver shares similar metadata lookup
        setState(() {
          _assignedVehicle = data['vehicle'] as MavioVehicle?;

          _activeTrip = data['activeTrip'] as MavioTrip?;
          _isTripActive = _activeTrip != null;
        });

        // Resume tracking if trip was left active
        if (_isTripActive) {
          _startTracking(_activeTrip!.id);
        }
      }

      // Fetch Drive History
      final history = await _db.getDriverTripHistory(profile.id);
      setState(() {
        _tripHistory = history;
        _calculateMonthlyTotal();
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _calculateMonthlyTotal() {
    final now = DateTime.now();
    int totalSeconds = 0;
    for (var trip in _tripHistory) {
      if (trip.status == 'COMPLETED' && trip.endedAt != null) {
        if (trip.startedAt.month == now.month && trip.startedAt.year == now.year) {
          totalSeconds += trip.endedAt!.difference(trip.startedAt).inSeconds;
        }
      }
    }
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    setState(() {
      _thisMonthDuration = '${hours}h ${minutes}m';
    });
  }

  Future<void> _checkGpsStatus() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    setState(() {
      _isGpsOn = serviceEnabled;
    });
  }

  // Request Permission and Start Trip
  void _toggleTrip() async {
    if (_isTripActive) {
      _endActiveTrip();
    } else {
      _startNewTrip();
    }
  }

  Future<void> _startNewTrip() async {
    if (_assignedVehicle == null) {
      _showSnackbar("No vehicle assigned to this driver.", AppColors.error);
      return;
    }

    // 1. Verify Internet Connection
    bool hasInternet = false;
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        hasInternet = true;
      }
    } catch (_) {
      hasInternet = false;
    }

    if (!hasInternet) {
      _showSnackbar("No internet connection. Please connect to internet to start trip.", AppColors.error);
      return;
    }

    // 2. Verify Location Service is Enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackbar("Location services (GPS) are disabled. Please enable them in settings.", AppColors.error);
      return;
    }

    // 3. Verify Location Permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackbar("Location permissions are required for GPS tracking.", AppColors.error);
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showSnackbar("Location permissions are permanently denied. Please enable in settings.", AppColors.error);
      return;
    }

    // 4. Request Notification Permission for Foreground Service on Android 13+
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (status != PermissionStatus.granted) {
        final result = await Permission.notification.request();
        if (result != PermissionStatus.granted) {
          _showSnackbar(
            "Notification permission is required to run location updates in the background.",
            AppColors.error,
          );
          return; // Block service initialization to prevent OS crash
        }
      }
    }

    // 5. Request Background Location Permission on Android 10+
    if (Platform.isAndroid) {
      final backgroundStatus = await Permission.locationAlways.status;
      if (backgroundStatus != PermissionStatus.granted) {
        final result = await Permission.locationAlways.request();
        if (result != PermissionStatus.granted) {
          _showSnackbar(
            "Background Location access is recommended to keep tracking when the screen is locked.",
            AppColors.warning,
          );
        }
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final trip = await _db.startTrip(_assignedVehicle!.id);
      setState(() {
        _activeTrip = trip;
        _isTripActive = true;
      });

      _startTracking(trip.id);
      _showSnackbar("Trip started successfully!", AppColors.success);
    } catch (e) {
      _showSnackbar(e.toString(), AppColors.error);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _endActiveTrip() async {
    if (_activeTrip == null || _assignedVehicle == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _db.endTrip(_activeTrip!.id, _assignedVehicle!.id);
      _stopTracking();
      await _loadDriverDetails();
      setState(() {
        _activeTrip = null;
        _isTripActive = false;
      });
      _showSnackbar("Trip completed successfully.", AppColors.primary);
    } catch (e) {
      _showSnackbar(e.toString(), AppColors.error);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Core tracking router
  void _startTracking(String tripId) async {
    _stopTracking(); // Ensure cleanup

    // Calculate elapsed duration if resuming from an active session
    int initialSeconds = 0;
    if (_activeTrip != null) {
      initialSeconds = DateTime.now().difference(_activeTrip!.startedAt).inSeconds;
      if (initialSeconds < 0) initialSeconds = 0;
    }

    setState(() {
      _currentSpeed = 0.0;
      _pingsSent = 0;
      _tripSeconds = initialSeconds;
    });

    _tripDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _tripSeconds++;
        });
      }
    });

    // Start background location service and pass tracking info
    final backgroundService = FlutterBackgroundService();
    await backgroundService.startService();
    backgroundService.invoke('startTracking', {
      'tripId': tripId,
      'vehicleName': _assignedVehicle?.name ?? 'Mavio Bus',
    });

    // Bind UI updates to background telemetry broadcaster
    _backgroundSubscription = backgroundService.on('updateStats').listen((event) {
      if (mounted) {
        setState(() {
          _isGpsOn = true;
          _currentSpeed = (event?['speed'] as num?)?.toDouble() ?? 0.0;
          _pingsSent = event?['uploads'] as int? ?? 0;
        });
      }
    });
  }

  void _stopTracking() {
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
    _backgroundSubscription?.cancel();
    _backgroundSubscription = null;
    _tripDurationTimer?.cancel();
    _tripDurationTimer = null;
    FlutterBackgroundService().invoke('stopService');
  }

  String _formatDuration(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    final String minutesStr = minutes.toString().padLeft(2, '0');
    final String secondsStr = seconds.toString().padLeft(2, '0');
    return '$minutesStr:$secondsStr';
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<AuthProvider>(context).currentProfile;
    final driverName = profile?.name ?? "Driver";

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Driver Console', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.textPrimary),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
                    content: const Text('Are you sure you want to log out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          _stopTracking();
                          await Provider.of<AuthProvider>(context, listen: false).logout();
                          if (!mounted) return;
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const SplashScreen()),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Log Out'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting & Status Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hello,',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            driverName,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      // Assigned Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Assigned',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Assigned Bus Details Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _assignedVehicle?.name ?? 'BUS --',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _assignedVehicle?.regNumber ?? 'TN -- AB ----',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),

                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.directions_bus_rounded,
                            color: AppColors.primary,
                            size: 36,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Status Indicators Box Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildIndicator(
                          label: 'GPS',
                          status: _isGpsOn ? 'ON' : 'OFF',
                          color: _isGpsOn ? AppColors.success : AppColors.error,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildIndicator(
                          label: 'Internet',
                          status: _isInternetOn ? 'ON' : 'OFF',
                          color: _isInternetOn ? AppColors.success : AppColors.error,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildIndicator(
                          label: 'Tracking',
                          status: _isTripActive ? 'Live' : 'Ready',
                          color: _isTripActive ? AppColors.primary : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 36),

                  // Large START/END TRIP button
                  ElevatedButton(
                    onPressed: _toggleTrip,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isTripActive ? AppColors.error : AppColors.primary,
                      minimumSize: const Size.fromHeight(68),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isTripActive ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _isTripActive ? 'END TRIP' : 'START TRIP',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isTripActive) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.query_stats_rounded, color: AppColors.primary, size: 20),
                              SizedBox(width: 8),
                              Text(
                                "Live Telemetry Dashboard",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24, thickness: 1),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              // Speedometer
                              Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primaryLight,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.speed_rounded, color: AppColors.primary, size: 22),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    "SPEED",
                                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${_currentSpeed.toStringAsFixed(1)} km/h",
                                    style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              // Duration
                              Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.timer_rounded, color: AppColors.success, size: 22),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    "DURATION",
                                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDuration(_tripSeconds),
                                    style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              // Updates Sent
                              Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50]!,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.cloud_upload_rounded, color: Colors.blue[700]!, size: 22),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    "UPLOADS",
                                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "$_pingsSent pings",
                                    style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),

                  const SizedBox(height: 12),

                  // Drive History Section
                  const Text(
                    "Drive History",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.15), width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "This Month's Total Duration",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          _thisMonthDuration,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_tripHistory.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          "No drive history found.",
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _tripHistory.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final trip = _tripHistory[index];
                        final dateStr = intl.DateFormat('MMM dd, yyyy').format(trip.startedAt);
                        
                        String durationStr = "Active";
                        if (trip.status == 'COMPLETED' && trip.endedAt != null) {
                          final duration = trip.endedAt!.difference(trip.startedAt);
                          final hours = duration.inHours;
                          final mins = duration.inMinutes % 60;
                          durationStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
                        }
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dateStr,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Started at ${intl.DateFormat('hh:mm a').format(trip.startedAt)}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                durationStr,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: trip.status == 'ACTIVE' ? AppColors.success : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildIndicator({
    required String label,
    required String status,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            status,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripScheduleRow(String title, String time, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          time,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
