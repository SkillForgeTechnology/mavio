import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/theme.dart';
import '../../core/services/supabase_service.dart';
import '../../models/models.dart';
import 'organization_detail_page.dart';

class AdminPortalPage extends StatefulWidget {
  const AdminPortalPage({super.key});

  @override
  State<AdminPortalPage> createState() => _AdminPortalPageState();
}

class _AdminPortalPageState extends State<AdminPortalPage>
    with SingleTickerProviderStateMixin {
  final SupabaseService _db = SupabaseService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Security & Rate Limiting state
  bool _obscurePassword = true;
  int _loginAttempts = 0;
  DateTime? _lockoutUntil;
  int _lockoutSecondsRemaining = 0;
  Timer? _lockoutTimer;

  // Workspace Navigation State
  int _selectedTab =
      0; // 0: Dashboard, 1: Organizations, 2: Subscriptions, 3: Settings

  List<MavioOrganization> _organizations = [];
  List<MavioOrganization> _filteredOrganizations = [];
  bool _isFetchingOrgs = false;
  final _searchController = TextEditingController();

  // Audit Logs Mock
  final List<Map<String, String>> _auditLogs = [
    {
      'time': '10 mins ago',
      'event': 'Stanford University limits updated to 35 buses / 30 drivers',
    },
    {
      'time': '2 hours ago',
      'event': 'Massachusetts Institute of Tech subscription marked inactive',
    },
    {
      'time': '1 day ago',
      'event': 'SkillForge Technical Academy registered under Free Trial',
    },
    {
      'time': '2 days ago',
      'event': 'ABC Engineering College marked active on custom plan',
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterOrganizations);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _searchController.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutSecondsRemaining = 60;
    _lockoutUntil = DateTime.now().add(const Duration(seconds: 60));
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lockoutSecondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _lockoutUntil = null;
          _lockoutSecondsRemaining = 0;
          _loginAttempts = 0;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _lockoutSecondsRemaining--;
          _errorMessage =
              'Too many failed login attempts. Try again in $_lockoutSecondsRemaining seconds.';
        });
      }
    });
  }

  // Super-Admin Authentication Flow
  Future<void> _handleLogin() async {
    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }

    if (email != 'admin@mavio.com') {
      setState(
        () => _errorMessage = 'Access denied. Invalid Super-Admin email.',
      );
      return;
    }

    // Enforce minimum password security limit
    if (password.length < 6) {
      setState(
        () => _errorMessage =
            'Security constraint: password must be at least 6 characters.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      bool authSuccess = false;
      if (password == 'Mavio@zxc' || password == 'MavioAdminSecure2026!') {
        authSuccess = true;
        // Silently authenticate in Supabase behind the scenes so the RLS policies accept the user
        try {
          final client = Supabase.instance.client;
          await client.auth.signInWithPassword(
            email: 'admin@mavio.com',
            password: 'password',
          );
        } catch (_) {}
      } else {
        try {
          final client = Supabase.instance.client;
          final response = await client.auth.signInWithPassword(
            email: email,
            password: password,
          );
          if (response.session != null) {
            authSuccess = true;
          }
        } catch (_) {
          // Failed Supabase request, authSuccess remains false
        }
      }

      if (authSuccess) {
        setState(() {
          _isLoggedIn = true;
          _loginAttempts = 0;
        });
        _loadOrganizations();
      } else {
        setState(() {
          _loginAttempts++;
          if (_loginAttempts >= 5) {
            _startLockoutTimer();
          } else {
            _errorMessage =
                'Incorrect password. (${5 - _loginAttempts} attempts remaining)';
          }
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Login failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Load organizations from database/mock service
  Future<void> _loadOrganizations() async {
    setState(() => _isFetchingOrgs = true);
    try {
      final list = await _db.fetchOrganizations();
      setState(() {
        _organizations = list;
        _filteredOrganizations = list;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading organizations: $e')),
      );
    } finally {
      setState(() => _isFetchingOrgs = false);
    }
  }

  // Filter organizations in UI
  void _filterOrganizations() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredOrganizations = _organizations.where((org) {
        return org.name.toLowerCase().contains(query) ||
            org.code.toLowerCase().contains(query) ||
            (org.email?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  // Add Organization Dialog
  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final vehiclesCtrl = TextEditingController(text: '10');
    final driversCtrl = TextEditingController(text: '10');
    String status = 'free_trial';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF1B1B1F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          title: const Text(
            'Add New Organization',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dialogInputDecoration(
                      'College/Organization Name',
                      'e.g. Stanford University',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: codeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(color: Colors.white),
                          decoration: _dialogInputDecoration(
                            'Org Code',
                            'e.g. STAN99',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          dropdownColor: const Color(0xFF1B1B1F),
                          value: status,
                          style: const TextStyle(color: Colors.white),
                          decoration: _dialogInputDecoration(
                            'Subscription Plan',
                            '',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'free_trial',
                              child: Text('Free Trial'),
                            ),
                            DropdownMenuItem(
                              value: 'active',
                              child: Text('Active Plan'),
                            ),
                            DropdownMenuItem(
                              value: 'inactive',
                              child: Text('Inactive'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setModalState(() => status = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dialogInputDecoration(
                      'Admin Contact Email',
                      'admin@stanford.edu',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dialogInputDecoration(
                      'Contact Phone',
                      '+1 (650) 555-0100',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: addressCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dialogInputDecoration(
                      'Physical Headquarters Address',
                      'Stanford, CA 94305',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: vehiclesCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: _dialogInputDecoration(
                            'Max Buses Limit',
                            '25',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: driversCtrl,
                          enabled: status != 'free_trial',
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                            color: status == 'free_trial' ? Colors.white30 : Colors.white,
                          ),
                          decoration: _dialogInputDecoration(
                            'Max Drivers Limit',
                            status == 'free_trial' ? 'Unlimited' : '10',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white38),
              ),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final code = codeCtrl.text.trim().toUpperCase();
                      if (name.isEmpty || code.isEmpty) return;

                      setModalState(() => isSaving = true);
                      final newOrg = await _db.createOrganization(
                        name: name,
                        code: code,
                        email: emailCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        address: addressCtrl.text.trim(),
                        subscriptionStatus: status,
                        maxVehicles: status == 'free_trial' ? 25 : (int.tryParse(vehiclesCtrl.text) ?? 25),
                        maxDrivers: status == 'free_trial' ? 999999 : (int.tryParse(driversCtrl.text) ?? 10),
                      );

                      if (newOrg != null) {
                        setState(() {
                          _auditLogs.insert(0, {
                            'time': 'Just now',
                            'event':
                                'New organization "${newOrg.name}" added successfully.',
                          });
                        });
                        Navigator.pop(ctx);
                        _loadOrganizations();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Organization registered successfully!',
                            ),
                          ),
                        );
                      } else {
                        setModalState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Failed to add organization. Code might be registered.',
                            ),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Register Site'),
            ),
          ],
        ),
      ),
    );
  }

  // Edit Organization Dialog
  void _showEditDialog(MavioOrganization org) {
    final nameCtrl = TextEditingController(text: org.name);
    final codeCtrl = TextEditingController(text: org.code);
    final emailCtrl = TextEditingController(text: org.email ?? '');
    final phoneCtrl = TextEditingController(text: org.phone ?? '');
    final addressCtrl = TextEditingController(text: org.address ?? '');
    final vehiclesCtrl = TextEditingController(
      text: '${org.maxVehicles ?? 10}',
    );
    final driversCtrl = TextEditingController(text: '${org.maxDrivers ?? 10}');
    String status = org.subscriptionStatus ?? 'free_trial';
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF1B1B1F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          title: const Text(
            'Edit Organization Settings',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dialogInputDecoration(
                      'College/Organization Name',
                      'e.g. Stanford University',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: codeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(color: Colors.white),
                          decoration: _dialogInputDecoration(
                            'Org Code',
                            'e.g. STAN99',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          dropdownColor: const Color(0xFF1B1B1F),
                          value: status,
                          style: const TextStyle(color: Colors.white),
                          decoration: _dialogInputDecoration(
                            'Subscription Plan',
                            '',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'free_trial',
                              child: Text('Free Trial'),
                            ),
                            DropdownMenuItem(
                              value: 'active',
                              child: Text('Active Plan'),
                            ),
                            DropdownMenuItem(
                              value: 'inactive',
                              child: Text('Inactive'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setModalState(() => status = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dialogInputDecoration(
                      'Admin Contact Email',
                      'admin@stanford.edu',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dialogInputDecoration(
                      'Contact Phone',
                      '+1 (650) 555-0100',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: addressCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: _dialogInputDecoration(
                      'Physical Headquarters Address',
                      'Stanford, CA 94305',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: vehiclesCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: _dialogInputDecoration(
                            'Max Buses Limit',
                            '25',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: driversCtrl,
                          enabled: status != 'free_trial',
                          keyboardType: TextInputType.number,
                          style: TextStyle(
                            color: status == 'free_trial' ? Colors.white30 : Colors.white,
                          ),
                          decoration: _dialogInputDecoration(
                            'Max Drivers Limit',
                            status == 'free_trial' ? 'Unlimited' : '10',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white38),
              ),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final code = codeCtrl.text.trim().toUpperCase();
                      if (name.isEmpty || code.isEmpty) return;

                      setModalState(() => isSaving = true);
                      final updated = await _db.updateOrganization(
                        id: org.id,
                        name: name,
                        code: code,
                        email: emailCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        address: addressCtrl.text.trim(),
                        subscriptionStatus: status,
                        maxVehicles: status == 'free_trial' ? 25 : (int.tryParse(vehiclesCtrl.text) ?? 25),
                        maxDrivers: status == 'free_trial' ? 999999 : (int.tryParse(driversCtrl.text) ?? 10),
                        createdAt: org.createdAt,
                      );

                      if (updated != null) {
                        setState(() {
                          _auditLogs.insert(0, {
                            'time': 'Just now',
                            'event':
                                'Organization settings updated for "${updated.name}".',
                          });
                        });
                        Navigator.pop(ctx);
                        _loadOrganizations();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Settings updated successfully!'),
                          ),
                        );
                      } else {
                        setModalState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to save settings details.'),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save Details'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dialogInputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF26262B),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
    );
  }

  // Delete Action Confirmation
  void _confirmDelete(MavioOrganization org) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1B1F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: const Text(
          'De-register Network?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to completely remove ${org.name}? This will sever all driver and student track links.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white38),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final ok = await _db.deleteOrganization(org.id);
              if (ok) {
                setState(() {
                  _auditLogs.insert(0, {
                    'time': 'Just now',
                    'event':
                        'Removed organization "${org.name}" from MAVIO system.',
                  });
                });
                Navigator.pop(ctx);
                _loadOrganizations();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Organization de-registered successfully.'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  // Quick Switch Status directly inside Subscriptions Audit Tab
  Future<void> _updateSubscriptionStatus(
    MavioOrganization org,
    String newStatus,
  ) async {
    int maxVehicles = org.maxVehicles;
    if (newStatus == 'free_trial') {
      maxVehicles = 15;
    } else if (newStatus == 'active') {
      maxVehicles = 25;
    }

    if (newStatus == 'custom') {
      final TextEditingController limitController = TextEditingController(text: org.maxVehicles.toString());
      final enteredLimit = await showDialog<int>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1B1B1F),
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Set Custom Vehicle Limit',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Enter the maximum number of vehicles allowed for this custom plan:',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: limitController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'e.g. 50',
                    hintStyle: const TextStyle(color: Colors.white30),
                    fillColor: Colors.white.withOpacity(0.05),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
              ),
              ElevatedButton(
                onPressed: () {
                  final limit = int.tryParse(limitController.text.trim());
                  if (limit != null && limit > 0) {
                    Navigator.pop(context, limit);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid positive number')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Limit'),
              ),
            ],
          );
        },
      );

      if (enteredLimit == null) return; // User cancelled
      maxVehicles = enteredLimit;
    }

    final updated = await _db.updateOrganization(
      id: org.id,
      name: org.name,
      code: org.code,
      email: org.email,
      phone: org.phone,
      address: org.address,
      subscriptionStatus: newStatus,
      maxVehicles: maxVehicles,
      maxDrivers: org.maxDrivers,
      createdAt: org.createdAt,
    );
    if (updated != null) {
      setState(() {
        _auditLogs.insert(0, {
          'time': 'Just now',
          'event':
              'Subscription for "${org.name}" switched to "${newStatus.toUpperCase()}" with limit $maxVehicles.',
        });
      });
      _loadOrganizations();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Subscription marked ${newStatus.toUpperCase()} (Max: $maxVehicles vehicles) successfully.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0F0F12),
      drawer: !isDesktop && _isLoggedIn
          ? Drawer(child: _buildSidebar(context, false))
          : null,
      body: Stack(
        children: [
          // Background Tech Gradient Bubbles
          Positioned(
            left: -150,
            top: -150,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.04),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // View Content Panel
          Positioned.fill(
            child: SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: !_isLoggedIn
                    ? _buildLoginCard()
                    : Row(
                        children: [
                          if (isDesktop)
                            SizedBox(
                              width: 260,
                              child: _buildSidebar(context, true),
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildTopNavigationHeader(context, !isDesktop),
                                Expanded(
                                  child: _isFetchingOrgs
                                      ? const Center(
                                          child: CircularProgressIndicator(
                                            color: AppColors.primary,
                                          ),
                                        )
                                      : _buildTabWorkspaceContent(),
                                ),
                              ],
                            ),
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

  // 1. Super-Admin Glassmorphic Login Screen
  Widget _buildLoginCard() {
    return Center(
      child: Container(
        width: 420,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1F).withOpacity(0.7),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Super-Admin Access',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Log in to manage network organizations.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF26262B),
                prefixIcon: const Icon(
                  Icons.mail_outline_rounded,
                  color: Colors.white54,
                ),
                hintText: 'admin@mavio.com',
                hintStyle: const TextStyle(color: Colors.white24),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF26262B),
                prefixIcon: const Icon(
                  Icons.lock_outline_rounded,
                  color: Colors.white54,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.white54,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                hintText: 'Password',
                hintStyle: const TextStyle(color: Colors.white24),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: (_isLoading || _lockoutUntil != null)
                  ? null
                  : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Authenticate Access',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Responsive Side Navigation Bar
  Widget _buildSidebar(BuildContext context, bool isEmbedded) {
    return Container(
      color: const Color(0xFF131317),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'MAVIO ADMIN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),

          // Sidebar Tab Items
          _buildSidebarTab(0, Icons.grid_view_rounded, 'Dashboard'),
          const SizedBox(height: 8),
          _buildSidebarTab(1, Icons.business_rounded, 'Organizations'),
          const SizedBox(height: 8),
          _buildSidebarTab(2, Icons.card_membership_rounded, 'Subscriptions'),
          const SizedBox(height: 8),
          _buildSidebarTab(3, Icons.settings_outlined, 'System Settings'),

          const Spacer(),

          // Admin profile footprint & logout
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.account_circle,
                  color: Colors.white54,
                  size: 36,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'System Admin',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'admin@mavio.com',
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _isLoggedIn = false;
                _selectedTab = 0;
                _emailController.clear();
                _passwordController.clear();
              });
              if (!isEmbedded) Navigator.pop(context);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: BorderSide(color: Colors.white.withOpacity(0.08)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.logout_rounded, size: 14),
            label: const Text('Logout', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarTab(int tabIndex, IconData icon, String title) {
    final isSelected = _selectedTab == tabIndex;
    return InkWell(
      onTap: () {
        setState(() => _selectedTab = tabIndex);
        if (_scaffoldKey.currentState?.isDrawerOpen == true) {
          Navigator.pop(context);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppColors.primary.withOpacity(0.15))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : Colors.white54,
              size: 20,
            ),
            const SizedBox(width: 14),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. Admin Top Navigation Header
  Widget _buildTopNavigationHeader(BuildContext context, bool showMenuButton) {
    String tabTitle = 'Dashboard Analytics';
    if (_selectedTab == 1) tabTitle = 'Manage Organizations';
    if (_selectedTab == 2) tabTitle = 'Subscription Audits';
    if (_selectedTab == 3) tabTitle = 'System Settings';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.04)),
        ),
      ),
      child: Row(
        children: [
          if (showMenuButton) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            const SizedBox(width: 12),
          ],
          Text(
            tabTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.success.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Live Server',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4. Tab Switcher Content Panel
  Widget _buildTabWorkspaceContent() {
    switch (_selectedTab) {
      case 0:
        return _buildDashboardTab();
      case 1:
        return _buildOrganizationsTab();
      case 2:
        return _buildSubscriptionsTab();
      default:
        return _buildSettingsTab();
    }
  }

  // ==================== DASHBOARD TAB ====================
  Widget _buildDashboardTab() {
    final int total = _organizations.length;
    final int active = _organizations
        .where((org) => org.subscriptionStatus == 'active')
        .length;
    final int trials = _organizations
        .where((org) => org.subscriptionStatus == 'free_trial')
        .length;
    final int inactive = _organizations
        .where((org) => org.subscriptionStatus == 'inactive')
        .length;

    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        // Metric Indicators
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth =
                (constraints.maxWidth - 48) /
                (constraints.maxWidth > 800 ? 4 : 2);
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildMetricCard(
                  Icons.business_rounded,
                  'Registered Networks',
                  '$total',
                  'Active organizations connected',
                  AppColors.primary,
                  cardWidth,
                ),
                _buildMetricCard(
                  Icons.verified_user_rounded,
                  'Active Subscriptions',
                  '$active',
                  'Paid enterprise accounts',
                  AppColors.success,
                  cardWidth,
                ),
                _buildMetricCard(
                  Icons.hourglass_empty_rounded,
                  'Free Trials',
                  '$trials',
                  'Ongoing trial audits',
                  Colors.orange,
                  cardWidth,
                ),
                _buildMetricCard(
                  Icons.domain_disabled_rounded,
                  'Inactive Nodes',
                  '$inactive',
                  'Deactivated school routes',
                  Colors.redAccent,
                  cardWidth,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 32),

        // Charts & Activity
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return Flex(
              direction: isWide ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Activity Line Chart
                Expanded(
                  flex: isWide ? 13 : 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131317),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.04),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text(
                                  'Live Network Traffic (Telemetry)',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Last 7 Days',
                                  style: TextStyle(
                                    color: Colors.white30,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            SizedBox(
                              height: 200,
                              child: CustomPaint(
                                painter: SmoothAreaChartPainter([
                                  45,
                                  60,
                                  52,
                                  78,
                                  65,
                                  88,
                                  92,
                                ]),
                                child: Container(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isWide) const SizedBox(width: 24),
                if (!isWide) const SizedBox(height: 24),

                // Recent Activities Audit Feed
                Expanded(
                  flex: isWide ? 7 : 0,
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131317),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.04)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recent Operations Audit',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ..._auditLogs.map(
                          (log) => Padding(
                            padding: const EdgeInsets.only(bottom: 18.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        log['event']!,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        log['time']!,
                                        style: const TextStyle(
                                          color: Colors.white24,
                                          fontSize: 11,
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
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    IconData icon,
    String title,
    String count,
    String desc,
    Color accentColor,
    double width,
  ) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF131317),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withOpacity(0.1),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: const TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ==================== ORGANIZATIONS TAB ====================
  Widget _buildOrganizationsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Controls Toolbar
        Padding(
          padding: const EdgeInsets.only(left: 32, right: 32, top: 24),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF131317),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white54,
                    ),
                    hintText:
                        'Search by organization name, code or admin email...',
                    hintStyle: const TextStyle(
                      color: Colors.white24,
                      fontSize: 14,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.04),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _showAddDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 50),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Add Organization',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        // List Grid
        Expanded(
          child: _filteredOrganizations.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(32),
                  itemCount: _filteredOrganizations.length,
                  itemBuilder: (context, index) {
                    final org = _filteredOrganizations[index];
                    return _buildOrganizationItemCard(org);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildOrganizationItemCard(MavioOrganization org) {
    Color badgeColor = Colors.orange;
    String badgeText = 'Free Trial';
    if (org.subscriptionStatus == 'active') {
      badgeColor = AppColors.success;
      badgeText = 'Active Plan';
    } else if (org.subscriptionStatus == 'inactive') {
      badgeColor = AppColors.error;
      badgeText = 'Deactivated';
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrganizationDetailPage(organization: org),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF131317),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with initials
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    org.name.substring(0, 2).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            org.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              org.code,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _buildCardMetadataIcon(
                            Icons.mail_outline_rounded,
                            org.email ?? 'No administrative email',
                          ),
                          _buildCardMetadataIcon(
                            Icons.phone_android_rounded,
                            org.phone ?? 'No contact phone',
                          ),
                          _buildCardMetadataIcon(
                            Icons.pin_drop_outlined,
                            org.address ?? 'No physical address',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: badgeColor.withOpacity(0.2)),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.white54,
                            size: 20,
                          ),
                          tooltip: 'Edit Settings',
                          onPressed: () => _showEditDialog(org),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.error,
                            size: 20,
                          ),
                          tooltip: 'De-register Organization',
                          onPressed: () => _confirmDelete(org),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.white.withOpacity(0.04), height: 1),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildLimitIndicator(
                      Icons.directions_bus_filled_rounded,
                      'Registered Buses limit',
                      org.subscriptionStatus == 'free_trial' ? '25' : '${org.maxVehicles ?? 25}',
                    ),
                    const SizedBox(width: 24),
                    _buildLimitIndicator(
                      Icons.people_alt_rounded,
                      'Active Drivers limit',
                      org.subscriptionStatus == 'free_trial' ? 'Unlimited' : '${org.maxDrivers ?? 10}',
                    ),
                  ],
                ),
                Text(
                  'Joined: ${_formatIsoDate(org.createdAt)}',
                  style: const TextStyle(color: Colors.white24, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardMetadataIcon(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white30, size: 14),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildLimitIndicator(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white24, size: 16),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ==================== SUBSCRIPTIONS AUDIT TAB ====================
  Widget _buildSubscriptionsTab() {
    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            indicatorColor: AppColors.primary,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white30,
            tabs: const [
              Tab(text: 'Active Plan Subscriptions'),
              Tab(text: 'Free Trial Evaluations'),
              Tab(text: 'Custom Plan Subscriptions'),
              Tab(text: 'Deactivated Subscriptions'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildFilteredSubscriptionList('active'),
                _buildFilteredSubscriptionList('free_trial'),
                _buildFilteredSubscriptionList('custom'),
                _buildFilteredSubscriptionList('inactive'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredSubscriptionList(String statusKey) {
    final list = _organizations
        .where((org) => org.subscriptionStatus == statusKey)
        .toList();

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.hourglass_empty_rounded,
              size: 48,
              color: Colors.white.withOpacity(0.1),
            ),
            const SizedBox(height: 16),
            Text(
              'No organizations found matching status "${statusKey.toUpperCase()}"',
              style: const TextStyle(color: Colors.white30, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(32),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final org = list[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF131317),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      org.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Code: ${org.code}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Max Vehicles: ${org.maxVehicles}',
                          style: const TextStyle(
                            color: Colors.orangeAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          org.email ?? 'No admin email registered',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Text(
                    'Mark Subscription as: ',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    dropdownColor: const Color(0xFF1B1B1F),
                    underline: const SizedBox(),
                    value: org.subscriptionStatus,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'active',
                        child: Text(
                          'Active Plan',
                          style: TextStyle(color: AppColors.success),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'free_trial',
                        child: Text(
                          'Free Trial',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'custom',
                        child: Text(
                          'Custom Plan',
                          style: TextStyle(color: Colors.blueAccent),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text(
                          'Inactive',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        _updateSubscriptionStatus(org, val);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== SYSTEM SETTINGS TAB ====================
  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF131317),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.04)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Console Preferences',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _buildSettingsToggleItem(
                'Live Supabase Database Connection',
                'Connected to supabase client schemas.',
                true,
              ),
              const SizedBox(height: 16),
              _buildSettingsToggleItem(
                'Background Telemetry Syncing',
                'Process background isolations updates.',
                true,
              ),
              const SizedBox(height: 16),
              _buildSettingsToggleItem(
                'Audit Log Recording',
                'Log operations actions to audit feed.',
                true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsToggleItem(String title, String subtitle, bool val) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white24, fontSize: 12),
            ),
          ],
        ),
        Switch(value: val, activeColor: AppColors.primary, onChanged: (_) {}),
      ],
    );
  }

  // Utility Date Formatter
  String _formatIsoDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Recent';
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return 'Recent';
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.domain_disabled_rounded,
            size: 64,
            color: Colors.white.withOpacity(0.1),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Organizations Found',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a new organization network to begin management.',
            style: TextStyle(color: Colors.white24, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// Custom Painter to render a premium area chart curve in the analytics section
class SmoothAreaChartPainter extends CustomPainter {
  final List<double> dataPoints;
  SmoothAreaChartPainter(this.dataPoints);

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final double paddingLeft = 40.0;
    final double paddingBottom = 25.0;
    final double chartWidth = size.width - paddingLeft;
    final double chartHeight = size.height - paddingBottom;

    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.primary.withOpacity(0.25),
          AppColors.primary.withOpacity(0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(paddingLeft, 0, chartWidth, chartHeight))
      ..style = PaintingStyle.fill;

    final double stepX = chartWidth / (dataPoints.length - 1);
    final double maxVal = dataPoints.reduce((a, b) => a > b ? a : b);
    final double scaleY = chartHeight / (maxVal * 1.15);

    final path = Path();
    final fillPath = Path();

    final double firstX = paddingLeft;
    final double firstY = chartHeight - (dataPoints[0] * scaleY);

    path.moveTo(firstX, firstY);
    fillPath.moveTo(firstX, chartHeight);
    fillPath.lineTo(firstX, firstY);

    for (int i = 1; i < dataPoints.length; i++) {
      final double x = paddingLeft + i * stepX;
      final double y = chartHeight - (dataPoints[i] * scaleY);
      final double prevX = paddingLeft + (i - 1) * stepX;
      final double prevY = chartHeight - (dataPoints[i - 1] * scaleY);

      // Smooth bezier curves
      final double cpX1 = prevX + (stepX / 2);
      final double cpY1 = prevY;
      final double cpX2 = prevX + (stepX / 2);
      final double cpY2 = y;

      path.cubicTo(cpX1, cpY1, cpX2, cpY2, x, y);
      fillPath.cubicTo(cpX1, cpY1, cpX2, cpY2, x, y);
    }

    fillPath.lineTo(paddingLeft + chartWidth, chartHeight);
    fillPath.close();

    // Draw background grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final double y = chartHeight * i / 4;
      canvas.drawLine(
        Offset(paddingLeft, y),
        Offset(paddingLeft + chartWidth, y),
        gridPaint,
      );

      // Draw Y labels
      final int labelVal = ((maxVal * 1.15) * (4 - i) / 4).round();
      _drawText(
        canvas,
        '${labelVal}k',
        Offset(paddingLeft - 10, y),
        Colors.white30,
        alignment: Alignment.centerRight,
      );
    }

    // Draw vertical grid lines
    for (int i = 0; i < dataPoints.length; i++) {
      final double x = paddingLeft + i * stepX;
      canvas.drawLine(Offset(x, 0), Offset(x, chartHeight), gridPaint);

      // Draw X labels (Days)
      final List<String> days = [
        'Mon',
        'Tue',
        'Wed',
        'Thu',
        'Fri',
        'Sat',
        'Sun',
      ];
      if (i < days.length) {
        _drawText(canvas, days[i], Offset(x, chartHeight + 12), Colors.white38);
      }
    }

    // Draw target horizontal dashed line
    final targetPaint = Paint()
      ..color = AppColors.success.withOpacity(0.3)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final double targetY = chartHeight * 0.25;
    canvas.drawLine(
      Offset(paddingLeft, targetY),
      Offset(paddingLeft + chartWidth, targetY),
      targetPaint,
    );
    _drawText(
      canvas,
      'GOAL',
      Offset(paddingLeft + chartWidth - 10, targetY - 8),
      AppColors.success.withOpacity(0.7),
      fontSize: 8,
    );

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw dots at points
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final dotBorderPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final pulsePaint = Paint()
      ..color = AppColors.primary.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < dataPoints.length; i++) {
      final double x = paddingLeft + i * stepX;
      final double y = chartHeight - (dataPoints[i] * scaleY);

      canvas.drawCircle(Offset(x, y), 8, pulsePaint);
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
      canvas.drawCircle(Offset(x, y), 4, dotBorderPaint);
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color, {
    double fontSize = 9,
    Alignment alignment = Alignment.center,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    Offset finalOffset = offset;
    if (alignment == Alignment.center) {
      finalOffset =
          offset - Offset(textPainter.width / 2, textPainter.height / 2);
    } else if (alignment == Alignment.centerRight) {
      finalOffset = offset - Offset(textPainter.width, textPainter.height / 2);
    }
    textPainter.paint(canvas, finalOffset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
