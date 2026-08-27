import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/keys.dart';
import '../../models/models.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool _isInitialized = false;
  bool _useMockMode = false;

  // Mock Database State for Demo Mode
  final Map<String, MavioOrganization> _mockOrgs = {
    'ABC123': MavioOrganization(
      id: '8a7a9a1a-1234-5678-abcd-ef0123456789',
      code: 'ABC123',
      name: 'ABC Engineering College',
      email: 'admin@abc.edu',
      phone: '+1 (555) 019-2834',
      address: '100 Innovation Way, Boston, MA',
      subscriptionStatus: 'free_trial',
      maxVehicles: 12,
      maxDrivers: 12,
      createdAt: '2026-08-18T10:00:00Z',
    ),
    'XYZ456': MavioOrganization(
      id: 'org-stanford-uuid-123456',
      code: 'XYZ456',
      name: 'Stanford University Route Hub',
      email: 'transit-admin@stanford.edu',
      phone: '+1 (650) 723-2300',
      address: '450 Serra Mall, Stanford, CA 94305',
      subscriptionStatus: 'active',
      maxVehicles: 35,
      maxDrivers: 30,
      createdAt: '2026-08-10T08:30:00Z',
    ),
    'MITS99': MavioOrganization(
      id: 'org-mit-uuid-789012',
      code: 'MITS99',
      name: 'Massachusetts Institute of Tech',
      email: 'contact-transit@mit.edu',
      phone: '+1 (617) 253-1000',
      address: '77 Massachusetts Ave, Cambridge, MA 02139',
      subscriptionStatus: 'inactive',
      maxVehicles: 8,
      maxDrivers: 8,
      createdAt: '2026-07-28T09:15:00Z',
    ),
    'SF101': MavioOrganization(
      id: 'org-skillforge-uuid-555555',
      code: 'SF101',
      name: 'SkillForge Technical Academy',
      email: 'support@skillforgetechnology.app',
      phone: '+1 (800) 555-0199',
      address: 'Suite 400, 500 Silicon Blvd, San Jose, CA',
      subscriptionStatus: 'free_trial',
      maxVehicles: 20,
      maxDrivers: 15,
      createdAt: '2026-08-19T14:20:00Z',
    ),
  };

  late final Map<String, MavioProfile> _mockProfiles = {
    'd1b11111-1111-1111-1111-111111111111': MavioProfile(
      id: 'd1b11111-1111-1111-1111-111111111111',
      email: 'student@mavio.com',
      name: 'Mathan S',
      role: 'student',
      orgId: '8a7a9a1a-1234-5678-abcd-ef0123456789',

    ),
    'd2b22222-2222-2222-2222-222222222222': MavioProfile(
      id: 'd2b22222-2222-2222-2222-222222222222',
      email: 'driver@mavio.com',
      name: 'Ravi Kumar',
      role: 'driver',
      orgId: '8a7a9a1a-1234-5678-abcd-ef0123456789',
      assignedVehicleId: 'e1a11111-1111-1111-1111-111111111111',
    ),
    'd3b33333-3333-3333-3333-333333333333': MavioProfile(
      id: 'd3b33333-3333-3333-3333-333333333333',
      email: 'admin@mavio.com',
      name: 'Admin User',
      role: 'management',
      orgId: '8a7a9a1a-1234-5678-abcd-ef0123456789',
    ),
  };

  final List<MavioVehicle> _mockVehicles = [
    MavioVehicle(
      id: 'e1a11111-1111-1111-1111-111111111111',
      name: 'BUS 03',
      regNumber: 'TN 38 AB 1234',
      status: 'OFFLINE',
      orgId: '8a7a9a1a-1234-5678-abcd-ef0123456789',
    ),
    MavioVehicle(
      id: 'e2a22222-2222-2222-2222-222222222222',
      name: 'BUS 01',
      regNumber: 'TN 38 AB 5678',
      status: 'OFFLINE',
      orgId: '8a7a9a1a-1234-5678-abcd-ef0123456789',
    ),
    MavioVehicle(
      id: 'e3a33333-3333-3333-3333-333333333333',
      name: 'BUS 02',
      regNumber: 'TN 38 AB 9012',
      status: 'OFFLINE',
      orgId: '8a7a9a1a-1234-5678-abcd-ef0123456789',
    ),
  ];



  final List<MavioTrip> _mockTrips = [
    MavioTrip(
      id: 't-mock-1',
      vehicleId: 'v1',
      driverId: 'd1b11111-1111-1111-1111-111111111111',
      status: 'COMPLETED',
      startedAt: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
      endedAt: DateTime.now().subtract(const Duration(days: 1, hours: 2, minutes: 45)),
      orgId: '8a7a9a1a-1234-5678-abcd-ef0123456789',
    ),
    MavioTrip(
      id: 't-mock-2',
      vehicleId: 'v1',
      driverId: 'd1b11111-1111-1111-1111-111111111111',
      status: 'COMPLETED',
      startedAt: DateTime.now().subtract(const Duration(days: 2, hours: 4)),
      endedAt: DateTime.now().subtract(const Duration(days: 2, hours: 2, minutes: 30)),
      orgId: '8a7a9a1a-1234-5678-abcd-ef0123456789',
    ),
    MavioTrip(
      id: 't-mock-3',
      vehicleId: 'v1',
      driverId: 'd1b11111-1111-1111-1111-111111111111',
      status: 'COMPLETED',
      startedAt: DateTime.now().subtract(const Duration(days: 3, hours: 4)),
      endedAt: DateTime.now().subtract(const Duration(days: 3, hours: 2, minutes: 50)),
      orgId: '8a7a9a1a-1234-5678-abcd-ef0123456789',
    ),
    MavioTrip(
      id: 't-mock-4',
      vehicleId: 'v2',
      driverId: 'd2b22222-2222-2222-2222-222222222222',
      status: 'COMPLETED',
      startedAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      endedAt: DateTime.now().subtract(const Duration(days: 1, hours: 1, minutes: 45)),
      orgId: '8a7a9a1a-1234-5678-abcd-ef0123456789',
    ),
    MavioTrip(
      id: 't-mock-5',
      vehicleId: 'v2',
      driverId: 'd2b22222-2222-2222-2222-222222222222',
      status: 'COMPLETED',
      startedAt: DateTime.now().subtract(const Duration(days: 2, hours: 3)),
      endedAt: DateTime.now().subtract(const Duration(days: 2, hours: 1, minutes: 30)),
      orgId: '8a7a9a1a-1234-5678-abcd-ef0123456789',
    ),
  ];
  final StreamController<MavioLocationUpdate> _mockLocationStreamController =
      StreamController<MavioLocationUpdate>.broadcast();

  // Active Session Details
  MavioProfile? _currentUserProfile;
  MavioOrganization? _currentOrganization;

  bool get useMockMode => _useMockMode;
  MavioProfile? get currentUserProfile => _currentUserProfile;
  MavioOrganization? get currentOrganization => _currentOrganization;

  // Initialize
  Future<void> init() async {
    if (_isInitialized) return;

    if (SupabaseKeys.isConfigured) {
      try {
        await Supabase.initialize(
          url: SupabaseKeys.url,
          anonKey: SupabaseKeys.anonKey,
        );
        _useMockMode = false;
        print("MAVIO: Connected to live Supabase Backend successfully!");

        // Restore persistent session details if a user is logged in
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null && session.user != null) {
          final userId = session.user!.id;
          final profileRes = await Supabase.instance.client
              .from('profiles')
              .select()
              .eq('id', userId)
              .maybeSingle();
          if (profileRes != null) {
            _currentUserProfile = MavioProfile.fromJson(profileRes);
            
            final orgRes = await Supabase.instance.client
                .from('organizations')
                .select()
                .eq('id', _currentUserProfile!.orgId)
                .maybeSingle();
            if (orgRes != null) {
              _currentOrganization = MavioOrganization.fromJson(orgRes);
            }
          }
        }
      } catch (e) {
        print("MAVIO Connection Error: $e.");
        _useMockMode = false;
      }
    } else {
      print("MAVIO: Supabase keys not set.");
      _useMockMode = false;
    }
    _isInitialized = true;
  }

  // Clear Session
  void clearSession() {
    _currentUserProfile = null;
    _currentOrganization = null;
  }

  // 1. Verify Organization Code
  Future<MavioOrganization?> verifyOrgCode(String code) async {
    await Future.delayed(const Duration(milliseconds: 600)); // Simulate latency
    final cleanCode = code.trim().toUpperCase();

    if (_useMockMode) {
      if (_mockOrgs.containsKey(cleanCode)) {
        _currentOrganization = _mockOrgs[cleanCode];
        return _currentOrganization;
      }
      return null;
    } else {
      try {
        final response = await Supabase.instance.client
            .from('organizations')
            .select()
            .eq('code', cleanCode)
            .maybeSingle();

        if (response != null) {
          _currentOrganization = MavioOrganization.fromJson(response);
          return _currentOrganization;
        }
      } catch (e) {
        print("Error verifying org code: $e");
      }
      return null;
    }
  }

  // Fetch all organizations (for super-admin)
  Future<List<MavioOrganization>> fetchOrganizations() async {
    // Run periodic database storage cleanup silently (60 days old trips pruning)
    runPeriodicCleanup().catchError((e) {
      print("Error in cleanup: $e");
    });

    if (_useMockMode) {
      return _mockOrgs.values.toList();
    } else {
      try {
        final response = await Supabase.instance.client
            .from('organizations')
            .select()
            .order('name', ascending: true);
        final List<dynamic> data = response as List<dynamic>;
        return data.map((json) => MavioOrganization.fromJson(json as Map<String, dynamic>)).toList();
      } catch (e) {
        print("Error fetching organizations: $e");
        return [];
      }
    }
  }

  // Periodic database cleanup: delete trips older than 60 days
  Future<void> runPeriodicCleanup() async {
    if (_useMockMode) return;
    try {
      final client = Supabase.instance.client;
      final limitDate = DateTime.now().subtract(const Duration(days: 60)).toUtc().toIso8601String();
      await client
          .from('trips')
          .delete()
          .lt('started_at', limitDate);
    } catch (e) {
      print("Periodic cleanup error: $e");
    }
  }

  // Create a new organization
  Future<MavioOrganization?> createOrganization({
    required String name,
    required String code,
    String? email,
    String? password,
    String? phone,
    String? address,
    String? subscriptionStatus,
    int? maxVehicles,
    int? maxDrivers,
  }) async {
    final cleanCode = code.trim().toUpperCase();
    final status = subscriptionStatus ?? 'free_trial';
    final limitVehicles = maxVehicles ?? (status == 'free_trial' ? 15 : (status == 'active' ? 25 : 10));
    final limitDrivers = maxDrivers ?? 10;

    if (_useMockMode) {
      final id = 'org-${DateTime.now().millisecondsSinceEpoch}';
      final newOrg = MavioOrganization(
        id: id,
        code: cleanCode,
        name: name,
        email: email,
        phone: phone,
        address: address,
        subscriptionStatus: status,
        maxVehicles: limitVehicles,
        maxDrivers: limitDrivers,
        createdAt: DateTime.now().toIso8601String(),
      );
      _mockOrgs[cleanCode] = newOrg;

      // Register the mock profile too!
      if (email != null && email.isNotEmpty) {
        final profileId = 'user-management-${DateTime.now().millisecondsSinceEpoch}';
        final newProfile = MavioProfile(
          id: profileId,
          email: email,
          name: email.split('@')[0].toUpperCase(),
          role: 'management',
          orgId: id,
        );
        _mockProfiles[profileId] = newProfile;
      }

      return newOrg;
    } else {
      try {
        final client = Supabase.instance.client;
        
        // 1. Create Organization
        final response = await client
            .from('organizations')
            .insert({
              'name': name,
              'code': cleanCode,
              'email': email,
              'phone': phone,
              'address': address,
              'subscription_status': status,
              'max_vehicles': limitVehicles,
              'max_drivers': limitDrivers,
            })
            .select()
            .single();
            
        final createdOrg = MavioOrganization.fromJson(response);
        
        // 2. Create Management Admin account if email and password are provided
        if (email != null && email.isNotEmpty && password != null && password.isNotEmpty) {
          final authRes = await client.auth.signUp(
            email: email.trim(),
            password: password,
            data: {
              'role': 'management',
              'org_id': createdOrg.id,
            },
          );
          
          final userId = authRes.user?.id;
          if (userId != null) {
            final profileData = {
              'id': userId,
              'email': email.trim(),
              'name': email.split('@')[0].toUpperCase(),
              'role': 'management',
              'org_id': createdOrg.id,
            };
            await client.from('profiles').insert(profileData);
          }
        }
        
        return createdOrg;
      } catch (e) {
        print("Error creating organization: $e");
        return null;
      }
    }
  }

  // Get all buses, drivers, and students for a specific organization (used in Admin Portal detailed view)
  Future<Map<String, dynamic>> getOrganizationDetailData(String orgId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_useMockMode) {
      final buses = _mockVehicles.where((v) => v.orgId == orgId).toList();
      final drivers = _mockProfiles.values.where((p) => p.orgId == orgId && p.role == 'driver').toList();
      final students = _mockProfiles.values.where((p) => p.orgId == orgId && p.role == 'student').toList();
      return {
        'buses': buses,
        'drivers': drivers,
        'students': students,
      };
    } else {
      try {
        final busesRes = await Supabase.instance.client
            .from('vehicles')
            .select()
            .eq('org_id', orgId);
        final profilesRes = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('org_id', orgId);

        final buses = (busesRes as List).map((x) => MavioVehicle.fromJson(x)).toList();
        final profiles = (profilesRes as List).map((x) => MavioProfile.fromJson(x)).toList();

        final drivers = profiles.where((p) => p.role == 'driver').toList();
        final students = profiles.where((p) => p.role == 'student').toList();

        return {
          'buses': buses,
          'drivers': drivers,
          'students': students,
        };
      } catch (e) {
        print("Error fetching org details: $e");
        return {
          'buses': <MavioVehicle>[],
          'drivers': <MavioProfile>[],
          'students': <MavioProfile>[],
        };
      }
    }
  }

  // Update an organization
  Future<MavioOrganization?> updateOrganization({
    required String id,
    required String name,
    required String code,
    String? email,
    String? phone,
    String? address,
    String? subscriptionStatus,
    int? maxVehicles,
    int? maxDrivers,
    String? createdAt,
  }) async {
    final cleanCode = code.trim().toUpperCase();
    if (_useMockMode) {
      final updatedOrg = MavioOrganization(
        id: id,
        code: cleanCode,
        name: name,
        email: email,
        phone: phone,
        address: address,
        subscriptionStatus: subscriptionStatus,
        maxVehicles: maxVehicles,
        maxDrivers: maxDrivers,
        createdAt: createdAt,
      );
      // Clean up old key if code changed
      _mockOrgs.removeWhere((k, v) => v.id == id);
      _mockOrgs[cleanCode] = updatedOrg;
      return updatedOrg;
    } else {
      try {
        final response = await Supabase.instance.client
            .from('organizations')
            .update({
              'name': name,
              'code': cleanCode,
              'email': email,
              'phone': phone,
              'address': address,
              'subscription_status': subscriptionStatus,
              'max_vehicles': maxVehicles,
              'max_drivers': maxDrivers,
            })
            .eq('id', id)
            .select()
            .single();
        return MavioOrganization.fromJson(response);
      } catch (e) {
        print("Error updating organization: $e");
        return null;
      }
    }
  }

  // Delete an organization
  Future<bool> deleteOrganization(String id) async {
    if (_useMockMode) {
      _mockOrgs.removeWhere((k, v) => v.id == id);
      return true;
    } else {
      try {
        await Supabase.instance.client
            .from('organizations')
            .delete()
            .eq('id', id);
        return true;
      } catch (e) {
        print("Error deleting organization: $e");
        return false;
      }
    }
  }

  Future<MavioProfile?> register(String email, String password, String role) async {
    if (_useMockMode) {
      final id = 'user-${DateTime.now().millisecondsSinceEpoch}';
      final newProfile = MavioProfile(
        id: id,
        email: email,
        name: email.split('@')[0].toUpperCase(),
        role: role,
        orgId: _currentOrganization?.id ?? '8a7a9a1a-1234-5678-abcd-ef0123456789',
      );
      _mockProfiles[id] = newProfile;
      _currentUserProfile = newProfile;
      return newProfile;
    } else {
      try {
        final client = Supabase.instance.client;
        
        final response = await client.auth.signUp(
          email: email.trim(),
          password: password,
          data: {
            'role': role,
            'org_id': _currentOrganization?.id ?? '8a7a9a1a-1234-5678-abcd-ef0123456789',
          },
        );

        final userId = response.user?.id;
        if (userId != null) {
          final profileData = {
            'id': userId,
            'email': email.trim(),
            'name': email.split('@')[0].toUpperCase(),
            'role': role,
            'org_id': _currentOrganization?.id ?? '8a7a9a1a-1234-5678-abcd-ef0123456789',
          };
          
          final profileRes = await client.from('profiles').insert(profileData).select().single();
          _currentUserProfile = MavioProfile.fromJson(profileRes);
          return _currentUserProfile;
        }
      } catch (e) {
        print("Registration Error: $e");
        rethrow;
      }
      return null;
    }
  }

  // 2. Sign In
  Future<MavioProfile?> login(String email, String password, String role) async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (_useMockMode) {
      // Simple mock credential matching
      MavioProfile? match;
      for (var p in _mockProfiles.values) {
        if (p.email.toLowerCase() == email.trim().toLowerCase() && p.role == role) {
          match = p;
          break;
        }
      }
      if (match != null && password == 'password') {
        _currentUserProfile = match;
        return _currentUserProfile;
      }
      throw Exception("Invalid credentials or role selection.");
    } else {
      try {
        // Authenticate via Supabase Auth
        final authRes = await Supabase.instance.client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );

        if (authRes.user != null) {
          // Fetch corresponding Profile and check if active (not deleted)
          Map<String, dynamic>? profileRes;
          try {
            profileRes = await Supabase.instance.client
                .from('profiles')
                .select()
                .eq('id', authRes.user!.id)
                .maybeSingle();
          } catch (_) {}

          if (profileRes == null) {
            await Supabase.instance.client.auth.signOut();
            throw Exception("This account has been deleted by the organization.");
          }

          final profile = MavioProfile.fromJson(profileRes);
          if (profile.role != role) {
            await Supabase.instance.client.auth.signOut();
            throw Exception("Access denied: Selected role does not match account.");
          }

          _currentUserProfile = profile;
          return _currentUserProfile;
        }
      } catch (e) {
        print("Login Error: $e");
        rethrow;
      }
      return null;
    }
  }

  // 3. Sign Out
  Future<void> logout() async {
    if (!_useMockMode) {
      await Supabase.instance.client.auth.signOut();
    }
    clearSession();
  }

  Future<void> updatePassword(String newPassword) async {
    if (_useMockMode) {
      return;
    }
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  // 4. Fetch Details for Current User
  Future<Map<String, dynamic>> getStudentDashboardData() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (_currentUserProfile == null) return {};

    final vehicleId = _currentUserProfile!.assignedVehicleId;

    if (_useMockMode) {
      MavioVehicle? vehicle = _mockVehicles.firstWhere(
        (v) => v.id == vehicleId,
        orElse: () => _mockVehicles.first,
      );

      // Check if there is an active trip for this vehicle
      MavioTrip? activeTrip;
      for (var t in _mockTrips) {
        if (t.vehicleId == vehicle.id && t.status == 'ACTIVE') {
          activeTrip = t;
          break;
        }
      }

      // Find driver name, email and phone
      String driverName = "Ravi Kumar";
      String driverEmail = "driver@mavio.com";
      String driverPhone = "9876543210";
      for (var p in _mockProfiles.values) {
        if (p.role == 'driver' && p.assignedVehicleId == vehicle.id) {
          driverName = p.name;
          driverEmail = p.email;
          driverPhone = p.phone ?? "9876543210";
          break;
        }
      }
      if (activeTrip != null) {
        final driver = _mockProfiles[activeTrip.driverId];
        if (driver != null) {
          driverName = driver.name;
          driverEmail = driver.email;
          driverPhone = driver.phone ?? "9876543210";
        }
      }

      return {
        'profile': _currentUserProfile,
        'vehicle': vehicle,
        'activeTrip': activeTrip,
        'driverName': driverName,
        'driverEmail': driverEmail,
        'driverPhone': driverPhone,
      };
    } else {
      try {
        final client = Supabase.instance.client;
        
        // Fetch fresh profile details
        final freshProfileRes = await client
            .from('profiles')
            .select()
            .eq('id', _currentUserProfile!.id)
            .single();
        _currentUserProfile = MavioProfile.fromJson(freshProfileRes);

        MavioVehicle? vehicle;
        if (_currentUserProfile!.assignedVehicleId != null) {
          final res = await client
              .from('vehicles')
              .select()
              .eq('id', _currentUserProfile!.assignedVehicleId!)
              .single();
          vehicle = MavioVehicle.fromJson(res);
        }



        MavioTrip? activeTrip;
        String driverName = "Not Assigned";
        String driverEmail = "";
        String driverPhone = "";
        if (vehicle != null) {
          // Fetch the driver assigned to this vehicle from profiles
          final driverRes = await client
              .from('profiles')
              .select()
              .eq('assigned_vehicle_id', vehicle.id)
              .eq('role', 'driver')
              .maybeSingle();
          if (driverRes != null) {
            driverName = driverRes['name'] as String? ?? "Not Assigned";
            driverEmail = driverRes['email'] as String? ?? "";
            driverPhone = driverRes['phone'] as String? ?? "";
          }

          final tripRes = await client
              .from('trips')
              .select('*, profiles:driver_id(name, email, phone)')
              .eq('vehicle_id', vehicle.id)
              .eq('status', 'ACTIVE')
              .maybeSingle();

          if (tripRes != null) {
            activeTrip = MavioTrip.fromJson(tripRes);
            final profData = tripRes['profiles'];
            if (profData != null) {
              driverName = profData['name'] as String? ?? driverName;
              driverEmail = profData['email'] as String? ?? driverEmail;
              driverPhone = profData['phone'] as String? ?? driverPhone;
            }
          }
        }

        return {
          'profile': _currentUserProfile,
          'vehicle': vehicle,
          'activeTrip': activeTrip,
          'driverName': driverName,
          'driverEmail': driverEmail,
          'driverPhone': driverPhone,
        };
      } catch (e) {
        print("Error fetching student data: $e");
        rethrow;
      }
    }
  }

  // 5. Driver: Start Trip
  Future<MavioTrip> startTrip(String vehicleId) async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (_currentUserProfile == null) throw Exception("Unauthorized");

    final orgId = _currentUserProfile!.orgId;
    final driverId = _currentUserProfile!.id;

    // Check if vehicle is deactivated due to plan limit
    MavioOrganization? org;
    if (_useMockMode) {
      org = _mockOrgs.values.firstWhere((o) => o.id == orgId, orElse: () => currentOrganization!);
    } else {
      try {
        final orgRes = await Supabase.instance.client
            .from('organizations')
            .select()
            .eq('id', orgId)
            .single();
        org = MavioOrganization.fromJson(orgRes);
      } catch (e) {
        print("Error fetching org for validation: $e");
      }
    }
    final limit = org?.maxVehicles ?? 15;

    List<MavioVehicle> vehicles = [];
    if (_useMockMode) {
      vehicles = _mockVehicles.where((v) => v.orgId == orgId).toList();
      vehicles.sort((a, b) {
        if (a.createdAt == null) return 1;
        if (b.createdAt == null) return -1;
        return a.createdAt!.compareTo(b.createdAt!);
      });
    } else {
      try {
        final res = await Supabase.instance.client
            .from('vehicles')
            .select()
            .eq('org_id', orgId)
            .order('created_at', ascending: true);
        vehicles = (res as List).map((v) => MavioVehicle.fromJson(v)).toList();
      } catch (e) {
        print("Error fetching vehicles for validation: $e");
      }
    }

    final vehicleIndex = vehicles.indexWhere((v) => v.id == vehicleId);
    if (vehicleIndex != -1 && vehicleIndex >= limit) {
      throw Exception(
        "This bus is temporarily deactivated because your institution is exceeding its plan limit ($limit buses allowed). "
        "Please ask your administrator to delete other buses or upgrade the subscription plan."
      );
    }

    if (_useMockMode) {
      // End any other active trips for this driver/vehicle
      _mockTrips.removeWhere((t) => (t.driverId == driverId || t.vehicleId == vehicleId) && t.status == 'ACTIVE');

      // Update vehicle status to LIVE
      final index = _mockVehicles.indexWhere((v) => v.id == vehicleId);
      if (index != -1) {
        final v = _mockVehicles[index];
        _mockVehicles[index] = MavioVehicle(
          id: v.id,
          name: v.name,
          regNumber: v.regNumber,
          status: 'LIVE',
          orgId: v.orgId,
        );
      }

      final trip = MavioTrip(
        id: 't-${DateTime.now().millisecondsSinceEpoch}',
        vehicleId: vehicleId,
        driverId: driverId,
        status: 'ACTIVE',
        startedAt: DateTime.now(),
        orgId: orgId,
      );

      _mockTrips.add(trip);
      return trip;
    } else {
      try {
        final client = Supabase.instance.client;

        // End any active trips for this driver or vehicle first
        await client
            .from('trips')
            .update({'status': 'COMPLETED', 'ended_at': DateTime.now().toUtc().toIso8601String()})
            .or('driver_id.eq.$driverId,vehicle_id.eq.$vehicleId')
            .eq('status', 'ACTIVE');

        // Create new active trip
        final response = await client
            .from('trips')
            .insert({
              'vehicle_id': vehicleId,
              'driver_id': driverId,

              'status': 'ACTIVE',
              'org_id': orgId,
            })
            .select()
            .single();

        // Set vehicle to LIVE
        await client
            .from('vehicles')
            .update({'status': 'LIVE'})
            .eq('id', vehicleId);

        return MavioTrip.fromJson(response);
      } catch (e) {
        print("Error starting trip: $e");
        rethrow;
      }
    }
  }

  // 6. Driver: End Trip
  Future<void> endTrip(String tripId, String vehicleId) async {
    await Future.delayed(const Duration(milliseconds: 600));

    if (_useMockMode) {
      final tripIndex = _mockTrips.indexWhere((t) => t.id == tripId);
      if (tripIndex != -1) {
        final t = _mockTrips[tripIndex];
        _mockTrips[tripIndex] = MavioTrip(
          id: t.id,
          vehicleId: t.vehicleId,
          driverId: t.driverId,

          status: 'COMPLETED',
          startedAt: t.startedAt,
          endedAt: DateTime.now(),
          orgId: t.orgId,
        );
      }

      // Update vehicle status to OFFLINE
      final vIndex = _mockVehicles.indexWhere((v) => v.id == vehicleId);
      if (vIndex != -1) {
        final v = _mockVehicles[vIndex];
        _mockVehicles[vIndex] = MavioVehicle(
          id: v.id,
          name: v.name,
          regNumber: v.regNumber,
          status: 'OFFLINE',
          orgId: v.orgId,
        );
      }
    } else {
      try {
        final client = Supabase.instance.client;

        // Set trip to completed
        await client
            .from('trips')
            .update({
              'status': 'COMPLETED',
              'ended_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', tripId);

        // Update vehicle status to OFFLINE
        await client
            .from('vehicles')
            .update({'status': 'OFFLINE'})
            .eq('id', vehicleId);
      } catch (e) {
        print("Error ending trip: $e");
        rethrow;
      }
    }
  }

  // 7. Stream Location Updates for Student View (polling-based for database flexibility)
  Stream<MavioLocationUpdate> streamLocationUpdates(String tripId) {
    if (_useMockMode) {
      return _mockLocationStreamController.stream.where((event) => event.tripId == tripId);
    } else {
      // Fetch location updates every 3 seconds to guarantee updates work even without Supabase Realtime enabled
      return Stream.periodic(const Duration(seconds: 3))
          .asyncMap((_) => getLatestLocationUpdate(tripId))
          .where((update) => update != null)
          .cast<MavioLocationUpdate>();
    }
  }

  // Stream All Location Updates for Admin Map view (polling-based for database flexibility)
  Stream<MavioLocationUpdate> streamAllLocationUpdates() {
    if (_useMockMode) {
      return _mockLocationStreamController.stream;
    } else {
      // Fetch latest locations of all trips every 3 seconds
      return Stream.periodic(const Duration(seconds: 3))
          .asyncMap((_) => getLatestLocationsOfAllTrips())
          .expand((updates) => updates)
          .cast<MavioLocationUpdate>();
    }
  }

  // Helper: Get single latest location update for a trip
  Future<MavioLocationUpdate?> getLatestLocationUpdate(String tripId) async {
    if (_useMockMode) return null;
    try {
      final response = await Supabase.instance.client
          .from('location_updates')
          .select()
          .eq('trip_id', tripId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (response != null) {
        return MavioLocationUpdate.fromJson(response);
      }
    } catch (e) {
      print("Error getting latest location update: $e");
    }
    return null;
  }

  // Helper: Get list of historical coordinates for a trip (ascending order)
  Future<List<Map<String, double>>> getTripPathCoordinates(String tripId) async {
    if (_useMockMode) return [];
    try {
      final response = await Supabase.instance.client
          .from('location_updates')
          .select('latitude, longitude')
          .eq('trip_id', tripId)
          .order('created_at', ascending: true);
      
      final list = response as List;
      return list.map((item) => {
        'latitude': (item['latitude'] as num).toDouble(),
        'longitude': (item['longitude'] as num).toDouble(),
      }).toList();
    } catch (e) {
      print("Error fetching trip coordinates: $e");
      return [];
    }
  }

  // Helper: Get latest location updates for all active trips (limits query payload)
  Future<List<MavioLocationUpdate>> getLatestLocationsOfAllTrips() async {
    if (_useMockMode) return [];
    try {
      final response = await Supabase.instance.client
          .from('location_updates')
          .select()
          .order('created_at', ascending: false)
          .limit(50);
          
      final List<MavioLocationUpdate> latestUpdates = [];
      final Set<String> tripIds = {};
      for (var row in response as List) {
        final update = MavioLocationUpdate.fromJson(row);
        if (!tripIds.contains(update.tripId)) {
          tripIds.add(update.tripId);
          latestUpdates.add(update);
        }
      }
      return latestUpdates;
    } catch (e) {
      print("Error getting latest locations of all trips: $e");
    }
    return [];
  }

  // 8. Driver: Send Live Location update
  Future<void> sendLocationUpdate({
    required String tripId,
    required double latitude,
    required double longitude,
    required double speed,
    required double heading,
    required double accuracy,
  }) async {
    final update = MavioLocationUpdate(
      id: 'loc-${DateTime.now().millisecondsSinceEpoch}',
      tripId: tripId,
      latitude: latitude,
      longitude: longitude,
      speed: speed,
      heading: heading,
      accuracy: accuracy,
      createdAt: DateTime.now(),
    );

    if (_useMockMode) {
      // Add update to local broadcast stream
      _mockLocationStreamController.add(update);
      
      // Update the status of vehicle of this trip to LIVE if stopped, or mock movement
      // Just emit stream
    } else {
      try {
        await Supabase.instance.client.from('location_updates').insert({
          'trip_id': tripId,
          'latitude': latitude,
          'longitude': longitude,
          'speed': speed,
          'heading': heading,
          'accuracy': accuracy,
        });
      } catch (e) {
        print("Error sending location update: $e");
      }
    }
  }

  // 9. Admin Dashboard Data
  Future<Map<String, dynamic>> getAdminDashboardData() async {
    await Future.delayed(const Duration(milliseconds: 600));

    if (_useMockMode) {
      final totalBuses = _mockVehicles.length;
      int activeNow = 0;
      
      final activeTripIds = <String>{};
      for (var t in _mockTrips) {
        if (t.status == 'ACTIVE') {
          activeTripIds.add(t.vehicleId);
        }
      }

      final List<Map<String, dynamic>> fleet = [];
      for (var v in _mockVehicles) {
        final isLive = activeTripIds.contains(v.id);
        if (isLive) activeNow++;

        // Find assigned driver from mock profiles
        String driverName = "Not Assigned";
        String driverEmail = "";
        for (var p in _mockProfiles.values) {
          if (p.role == 'driver' && p.assignedVehicleId == v.id) {
            driverName = p.name;
            driverEmail = p.email;
            break;
          }
        }
        MavioTrip? activeTrip;
        for (var t in _mockTrips) {
          if (t.vehicleId == v.id && t.status == 'ACTIVE') {
            activeTrip = t;
            final driver = _mockProfiles[t.driverId];
            if (driver != null) {
              driverName = driver.name;
              driverEmail = driver.email;
            }
            break;
          }
        }

        fleet.add({
          'vehicle': v,
          'isLive': isLive,
          'driverName': driverName,
          'driverEmail': driverEmail,
          'status': isLive ? 'LIVE' : (activeTrip != null ? 'STOPPED' : 'OFFLINE'),
          'activeTrip': activeTrip,
        });
      }

      return {
        'totalBuses': totalBuses,
        'activeNow': activeNow,
        'fleet': fleet,
        'routes': [],
        'drivers': _mockProfiles.values.where((p) => p.role == 'driver').toList(),
        'students': _mockProfiles.values.where((p) => p.role == 'student').toList(),
      };
    } else {
      try {
        final client = Supabase.instance.client;
        final orgId = _currentUserProfile!.orgId;

        final vehiclesRes = await client
            .from('vehicles')
            .select()
            .eq('org_id', orgId)
            .order('created_at', ascending: true);
        final vehicles = (vehiclesRes as List).map((v) => MavioVehicle.fromJson(v)).toList();

        // 2. Fetch Active Trips
        final tripsRes = await client
            .from('trips')
            .select('*, profiles:driver_id(name)')
            .eq('org_id', orgId)
            .eq('status', 'ACTIVE');
        final trips = (tripsRes as List).map((t) => MavioTrip.fromJson(t)).toList();

        final activeVehicleIds = trips.map((t) => t.vehicleId).toSet();

        // Fetch Drivers
        final driversRes = await client.from('profiles').select().eq('org_id', orgId).eq('role', 'driver');
        final drivers = (driversRes as List).map((d) => MavioProfile.fromJson(d)).toList();

        final List<Map<String, dynamic>> fleet = [];
        for (var v in vehicles) {
          final isLive = activeVehicleIds.contains(v.id);
          
          MavioTrip? activeTrip;
          if (isLive) {
            try {
              activeTrip = trips.firstWhere((t) => t.vehicleId == v.id);
            } catch (_) {
              activeTrip = null;
            }
          }
          
          String driverName = "Not Assigned";
          String driverEmail = "";
          try {
            final assignedDriver = drivers.firstWhere((d) => d.assignedVehicleId == v.id);
            driverName = assignedDriver.name;
            driverEmail = assignedDriver.email;
          } catch (_) {}

          if (isLive && activeTrip != null) {
            try {
              final tData = (tripsRes as List).firstWhere(
                (t) => t['vehicle_id'] == v.id,
                orElse: () => null,
              );
              if (tData != null && tData['profiles'] != null) {
                driverName = tData['profiles']['name'] as String? ?? driverName;
                if (tData['profiles']['email'] != null) {
                  driverEmail = tData['profiles']['email'] as String;
                }
              }
            } catch (_) {}
          }

          fleet.add({
            'vehicle': v,
            'isLive': isLive,
            'driverName': driverName,
            'driverEmail': driverEmail,
            'status': v.status,
            'activeTrip': activeTrip,
          });
        }



        final studentsRes = await client.from('profiles').select().eq('org_id', orgId).eq('role', 'student');
        final students = (studentsRes as List).map((s) => MavioProfile.fromJson(s)).toList();

        return {
          'totalBuses': vehicles.length,
          'activeNow': trips.length,
          'fleet': fleet,
          'routes': [],
          'drivers': drivers,
          'students': students,
        };
      } catch (e) {
        print("Error fetching admin dashboard data: $e");
        rethrow;
      }
    }
  }

  // 10. CRUD Helpers for Admin Settings
  Future<void> addVehicle(String name, String regNumber) async {
    if (_useMockMode) {
      _mockVehicles.add(MavioVehicle(
        id: 'v-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        regNumber: regNumber,
        status: 'OFFLINE',
        orgId: _currentUserProfile!.orgId,
      ));
    } else {
      await Supabase.instance.client.from('vehicles').insert({
        'name': name,
        'reg_number': regNumber,
        'org_id': _currentUserProfile!.orgId,
      });
    }
  }

  String _generateUuid() {
    final random = Random();
    final hexDigits = '0123456789abcdef';
    final charCodes = List<int>.generate(36, (index) {
      if (index == 8 || index == 13 || index == 18 || index == 23) {
        return 45; // '-'
      }
      return hexDigits.codeUnitAt(random.nextInt(16));
    });
    return String.fromCharCodes(charCodes);
  }

  Future<void> addDriver(String name, String email, String password, String? assignedVehicleId, {String? phone}) async {
    if (_useMockMode) {
      final id = 'd-${DateTime.now().millisecondsSinceEpoch}';
      _mockProfiles[id] = MavioProfile(
        id: id,
        email: email,
        name: name,
        role: 'driver',
        orgId: _currentUserProfile!.orgId,
        assignedVehicleId: assignedVehicleId,
        phone: phone,
      );
    } else {
      try {
        final orgId = _currentUserProfile!.orgId;
        final tempClient = SupabaseClient(
          SupabaseKeys.url,
          SupabaseKeys.anonKey,
          authOptions: const AuthClientOptions(
            authFlowType: AuthFlowType.implicit,
          ),
        );
        
        final authRes = await tempClient.auth.signUp(
          email: email.trim(),
          password: password,
          data: {
            'role': 'driver',
            'org_id': orgId,
          },
        );

        final userId = authRes.user?.id;
        if (userId != null) {
          final client = Supabase.instance.client;
          await client.from('profiles').insert({
            'id': userId,
            'email': email.trim(),
            'name': name,
            'role': 'driver',
            'org_id': orgId,
            'assigned_vehicle_id': assignedVehicleId,
            'phone': phone,
          });
        } else {
          throw Exception("Auth signUp failed to return user ID.");
        }
      } catch (e) {
        print("Error inserting driver profile: $e");
        rethrow;
      }
    }
  }

  Future<void> addStudent(String name, String email, String? assignedVehicleId, {String? phone, String? rollNumber, String? dob}) async {
    if (_useMockMode) {
      final id = 's-${DateTime.now().millisecondsSinceEpoch}';
      _mockProfiles[id] = MavioProfile(
        id: id,
        email: email,
        name: name,
        role: 'student',
        orgId: _currentUserProfile!.orgId,
        assignedVehicleId: assignedVehicleId,
        phone: phone,
        rollNumber: rollNumber,
        dob: dob,
      );
    } else {
      try {
        final orgId = _currentUserProfile!.orgId;
        final tempClient = SupabaseClient(
          SupabaseKeys.url,
          SupabaseKeys.anonKey,
          authOptions: const AuthClientOptions(
            authFlowType: AuthFlowType.implicit,
          ),
        );
        
        final authRes = await tempClient.auth.signUp(
          email: email.trim(),
          password: dob ?? 'mavio123',
          data: {
            'role': 'student',
            'org_id': orgId,
          },
        );

        final userId = authRes.user?.id;
        if (userId != null) {
          final client = Supabase.instance.client;
          await client.from('profiles').insert({
            'id': userId,
            'email': email.trim(),
            'name': name,
            'role': 'student',
            'org_id': orgId,
            'assigned_vehicle_id': assignedVehicleId,
            'phone': phone,
            'roll_number': rollNumber,
            'dob': dob,
          });
        } else {
          throw Exception("Auth signUp failed to return user ID.");
        }
      } catch (e) {
        print("Error inserting student profile: $e");
        rethrow;
      }
    }
  }

  Future<void> updateDriverAssignment(String driverId, String? vehicleId) async {
    if (_useMockMode) {
      final d = _mockProfiles[driverId];
      if (d != null) {
        _mockProfiles[driverId] = MavioProfile(
          id: d.id,
          email: d.email,
          name: d.name,
          role: d.role,
          orgId: d.orgId,
          assignedVehicleId: vehicleId,

        );
      }
    } else {
      await Supabase.instance.client
          .from('profiles')
          .update({'assigned_vehicle_id': vehicleId})
          .eq('id', driverId);
    }
  }

  Future<void> updateStudentAssignment(String studentId, String? vehicleId) async {
    if (_useMockMode) {
      final s = _mockProfiles[studentId];
      if (s != null) {
        _mockProfiles[studentId] = MavioProfile(
          id: s.id,
          email: s.email,
          name: s.name,
          role: s.role,
          orgId: s.orgId,
          assignedVehicleId: vehicleId,
        );
      }
    } else {
      await Supabase.instance.client
          .from('profiles')
          .update({
            'assigned_vehicle_id': vehicleId,
          })
          .eq('id', studentId);
    }
  }

  Future<List<MavioTrip>> getDriverTripHistory(String driverId) async {
    if (_useMockMode) {
      return _mockTrips.where((t) => t.driverId == driverId).toList();
    } else {
      try {
        final client = Supabase.instance.client;
        final response = await client
            .from('trips')
            .select()
            .eq('driver_id', driverId)
            .order('started_at', ascending: false);
        return (response as List).map((t) => MavioTrip.fromJson(t)).toList();
      } catch (e) {
        print("Error fetching driver trip history: $e");
        return [];
      }
    }
  }

  Future<void> updateDriverDetails({
    required String id,
    required String name,
    required String email,
    String? phone,
    String? assignedVehicleId,
  }) async {
    if (_useMockMode) {
      final d = _mockProfiles[id];
      if (d != null) {
        _mockProfiles[id] = MavioProfile(
          id: d.id,
          email: email,
          name: name,
          role: d.role,
          orgId: d.orgId,
          assignedVehicleId: assignedVehicleId,
          phone: phone,
        );
      }
    } else {
      await Supabase.instance.client.from('profiles').update({
        'name': name,
        'email': email,
        'phone': phone,
        'assigned_vehicle_id': assignedVehicleId,
      }).eq('id', id);

      try {
        await Supabase.instance.client.rpc(
          'update_auth_user',
          params: {
            'target_user_id': id,
            'new_email': email.trim(),
            'new_password': null,
          },
        );
      } catch (e) {
        print("Error syncing driver auth email: $e");
        rethrow;
      }
    }
  }

  Future<void> updateStudentDetails({
    required String id,
    required String name,
    required String email,
    String? phone,
    String? rollNumber,
    String? dob,
    String? assignedVehicleId,
  }) async {
    if (_useMockMode) {
      final s = _mockProfiles[id];
      if (s != null) {
        _mockProfiles[id] = MavioProfile(
          id: s.id,
          email: email,
          name: name,
          role: s.role,
          orgId: s.orgId,
          assignedVehicleId: assignedVehicleId,
          phone: phone,
          rollNumber: rollNumber,
          dob: dob,
        );
      }
    } else {
      await Supabase.instance.client.from('profiles').update({
        'name': name,
        'email': email,
        'phone': phone,
        'roll_number': rollNumber,
        'dob': dob,
        'assigned_vehicle_id': assignedVehicleId,
      }).eq('id', id);

      try {
        await Supabase.instance.client.rpc(
          'update_auth_user',
          params: {
            'target_user_id': id,
            'new_email': email.trim(),
            'new_password': dob?.trim(),
          },
        );
      } catch (e) {
        print("Error syncing student auth details: $e");
        rethrow;
      }
    }
  }

  Future<void> deleteProfile(String id) async {
    if (_useMockMode) {
      _mockProfiles.remove(id);
    } else {
      // Deleting from auth.users cascades to public.profiles
      await Supabase.instance.client.rpc(
        'delete_auth_user',
        params: {'target_user_id': id},
      );
    }
  }

  // Update student's self-service alert stop location and radius
  Future<void> updateProfileAlertStop({
    required String id,
    required double? latitude,
    required double? longitude,
    required int radiusMeters,
  }) async {
    if (_useMockMode) {
      final s = _mockProfiles[id];
      if (s != null) {
        final updated = s.copyWith(
          alertLatitude: latitude,
          alertLongitude: longitude,
          alertRadiusMeters: radiusMeters,
        );
        _mockProfiles[id] = updated;
        if (_currentUserProfile?.id == id) {
          _currentUserProfile = updated;
        }
      }
    } else {
      await Supabase.instance.client.from('profiles').update({
        'alert_latitude': latitude,
        'alert_longitude': longitude,
        'alert_radius_meters': radiusMeters,
      }).eq('id', id);

      if (_currentUserProfile?.id == id) {
        _currentUserProfile = _currentUserProfile?.copyWith(
          alertLatitude: latitude,
          alertLongitude: longitude,
          alertRadiusMeters: radiusMeters,
        );
      }
    }
  }

  // Update student's OneSignal subscription ID
  Future<void> updateProfileOneSignalId({
    required String id,
    required String? onesignalId,
  }) async {
    if (_useMockMode) {
      final s = _mockProfiles[id];
      if (s != null) {
        final updated = s.copyWith(onesignalId: onesignalId);
        _mockProfiles[id] = updated;
        if (_currentUserProfile?.id == id) {
          _currentUserProfile = updated;
        }
      }
    } else {
      await Supabase.instance.client.from('profiles').update({
        'onesignal_id': onesignalId,
      }).eq('id', id);

      if (_currentUserProfile?.id == id) {
        _currentUserProfile = _currentUserProfile?.copyWith(onesignalId: onesignalId);
      }
    }
  }
}
