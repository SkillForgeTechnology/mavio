import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../providers/auth_provider.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/push_notification_service.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/toast_utils.dart';
import '../../models/models.dart';
import '../auth/splash_screen.dart';
import 'package:intl/intl.dart' as intl;
import 'bulk_import_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  final SupabaseService _db = SupabaseService();

  bool _isLoading = false;
  int _totalBuses = 0;
  int _activeNow = 0;
  List<Map<String, dynamic>> _fleet = [];
  List<MavioProfile> _drivers = [];
  List<MavioProfile> _students = [];
  String _vehicleQuery = "";
  String _vehicleSortOption = "name";
  String _driverQuery = "";
  String _studentQuery = "";
  final TextEditingController _vehicleSearchCtrl = TextEditingController();
  final TextEditingController _driverSearchCtrl = TextEditingController();
  final TextEditingController _studentSearchCtrl = TextEditingController();

  void _resetSearchQueries() {
    _vehicleQuery = "";
    _driverQuery = "";
    _studentQuery = "";
    _vehicleSearchCtrl.clear();
    _driverSearchCtrl.clear();
    _studentSearchCtrl.clear();
  }

  Map<String, dynamic>? _selectedMapFleetItem;
  final MapController _mapController = MapController();
  final Map<String, LatLng> _liveVehicleLocations = {};
  final Map<String, double> _liveVehicleSpeeds = {};
  String _mapLayerStyle =
      'm'; // 'm' = road, 'y' = satellite hybrid, 'p' = terrain

  // Poll timer to refresh admin dashboard updates
  Timer? _refreshTimer;
  StreamSubscription<MavioLocationUpdate>? _liveLocationSub;
  LatLng? _mockBusLocation;

  void _showSnackbar(String message, Color backgroundColor) {
    if (!mounted) return;
    final isErr = backgroundColor == AppColors.error ||
        backgroundColor == Colors.red ||
        backgroundColor == Colors.redAccent;
    AppToast.show(context, message, isError: isErr);
  }

  @override
  void initState() {
    super.initState();
    _loadAdminData();

    // Poll updates every 4 seconds to catch moving simulation coordinates
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      _silentRefreshData();
    });

    // Subscribe to mock updates for live map tracking on admin
    _subscribeToLiveLocations();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.setupVerificationObserver(context);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _liveLocationSub?.cancel();
    _vehicleSearchCtrl.dispose();
    _driverSearchCtrl.dispose();
    _studentSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    setState(() {
      _isLoading = true;
    });
    await _silentRefreshData();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _silentRefreshData() async {
    try {
      final data = await _db.getAdminDashboardData();
      if (!mounted) return;
      
      final fleetData = List<Map<String, dynamic>>.from(data['fleet']);
      fleetData.sort((a, b) {
        final vA = a['vehicle'] as MavioVehicle;
        final vB = b['vehicle'] as MavioVehicle;
        return _naturalCompare(vA.name, vB.name);
      });

      final driversData = List<MavioProfile>.from(data['drivers']);
      driversData.sort((a, b) => _naturalCompare(a.name, b.name));

      final studentsData = List<MavioProfile>.from(data['students']);
      studentsData.sort((a, b) => _naturalCompare(a.name, b.name));

      setState(() {
        _totalBuses = data['totalBuses'] as int;
        _activeNow = data['activeNow'] as int;
        _fleet = fleetData;
        _drivers = driversData;
        _students = studentsData;
      });
    } catch (e) {
      print("Admin Refresh Error: $e");
    }
  }

  int _naturalCompare(String a, String b) {
    final regExp = RegExp(r'(\d+)|(\D+)');
    final matchesA = regExp.allMatches(a.toUpperCase()).map((m) => m.group(0)!).toList();
    final matchesB = regExp.allMatches(b.toUpperCase()).map((m) => m.group(0)!).toList();

    for (int i = 0; i < matchesA.length && i < matchesB.length; i++) {
      final strA = matchesA[i];
      final strB = matchesB[i];

      final numA = int.tryParse(strA);
      final numB = int.tryParse(strB);

      if (numA != null && numB != null) {
        final comp = numA.compareTo(numB);
        if (comp != 0) return comp;
      } else {
        final comp = strA.compareTo(strB);
        if (comp != 0) return comp;
      }
    }
    return matchesA.length.compareTo(matchesB.length);
  }

  void _subscribeToLiveLocations() {
    _liveLocationSub?.cancel();
    _liveLocationSub = _db.streamAllLocationUpdates().listen(
      (loc) {
        if (!mounted) return;
        setState(() {
          _liveVehicleLocations[loc.tripId] = LatLng(
            loc.latitude,
            loc.longitude,
          );
          _liveVehicleSpeeds[loc.tripId] = loc.speed;

          if (_selectedMapFleetItem != null &&
              _selectedMapFleetItem!['activeTrip'] != null) {
            final activeTrip =
                _selectedMapFleetItem!['activeTrip'] as MavioTrip;
            if (activeTrip.id == loc.tripId) {
              _mockBusLocation = LatLng(loc.latitude, loc.longitude);
            }
          }
        });
      },
      onError: (err) {
        print("Admin live location subscription error: $err");
      },
    );
  }

  void _navigateToBulkImport(String type) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MavioBulkImportScreen(importType: type, db: _db, fleet: _fleet),
      ),
    );
    if (result == true) {
      _loadAdminData();
    }
  }

  // Dialog to Add Vehicle
  void _showAddVehicleDialog() {
    final nameController = TextEditingController();
    final regController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Add Vehicle',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Bus Name (e.g. BUS 04)',
                        prefixIcon: Icon(
                          Icons.directions_bus_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      validator: (v) => v!.trim().isEmpty ? 'Enter name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: regController,
                      decoration: const InputDecoration(
                        labelText: 'Registration No. (e.g. TN 38 AB 9999)',
                        prefixIcon: Icon(
                          Icons.badge_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      validator: (v) => v!.trim().isEmpty
                          ? 'Enter registration number'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final messenger = ScaffoldMessenger.of(context);
                final org = _db.currentOrganization;
                final limit = org?.maxVehicles ?? 15;
                if (_totalBuses >= limit) {
                  Navigator.pop(context);
                  _showLimitExceededDialog(limit);
                  return;
                }
                Navigator.pop(context);
                setState(() => _isLoading = true);
                try {
                  await _db.addVehicle(nameController.text, regController.text);
                  await _loadAdminData();
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error adding: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(100, 40)),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showLimitExceededDialog(int limit) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.amber,
                size: 28,
              ),
              SizedBox(width: 8),
              Text(
                'Limit Reached',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          content: Text(
            'Vehicle limit reached! Your plan is limited to $limit vehicles. '
            'Please upgrade your subscription by contacting us to add more buses.',
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showContactSupportInfo();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Contact Support'),
            ),
          ],
        );
      },
    );
  }

  void _showContactSupportInfo() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Logos Section
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('logo.png', height: 45),
                  const SizedBox(width: 20),
                  Container(
                    height: 30,
                    width: 1.5,
                    color: AppColors.borderLight,
                  ),
                  const SizedBox(width: 20),
                  Image.asset('company-logo.png', height: 40),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Contact Our Sales & Setup Team',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Let us help you configure the real-time student visibility transit system for your institution.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              
              // Email Detail
              _buildContactItem(
                icon: Icons.email_outlined,
                title: 'Email Us',
                value: 'info@skillforgetechnology.app',
                onTap: () => launchUrl(Uri.parse('mailto:info@skillforgetechnology.app')),
              ),
              const SizedBox(height: 12),
              
              // Mobile Detail
              _buildContactItem(
                icon: Icons.phone_android_outlined,
                title: 'Mobile / Phone',
                value: '+91 93455 18760',
                onTap: () => launchUrl(Uri.parse('tel:+919345518760')),
              ),
              const SizedBox(height: 24),
              
              // Call & WhatsApp Action Row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse('https://wa.me/919345518760?text=Hi%2C%20I\'m%20interested%20in%20Mavio%20Transit%20Service!'),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Colors.white),
                      label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => launchUrl(Uri.parse('tel:+919345518760')),
                      icon: const Icon(Icons.call_outlined, size: 18, color: Colors.white),
                      label: const Text('Call Now', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.textPrimary.withOpacity(0.04),
          border: Border.all(color: AppColors.borderLight.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog to Add Driver
  void _showAddDriverDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    String? selectedVehicleId;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        final availableVehicles = _fleet
            .map((item) => item['vehicle'] as MavioVehicle)
            .toList();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text(
                'Add Driver',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(
                              Icons.person_outline_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          validator: (v) =>
                              v!.trim().isEmpty ? 'Enter name' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          validator: (v) =>
                              v!.trim().isEmpty ? 'Enter email' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Mobile Number',
                            prefixIcon: Icon(
                              Icons.phone_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          validator: (v) =>
                              v!.trim().isEmpty ? 'Enter mobile number' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(
                              Icons.lock_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          validator: (v) =>
                              v!.trim().isEmpty ? 'Enter password' : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedVehicleId,
                          decoration: const InputDecoration(
                            labelText: 'Assign Bus (Optional)',
                            prefixIcon: Icon(
                              Icons.directions_bus_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          items: availableVehicles.map((v) {
                            return DropdownMenuItem<String>(
                              value: v.id,
                              child: Text(v.name),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedVehicleId = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    setState(() => _isLoading = true);
                    try {
                      await _db.addDriver(
                        nameController.text,
                        emailController.text,
                        passwordController.text,
                        selectedVehicleId,
                        phone: phoneController.text,
                      );
                      await _loadAdminData();
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Error adding: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(100, 40),
                  ),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDriverDetailsAndEditDialog(MavioProfile d) {
    final TextEditingController nameController = TextEditingController(text: d.name);
    final TextEditingController emailController = TextEditingController(text: d.email);
    final TextEditingController phoneController = TextEditingController(text: d.phone ?? '');
    String? selectedVehicleId = d.assignedVehicleId;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Driver Profile',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Full Name',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: 'Enter name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Email Address',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          hintText: 'Enter email',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Phone Number',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: phoneController,
                        decoration: InputDecoration(
                          hintText: 'Enter phone',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Assign Vehicle / Bus',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String?>(
                        value: selectedVehicleId,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Unassigned'),
                          ),
                          ..._fleet.map((item) {
                            final v = item['vehicle'] as MavioVehicle;
                            return DropdownMenuItem<String?>(
                              value: v.id,
                              child: Text(v.name),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setDialogState(() {
                            selectedVehicleId = val;
                          });
                        },
                      ),
                      const SizedBox(height: 24),

                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'Drive History & Durations',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      
                      FutureBuilder<List<MavioTrip>>(
                        future: _db.getDriverTripHistory(d.id),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          final history = snapshot.data ?? [];
                          
                          final now = DateTime.now();
                          int monthlySeconds = 0;
                          for (var trip in history) {
                            if (trip.status == 'COMPLETED' && trip.endedAt != null) {
                              if (trip.startedAt.month == now.month && trip.startedAt.year == now.year) {
                                monthlySeconds += trip.endedAt!.difference(trip.startedAt).inSeconds;
                              }
                            }
                          }
                          final hHours = monthlySeconds ~/ 3600;
                          final hMins = (monthlySeconds % 3600) ~/ 60;
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "This Month's Total: ${hHours}h ${hMins}m",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                              ),
                              const SizedBox(height: 10),
                              if (history.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text('No drive history recorded.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                                )
                              else
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: history.length > 5 ? 5 : history.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1),
                                  itemBuilder: (context, idx) {
                                    final trip = history[idx];
                                    final dateLabel = intl.DateFormat('MMM dd, yyyy').format(trip.startedAt);
                                    String durationLabel = "Active";
                                    if (trip.status == 'COMPLETED' && trip.endedAt != null) {
                                      final diff = trip.endedAt!.difference(trip.startedAt);
                                      final hrs = diff.inHours;
                                      final mns = diff.inMinutes % 60;
                                      durationLabel = hrs > 0 ? '${hrs}h ${mns}m' : '${mns}m';
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(dateLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                          Text(durationLabel, style: TextStyle(fontSize: 13, color: trip.status == 'ACTIVE' ? AppColors.success : AppColors.textPrimary)),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: AppColors.error),
                            icon: const Icon(Icons.delete_forever),
                            label: const Text('Delete'),
                            onPressed: () => _confirmDeleteProfile(dialogContext, d),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(100, 40),
                            ),
                            onPressed: () async {
                              try {
                                await _db.updateDriverDetails(
                                  id: d.id,
                                  name: nameController.text.trim(),
                                  email: emailController.text.trim(),
                                  phone: phoneController.text.trim(),
                                  assignedVehicleId: selectedVehicleId,
                                );
                                _loadAdminData();
                                if (mounted) Navigator.pop(dialogContext);
                              } catch (e) {
                                _showSnackbar('Error updating driver: $e', AppColors.error);
                              }
                            },
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteProfile(BuildContext dialogContext, MavioProfile profile) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete ${profile.name}? This will remove all their data and permanently block their login access.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
              onPressed: () async {
                try {
                  Navigator.pop(context);
                  Navigator.pop(dialogContext);
                  
                  await _db.deleteProfile(profile.id);
                  _loadAdminData();
                  _showSnackbar('${profile.name} deleted successfully.', AppColors.success);
                } catch (e) {
                  _showSnackbar('Error deleting: $e', AppColors.error);
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showStudentDetails(MavioProfile student) {
    final TextEditingController nameController = TextEditingController(text: student.name);
    final TextEditingController emailController = TextEditingController(text: student.email);
    final TextEditingController phoneController = TextEditingController(text: student.phone ?? '');
    final TextEditingController rollController = TextEditingController(text: student.rollNumber ?? '');
    final TextEditingController dobController = TextEditingController(text: student.dob ?? '');
    String? selectedVehicleId = student.assignedVehicleId;
    bool dialogLoading = false;
    final allVehicles = _fleet.map((item) => item['vehicle'] as MavioVehicle).toList();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Student Profile',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Full Name',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Email Address',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Roll Number',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: rollController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Phone Number',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: phoneController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Date of Birth (YYYY-MM-DD)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: dobController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Assign Vehicle / Bus',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String?>(
                        value: selectedVehicleId,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Unassigned'),
                          ),
                          ...allVehicles.map((v) {
                            return DropdownMenuItem<String?>(
                              value: v.id,
                              child: Text(v.name),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setDialogState(() {
                            selectedVehicleId = val;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: AppColors.error),
                            icon: const Icon(Icons.delete_forever),
                            label: const Text('Delete'),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold)),
                                    content: Text('Are you sure you want to delete ${student.name}? This will remove all their data and permanently block their login access.'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
                                        onPressed: () async {
                                          try {
                                            Navigator.pop(context);
                                            Navigator.pop(dialogContext);
                                            
                                            await _db.deleteProfile(student.id);
                                            _loadAdminData();
                                            _showSnackbar('${student.name} deleted successfully.', AppColors.success);
                                          } catch (e) {
                                            _showSnackbar('Error deleting: $e', AppColors.error);
                                          }
                                        },
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(100, 40),
                            ),
                            onPressed: dialogLoading
                                ? null
                                : () async {
                                    setDialogState(() {
                                      dialogLoading = true;
                                    });
                                    try {
                                      await _db.updateStudentDetails(
                                        id: student.id,
                                        name: nameController.text.trim(),
                                        email: emailController.text.trim(),
                                        phone: phoneController.text.trim(),
                                        rollNumber: rollController.text.trim(),
                                        dob: dobController.text.trim(),
                                        assignedVehicleId: selectedVehicleId,
                                      );
                                      _loadAdminData();
                                      if (mounted) {
                                        Navigator.pop(dialogContext);
                                      }
                                    } catch (e) {
                                      _showSnackbar('Error updating student: $e', AppColors.error);
                                    } finally {
                                      setDialogState(() {
                                        dialogLoading = false;
                                      });
                                    }
                                  },
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWebLayout(String collegeName, List<Widget> tabs) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Row(
        children: [
          // Web Left Sidebar
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 20,
                  offset: const Offset(4, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Brand Header with Premium styling
                Container(
                  padding: const EdgeInsets.all(32),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.directions_bus_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'MAVIO',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 24),
                // Navigation Items
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _buildWebSidebarItem(
                          0,
                          Icons.dashboard_rounded,
                          'Dashboard',
                        ),
                        const SizedBox(height: 8),
                        _buildWebSidebarItem(
                          1,
                          Icons.map_rounded,
                          'Live Tracker',
                        ),
                        const SizedBox(height: 8),
                        _buildWebSidebarItem(
                          2,
                          Icons.manage_accounts_rounded,
                          'Management',
                        ),
                        const SizedBox(height: 8),
                        _buildWebSidebarItem(
                          3,
                          Icons.business_rounded,
                          'Profile Settings',
                        ),
                      ],
                    ),
                  ),
                ),
                // Footer & Logout
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Text(
                        collegeName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Management Portal',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildPlanBadge(),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => _confirmLogout(context),
                        icon: const Icon(
                          Icons.logout_rounded,
                          color: Colors.redAccent,
                          size: 18,
                        ),
                        label: const Text(
                          'Log Out',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          backgroundColor: Colors.red[50],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Content Pane
          Expanded(
            child: Stack(
              children: [
                // Animated Transit Route Network Background
                const Positioned.fill(child: _DashboardTransitBackground()),
                // Dashboard Foreground UI
                Column(
                  children: [
                    // Top Header bar
                    Container(
                      height: 80,
                      color: Colors.white.withOpacity(0.85),
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _currentIndex == 0
                                ? 'Operations Dashboard'
                                : _currentIndex == 1
                                ? 'Real-Time Fleet Tracking'
                                : _currentIndex == 2
                                ? 'Database Management Control'
                                : 'Organization Profile Settings',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface.withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppColors.success,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Live Server Connected',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
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
                    const Divider(height: 1),

                    // Actual Tab View Content
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primary,
                                  ),
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: tabs[_currentIndex],
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanBadge() {
    final org = _db.currentOrganization;
    final planStatus = org?.subscriptionStatus ?? 'free_trial';

    Color color;
    String label;
    if (planStatus == 'active') {
      color = Colors.green;
      label = 'Premium';
    } else if (planStatus == 'inactive') {
      color = AppColors.error;
      label = 'Inactive';
    } else {
      color = Colors.amber;
      label = 'Free Trial';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildWebSidebarItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () {
        if (_currentIndex != index) {
          _resetSearchQueries();
        }
        setState(() => _currentIndex = index);
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 14,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(String collegeName, List<Widget> tabs) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    collegeName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildPlanBadge(),
              ],
            ),
            const Text(
              'Management Console',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: () => _confirmLogout(context),
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
          : tabs[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (_currentIndex != index) {
              _resetSearchQueries();
            }
            setState(() => _currentIndex = index);
          },
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map_rounded),
              label: 'Map Tracker',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.manage_accounts_outlined),
              activeIcon: Icon(Icons.manage_accounts_rounded),
              label: 'Manage',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.business_outlined),
              activeIcon: Icon(Icons.business_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
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
          content: const Text('Are you sure you want to log out?'),
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
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const SplashScreen()),
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
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final collegeName = auth.verifiedOrg?.name ?? "Mavio Network";

    final List<Widget> tabs = [
      _buildDashboardTab(collegeName),
      _buildMapTab(),
      _buildManagementTab(),
      _buildProfileTab(auth.verifiedOrg),
    ];

    final bool isWeb = MediaQuery.of(context).size.width > 900;
    return isWeb
        ? _buildWebLayout(collegeName, tabs)
        : _buildMobileLayout(collegeName, tabs);
  }

  // =========================================================================
  // TAB 1: OVERVIEW DASHBOARD
  // =========================================================================

  Widget _buildFleetCardItem(Map<String, dynamic> item) {
    final vehicle = item['vehicle'] as MavioVehicle;
    final isLive = item['isLive'] as bool;
    final driverName = item['driverName'] as String;
    final status = item['status'] as String;
    final activeTrip = item['activeTrip'] as MavioTrip?;
    final double? liveSpeed = isLive && activeTrip != null
        ? _liveVehicleSpeeds[activeTrip.id]
        : null;

    Color badgeBg = AppColors.textSecondary.withOpacity(0.1);
    Color badgeText = AppColors.textSecondary;
    if (status == 'LIVE') {
      badgeBg = AppColors.success.withOpacity(0.12);
      badgeText = AppColors.success;
    } else if (status == 'STOPPED') {
      badgeBg = AppColors.warning.withOpacity(0.12);
      badgeText = AppColors.warning;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                MavioVehicleDetailsScreen(fleetItem: item, db: _db),
          ),
        );
      },
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isLive
                ? AppColors.primary.withOpacity(0.4)
                : AppColors.border.withOpacity(0.5),
            width: isLive ? 1.5 : 0.8,
          ),
        ),
        color: isLive
            ? Colors.white.withOpacity(0.9)
            : Colors.white.withOpacity(0.6),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isLive ? AppColors.primaryLight : AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.directions_bus_rounded,
                  color: isLive ? AppColors.primary : AppColors.textSecondary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          vehicle.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.border,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            vehicle.regNumber,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Driver: $driverName',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (liveSpeed != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.speed_rounded,
                            size: 14,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${liveSpeed.toStringAsFixed(1)} km/h',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: badgeText,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardTab(String collegeName) {
    final bool isWeb = MediaQuery.of(context).size.width > 900;
    final org = _db.currentOrganization;
    final maxVehiclesLimit = org?.maxVehicles ?? 15;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_totalBuses > maxVehiclesLimit) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.redAccent,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Action Required: Fleet Over Plan Limit',
                          style: TextStyle(
                            color: Color(0xFF7F1D1D),
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your institution has registered $_totalBuses buses but your current plan is limited to $maxVehiclesLimit. '
                    'The extra ${_totalBuses - maxVehiclesLimit} buses have been temporarily deactivated and cannot be tracked by drivers. '
                    'Please delete excess buses or upgrade your plan to reactivate them.',
                    style: const TextStyle(
                      color: Color(0xFF991B1B),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showContactSupportInfo,
                      icon: const Icon(Icons.upgrade_rounded, color: Colors.white, size: 18),
                      label: const Text(
                        'Upgrade Plan Now',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          isWeb
              ? Row(
                  children: [
                    Expanded(
                      child: _buildKPIBlock(
                        label: 'Total Buses',
                        value: '$_totalBuses / $maxVehiclesLimit',
                        icon: Icons.directions_bus_rounded,
                        color: _totalBuses > maxVehiclesLimit ? Colors.redAccent : AppColors.primary,
                        description: 'Plan limit: $maxVehiclesLimit buses',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildKPIBlock(
                        label: 'Active Now',
                        value: _activeNow.toString(),
                        icon: Icons.wifi_tethering_rounded,
                        color: AppColors.success,
                        description: 'Buses running live routes',
                        showLiveIndicator: true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildKPIBlock(
                        label: 'Total Drivers',
                        value: _drivers.length.toString(),
                        icon: Icons.person_pin_rounded,
                        color: const Color(0xFF8B5CF6),
                        description: 'Assigned staff accounts',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildKPIBlock(
                        label: 'Tracked Students',
                        value: _students.length.toString(),
                        icon: Icons.people_alt_rounded,
                        color: const Color(0xFF06B6D4),
                        description: 'Students registered for alerts',
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildKPIBlock(
                            label: 'Total Buses',
                            value: '$_totalBuses / $maxVehiclesLimit',
                            icon: Icons.directions_bus_rounded,
                            color: _totalBuses > maxVehiclesLimit ? Colors.redAccent : AppColors.primary,
                            description: 'Limit: $maxVehiclesLimit buses',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildKPIBlock(
                            label: 'Active Now',
                            value: _activeNow.toString(),
                            icon: Icons.wifi_tethering_rounded,
                            color: AppColors.success,
                            description: 'Running live',
                            showLiveIndicator: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildKPIBlock(
                            label: 'Total Drivers',
                            value: _drivers.length.toString(),
                            icon: Icons.person_pin_rounded,
                            color: const Color(0xFF8B5CF6),
                            description: 'Staff accounts',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildKPIBlock(
                            label: 'Tracked Students',
                            value: _students.length.toString(),
                            icon: Icons.people_alt_rounded,
                            color: const Color(0xFF06B6D4),
                            description: 'Alert registry',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Buses',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentIndex = 1;
                  });
                },
                child: const Text('View All Map'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          isWeb
              ? SizedBox(
                  height: 392,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: 120,
                    ),
                    itemCount: _fleet.length,
                    itemBuilder: (context, index) {
                      return _buildFleetCardItem(_fleet[index]);
                    },
                  ),
                )
              : SizedBox(
                  height: 400,
                  child: ListView.builder(
                    itemCount: _fleet.length,
                    itemBuilder: (context, index) {
                      return _buildFleetCardItem(_fleet[index]);
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildKPIBlock({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required String description,
    bool showLiveIndicator = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              if (showLiveIndicator && _activeNow > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            value,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              height: 1.0,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: ACTIVE FLEET MAP
  // =========================================================================
  void _showMapFleetItemDetailsBottomSheet(Map<String, dynamic> item) {
    final v = item['vehicle'] as MavioVehicle;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Bus & Driver Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              _buildMapDetailTile(
                Icons.directions_bus_rounded,
                'Bus Name',
                v.name,
              ),
              const Divider(height: 24),
              _buildMapDetailTile(
                Icons.pin_rounded,
                'Registration Plate',
                v.regNumber,
              ),
              const Divider(height: 24),
              _buildMapDetailTile(
                Icons.person_rounded,
                'Assigned Driver',
                item['driverName'] as String? ?? 'Not Assigned',
              ),
              const Divider(height: 24),
              _buildMapDetailTile(
                Icons.email_rounded,
                'Driver Email',
                (item['driverEmail'] as String? ?? '').isNotEmpty
                    ? (item['driverEmail'] as String)
                    : 'Not Available',
              ),
              const Divider(height: 24),
              _buildMapDetailTile(
                Icons.wifi_tethering_rounded,
                'Tracking Status',
                item['isLive'] as bool ? 'LIVE' : 'OFFLINE',
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          MavioVehicleDetailsScreen(fleetItem: item, db: _db),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                ),
                label: const Text(
                  'Open Full Details Page',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: AppColors.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapDetailTile(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Column(
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
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMapTab() {
    final activeLocation = _mockBusLocation ?? const LatLng(11.0168, 76.9558);
    final bool isWeb = MediaQuery.of(context).size.width > 900;

    final List<Marker> markers = [];
    for (int i = 0; i < _fleet.length; i++) {
      final item = _fleet[i];
      final v = item['vehicle'] as MavioVehicle;
      final isLive = item['isLive'] as bool;

      if (!isLive) continue; // Skip offline buses from map view

      LatLng markerPos;
      final activeTrip = item['activeTrip'] as MavioTrip?;
      if (isLive &&
          activeTrip != null &&
          _liveVehicleLocations.containsKey(activeTrip.id)) {
        markerPos = _liveVehicleLocations[activeTrip.id]!;
      } else if (isLive) {
        if (v.name == 'BUS 03') {
          markerPos = activeLocation;
        } else {
          markerPos = LatLng(11.0168 + (i * 0.007), 76.9558 + (i * 0.004));
        }
      } else {
        markerPos = LatLng(11.045 - (i * 0.009), 76.995 + (i * 0.007));
      }

      final isSelected =
          _selectedMapFleetItem != null &&
          (_selectedMapFleetItem!['vehicle'] as MavioVehicle).id == v.id;

      markers.add(
        Marker(
          point: markerPos,
          width: isLive ? 52 : 40,
          height: isLive ? 52 : 40,
          child: Tooltip(
            message: v.name,
            preferBelow: false,
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            textStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedMapFleetItem = item;
                });
                _mapController.move(markerPos, 14.0);
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isLive)
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                    ),
                  Container(
                    width: isLive ? 38 : 30,
                    height: isLive ? 38 : 30,
                    decoration: BoxDecoration(
                      color: isLive
                          ? AppColors.primary
                          : AppColors.textSecondary.withOpacity(0.8),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.amber[600]! : Colors.white,
                        width: isSelected ? 3.0 : (isLive ? 2.5 : 1.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isLive ? AppColors.primary : Colors.black)
                              .withOpacity(0.2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.directions_bus_rounded,
                      color: Colors.white,
                      size: isLive ? 18 : 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final mapWidget = FlutterMap(
      mapController: _mapController,
      options: MapOptions(initialCenter: activeLocation, initialZoom: 13.0),
      children: [
        TileLayer(
          urlTemplate:
              'https://mt{s}.google.com/vt/lyrs=$_mapLayerStyle&x={x}&y={y}&z={z}',
          subdomains: const ['0', '1', '2', '3'],
          userAgentPackageName: 'com.example.mavio',
          tileDisplay: const TileDisplay.fadeIn(
            duration: Duration(milliseconds: 100),
          ),
          panBuffer: 1,
          keepBuffer: 3,
        ),
        MarkerLayer(markers: markers),
      ],
    );

    if (isWeb) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 320,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    'Fleet Status List',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: _fleet.length,
                    itemBuilder: (context, index) {
                      final item = _fleet[index];
                      final v = item['vehicle'] as MavioVehicle;
                      final isLive = item['isLive'] as bool;
                      final isSelected =
                          _selectedMapFleetItem != null &&
                          (_selectedMapFleetItem!['vehicle'] as MavioVehicle)
                                  .id ==
                              v.id;

                      return Container(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.05)
                            : Colors.transparent,
                        child: ListTile(
                          leading: Icon(
                            Icons.directions_bus_rounded,
                            color: isLive
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                          title: Text(
                            v.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            isLive ? 'LIVE' : 'OFFLINE',
                            style: TextStyle(
                              color: isLive
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                          ),
                          onTap: () {
                            setState(() {
                              _selectedMapFleetItem = item;
                            });
                            if (isLive) {
                              LatLng markerPos;
                              final activeTrip =
                                  item['activeTrip'] as MavioTrip?;
                              if (activeTrip != null &&
                                  _liveVehicleLocations.containsKey(
                                    activeTrip.id,
                                  )) {
                                markerPos =
                                    _liveVehicleLocations[activeTrip.id]!;
                              } else {
                                if (v.name == 'BUS 03') {
                                  markerPos = activeLocation;
                                } else {
                                  markerPos = LatLng(
                                    11.0168 + (index * 0.007),
                                    76.9558 + (index * 0.004),
                                  );
                                }
                              }
                              _mapController.move(markerPos, 14.5);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
                if (_selectedMapFleetItem != null) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (_selectedMapFleetItem!['vehicle'] as MavioVehicle)
                              .name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Driver: ${_selectedMapFleetItem!['driverName'] ?? "Not Assigned"}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Plate: ${(_selectedMapFleetItem!['vehicle'] as MavioVehicle).regNumber}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (_selectedMapFleetItem!['isLive'] == true) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.speed_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Speed: ${(() {
                                  final activeTrip = _selectedMapFleetItem!['activeTrip'] as MavioTrip?;
                                  final speedVal = activeTrip != null ? _liveVehicleSpeeds[activeTrip.id] : null;
                                  return (speedVal ?? 0.0).toStringAsFixed(1);
                                })()} km/h',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ] else ...[
                          const SizedBox(height: 12),
                        ],
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MavioVehicleDetailsScreen(
                                  fleetItem: _selectedMapFleetItem!,
                                  db: _db,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 36),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Full Specifications',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                mapWidget,
                if (_selectedMapFleetItem == null)
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Text(
                        'Select a bus on the left to track location',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 20,
                  right: 20,
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
              ],
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        mapWidget,
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                ),
              ],
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedMapFleetItem != null
                        ? '${(_selectedMapFleetItem!['vehicle'] as MavioVehicle).name} selected'
                        : (_activeNow > 0
                              ? 'Tracking $_activeNow active vehicle(s)'
                              : 'No live trips running'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  onPressed: () {
                    if (_selectedMapFleetItem == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Select a bus marker on the map first to view details.',
                          ),
                        ),
                      );
                    } else {
                      _showMapFleetItemDetailsBottomSheet(
                        _selectedMapFleetItem!,
                      );
                    }
                  },
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton(
            mini: true,
            onPressed: () => _showMapStyleDialog(context),
            backgroundColor: Colors.white,
            foregroundColor: AppColors.textPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.borderLight, width: 1.5),
            ),
            child: const Icon(Icons.layers_outlined, size: 20),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 3: SETTINGS / CRUD MANAGEMENT
  // =========================================================================
  Widget _buildManagementTab() {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            onTap: (idx) {
              setState(() {
                _resetSearchQueries();
              });
            },
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Vehicles'),
              Tab(text: 'Drivers'),
              Tab(text: 'Students'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildVehiclesList(),
            _buildDriversList(),
            _buildStudentsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildVehiclesList() {
    final vehicles = _fleet
        .map((item) => item['vehicle'] as MavioVehicle)
        .toList();

    if (_vehicleSortOption == 'name') {
      vehicles.sort((a, b) => _naturalCompare(a.name, b.name));
    } else if (_vehicleSortOption == 'date_oldest') {
      vehicles.sort((a, b) {
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return a.createdAt!.compareTo(b.createdAt!);
      });
    } else if (_vehicleSortOption == 'date_newest') {
      vehicles.sort((a, b) {
        if (a.createdAt == null) return -1;
        if (b.createdAt == null) return 1;
        return b.createdAt!.compareTo(a.createdAt!);
      });
    }

    final filteredVehicles = vehicles.where((v) {
      if (_vehicleQuery.isEmpty) return true;
      return v.name.toLowerCase().contains(_vehicleQuery.toLowerCase()) ||
             v.regNumber.toLowerCase().contains(_vehicleQuery.toLowerCase());
    }).toList();

    final bool isWeb = MediaQuery.of(context).size.width > 900;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double contentWidth = isWeb ? (screenWidth - 280) : screenWidth;
    int crossAxisCount = 3;
    if (contentWidth < 650) {
      crossAxisCount = 1;
    } else if (contentWidth < 1050) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 3;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _vehicleSearchCtrl,
                    onChanged: (val) {
                      setState(() {
                        _vehicleQuery = val;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: "Search Vehicles...",
                      prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                      suffixIcon: _vehicleQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: AppColors.textSecondary),
                              onPressed: () {
                                setState(() {
                                  _vehicleQuery = "";
                                  _vehicleSearchCtrl.clear();
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.borderLight),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _vehicleSortOption,
                      dropdownColor: Colors.white,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      icon: const Icon(Icons.sort_rounded, color: AppColors.textSecondary),
                      items: const [
                        DropdownMenuItem(
                          value: 'name',
                          child: Text('Sort by Name (A-Z)'),
                        ),
                        DropdownMenuItem(
                          value: 'date_oldest',
                          child: Text('Sort by Date (Oldest First)'),
                        ),
                        DropdownMenuItem(
                          value: 'date_newest',
                          child: Text('Sort by Date (Newest First)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _vehicleSortOption = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredVehicles.isEmpty
                ? const Center(
                    child: Text(
                      "No vehicles found matching search.",
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : (isWeb
                    ? GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          mainAxisExtent: 96,
                        ),
                        itemCount: filteredVehicles.length,
                        itemBuilder: (context, index) {
                          return _buildVehicleCardItem(filteredVehicles[index]);
                        },
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filteredVehicles.length,
                        itemBuilder: (context, index) {
                          return _buildVehicleCardItem(filteredVehicles[index]);
                        },
                      )),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'vehicle_excel',
            onPressed: () => _navigateToBulkImport('vehicle'),
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
            tooltip: 'Import Excel / CSV',
            child: const Icon(Icons.upload_file_rounded),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'vehicle_add',
            onPressed: _showAddVehicleDialog,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            tooltip: 'Add Vehicle',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCardItem(MavioVehicle v) {
    final allVehicles = _fleet.map((item) => item['vehicle'] as MavioVehicle).toList();
    allVehicles.sort((a, b) {
      if (a.createdAt == null) return 1;
      if (b.createdAt == null) return -1;
      return a.createdAt!.compareTo(b.createdAt!);
    });
    final index = allVehicles.indexWhere((x) => x.id == v.id);
    final limit = _db.currentOrganization?.maxVehicles ?? 15;
    final isDeactivated = index != -1 && index >= limit;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDeactivated ? const Color(0xFFFFF5F5) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDeactivated ? Colors.redAccent.withOpacity(0.3) : AppColors.border,
          width: isDeactivated ? 1.2 : 0.8,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isDeactivated ? Colors.red[50] : AppColors.primaryLight,
          child: Icon(
            Icons.directions_bus_rounded,
            color: isDeactivated ? Colors.redAccent : AppColors.primary,
          ),
        ),
        title: Row(
          children: [
            Text(
              v.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDeactivated ? Colors.red[900] : AppColors.textPrimary,
              ),
            ),
            if (isDeactivated) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Over Plan Limit',
                  style: TextStyle(
                    color: Colors.red[900],
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          v.regNumber,
          style: TextStyle(
            color: isDeactivated ? Colors.red[700]?.withOpacity(0.8) : AppColors.textSecondary,
          ),
        ),
        trailing: isDeactivated
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
                ),
                child: const Text(
                  'Deactivated',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: v.status == 'LIVE'
                      ? AppColors.success
                      : AppColors.textSecondary.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }

  Widget _buildDriversList() {
    final filteredDrivers = _drivers.where((d) {
      if (_driverQuery.isEmpty) return true;
      return d.name.toLowerCase().contains(_driverQuery.toLowerCase()) ||
             (d.phone ?? '').toLowerCase().contains(_driverQuery.toLowerCase()) ||
             d.email.toLowerCase().contains(_driverQuery.toLowerCase());
    }).toList();
    filteredDrivers.sort((a, b) => _naturalCompare(a.name, b.name));

    final bool isWeb = MediaQuery.of(context).size.width > 900;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double contentWidth = isWeb ? (screenWidth - 280) : screenWidth;
    int crossAxisCount = 3;
    if (contentWidth < 650) {
      crossAxisCount = 1;
    } else if (contentWidth < 1050) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 3;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: TextField(
              controller: _driverSearchCtrl,
              onChanged: (val) {
                setState(() {
                  _driverQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: "Search Drivers...",
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _driverQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: AppColors.textSecondary),
                        onPressed: () {
                          setState(() {
                            _driverQuery = "";
                            _driverSearchCtrl.clear();
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
              ),
            ),
          ),
          Expanded(
            child: filteredDrivers.isEmpty
                ? const Center(
                    child: Text(
                      "No drivers found matching search.",
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : (isWeb
                    ? GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          mainAxisExtent: 96,
                        ),
                        itemCount: filteredDrivers.length,
                        itemBuilder: (context, index) {
                          return _buildDriverCardItem(filteredDrivers[index]);
                        },
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filteredDrivers.length,
                        itemBuilder: (context, index) {
                          return _buildDriverCardItem(filteredDrivers[index]);
                        },
                      )),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'driver_excel',
            onPressed: () => _navigateToBulkImport('driver'),
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
            tooltip: 'Import Excel / CSV',
            child: const Icon(Icons.upload_file_rounded),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'driver_add',
            onPressed: _showAddDriverDialog,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            tooltip: 'Add Driver',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCardItem(MavioProfile d) {
    String busName = "Unassigned";
    if (d.assignedVehicleId != null) {
      final v = _fleet.firstWhere(
        (item) => (item['vehicle'] as MavioVehicle).id == d.assignedVehicleId,
        orElse: () => {},
      );
      if (v.isNotEmpty) {
        busName = (v['vehicle'] as MavioVehicle).name;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 0.8),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.primaryLight,
          child: Icon(Icons.person_rounded, color: AppColors.primary),
        ),
        title: Text(
          d.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(d.email),
        onTap: () => _showDriverDetailsAndEditDialog(d),
        trailing: Chip(
          label: Text(busName, style: const TextStyle(fontSize: 11)),
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }

  Widget _buildStudentsList() {
    final filteredStudents = _students.where((s) {
      if (_studentQuery.isEmpty) return true;
      return s.name.toLowerCase().contains(_studentQuery.toLowerCase()) ||
             (s.rollNumber ?? '').toLowerCase().contains(_studentQuery.toLowerCase()) ||
             (s.phone ?? '').toLowerCase().contains(_studentQuery.toLowerCase()) ||
             s.email.toLowerCase().contains(_studentQuery.toLowerCase());
    }).toList();
    filteredStudents.sort((a, b) => _naturalCompare(a.name, b.name));

    final bool isWeb = MediaQuery.of(context).size.width > 900;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double contentWidth = isWeb ? (screenWidth - 280) : screenWidth;
    int crossAxisCount = 3;
    if (contentWidth < 650) {
      crossAxisCount = 1;
    } else if (contentWidth < 1050) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 3;
    }

    final List<Map<String, dynamic>> busGroups = [];

    // Group active fleet buses
    for (final item in _fleet) {
      final v = item['vehicle'] as MavioVehicle;
      final driver = item['driver'] as MavioProfile?;
      final assignedStudents = _students
          .where((s) => s.assignedVehicleId == v.id)
          .toList();
      busGroups.add({
        'vehicle': v,
        'driverName': driver?.name ?? 'No Driver Assigned',
        'students': assignedStudents,
      });
    }

    // Group unassigned
    final unassignedStudents = _students
        .where((s) => s.assignedVehicleId == null)
        .toList();
    busGroups.add({
      'vehicle': null,
      'driverName': '',
      'students': unassignedStudents,
    });

    Widget gridOrList = _studentQuery.isNotEmpty
        ? ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            itemCount: filteredStudents.length,
            itemBuilder: (context, index) {
              final s = filteredStudents[index];
              String busName = "Unassigned";
              if (s.assignedVehicleId != null) {
                final v = _fleet.firstWhere(
                  (item) => (item['vehicle'] as MavioVehicle).id == s.assignedVehicleId,
                  orElse: () => {},
                );
                if (v.isNotEmpty) {
                  busName = (v['vehicle'] as MavioVehicle).name;
                }
              }
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.borderLight, width: 0.8),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(Icons.person_rounded, color: AppColors.primary),
                  ),
                  title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Roll: ${s.rollNumber ?? 'N/A'} • ${s.email}"),
                  trailing: Chip(
                    label: Text(busName, style: const TextStyle(fontSize: 11)),
                    backgroundColor: AppColors.surface,
                    side: const BorderSide(color: AppColors.border),
                  ),
                  onTap: () => _showStudentDetails(s),
                ),
              );
            },
          )
        : (isWeb
            ? GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 110,
                ),
                itemCount: busGroups.length,
                itemBuilder: (context, index) {
                  return _buildBusGroupCard(busGroups[index]);
                },
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: busGroups.length,
                itemBuilder: (context, index) {
                  return _buildBusGroupCard(busGroups[index]);
                },
              ));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: TextField(
              controller: _studentSearchCtrl,
              onChanged: (val) {
                setState(() {
                  _studentQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: "Search by Roll Number, Name, or Email...",
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _studentQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: AppColors.textSecondary),
                        onPressed: () {
                          setState(() {
                            _studentQuery = "";
                            _studentSearchCtrl.clear();
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
              ),
            ),
          ),
          Expanded(child: gridOrList),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'student_excel',
            onPressed: () => _navigateToBulkImport('student'),
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
            tooltip: 'Import Excel / CSV',
            child: const Icon(Icons.upload_file_rounded),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'student_add',
            onPressed: _showAddStudentDialog,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            tooltip: 'Add Student',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildBusGroupCard(Map<String, dynamic> group) {
    final v = group['vehicle'] as MavioVehicle?;
    final List<MavioProfile> studentsList =
        group['students'] as List<MavioProfile>;
    final String title = v != null
        ? 'Students in ${v.name}'
        : 'Unassigned Students';
    final String subtitle = v != null
        ? 'Driver: ${group['driverName']} • ${studentsList.length} Students'
        : '${studentsList.length} Students';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 0.8),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: v != null ? AppColors.primaryLight : AppColors.surface,
            shape: BoxShape.circle,
          ),
          child: Icon(
            v != null ? Icons.directions_bus_rounded : Icons.school_rounded,
            color: v != null ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, height: 1.4),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.textSecondary,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BusStudentsScreen(
                vehicle: v,
                students: studentsList,
                allVehicles: _fleet
                    .map((f) => f['vehicle'] as MavioVehicle)
                    .toList(),
                onRefresh: _loadAdminData,
                onShowStudentDetails: _showStudentDetails,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddStudentDialog() {
    final nameController = TextEditingController();
    final rollController = TextEditingController();
    final dobController = TextEditingController();
    final phoneController = TextEditingController();
    String? selectedVehicleId;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        final availableVehicles = _fleet
            .map((item) => item['vehicle'] as MavioVehicle)
            .toList();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text(
                'Add Student',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Student Name',
                            prefixIcon: Icon(
                              Icons.person_outline_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          validator: (v) =>
                              v!.trim().isEmpty ? 'Enter student name' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: rollController,
                          decoration: const InputDecoration(
                            labelText: 'Roll Number (Username)',
                            prefixIcon: Icon(
                              Icons.tag_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          validator: (v) =>
                              v!.trim().isEmpty ? 'Enter roll number' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: dobController,
                          decoration: const InputDecoration(
                            labelText:
                                'Date of Birth (Password, e.g. DDMMYYYY)',
                            prefixIcon: Icon(
                              Icons.cake_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          validator: (v) =>
                              v!.trim().isEmpty ? 'Enter DOB' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Mobile Number',
                            prefixIcon: Icon(
                              Icons.phone_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          validator: (v) =>
                              v!.trim().isEmpty ? 'Enter mobile number' : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedVehicleId,
                          decoration: const InputDecoration(
                            labelText: 'Assign Bus (Optional)',
                            prefixIcon: Icon(
                              Icons.directions_bus_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          items: availableVehicles.map((v) {
                            return DropdownMenuItem<String>(
                              value: v.id,
                              child: Text(v.name),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedVehicleId = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    setState(() => _isLoading = true);
                    final constructedEmail =
                        '${rollController.text.trim()}@mavio.student';
                    try {
                      await _db.addStudent(
                        nameController.text,
                        constructedEmail,
                        selectedVehicleId,
                        phone: phoneController.text,
                        rollNumber: rollController.text,
                        dob: dobController.text,
                      );
                      await _loadAdminData();
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Error adding: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(100, 40),
                  ),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
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

  Widget _buildProfileTab(MavioOrganization? org) {
    return _OrganizationProfileView(org: org);
  }
}

class _OrganizationProfileView extends StatefulWidget {
  final MavioOrganization? org;

  const _OrganizationProfileView({Key? key, this.org}) : super(key: key);

  @override
  State<_OrganizationProfileView> createState() => _OrganizationProfileViewState();
}

class _OrganizationProfileViewState extends State<_OrganizationProfileView> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final _passFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.org?.name ?? '');
    _codeCtrl = TextEditingController(text: widget.org?.code ?? '');
    _emailCtrl = TextEditingController(text: widget.org?.email ?? '');
    _phoneCtrl = TextEditingController(text: widget.org?.phone ?? '');
    _addressCtrl = TextEditingController(text: widget.org?.address ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final org = widget.org;
    if (org == null) {
      return const Center(
        child: Text(
          'No organization details found.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Details Card
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.business_rounded, color: AppColors.primary, size: 28),
                            SizedBox(width: 16),
                            Text(
                              'Organization Profile',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _nameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Organization Name',
                                  prefixIcon: Icon(Icons.apartment_rounded),
                                ),
                                validator: (v) => v!.trim().isEmpty ? 'Enter name' : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _codeCtrl,
                                readOnly: true,
                                decoration: InputDecoration(
                                  labelText: 'Organization Code',
                                  prefixIcon: const Icon(Icons.tag_rounded),
                                  fillColor: Colors.grey.shade50,
                                  filled: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailCtrl,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Administrator Email',
                            prefixIcon: const Icon(Icons.email_outlined),
                            fillColor: Colors.grey.shade50,
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Contact Phone Number',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _addressCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Physical Address',
                            prefixIcon: Icon(Icons.location_on_outlined),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (_formKey.currentState!.validate()) {
                              final auth = Provider.of<AuthProvider>(context, listen: false);
                              final success = await auth.updateOrganizationDetails(
                                name: _nameCtrl.text.trim(),
                                code: _codeCtrl.text.trim(),
                                phone: _phoneCtrl.text.trim(),
                                address: _addressCtrl.text.trim(),
                              );
                              if (success && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Organization details updated successfully.'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              } else if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(auth.error ?? 'Failed to update details.'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.save_rounded, size: 18),
                          label: const Text('Update Profile Details'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 2. Change Password Card
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Form(
                    key: _passFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 28),
                            SizedBox(width: 16),
                            Text(
                              'Change Password',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Update your administrator login credential. Choose a strong, secure password.',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'New Password',
                            prefixIcon: Icon(Icons.vpn_key_outlined),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Enter new password';
                            if (v.trim().length < 6) return 'Password must be at least 6 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirm New Password',
                            prefixIcon: Icon(Icons.vpn_key_rounded),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Confirm new password';
                            if (v.trim() != _passwordCtrl.text.trim()) return 'Passwords do not match';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (_passFormKey.currentState!.validate()) {
                              final auth = Provider.of<AuthProvider>(context, listen: false);
                              final success = await auth.updatePassword(_passwordCtrl.text.trim());
                              if (success && mounted) {
                                _passwordCtrl.clear();
                                _confirmPasswordCtrl.clear();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Password updated successfully.'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              } else if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(auth.error ?? 'Failed to update password.'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.lock_reset_rounded, size: 18),
                          label: const Text('Save New Password'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
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
// 4. DETAILED VEHICLE VIEW SCREEN (REAL-TIME LOCATION & DRIVER PROFILE DETAILS)
// =========================================================================
class MavioVehicleDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> fleetItem;
  final SupabaseService db;

  const MavioVehicleDetailsScreen({
    Key? key,
    required this.fleetItem,
    required this.db,
  }) : super(key: key);

  @override
  State<MavioVehicleDetailsScreen> createState() =>
      _MavioVehicleDetailsScreenState();
}

class _MavioVehicleDetailsScreenState extends State<MavioVehicleDetailsScreen> {
  late MavioVehicle _vehicle;
  late String _driverName;
  late String _driverEmail;
  late bool _isLive;
  late String _status;
  MavioTrip? _activeTrip;

  LatLng? _currentLocation;
  double? _liveSpeed;
  StreamSubscription<MavioLocationUpdate>? _locationSubscription;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _vehicle = widget.fleetItem['vehicle'] as MavioVehicle;
    _driverName = widget.fleetItem['driverName'] as String? ?? 'Not Assigned';
    _driverEmail =
        widget.fleetItem['driverEmail'] as String? ?? 'Not Available';
    _isLive = widget.fleetItem['isLive'] as bool? ?? false;
    _status = widget.fleetItem['status'] as String? ?? 'OFFLINE';
    _activeTrip = widget.fleetItem['activeTrip'] as MavioTrip?;

    if (_isLive) {
      _currentLocation = const LatLng(11.0168, 76.9558);
      _startTrackingLocation();
    } else {
      _currentLocation = const LatLng(11.025, 76.98);
    }
  }

  void _startTrackingLocation() {
    if (_activeTrip == null) return;
    _locationSubscription = widget.db
        .streamLocationUpdates(_activeTrip!.id)
        .listen(
          (loc) {
            if (!mounted) return;
            setState(() {
              _currentLocation = LatLng(loc.latitude, loc.longitude);
              _liveSpeed = loc.speed;
            });
            _mapController.move(_currentLocation!, 15.0);
          },
          onError: (err) {
            print("Error in details map stream: $err");
          },
        );
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor = AppColors.textSecondary;
    if (_status == 'LIVE') statusColor = AppColors.success;
    if (_status == 'STOPPED') statusColor = AppColors.warning;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_vehicle.name} Details'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                if (_currentLocation != null)
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentLocation!,
                      initialZoom: 14.5,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                        subdomains: const ['0', '1', '2', '3'],
                        userAgentPackageName: 'com.example.mavio',
                        tileDisplay: const TileDisplay.fadeIn(
                          duration: Duration(milliseconds: 100),
                        ),
                        panBuffer: 1,
                        keepBuffer: 3,
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentLocation!,
                            width: 50,
                            height: 50,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                if (_isLive)
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: _isLive
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.directions_bus_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  const Center(child: CircularProgressIndicator()),
                Positioned(
                  top: 16,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _status,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vehicle Specification',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      Icons.directions_bus_rounded,
                      'Bus Name',
                      _vehicle.name,
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      Icons.pin_rounded,
                      'Plate Registration',
                      _vehicle.regNumber,
                    ),
                    if (_isLive && _liveSpeed != null) ...[
                      const Divider(height: 24),
                      _buildInfoRow(
                        Icons.speed_rounded,
                        'Live Speed',
                        '${_liveSpeed!.toStringAsFixed(1)} km/h',
                      ),
                    ],
                    const SizedBox(height: 32),
                    Text(
                      'Usage & Maintenance Status',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      Icons.speed_outlined,
                      'Total Distance (Odometer)',
                      '${_vehicle.totalDistanceKm.toStringAsFixed(1)} km',
                    ),
                    const Divider(height: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          Icons.build_circle_outlined,
                          'Service Interval Status',
                          'Due in ${(_vehicle.serviceDueKm - (_vehicle.totalDistanceKm % _vehicle.serviceDueKm)).toStringAsFixed(1)} km',
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.only(left: 56.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: (_vehicle.totalDistanceKm % _vehicle.serviceDueKm) / _vehicle.serviceDueKm,
                                  backgroundColor: AppColors.borderLight,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    ((_vehicle.totalDistanceKm % _vehicle.serviceDueKm) / _vehicle.serviceDueKm) > 0.9
                                        ? Colors.redAccent
                                        : AppColors.primary,
                                  ),
                                  minHeight: 8,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Last Service: ${(_vehicle.totalDistanceKm - (_vehicle.totalDistanceKm % _vehicle.serviceDueKm)).toStringAsFixed(0)} km',
                                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                  ),
                                  Text(
                                    'Next Service: ${(_vehicle.totalDistanceKm - (_vehicle.totalDistanceKm % _vehicle.serviceDueKm) + _vehicle.serviceDueKm).toStringAsFixed(0)} km',
                                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Assigned Driver Profile',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      Icons.person_rounded,
                      'Driver Name',
                      _driverName,
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      Icons.email_rounded,
                      'Driver Email',
                      _driverEmail,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Column(
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
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class BusStudentsScreen extends StatefulWidget {
  final MavioVehicle? vehicle;
  final List<MavioProfile> students;
  final List<MavioVehicle> allVehicles;
  final VoidCallback onRefresh;
  final Function(MavioProfile) onShowStudentDetails;

  const BusStudentsScreen({
    super.key,
    required this.vehicle,
    required this.students,
    required this.allVehicles,
    required this.onRefresh,
    required this.onShowStudentDetails,
  });

  @override
  State<BusStudentsScreen> createState() => _BusStudentsScreenState();
}

class _BusStudentsScreenState extends State<BusStudentsScreen> {
  final SupabaseService _db = SupabaseService();
  bool _isLoading = false;
  late List<MavioProfile> _currentStudents;

  @override
  void initState() {
    super.initState();
    _currentStudents = List<MavioProfile>.from(widget.students);
  }

  @override
  Widget build(BuildContext context) {
    final String titleName = widget.vehicle?.name != null
        ? 'Students in ${widget.vehicle!.name}'
        : 'Unassigned Students';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          titleName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderLight, height: 1),
        ),
      ),
      body: _currentStudents.isEmpty
          ? const Center(
              child: Text(
                'No students assigned to this group.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _currentStudents.length,
              itemBuilder: (context, index) {
                final s = _currentStudents[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(
                      color: AppColors.borderLight,
                      width: 0.8,
                    ),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primaryLight,
                      child: Icon(
                        Icons.person_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      s.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(s.email),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                    ),
                    onTap: () => widget.onShowStudentDetails(s),
                  ),
                );
              },
            ),
    );
  }
}

class _DashboardTransitBackground extends StatelessWidget {
  const _DashboardTransitBackground({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _PremiumTransitBackgroundPainter()),
        ),
        Positioned(
          bottom: 10,
          right: 20,
          child: SizedBox(
            width: 480,
            height: 300,
            child: Image.asset('mavio_bus.png', fit: BoxFit.contain),
          ),
        ),
      ],
    );
  }
}

class _PremiumTransitBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Gradient 1: Top-Right Waves (Soft Orange to Light Transparent)
    final rectTR = Rect.fromLTRB(w * 0.4, 0, w, h * 0.5);
    final gradientTR = LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: [
        const Color(0xFFFFE0B2).withOpacity(0.0),
        const Color(0xFFFFB74D).withOpacity(0.12),
        const Color(0xFFFF9800).withOpacity(0.20),
      ],
    );

    final pathTR1 = Path();
    pathTR1.moveTo(w * 0.45, 0);
    pathTR1.cubicTo(w * 0.6, h * 0.25, w * 0.75, h * 0.1, w, h * 0.4);
    pathTR1.lineTo(w, 0);
    pathTR1.close();
    canvas.drawPath(pathTR1, Paint()..shader = gradientTR.createShader(rectTR));

    final pathTR2 = Path();
    pathTR2.moveTo(w * 0.55, 0);
    pathTR2.cubicTo(w * 0.7, h * 0.15, w * 0.8, h * 0.25, w, h * 0.3);
    pathTR2.lineTo(w, 0);
    pathTR2.close();
    canvas.drawPath(pathTR2, Paint()..shader = gradientTR.createShader(rectTR));

    // Gradient 2: Bottom Waves (Soft Orange to White/Transparent)
    final rectBottom = Rect.fromLTRB(0, h * 0.4, w, h);
    final gradientBottom = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFFFFE0B2).withOpacity(0.0),
        const Color(0xFFFFB74D).withOpacity(0.10),
        const Color(0xFFFF9800).withOpacity(0.16),
      ],
    );

    final pathB1 = Path();
    pathB1.moveTo(0, h * 0.7);
    pathB1.cubicTo(w * 0.2, h * 0.6, w * 0.5, h * 0.95, w, h * 0.65);
    pathB1.lineTo(w, h);
    pathB1.lineTo(0, h);
    pathB1.close();
    canvas.drawPath(
      pathB1,
      Paint()..shader = gradientBottom.createShader(rectBottom),
    );

    final pathB2 = Path();
    pathB2.moveTo(0, h * 0.8);
    pathB2.cubicTo(w * 0.3, h * 0.75, w * 0.6, h * 0.98, w, h * 0.78);
    pathB2.lineTo(w, h);
    pathB2.lineTo(0, h);
    pathB2.close();
    canvas.drawPath(
      pathB2,
      Paint()..shader = gradientBottom.createShader(rectBottom),
    );
  }

  @override
  bool shouldRepaint(covariant _PremiumTransitBackgroundPainter oldDelegate) =>
      false;
}
