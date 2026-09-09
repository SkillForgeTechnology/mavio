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
import 'driver_live_navigation_screen.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  final SupabaseService _db = SupabaseService();
  
  int _currentIndex = 0;
  bool _isLoading = false;
  MavioVehicle? _assignedVehicle;
  MavioVehicle? _defaultVehicle;
  bool _isTemporaryAssigned = false;
  List<MavioTrip> _tripHistory = [];
  String _thisMonthDuration = "0h 0m";
  String _thisMonthDistance = "0.0 km";

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
  bool _isInternetOn = true;

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
        final data = await _db.getStudentDashboardData();
        setState(() {
          _defaultVehicle = data['vehicle'] as MavioVehicle?;
          _assignedVehicle = _defaultVehicle;
          _isTemporaryAssigned = false;

          _activeTrip = data['activeTrip'] as MavioTrip?;
          _isTripActive = _activeTrip != null;
        });

        if (_isTripActive) {
          _startTracking(_activeTrip!.id);
        }
      }

      // Fetch Driver History
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
    double totalKm = 0.0;
    for (var trip in _tripHistory) {
      if (trip.status == 'COMPLETED' && trip.endedAt != null) {
        if (trip.startedAt.month == now.month && trip.startedAt.year == now.year) {
          totalSeconds += trip.endedAt!.difference(trip.startedAt).inSeconds;
          totalKm += trip.totalDistanceKm;
        }
      }
    }
    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    setState(() {
      _thisMonthDuration = '${hours}h ${minutes}m';
      _thisMonthDistance = '${totalKm.toStringAsFixed(1)} km';
    });
  }

  Future<void> _checkGpsStatus() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    setState(() {
      _isGpsOn = serviceEnabled;
    });
  }

  Future<void> _openQrScanner() async {
    final status = await Permission.camera.status;
    if (!status.isGranted) {
      final consented = await _showCameraProminentDisclosureDialog();
      if (!consented) return;

      final req = await Permission.camera.request();
      if (!req.isGranted) {
        if (!mounted) return;
        _showPermissionSettingsDialog(
          title: "Camera Permission Required",
          message: "Camera access is needed to scan the bus QR code. Please enable camera permission in App Settings.",
          icon: Icons.camera_alt_rounded,
        );
        return;
      }
    }

    if (!mounted) return;
    final result = await showDialog<MavioVehicle>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const BusQrScannerDialog(),
    );

    if (result != null && mounted) {
      setState(() {
        _assignedVehicle = result;
        _isTemporaryAssigned = (_defaultVehicle == null || result.id != _defaultVehicle!.id);
      });

      _showSnackbar(
        _isTemporaryAssigned
            ? "Shift bus set to ${result.name} (${result.regNumber})."
            : "Bus assigned to ${result.name}.",
        AppColors.success,
      );
    }
  }

  Future<void> _toggleTrip() async {
    if (_isTripActive) {
      await _endActiveTrip();
    } else {
      await _startNewTrip();
    }
  }

  Future<void> _startNewTrip() async {
    if (_assignedVehicle == null) {
      _showSnackbar("Please scan a bus QR code first.", AppColors.error);
      return;
    }

    bool isGpsEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isGpsEnabled) {
      final opened = await _showEnableGpsDialog();
      if (!opened) return;
      isGpsEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isGpsEnabled) {
        _showSnackbar("GPS must be turned on to start the trip.", AppColors.error);
        return;
      }
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final consented = await _showLocationProminentDisclosureDialog();
      if (!consented) {
        _showSnackbar("Location permission is required for live bus tracking.", AppColors.error);
        return;
      }

      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackbar("Location permission was denied.", AppColors.error);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showPermissionSettingsDialog(
        title: "Location Permission Required",
        message: "Precise location access is permanently denied. Please allow location access in App Settings.",
        icon: Icons.location_off_rounded,
      );
      return;
    }

    if (!kIsWeb && Platform.isAndroid) {
      final notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted) {
        await Permission.notification.request();
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

      await _startTracking(trip.id);

      await PushNotificationService.notifyTripStarted(
        vehicleId: _assignedVehicle!.id,
        vehicleName: _assignedVehicle!.name,
        tripId: trip.id,
      );

      _showSnackbar("Trip started successfully! Location broadcasting in background.", AppColors.success);
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                child: const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  "Location & Background Access",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
                  "MAVIO collects and uses your location data in the background and foreground to enable real-time bus tracking, route monitoring, and live ETA updates for student riders, even when the app is closed or in background.",
                  style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("• ", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text("Background tracking starts ONLY when you tap 'Start Trip'.", style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary)),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("• ", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text("Tracking STOPS immediately when you tap 'End Trip'.", style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary)),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("• ", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text("Location data is NEVER shared with third parties.", style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary)),
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
              child: const Text("Deny", style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text("Agree & Continue", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<bool> _showCameraProminentDisclosureDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text("Camera Access for Bus QR", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ),
            ],
          ),
          content: const Text(
            "MAVIO uses your camera only to scan the bus QR code to assign your shift vehicle. Camera images are processed locally on your device and are never recorded or stored.",
            style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text("Deny", style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Agree & Continue", style: TextStyle(fontWeight: FontWeight.bold)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.location_off_rounded, color: Color(0xFFDC2626), size: 26),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text("Turn On Location (GPS)", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ),
            ],
          ),
          content: const Text(
            "Device GPS is currently turned off. To broadcast real-time bus location to students, please turn on Location services.",
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4)),
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
              label: const Text("Open Settings", style: TextStyle(fontWeight: FontWeight.bold)),
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

  Future<void> _startTracking(String tripId) async {
    _cleanupLocalTrackingUI();

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

    if (!kIsWeb) {
      await BackgroundLocationService.initialize();
      final backgroundService = FlutterBackgroundService();
      final bool isServiceRunning = await backgroundService.isRunning();

      if (!isServiceRunning) {
        await backgroundService.startService();
        await Future.delayed(const Duration(milliseconds: 600));
      }

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
          debugPrint("Error pre-loading students for background service: $e");
        }
      }

      final trackingPayload = {
        'tripId': tripId,
        'vehicleId': _assignedVehicle?.id,
        'vehicleName': _assignedVehicle?.name ?? 'Mavio Bus',
        'students': studentList,
        'initialUploads': initialPings,
      };

      backgroundService.invoke('startTracking', trackingPayload);
      
      // Follow-up redundancy handshakes to guarantee background isolate receives event
      Future.delayed(const Duration(milliseconds: 1000), () {
        backgroundService.invoke('startTracking', trackingPayload);
      });
      Future.delayed(const Duration(milliseconds: 2500), () {
        backgroundService.invoke('getStats');
      });
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          _buildLiveMapTab(),
          _buildHistoryTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() => _currentIndex = index);
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.textSecondary,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.map_outlined),
                  activeIcon: Icon(Icons.map_rounded),
                  label: 'Live Map',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history_rounded),
                  activeIcon: Icon(Icons.history_toggle_off_rounded),
                  label: 'History',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline_rounded),
                  activeIcon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= TAB 0: HOME =================
  Widget _buildHomeTab() {
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
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
            tooltip: 'Scan Bus QR',
            onPressed: _openQrScanner,
          ),
          const SizedBox(width: 4),
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
          : RefreshIndicator(
              onRefresh: _loadDriverDetails,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
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
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              driverName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
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
                    const SizedBox(height: 20),

                    // Assigned Bus Details Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _isTemporaryAssigned ? AppColors.primary.withOpacity(0.4) : AppColors.border,
                          width: _isTemporaryAssigned ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.directions_bus_rounded,
                              color: AppColors.primary,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _assignedVehicle?.name ?? 'No Bus Assigned',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _assignedVehicle != null ? AppColors.textPrimary : AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _assignedVehicle?.regNumber ?? 'Scan QR code to assign bus',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bus QR Switcher Action
                    if (!_isTripActive) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _openQrScanner,
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                        label: Text(
                          _isTemporaryAssigned
                              ? 'Switch to Another Bus'
                              : (_assignedVehicle == null
                                  ? 'Scan Bus QR Code to Drive'
                                  : 'Scan Bus QR (Shift / Substitute)'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary, width: 1.5),
                          backgroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      if (_isTemporaryAssigned && _defaultVehicle != null) ...[
                        const SizedBox(height: 6),
                        Center(
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _assignedVehicle = _defaultVehicle;
                                _isTemporaryAssigned = false;
                              });
                              _showSnackbar("Reverted to default bus (${_defaultVehicle?.name}).", AppColors.success);
                            },
                            icon: const Icon(Icons.restore_rounded, size: 16, color: AppColors.textSecondary),
                            label: Text(
                              'Revert to my default bus (${_defaultVehicle?.name})',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 20),

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
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildIndicator(
                            label: 'Internet',
                            status: _isInternetOn ? 'ON' : 'OFF',
                            color: _isInternetOn ? AppColors.success : AppColors.error,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildIndicator(
                            label: 'Tracking',
                            status: _isTripActive ? 'Live' : 'Ready',
                            color: _isTripActive ? AppColors.primary : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Large START/END TRIP button
                    ElevatedButton(
                      onPressed: _toggleTrip,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isTripActive ? AppColors.error : AppColors.primary,
                        minimumSize: const Size.fromHeight(62),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 3,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isTripActive ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                            size: 24,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _isTripActive ? 'END TRIP' : 'START TRIP',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Active Trip Telemetry Card & Map Button
                    if (_isTripActive) ...[
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() => _currentIndex = 1);
                        },
                        icon: const Icon(Icons.map_rounded, size: 20),
                        label: const Text(
                          'VIEW ON LIVE MAP',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(18),
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
                                Icon(Icons.query_stats_rounded, color: AppColors.primary, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  "Live Telemetry",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 20, thickness: 1),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                // Speedometer
                                Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primaryLight,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.speed_rounded, color: AppColors.primary, size: 20),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      "SPEED",
                                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "${_currentSpeed.toStringAsFixed(1)} km/h",
                                      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                // Duration
                                Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.timer_rounded, color: AppColors.success, size: 20),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      "DURATION",
                                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDuration(_tripSeconds),
                                      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                // Updates Sent
                                Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50]!,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.cloud_upload_rounded, color: Colors.blue[700]!, size: 20),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      "UPLOADS",
                                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "$_pingsSent pings",
                                      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  // ================= TAB 1: LIVE MAP =================
  Widget _buildLiveMapTab() {
    if (_assignedVehicle == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Live Map', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, size: 48, color: AppColors.primary),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No Bus Assigned',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please scan your bus QR code on the Home tab to view the live map with student pickup stops.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _openQrScanner,
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: const Text('Scan Bus QR Code'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DriverLiveNavigationScreen(
      key: ValueKey('live_map_${_assignedVehicle!.id}'),
      vehicle: _assignedVehicle!,
      activeTrip: _activeTrip,
      isEmbeddedTab: true,
      onTripEnded: _endActiveTrip,
      onStartTrip: _startNewTrip,
    );
  }

  // ================= TAB 2: TRIP HISTORY =================
  Widget _buildHistoryTab() {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Trip History', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDriverDetails,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Monthly Summary Cards
              Row(
                children: [
                  // Total Duration Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.timer_rounded, color: AppColors.primary, size: 16),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "Total Time",
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _thisMonthDuration,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "This Month",
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Total KM Traveled Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.route_rounded, color: AppColors.success, size: 16),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "Total Distance",
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _thisMonthDistance,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "This Month",
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Trip List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "All Trips",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  Text(
                    "${_tripHistory.length} recorded",
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_tripHistory.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          "No drive history yet",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Completed trips with total km and duration will show up here.",
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _tripHistory.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final trip = _tripHistory[index];
                    final dateStr = intl.DateFormat('MMM dd, yyyy').format(trip.startedAt);
                    final timeStr = intl.DateFormat('hh:mm a').format(trip.startedAt);
                    
                    String durationStr = "In Progress";
                    if (trip.status == 'COMPLETED' && trip.endedAt != null) {
                      final duration = trip.endedAt!.difference(trip.startedAt);
                      final hours = duration.inHours;
                      final mins = duration.inMinutes % 60;
                      durationStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
                    }

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: (trip.status == 'ACTIVE' ? AppColors.primary : AppColors.success).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      trip.status == 'ACTIVE' ? Icons.navigation_rounded : Icons.check_circle_rounded,
                                      color: trip.status == 'ACTIVE' ? AppColors.primary : AppColors.success,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
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
                                      Text(
                                        "Started $timeStr",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (trip.status == 'ACTIVE' ? AppColors.primary : AppColors.success).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  trip.status == 'ACTIVE' ? 'ACTIVE' : 'COMPLETED',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: trip.status == 'ACTIVE' ? AppColors.primary : AppColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20, thickness: 1),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Duration
                              Row(
                                children: [
                                  const Icon(Icons.timer_outlined, size: 16, color: AppColors.textSecondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Duration: ",
                                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                  Text(
                                    durationStr,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  ),
                                ],
                              ),
                              // Total Distance KM
                              Row(
                                children: [
                                  const Icon(Icons.straighten_rounded, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Distance: ",
                                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                  Text(
                                    "${trip.totalDistanceKm.toStringAsFixed(1)} km",
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= TAB 3: PROFILE =================
  Widget _buildProfileTab() {
    final auth = Provider.of<AuthProvider>(context);
    final profile = auth.currentProfile;
    final driverName = profile?.name ?? "Driver";
    final phone = profile?.phone ?? "Not provided";
    final email = profile?.email ?? "Not provided";

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Driver Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Driver Avatar & Name
            Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      driverName.isNotEmpty ? driverName[0].toUpperCase() : 'D',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    driverName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Bus Driver',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Profile Info List
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildProfileRow(Icons.email_outlined, "Email", email),
                  const Divider(height: 20),
                  _buildProfileRow(Icons.phone_outlined, "Phone", phone),
                  const Divider(height: 20),
                  _buildProfileRow(
                    Icons.directions_bus_outlined,
                    "Assigned Bus",
                    _assignedVehicle != null ? "${_assignedVehicle!.name} (${_assignedVehicle!.regNumber})" : "None",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Switch Bus Action
            OutlinedButton.icon(
              onPressed: _openQrScanner,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
              label: const Text('Scan & Switch Assigned Bus', style: TextStyle(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 24),

            // Log Out Button
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    return AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
                      content: const Text('Are you sure you want to log out from your driver account?'),
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
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFEF2F2),
                foregroundColor: const Color(0xFFDC2626),
                elevation: 0,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFFECACA)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          ],
        ),
      ],
    );
  }

  Widget _buildIndicator({
    required String label,
    required String status,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
