class MavioOrganization {
  final String id;
  final String code;
  final String name;
  final String? email;
  final String? phone;
  final String? address;
  final String? subscriptionStatus; // 'active' | 'inactive' | 'free_trial'
  final int? maxVehicles;
  final int? maxDrivers;
  final String? createdAt;

  MavioOrganization({
    required this.id,
    required this.code,
    required this.name,
    this.email,
    this.phone,
    this.address,
    this.subscriptionStatus = 'free_trial',
    this.maxVehicles = 10,
    this.maxDrivers = 10,
    this.createdAt,
  });

  factory MavioOrganization.fromJson(Map<String, dynamic> json) {
    return MavioOrganization(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      subscriptionStatus: json['subscription_status'] as String? ?? 'free_trial',
      maxVehicles: json['max_vehicles'] as int? ?? 10,
      maxDrivers: json['max_drivers'] as int? ?? 10,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'subscription_status': subscriptionStatus,
      'max_vehicles': maxVehicles,
      'max_drivers': maxDrivers,
      'created_at': createdAt,
    };
  }
}

class MavioProfile {
  final String id;
  final String email;
  final String name;
  final String role; // 'student' | 'driver' | 'management'
  final String orgId;
  final String? assignedVehicleId;
  final String? phone;
  final String? rollNumber;
  final String? dob;
  final double? alertLatitude;
  final double? alertLongitude;
  final int alertRadiusMeters;
  final String? onesignalId;

  MavioProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.orgId,
    this.assignedVehicleId,
    this.phone,
    this.rollNumber,
    this.dob,
    this.alertLatitude,
    this.alertLongitude,
    this.alertRadiusMeters = 500,
    this.onesignalId,
  });

  factory MavioProfile.fromJson(Map<String, dynamic> json) {
    return MavioProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      orgId: json['org_id'] as String,
      assignedVehicleId: json['assigned_vehicle_id'] as String?,
      phone: json['phone'] as String?,
      rollNumber: json['roll_number'] as String?,
      dob: json['dob'] as String?,
      alertLatitude: json['alert_latitude'] != null ? (json['alert_latitude'] as num).toDouble() : null,
      alertLongitude: json['alert_longitude'] != null ? (json['alert_longitude'] as num).toDouble() : null,
      alertRadiusMeters: json['alert_radius_meters'] as int? ?? 500,
      onesignalId: json['onesignal_id'] as String?,
    );
  }

  MavioProfile copyWith({
    String? assignedVehicleId,
    String? phone,
    String? rollNumber,
    String? dob,
    double? alertLatitude,
    double? alertLongitude,
    int? alertRadiusMeters,
    String? onesignalId,
  }) {
    return MavioProfile(
      id: id,
      email: email,
      name: name,
      role: role,
      orgId: orgId,
      assignedVehicleId: assignedVehicleId ?? this.assignedVehicleId,
      phone: phone ?? this.phone,
      rollNumber: rollNumber ?? this.rollNumber,
      dob: dob ?? this.dob,
      alertLatitude: alertLatitude ?? this.alertLatitude,
      alertLongitude: alertLongitude ?? this.alertLongitude,
      alertRadiusMeters: alertRadiusMeters ?? this.alertRadiusMeters,
      onesignalId: onesignalId ?? this.onesignalId,
    );
  }
}

class MavioVehicle {
  final String id;
  final String name;
  final String regNumber;
  final String status; // 'LIVE' | 'STOPPED' | 'OFFLINE'
  final String orgId;

  MavioVehicle({
    required this.id,
    required this.name,
    required this.regNumber,
    required this.status,
    required this.orgId,
  });

  factory MavioVehicle.fromJson(Map<String, dynamic> json) {
    return MavioVehicle(
      id: json['id'] as String,
      name: json['name'] as String,
      regNumber: json['reg_number'] as String,
      status: json['status'] as String,
      orgId: json['org_id'] as String,
    );
  }
}



class MavioTrip {
  final String id;
  final String vehicleId;
  final String driverId;

  final String status; // 'ACTIVE' | 'COMPLETED'
  final DateTime startedAt;
  final DateTime? endedAt;
  final String orgId;

  MavioTrip({
    required this.id,
    required this.vehicleId,
    required this.driverId,

    required this.status,
    required this.startedAt,
    this.endedAt,
    required this.orgId,
  });

  factory MavioTrip.fromJson(Map<String, dynamic> json) {
    return MavioTrip(
      id: json['id'] as String,
      vehicleId: json['vehicle_id'] as String,
      driverId: json['driver_id'] as String,

      status: json['status'] as String,
      startedAt: DateTime.parse(json['started_at'] as String).toLocal(),
      endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at'] as String).toLocal() : null,
      orgId: json['org_id'] as String,
    );
  }
}

class MavioLocationUpdate {
  final String id;
  final String tripId;
  final double latitude;
  final double longitude;
  final double speed;
  final double heading;
  final double accuracy;
  final DateTime createdAt;

  MavioLocationUpdate({
    required this.id,
    required this.tripId,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.heading,
    required this.accuracy,
    required this.createdAt,
  });

  factory MavioLocationUpdate.fromJson(Map<String, dynamic> json) {
    return MavioLocationUpdate(
      id: json['id'].toString(),
      tripId: json['trip_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      speed: (json['speed'] as num).toDouble(),
      heading: (json['heading'] as num).toDouble(),
      accuracy: (json['accuracy'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
