import 'package:flutter/material.dart';
import '../core/services/supabase_service.dart';
import '../core/services/push_notification_service.dart';
import '../models/models.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseService _db = SupabaseService();

  bool _isLoading = false;
  String? _error;
  MavioOrganization? _verifiedOrg;
  MavioProfile? _currentProfile;

  bool get isLoading => _isLoading;
  String? get error => _error;
  MavioOrganization? get verifiedOrg => _verifiedOrg ?? _db.currentOrganization;
  MavioProfile? get currentProfile => _currentProfile ?? _db.currentUserProfile;

  bool get isAuthenticated => currentProfile != null;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    await _db.init();
    _isLoading = false;
    notifyListeners();
    
    if (currentProfile != null) {
      PushNotificationService.syncSubscriptionId(currentProfile!.id).catchError((e) {
        print("Error syncing OneSignal on init: $e");
      });
    }
  }

  // 1. Verify Organization Code
  Future<bool> verifyOrganizationCode(String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final org = await _db.verifyOrgCode(code);
      if (org != null) {
        _verifiedOrg = org;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = "Invalid organization code. Please try again.";
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 1.5. Register
  Future<bool> register(String email, String password, String role) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _db.register(email, password, role);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 2. Login
  Future<bool> login(String email, String password, String role) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final profile = await _db.login(email, password, role);
      if (profile != null) {
        _currentProfile = profile;
        _isLoading = false;
        notifyListeners();
        
        PushNotificationService.syncSubscriptionId(profile.id).catchError((e) {
          print("Error syncing OneSignal on login: $e");
        });
        
        return true;
      } else {
        _error = "Authentication failed.";
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString().replaceAll("Exception: ", "");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 3. Logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    await _db.logout();
    _currentProfile = null;
    _verifiedOrg = null;
    _isLoading = false;
    notifyListeners();
  }

  // Clear Error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
