import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:intl/intl.dart' as intl;
import '../../providers/auth_provider.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/push_notification_service.dart';
import '../../core/services/background_location_service.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/toast_utils.dart';
import '../../models/models.dart';
import '../../widgets/mavio_org_logo.dart';
import '../auth/splash_screen.dart';
import 'bus_qr_scanner_dialog.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  final SupabaseService _db = SupabaseService();
  
  bool _isLoading = false;
  MavioVehicle? _assignedVehicle;
  MavioVehicle? _defaultVehicle;
  bool _isTemporaryAssigned = false;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.setupVerificationObserver(context);
    });
  }

  @override
  void dispose() {
    _cleanupLocalTrackingUI();
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
          _defaultVehicle = data['vehicle'] as MavioVehicle?;
          _assignedVehicle = _defaultVehicle;
          _isTemporaryAssigned = false;

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

  Future<void> _openQrScanner() async {
    final profile = Provider.of<AuthProvider>(context, listen: false).currentProfile;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => BusQrScannerDialog(expectedOrgId: profile?.orgId),
      ),
    );

    if (result != null && mounted) {
      final vehicleId = result['vehicleId'] as String;
      final name = result['name'] as String? ?? 'BUS';
      final regNumber = result['regNumber'] as String? ?? '';
      final orgId = result['orgId'] as String? ?? profile?.orgId;

      setState(() {
        _assignedVehicle = MavioVehicle(
          id: vehicleId,
          name: name,
          regNumber: regNumber,
          status: 'OFFLINE',
          orgId: orgId ?? profile?.orgId ?? '',
        );
        _isTemporaryAssigned = true;
      });

      _showVehicleSwitchedModal(name, regNumber);
    }
  }

  void _showVehicleSwitchedModal(String name, String regNumber) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Connected to $name',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                regNumber,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'You are driving this bus for this shift. Live tracking will broadcast to students on this route.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Ready'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _startNewTrip();
                      },
                      icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
                      label: const Text('Start Trip Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
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
      _showSnackbar("Please scan a bus QR code to select your vehicle.", AppColors.warning);
      _openQrScanner();
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

    // 2. Verify Location Service is Enabled (GPS)
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      final opened = await _showEnableGpsDialog();
      if (opened) {
        // Wait a moment for OS toggle transition
        await Future.delayed(const Duration(milliseconds: 1200));
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      }
      if (!serviceEnabled) {
        _showSnackbar("Location services (GPS) must be turned on to start a trip.", AppColors.error);
        return;
      }
    }

    // 3. Prominent Disclosure Check for Background Location (Google Play Policy Compliance)
    LocationPermission permission = await Geolocator.checkPermission();
    PermissionStatus backgroundStatus = PermissionStatus.denied;
    if (Platform.isAndroid) {
      backgroundStatus = await Permission.locationAlways.status;
    }

    if (permission == LocationPermission.denied ||
        (Platform.isAndroid && backgroundStatus != PermissionStatus.granted)) {
      final bool userConsented = await _showLocationProminentDisclosureDialog();
      if (!userConsented) {
        _showSnackbar(
          "Location and background tracking permissions are required to start a trip and broadcast live bus updates.",
          AppColors.warning,
        );
        return;
      }
    }

    // 4. Verify Foreground Location Permissions
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      await _showPermissionSettingsDialog(
        title: "Location Permission Required",
        message: "Location permission is required to track and broadcast your bus route. Please enable location permissions in app settings.",
        icon: Icons.location_on_rounded,
      );
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _showSnackbar("Location permissions are required for GPS tracking.", AppColors.error);
        return;
      }
    }

    // 5. Request Notification Permission for Foreground Service on Android 13+
    if (Platform.isAndroid) {
      var notifStatus = await Permission.notification.status;
      if (notifStatus != PermissionStatus.granted) {
        final result = await Permission.notification.request();
        if (result != PermissionStatus.granted) {
          await _showPermissionSettingsDialog(
            title: "Notification Permission Required",
            message: "Notification access is required to keep the live bus tracking service running in the background while driving.",
            icon: Icons.notifications_active_rounded,
          );
          notifStatus = await Permission.notification.status;
          if (notifStatus != PermissionStatus.granted) {
            _showSnackbar(
              "Notification permission is required to run location updates in the background.",
              AppColors.error,
            );
            return; // Block service initialization to prevent OS crash
          }
        }
      }
    }

    // 6. Request Background Location Permission on Android 10+
    if (Platform.isAndroid) {
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

      // Broadcast trip started notification to all students assigned to this bus
      await PushNotificationService.notifyTripStarted(
        vehicleId: _assignedVehicle!.id,
        vehicleName: _assignedVehicle!.name,
        tripId: trip.id,
      );

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

  Future<bool> _showLocationProminentDisclosureDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  "Location & Background Access",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "MAVIO collects and uses your location data in the background and foreground to enable real-time bus tracking, route monitoring, and live ETA updates for student riders, even when the app is closed, minimized, or not in use.",
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("• ", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              "Background tracking starts ONLY when you tap 'Start Trip'.",
                              style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("• ", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              "Tracking STOPS immediately when you tap 'End Trip'.",
                              style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("• ", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              "Location data is NEVER used for advertising or shared with third parties.",
                              style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text(
                "Deny",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text(
                "Agree & Continue",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<bool> _showEnableGpsDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_off_rounded,
                  color: Color(0xFFDC2626),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Turn On Location (GPS)",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            "Device GPS is currently turned off. To start the trip and broadcast real-time bus location to students, please turn on Location services.",
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(dialogContext).pop(true);
                await Geolocator.openLocationSettings();
              },
              icon: const Icon(Icons.settings_suggest_rounded, size: 18),
              label: const Text("Turn On GPS", style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _showPermissionSettingsDialog({
    required String title,
    required String message,
    required IconData icon,
  }) async {
    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await Geolocator.openAppSettings();
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text("Open App Settings", style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _cleanupLocalTrackingUI() {
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
    _backgroundSubscription?.cancel();
    _backgroundSubscription = null;
    _tripDurationTimer?.cancel();
    _tripDurationTimer = null;
  }

  // Core tracking router
  void _startTracking(String tripId) async {
    _cleanupLocalTrackingUI(); // Ensure cleanup of local variables only

    // Calculate elapsed duration & existing uploaded pings if resuming from an active session
    int initialSeconds = 0;
    int initialPings = 0;
    if (_activeTrip != null) {
      initialSeconds = DateTime.now().difference(_activeTrip!.startedAt).inSeconds;
      if (initialSeconds < 0) initialSeconds = 0;
      try {
        initialPings = await _db.getTripLocationCount(_activeTrip!.id);
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _currentSpeed = 0.0;
        _pingsSent = initialPings;
        _tripSeconds = initialSeconds;
      });
    }

    _tripDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _tripSeconds++;
        });
      }
    });

    // Start background location service and pass tracking info
    if (!kIsWeb) {
      await BackgroundLocationService.initialize();
      final backgroundService = FlutterBackgroundService();
      final bool isServiceRunning = await backgroundService.isRunning();

      if (!isServiceRunning) {
        await backgroundService.startService();
      }

      // Bind UI updates to background telemetry broadcaster FIRST
      _backgroundSubscription = backgroundService.on('updateStats').listen((event) {
        if (mounted) {
          setState(() {
            _isGpsOn = true;
            _currentSpeed = (event?['speed'] as num?)?.toDouble() ?? 0.0;
            final uploads = event?['uploads'] as int?;
            if (uploads != null && uploads >= _pingsSent) {
              _pingsSent = uploads;
            }
          });
        }
      });

      List<Map<String, dynamic>> studentList = [];
      if (_assignedVehicle != null) {
        try {
          final students = await _db.getAssignedStudentsForVehicle(_assignedVehicle!.id);
          studentList = students.map((s) => {
            'id': s.id,
            'name': s.name,
            'onesignal_id': s.onesignalId,
            'alert_latitude': s.alertLatitude,
            'alert_longitude': s.alertLongitude,
            'alert_radius_meters': s.alertRadiusMeters,
          }).toList();
        } catch (e) {
          print("Error pre-loading students for background service: $e");
        }
      }

      backgroundService.invoke('startTracking', {
        'tripId': tripId,
        'vehicleId': _assignedVehicle?.id,
        'vehicleName': _assignedVehicle?.name ?? 'Mavio Bus',
        'students': studentList,
        'initialUploads': initialPings,
      });

      // Request immediate current stats from background service
      backgroundService.invoke('getStats');
    }
  }

  void _stopTracking() {
    _cleanupLocalTrackingUI();
    if (!kIsWeb) {
      FlutterBackgroundService().invoke('stopService');
    }
  }

  String _formatDuration(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    final String minutesStr = minutes.toString().padLeft(2, '0');
    final String secondsStr = seconds.toString().padLeft(2, '0');
    return '$minutesStr:$secondsStr';
  }

  void _showSnackbar(String msg, Color color) {
    if (!mounted) return;
    final isErr = color == AppColors.error || color == Colors.red || color == Colors.redAccent;
    AppToast.show(context, msg, isError: isErr);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final profile = auth.currentProfile;
    final driverName = profile?.name ?? "Driver";

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Driver Console', style: TextStyle(fontWeight: FontWeight.bold)),
            if (auth.verifiedOrg?.logoUrl != null &&
                auth.verifiedOrg!.logoUrl!.trim().isNotEmpty) ...[
              const SizedBox(width: 10),
              MavioOrgLogo(
                logoUrl: auth.verifiedOrg!.logoUrl,
                size: 32,
                borderRadius: 8,
              ),
            ],
          ],
        ),
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
                          color: (_isTemporaryAssigned ? const Color(0xFFF97316) : AppColors.success).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _isTemporaryAssigned ? 'Shift Mode' : (_assignedVehicle != null ? 'Assigned' : 'Unassigned'),
                          style: TextStyle(
                            color: _isTemporaryAssigned ? const Color(0xFFEA580C) : (_assignedVehicle != null ? AppColors.success : AppColors.error),
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
                      border: Border.all(
                        color: _isTemporaryAssigned ? AppColors.primary.withOpacity(0.4) : AppColors.border,
                        width: _isTemporaryAssigned ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _assignedVehicle?.name ?? 'No Bus Selected',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: _assignedVehicle != null ? AppColors.textPrimary : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _assignedVehicle?.regNumber ?? 'Scan a bus QR sticker to begin',
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

                  // Scan Bus QR Code Action (visible before starting trip)
                  if (!_isTripActive) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _openQrScanner,
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                      label: Text(
                        _isTemporaryAssigned
                            ? 'Switch to Another Bus'
                            : (_assignedVehicle == null
                                ? 'Scan Bus QR Code to Drive'
                                : 'Scan Bus QR Code (Shift / Substitute)'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        backgroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    if (_isTemporaryAssigned && _defaultVehicle != null) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _assignedVehicle = _defaultVehicle;
                            _isTemporaryAssigned = false;
                          });
                          _showSnackbar(
                            "Reverted back to your default assigned bus (${_defaultVehicle?.name}).",
                            AppColors.success,
                          );
                        },
                        icon: const Icon(Icons.restore_rounded, size: 18, color: AppColors.textSecondary),
                        label: Text(
                          'Revert to my default bus (${_defaultVehicle?.name})',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
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
