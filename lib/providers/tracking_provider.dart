import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/push_notification_service.dart';
import '../core/services/supabase_service.dart';
import '../models/models.dart';

class TrackingProvider extends ChangeNotifier {
  final SupabaseService _db = SupabaseService();

  bool _isLoading = false;
  MavioVehicle? _assignedVehicle;

  MavioTrip? _activeTrip;
  String _driverName = "Not Assigned";
  String _driverEmail = "";
  String _driverPhone = "";
  MavioLocationUpdate? _latestLocation;
  List<LatLng> _tripPath = [];
  StreamSubscription<MavioLocationUpdate>? _locationSub;
  Timer? _tripCheckTimer;
  final Set<String> _notifiedTripIds = {};

  MavioVehicle? _originalVehicle;
  bool _isSubstituteRoute = false;

  bool get isLoading => _isLoading;
  MavioVehicle? get assignedVehicle => _assignedVehicle;
  MavioVehicle? get originalVehicle => _originalVehicle;
  bool get isSubstituteRoute => _isSubstituteRoute;

  MavioTrip? get activeTrip => _activeTrip;
  String get driverName => _driverName;
  String get driverEmail => _driverEmail;
  String get driverPhone => _driverPhone;
  MavioLocationUpdate? get latestLocation => _latestLocation;
  List<LatLng> get tripPath => _tripPath;

  bool get isTripLive => _activeTrip != null && _activeTrip!.status == 'ACTIVE';

  double? get distanceToStudentMeters {
    final profile = _db.currentUserProfile;
    if (_latestLocation == null ||
        profile == null ||
        profile.alertLatitude == null ||
        profile.alertLongitude == null) {
      return null;
    }
    return Geolocator.distanceBetween(
      _latestLocation!.latitude,
      _latestLocation!.longitude,
      profile.alertLatitude!,
      profile.alertLongitude!,
    );
  }

  double? get distanceToStudentKm =>
      distanceToStudentMeters != null ? distanceToStudentMeters! / 1000 : null;

  int? get etaMinutes {
    final dist = distanceToStudentMeters;
    if (dist == null) return null;
    final currentSpeedKmH = _latestLocation?.speed ?? 30.0;
    final effectiveSpeed = currentSpeedKmH > 5 ? currentSpeedKmH : 30.0;
    final mins = ((dist / 1000) / effectiveSpeed * 60).ceil();
    return mins < 1 ? 1 : mins;
  }

  RealtimeChannel? _statusRealtimeChannel;

  // Fetch student dashboard details and set up stream
  Future<void> loadStudentDashboard() async {
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _db.getStudentDashboardData();
      _assignedVehicle = data['vehicle'] as MavioVehicle?;
      _originalVehicle = data['originalVehicle'] as MavioVehicle?;
      _isSubstituteRoute = data['isSubstituteRoute'] as bool? ?? false;

      _activeTrip = data['activeTrip'] as MavioTrip?;
      _driverName = data['driverName'] as String? ?? "Not Assigned";
      _driverEmail = data['driverEmail'] as String? ?? "";
      _driverPhone = data['driverPhone'] as String? ?? "";

      // If trip is live, listen to location changes
      if (_activeTrip != null && _activeTrip!.status == 'ACTIVE') {
        _subscribeToLocationUpdates(_activeTrip!.id);
      } else {
        _latestLocation = null;
        _unsubscribeFromLocationUpdates();
      }

      // Start instant Realtime status channel + fast heartbeat polling
      _subscribeToRealtimeStatus();
      _startTripStatusPolling();
    } catch (e) {
      print("Error loading student dashboard: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _subscribeToRealtimeStatus() {
    _statusRealtimeChannel?.unsubscribe();
    try {
      _statusRealtimeChannel = Supabase.instance.client
          .channel('realtime:student_trip_status')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'trips',
            callback: (_) async {
              await _refreshDashboardState();
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'vehicles',
            callback: (_) async {
              await _refreshDashboardState();
            },
          )
          .subscribe();
    } catch (e) {
      print("Error subscribing to realtime status: $e");
    }
  }

  Future<void> _refreshDashboardState() async {
    try {
      final data = await _db.getStudentDashboardData();
      final newVehicle = data['vehicle'] as MavioVehicle?;
      final newOriginalVehicle = data['originalVehicle'] as MavioVehicle?;
      final newIsSubstituteRoute = data['isSubstituteRoute'] as bool? ?? false;
      final newActiveTrip = data['activeTrip'] as MavioTrip?;
      final newDriverName = data['driverName'] as String? ?? "Not Assigned";
      final newDriverEmail = data['driverEmail'] as String? ?? "";
      final newDriverPhone = data['driverPhone'] as String? ?? "";

      bool changed = false;
      if (newVehicle?.id != _assignedVehicle?.id ||
          newOriginalVehicle?.id != _originalVehicle?.id ||
          newIsSubstituteRoute != _isSubstituteRoute ||
          newActiveTrip?.id != _activeTrip?.id ||
          newActiveTrip?.status != _activeTrip?.status ||
          newDriverName != _driverName ||
          newDriverPhone != _driverPhone) {
        changed = true;
      }

      if (changed) {
        _assignedVehicle = newVehicle;
        _originalVehicle = newOriginalVehicle;
        _isSubstituteRoute = newIsSubstituteRoute;
        _activeTrip = newActiveTrip;
        _driverName = newDriverName;
        _driverEmail = newDriverEmail;
        _driverPhone = newDriverPhone;

        if (_activeTrip != null && _activeTrip!.status == 'ACTIVE') {
          _subscribeToLocationUpdates(_activeTrip!.id);
        } else {
          _latestLocation = null;
          _unsubscribeFromLocationUpdates();
        }
        notifyListeners();
      }
    } catch (e) {
      print("Error refreshing dashboard state: $e");
    }
  }

  void _startTripStatusPolling() {
    _tripCheckTimer?.cancel();
    _tripCheckTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      await _refreshDashboardState();
    });
  }

  Future<void> syncTripPath() async {
    if (_activeTrip == null || _activeTrip!.status != 'ACTIVE') return;
    try {
      final results = await Future.wait([
        _db.getTripPathCoordinates(_activeTrip!.id),
        _db.getLatestLocationUpdate(_activeTrip!.id),
      ]);
      final coords = results[0] as List<Map<String, double>>;
      final latest = results[1] as MavioLocationUpdate?;

      if (coords.isNotEmpty) {
        _tripPath = coords.map((c) => LatLng(c['latitude']!, c['longitude']!)).toList();
      }
      if (latest != null) {
        _latestLocation = latest;
      }
      notifyListeners();
    } catch (e) {
      print("Error syncing full trip path: $e");
    }
  }

  Future<void> _subscribeToLocationUpdates(String tripId) async {
    _locationSub?.cancel();
    _tripPath = [];
    try {
      final results = await Future.wait([
        _db.getTripPathCoordinates(tripId),
        _db.getLatestLocationUpdate(tripId),
      ]);
      final coords = results[0] as List<Map<String, double>>;
      final latest = results[1] as MavioLocationUpdate?;

      if (coords.isNotEmpty) {
        _tripPath = coords.map((c) => LatLng(c['latitude']!, c['longitude']!)).toList();
      }
      if (latest != null) {
        _latestLocation = latest;
      } else if (_tripPath.isNotEmpty) {
        _latestLocation = MavioLocationUpdate(
          id: 'initial',
          tripId: tripId,
          latitude: _tripPath.last.latitude,
          longitude: _tripPath.last.longitude,
          speed: 0,
          heading: 0,
          accuracy: 5,
          createdAt: DateTime.now(),
        );
      }
      notifyListeners();
    } catch (e) {
      print("Error fetching initial trip path: $e");
    }

    _locationSub = _db.streamLocationUpdates(tripId).listen((update) async {
      _latestLocation = update;
      final newPoint = LatLng(update.latitude, update.longitude);

      if (_tripPath.isEmpty) {
        _tripPath.add(newPoint);
      } else if (_tripPath.last != newPoint) {
        final lastPoint = _tripPath.last;
        final dist = Geolocator.distanceBetween(
          lastPoint.latitude,
          lastPoint.longitude,
          newPoint.latitude,
          newPoint.longitude,
        );

        // If distance jumped by > 150m (e.g. driver reconnected after network drop & flushed queued GPS points),
        // re-fetch the complete database path so all road curve points are populated!
        if (dist > 150.0) {
          try {
            final fullCoords = await _db.getTripPathCoordinates(tripId);
            if (fullCoords.isNotEmpty) {
              _tripPath = fullCoords.map((c) => LatLng(c['latitude']!, c['longitude']!)).toList();
            } else {
              _tripPath.add(newPoint);
            }
          } catch (_) {
            _tripPath.add(newPoint);
          }
        } else {
          _tripPath.add(newPoint);
        }
      }

      // Check proximity alert for student stop radius
      _checkProximityAlert(tripId, update);

      notifyListeners();
    }, onError: (err) {
      print("Error in location stream: $err");
    });
  }

  void _checkProximityAlert(String tripId, MavioLocationUpdate update) {
    final profile = _db.currentUserProfile;
    if (profile == null ||
        profile.alertLatitude == null ||
        profile.alertLongitude == null) {
      return;
    }

    if (_notifiedTripIds.contains(tripId)) return;

    final distance = Geolocator.distanceBetween(
      update.latitude,
      update.longitude,
      profile.alertLatitude!,
      profile.alertLongitude!,
    );

    final radius = (profile.alertRadiusMeters > 0) ? profile.alertRadiusMeters : 500;
    if (distance <= radius) {
      _notifiedTripIds.add(tripId);

      final busName = _assignedVehicle?.name ?? 'Your Bus';
      final distanceStr = distance < 1000
          ? "${distance.round()}m"
          : "${(distance / 1000).toStringAsFixed(1)}km";

      final alertTitle = "🚌 Bus Approaching!";
      final alertBody =
          "$busName has entered your alert zone ($distanceStr away, ${radius}m radius). Please be ready at your stop!";

      // 1. Show instant Heads-Up Local Notification if student is actively looking at app
      PushNotificationService.showLocalNotification(
        title: alertTitle,
        body: alertBody,
      );
    }
  }

  void _unsubscribeFromLocationUpdates() {
    _locationSub?.cancel();
    _locationSub = null;
    _tripPath = [];
  }

  @override
  void dispose() {
    _statusRealtimeChannel?.unsubscribe();
    _tripCheckTimer?.cancel();
    _unsubscribeFromLocationUpdates();
    super.dispose();
  }
}
