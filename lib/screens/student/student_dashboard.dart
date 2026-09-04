import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tracking_provider.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/toast_utils.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/push_notification_service.dart';
import '../../models/models.dart';
import '../auth/splash_screen.dart';
import 'stop_selection_page.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentIndex = 0;
  final TrackingProvider _trackingProvider = TrackingProvider();
  bool _hasNewNotifications = true;
  final Set<String> _clearedNotificationIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackingProvider.loadStudentDashboard();
      PushNotificationService.setupVerificationObserver(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _trackingProvider,
      child: Consumer<TrackingProvider>(
        builder: (context, tracking, _) {
          final profile = Provider.of<AuthProvider>(context).currentProfile;
          final String studentName = profile?.name ?? "Student";

          final List<Widget> tabs = [
            _HomeTab(
              studentName: studentName,
              onNavigateToMap: () {
                setState(() {
                  _currentIndex = 1; // Switch to Map Tab
                });
              },
            ),
            const _MapTab(),
            _AlertsTab(
              clearedIds: _clearedNotificationIds,
              onClearAll: () {
                setState(() {
                  _clearedNotificationIds.add('approaching');
                  _clearedNotificationIds.add('started');
                });
              },
            ),
            _ProfileTab(studentName: studentName),
          ];

          return Scaffold(
            backgroundColor: AppColors.background,
            body: tracking.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  )
                : tabs[_currentIndex],
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
                border: const Border(
                  top: BorderSide(color: AppColors.borderLight, width: 1),
                ),
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                backgroundColor: Colors.white,
                selectedItemColor: AppColors.primary,
                unselectedItemColor: AppColors.textSecondary,
                showUnselectedLabels: true,
                type: BottomNavigationBarType.fixed,
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 11),
                onTap: (index) {
                  setState(() {
                    _currentIndex = index;
                    if (index == 2) {
                      _hasNewNotifications = false;
                    }
                  });
                },
                items: [
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.home_rounded),
                    activeIcon: Icon(
                      Icons.home_rounded,
                      color: AppColors.primary,
                    ),
                    label: 'Home',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.directions_bus_outlined),
                    activeIcon: Icon(
                      Icons.directions_bus_rounded,
                      color: AppColors.primary,
                    ),
                    label: 'Live Map',
                  ),
                  BottomNavigationBarItem(
                    icon: _hasNewNotifications
                        ? const Badge(
                            child: Icon(Icons.notifications_none_rounded),
                          )
                        : const Icon(Icons.notifications_none_rounded),
                    activeIcon: const Icon(
                      Icons.notifications_rounded,
                      color: AppColors.primary,
                    ),
                    label: 'Alerts',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline_rounded),
                    activeIcon: Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                    ),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// =========================================================================
// 1. HOME TAB (REDESIGNED PREMIUM VIEW)
// =========================================================================
class _HomeTab extends StatelessWidget {
  final String studentName;
  final VoidCallback onNavigateToMap;

  const _HomeTab({required this.studentName, required this.onNavigateToMap});

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000; // Earth radius in meters
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final deltaPhi = (lat2 - lat1) * math.pi / 180;
    final deltaLambda = (lon2 - lon1) * math.pi / 180;
    
    final a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
              math.cos(phi1) * math.cos(phi2) *
              math.sin(deltaLambda / 2) * math.sin(deltaLambda / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c; // in meters
  }

  @override
  Widget build(BuildContext context) {
    final tracking = Provider.of<TrackingProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final profile = auth.currentProfile;
    final vehicle = tracking.assignedVehicle;
    final isLive = tracking.isTripLive;
    final driverName = tracking.driverName;
    final driverPhone = tracking.driverPhone;

    final String initial = studentName.trim().isNotEmpty
        ? studentName.trim()[0].toUpperCase()
        : 'S';

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => tracking.loadStudentDashboard(),
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Grid
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome back,',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$studentName 👋',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // User Avatar outline
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.15),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Journey Overview Section
              Row(
                children: [
                  const Icon(
                    Icons.explore_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Journey Overview',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Assigned Vehicle Primary Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.borderLight, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withOpacity(
                                    0.5,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.directions_bus_rounded,
                                  color: AppColors.primary,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vehicle?.name ?? 'BUS --',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    vehicle?.regNumber ?? 'TN -- AB ----',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (isLive &&
                                      tracking.latestLocation != null) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.speed_rounded,
                                          size: 14,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Speed: ${tracking.latestLocation!.speed.toStringAsFixed(1)} km/h',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (profile?.alertLatitude != null &&
                                        profile?.alertLongitude != null) ...[
                                      const SizedBox(height: 6),
                                      Builder(
                                        builder: (context) {
                                          final distM = _calculateDistance(
                                            tracking.latestLocation!.latitude,
                                            tracking.latestLocation!.longitude,
                                            profile!.alertLatitude!,
                                            profile.alertLongitude!,
                                          );
                                          
                                          double speedKmh = tracking.latestLocation!.speed;
                                          if (speedKmh < 5.0) speedKmh = 25.0;
                                          final speedMps = speedKmh / 3.6;
                                          final etaSeconds = distM / speedMps;
                                          final etaMinutes = (etaSeconds / 60).round();
                                          
                                          final distText = distM >= 1000
                                              ? '${(distM / 1000.0).toStringAsFixed(2)} km'
                                              : '${distM.toStringAsFixed(0)} m';

                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.location_on_rounded,
                                                    size: 14,
                                                    color: Colors.orangeAccent,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Distance to Stop: $distText',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.orangeAccent,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.access_time_filled_rounded,
                                                    size: 14,
                                                    color: AppColors.success,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    etaMinutes <= 0
                                                        ? 'Arriving now'
                                                        : 'Arriving in ~ $etaMinutes mins',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.success,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ],
                          ),
                          // Live Indicator Pill
                          _PulsingLiveIndicator(isLive: isLive),
                        ],
                      ),
                    ),

                    // Map Preview container (Only visible when active)
                    if (isLive)
                      GestureDetector(
                        onTap: onNavigateToMap,
                        child: Container(
                          height: 140,
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(24),
                            ),
                            color: AppColors.primaryLight,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              AbsorbPointer(
                                child: FlutterMap(
                                  options: MapOptions(
                                    initialCenter:
                                        tracking.latestLocation != null
                                        ? LatLng(
                                            tracking.latestLocation!.latitude,
                                            tracking.latestLocation!.longitude,
                                          )
                                        : const LatLng(11.025, 76.98),
                                    initialZoom: 16.0,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate: 'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                                      subdomains: const ['0', '1', '2', '3'],
                                      userAgentPackageName: 'com.example.mavio',
                                      tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 100)),
                                      panBuffer: 1,
                                      keepBuffer: 3,
                                    ),
                                    if (tracking.latestLocation != null)
                                      MarkerLayer(
                                        markers: [
                                          Marker(
                                            point: LatLng(
                                              tracking.latestLocation!.latitude,
                                              tracking
                                                  .latestLocation!
                                                  .longitude,
                                            ),
                                            width: 44,
                                            height: 44,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppColors.primary
                                                        .withOpacity(0.35),
                                                    blurRadius: 12,
                                                    spreadRadius: 2,
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
                                  ],
                                ),
                              ),
                              Positioned(
                                bottom: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 8,
                                      ),
                                    ],
                                    border: Border.all(
                                      color: AppColors.borderLight,
                                      width: 1,
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.fullscreen_rounded,
                                        color: AppColors.primary,
                                        size: 16,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Expand Live Map',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      // Not started message placeholder card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 24,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.borderLight.withOpacity(0.2),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(24),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Tracking will automatically start once the driver begins the trip route.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Assigned Driver Card
              Row(
                children: [
                  const Icon(
                    Icons.person_pin_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Driver Information',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.borderLight, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driverName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (driverPhone.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              driverPhone,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          const Row(
                            children: [
                              Icon(
                                Icons.verified_user_rounded,
                                color: AppColors.success,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Verified Transport Personnel',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Action Buttons (Dial / Message)
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.phone_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        onPressed: () async {
                          if (driverPhone.isNotEmpty) {
                            final Uri telUri = Uri(
                              scheme: 'tel',
                              path: driverPhone,
                            );
                            try {
                              if (await canLaunchUrl(telUri)) {
                                await launchUrl(telUri);
                              } else {
                                AppToast.show(
                                  context,
                                  "Cannot launch phone dialer on this device.",
                                  isError: true,
                                );
                              }
                            } catch (e) {
                              print("Error launching dialer: $e");
                            }
                          } else {
                            AppToast.show(
                              context,
                              "No phone number registered for this driver.",
                              isError: true,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Emergency contacts dashboard button
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.error.withOpacity(0.12),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.phone_in_talk_rounded,
                          color: AppColors.error,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SOS Emergency Contacts',
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Instantly alert college transport administration support',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.error,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// WIDGET: PULSING LIVE INDICATOR WIDGET
// =========================================================================
class _PulsingLiveIndicator extends StatefulWidget {
  final bool isLive;

  const _PulsingLiveIndicator({required this.isLive});

  @override
  State<_PulsingLiveIndicator> createState() => _PulsingLiveIndicatorState();
}

class _PulsingLiveIndicatorState extends State<_PulsingLiveIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.textSecondary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, color: AppColors.textSecondary, size: 8),
            SizedBox(width: 6),
            Text(
              'NOT STARTED',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing background ring
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + 0.35 * _controller.value,
              child: Opacity(
                opacity: 0.45 * (1.0 - _controller.value),
                child: Container(
                  width: 90,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            );
          },
        ),

        // Core Pill Indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.success,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, color: Colors.white, size: 8),
              SizedBox(width: 6),
              Text(
                'LIVE TRACK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =========================================================================
// 2. LIVE MAP TAB (FULLSCREEN MAP)
// =========================================================================
class _MapTab extends StatefulWidget {
  const _MapTab();

  @override
  State<_MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<_MapTab> {
  final MapController _mapController = MapController();
  TrackingProvider? _trackingProvider;
  bool _isAutoCenterEnabled = true;
  String _mapLayerStyle =
      'm'; // 'm' = road, 'y' = satellite hybrid, 'p' = terrain

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newProvider = Provider.of<TrackingProvider>(context);
    if (_trackingProvider != newProvider) {
      _trackingProvider?.removeListener(_onTrackingUpdate);
      _trackingProvider = newProvider;
      _trackingProvider?.addListener(_onTrackingUpdate);

      // Centering once map layouts complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _trackingProvider?.latestLocation != null) {
          _centerOnBus(_trackingProvider!.latestLocation);
        }
      });
    }
  }

  @override
  void dispose() {
    _trackingProvider?.removeListener(_onTrackingUpdate);
    super.dispose();
  }

  void _onTrackingUpdate() {
    if (_isAutoCenterEnabled &&
        _trackingProvider != null &&
        _trackingProvider!.isTripLive &&
        _trackingProvider!.latestLocation != null) {
      final loc = _trackingProvider!.latestLocation!;
      try {
        double currentZoom = 18.5;
        try {
          currentZoom = _mapController.camera.zoom;
        } catch (_) {}
        _mapController.move(LatLng(loc.latitude, loc.longitude), currentZoom);
      } catch (_) {}
    }
  }

  void _centerOnBus(MavioLocationUpdate? loc) {
    if (loc != null) {
      try {
        _mapController.move(LatLng(loc.latitude, loc.longitude), 17.5);
      } catch (_) {}
    }
  }

  void _showMapStyleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Map Style',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStyleOption(
                          context,
                          label: 'Standard',
                          styleCode: 'm',
                          icon: Icons.map_outlined,
                          setDialogState: setDialogState,
                        ),
                        _buildStyleOption(
                          context,
                          label: 'Satellite',
                          styleCode: 'y',
                          icon: Icons.satellite_alt_outlined,
                          setDialogState: setDialogState,
                        ),
                        _buildStyleOption(
                          context,
                          label: 'Terrain',
                          styleCode: 'p',
                          icon: Icons.terrain_outlined,
                          setDialogState: setDialogState,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStyleOption(
    BuildContext context, {
    required String label,
    required String styleCode,
    required IconData icon,
    required StateSetter setDialogState,
  }) {
    final isSelected = _mapLayerStyle == styleCode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _mapLayerStyle = styleCode;
        });
        setDialogState(() {});
        Navigator.pop(context);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.12)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.borderLight,
                width: 2,
              ),
            ),
            child: Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tracking = Provider.of<TrackingProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final profile = auth.currentProfile;
    final isLive = tracking.isTripLive;
    final latestLoc = tracking.latestLocation;

    return Scaffold(
      body: Stack(
        children: [
          // Base Map View
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: latestLoc != null
                  ? LatLng(latestLoc.latitude, latestLoc.longitude)
                  : const LatLng(11.025, 76.98),
              initialZoom: 17.5,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture && _isAutoCenterEnabled) {
                  setState(() {
                    _isAutoCenterEnabled = false;
                  });
                }
              },
            ),
            children: [
              // Premium Light-Mode Map Tiles
              TileLayer(
                urlTemplate: 'https://mt{s}.google.com/vt/lyrs=$_mapLayerStyle&x={x}&y={y}&z={z}',
                subdomains: const ['0', '1', '2', '3'],
                userAgentPackageName: 'com.example.mavio',
                tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 100)),
                panBuffer: 1,
                keepBuffer: 3,
              ),

              // Glowing Route Path Line
              if (isLive && tracking.tripPath.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: tracking.tripPath,
                      strokeWidth: 4.5,
                      color: AppColors.primary,
                      borderColor: AppColors.primary.withOpacity(0.3),
                      borderStrokeWidth: 4.0,
                    ),
                  ],
                ),

              // Pinned Student Alert Stop Circle Layer
              if (profile?.alertLatitude != null && profile?.alertLongitude != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: LatLng(profile!.alertLatitude!, profile.alertLongitude!),
                      radius: profile.alertRadiusMeters.toDouble(),
                      useRadiusInMeter: true,
                      color: AppColors.primary.withOpacity(0.08),
                      borderColor: AppColors.primary.withOpacity(0.4),
                      borderStrokeWidth: 1.2,
                    ),
                  ],
                ),

              // Pinned Student Alert Stop Marker Layer
              if (profile?.alertLatitude != null && profile?.alertLongitude != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(profile!.alertLatitude!, profile.alertLongitude!),
                      width: 40,
                      height: 40,
                      child: Tooltip(
                        message: 'Your Alert Location',
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary, width: 2.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.home_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

              // Glowing Bus Marker Layer
              MarkerLayer(
                markers: [
                  // Active Glowing Bus Marker
                  if (isLive && latestLoc != null)
                    Marker(
                      point: LatLng(latestLoc.latitude, latestLoc.longitude),
                      width: 56,
                      height: 56,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Concentric ripple animations
                          _GlowingMarkerPulse(),
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.directions_bus_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Map Layers Style Toggle Button (unconditional)
          Positioned(
            bottom: isLive && latestLoc != null ? 96 : 24,
            right: 24,
            child: FloatingActionButton(
              mini: true,
              onPressed: () => _showMapStyleDialog(context),
              backgroundColor: Colors.white,
              foregroundColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(
                  color: AppColors.borderLight,
                  width: 1.5,
                ),
              ),
              child: const Icon(Icons.layers_outlined, size: 20),
            ),
          ),

          // Floating Center-On-Bus Button
          if (isLive && latestLoc != null)
            Positioned(
              bottom: 24,
              right: 24,
              child: FloatingActionButton(
                onPressed: () {
                  setState(() {
                    _isAutoCenterEnabled = true;
                  });
                  _centerOnBus(latestLoc);
                },
                backgroundColor: _isAutoCenterEnabled
                    ? AppColors.primary
                    : Colors.white,
                foregroundColor: _isAutoCenterEnabled
                    ? Colors.white
                    : AppColors.textPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: _isAutoCenterEnabled
                        ? Colors.transparent
                        : AppColors.borderLight,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  _isAutoCenterEnabled
                      ? Icons.gps_fixed_rounded
                      : Icons.gps_not_fixed_rounded,
                ),
              ),
            ),

          // Status Panel Card Overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isLive
                          ? AppColors.success.withOpacity(0.12)
                          : AppColors.textSecondary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isLive ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
                      color: isLive
                          ? AppColors.success
                          : AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isLive ? 'Active Live Tracking' : 'Bus is Offline',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isLive
                              ? (latestLoc != null
                                    ? 'Speed: ${latestLoc.speed.toStringAsFixed(1)} km/h | Live Updating'
                                    : 'Coordinates update dynamically in real time')
                              : 'Waiting for driver to start tracking...',
                          style: const TextStyle(
                            fontSize: 11.5,
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
        ],
      ),
    );
  }
}

// Glowing Pulse Effect for Bus Marker
class _GlowingMarkerPulse extends StatefulWidget {
  @override
  State<_GlowingMarkerPulse> createState() => _GlowingMarkerPulseState();
}

class _GlowingMarkerPulseState extends State<_GlowingMarkerPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + 0.45 * _controller.value,
          child: Opacity(
            opacity: 0.5 * (1.0 - _controller.value),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }
}

// =========================================================================
// 3. ALERTS TAB (PREMIUM TIMELINE TIMESTAMPS)
// =========================================================================
class _AlertsTab extends StatelessWidget {
  final Set<String> clearedIds;
  final VoidCallback onClearAll;

  const _AlertsTab({required this.clearedIds, required this.onClearAll});

  @override
  Widget build(BuildContext context) {
    final tracking = Provider.of<TrackingProvider>(context);
    final isLive = tracking.isTripLive;

    final List<Map<String, dynamic>> notifications = [
      if (isLive) ...[
        {
          'id': 'approaching',
          'title': 'Bus 03 is approaching your location',
          'time': '2 min ago',
          'type': 'approaching',
          'icon': Icons.directions_bus_rounded,
          'color': AppColors.primary,
        },
        {
          'id': 'started',
          'title': 'Bus 03 has started today\'s morning trip',
          'time': '12 min ago',
          'type': 'started',
          'icon': Icons.play_circle_fill_rounded,
          'color': AppColors.success,
        },
      ],
    ];

    final List<Map<String, dynamic>> activeNotifications = notifications
        .where((n) => !clearedIds.contains(n['id']))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        actions: [
          if (activeNotifications.isNotEmpty)
            TextButton(
              onPressed: onClearAll,
              child: const Text(
                'Clear All',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderLight, height: 1),
        ),
      ),
      body: activeNotifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_rounded,
                    size: 48,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No new alerts or notifications.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              itemCount: activeNotifications.length,
              itemBuilder: (context, index) {
                final n = activeNotifications[index];
                final bool isLast = index == activeNotifications.length - 1;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Timeline Connector Line & Dots
                      Column(
                        children: [
                          // Dot Indicator
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: (n['color'] as Color).withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: (n['color'] as Color).withOpacity(0.2),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              n['icon'] as IconData,
                              color: n['color'] as Color,
                              size: 18,
                            ),
                          ),
                          // Line
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: AppColors.borderLight,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),

                      // Card panel
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.borderLight,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.01),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n['title'] as String,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time_rounded,
                                      color: AppColors.textSecondary,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      n['time'] as String,
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// =========================================================================
// 4. PROFILE TAB (REDESIGNED MINIMAL GRID CARD PANEL)
// =========================================================================
class _ProfileTab extends StatefulWidget {
  final String studentName;

  const _ProfileTab({required this.studentName});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  bool _pushNotificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _pushNotificationsEnabled = PushNotificationService.isPushEnabled();
  }

  @override
  Widget build(BuildContext context) {
    final tracking = Provider.of<TrackingProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final profile = auth.currentProfile;
    final vehicle = tracking.assignedVehicle;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              // Profile Header Card details
              Center(
                child: Column(
                  children: [
                    // Profile Avatar with dynamic gradient bounds
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withOpacity(0.5),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.studentName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Student • ${auth.verifiedOrg?.name ?? "Mavio Network"}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 1. Personal Details Section Header
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Personal Details',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Personal Details Box
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight, width: 1.5),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      icon: Icons.badge_rounded,
                      label: 'Roll Number',
                      value: profile?.rollNumber ?? 'N/A',
                    ),
                    const Divider(height: 32, color: AppColors.borderLight),
                    _buildDetailRow(
                      icon: Icons.cake_rounded,
                      label: 'Date of Birth',
                      value: profile?.dob ?? 'N/A',
                    ),
                    const Divider(height: 32, color: AppColors.borderLight),
                    _buildDetailRow(
                      icon: Icons.phone_android_rounded,
                      label: 'Mobile Number',
                      value: profile?.phone ?? 'N/A',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 2. Bus Details Section Header
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Bus Details',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Bus Details Box
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight, width: 1.5),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      icon: Icons.directions_bus_rounded,
                      label: 'Assigned Bus',
                      value: vehicle?.name ?? 'Not Assigned',
                    ),
                    const Divider(height: 32, color: AppColors.borderLight),
                    _buildDetailRow(
                      icon: Icons.pin_drop_rounded,
                      label: 'Registration Number',
                      value: vehicle?.regNumber ?? 'Not Assigned',
                    ),
                    const Divider(height: 32, color: AppColors.borderLight),
                    _buildDetailRow(
                      icon: Icons.verified_user_rounded,
                      label: 'Account Status',
                      value: 'Active Verification',
                      isSuccess: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 3. Proximity Alert Configuration
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Proximity Alert Stop',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notifications_active_outlined, color: AppColors.primary, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your Stop Alert Location',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                profile?.alertLatitude != null 
                                    ? 'Radius: ${(profile!.alertRadiusMeters / 1000).toStringAsFixed(1)} km • Selected'
                                    : 'Not configured yet',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (profile?.alertLatitude != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Lat: ${profile!.alertLatitude!.toStringAsFixed(5)}, Lng: ${profile.alertLongitude!.toStringAsFixed(5)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                     ElevatedButton.icon(
                      onPressed: () {
                        if (profile != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StudentStopSelectionPage(profile: profile),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.map_rounded, size: 16),
                      label: Text(
                        profile?.alertLatitude != null ? 'Edit Alert Location' : 'Set Alert Location',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Settings Switch Card
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.notifications_active_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Push Notifications',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _pushNotificationsEnabled,
                      activeThumbColor: AppColors.primary,
                      activeTrackColor: AppColors.primaryLight,
                      onChanged: (val) async {
                        setState(() {
                          _pushNotificationsEnabled = val;
                        });
                        if (profile != null) {
                          final result =
                              await PushNotificationService.setPushNotificationsEnabled(
                                  val, profile.id);
                          if (mounted) {
                            setState(() {
                              _pushNotificationsEnabled = result;
                            });
                            AppToast.show(
                              context,
                              val
                                  ? "Push notifications enabled for bus arrival alerts."
                                  : "Push notifications disabled for this device.",
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Logout Button
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text(
                          'Log Out',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        content: const Text(
                          'Are you sure you want to log out?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(dialogContext);
                              await auth.logout();
                              if (!mounted) return;
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const SplashScreen(),
                                ),
                                (route) => false,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Log Out'),
                          ),
                        ],
                      );
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.error,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.error, width: 1.5),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Logout Account',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isSuccess = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSuccess
                ? AppColors.success.withOpacity(0.1)
                : AppColors.primaryLight,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isSuccess ? AppColors.success : AppColors.primary,
            size: 18,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: isSuccess ? AppColors.success : AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
