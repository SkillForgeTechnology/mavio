/// Input validation utilities for the MAVIO platform.
///
/// Centralizes all validation logic to prevent injection, enforce constraints,
/// and provide consistent error messages across the app.
class InputValidator {
  // ── Text Length Constraints ──────────────────────────────────────────
  static const int maxNameLength = 200;
  static const int maxEmailLength = 320;
  static const int maxPhoneLength = 20;
  static const int maxOrgCodeLength = 50;
  static const int maxOrgNameLength = 300;
  static const int maxVehicleNameLength = 100;
  static const int maxRegNumberLength = 50;
  static const int maxComplaintTitleLength = 500;
  static const int maxComplaintDescLength = 5000;

  // ── Email Validation ────────────────────────────────────────────────
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final email = value.trim();
    if (email.length > maxEmailLength) {
      return 'Email is too long (max $maxEmailLength characters)';
    }
    if (!_emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  // ── Name Validation ─────────────────────────────────────────────────
  static String? validateName(String? value, {String fieldName = 'Name'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    if (value.trim().length > maxNameLength) {
      return '$fieldName is too long (max $maxNameLength characters)';
    }
    return null;
  }

  // ── Phone Validation ────────────────────────────────────────────────
  static final RegExp _phoneRegex = RegExp(r'^[+]?[\d\s\-()]{7,20}$');

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return null; // Phone is optional
    if (value.trim().length > maxPhoneLength) {
      return 'Phone number is too long';
    }
    if (!_phoneRegex.hasMatch(value.trim())) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  // ── Organization Code Validation ────────────────────────────────────
  static final RegExp _orgCodeRegex = RegExp(r'^[A-Z0-9]{3,50}$');

  static String? validateOrgCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Organization code is required';
    }
    final code = value.trim().toUpperCase();
    if (code.length > maxOrgCodeLength) {
      return 'Code is too long (max $maxOrgCodeLength characters)';
    }
    if (!_orgCodeRegex.hasMatch(code)) {
      return 'Code must be 3-50 uppercase alphanumeric characters';
    }
    return null;
  }

  // ── Organization Name Validation ────────────────────────────────────
  static String? validateOrgName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Organization name is required';
    }
    if (value.trim().length > maxOrgNameLength) {
      return 'Organization name is too long (max $maxOrgNameLength characters)';
    }
    return null;
  }

  // ── Vehicle Name Validation ─────────────────────────────────────────
  static String? validateVehicleName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vehicle name is required';
    }
    if (value.trim().length > maxVehicleNameLength) {
      return 'Vehicle name is too long (max $maxVehicleNameLength characters)';
    }
    return null;
  }

  // ── Registration Number Validation ──────────────────────────────────
  static String? validateRegNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Registration number is required';
    }
    if (value.trim().length > maxRegNumberLength) {
      return 'Registration number is too long (max $maxRegNumberLength characters)';
    }
    return null;
  }

  // ── Complaint Validation ────────────────────────────────────────────
  static String? validateComplaintTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Title is required';
    }
    if (value.trim().length > maxComplaintTitleLength) {
      return 'Title is too long (max $maxComplaintTitleLength characters)';
    }
    return null;
  }

  static String? validateComplaintDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Description is required';
    }
    if (value.trim().length > maxComplaintDescLength) {
      return 'Description is too long (max $maxComplaintDescLength characters)';
    }
    return null;
  }

  // ── PIN / Password Validation ───────────────────────────────────────
  static String? validatePin(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'PIN is required' : null;
    }
    if (value.trim().length < 4) {
      return 'PIN must be at least 4 characters';
    }
    if (value.trim().length > 20) {
      return 'PIN is too long (max 20 characters)';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  // ── GPS Coordinate Validation ───────────────────────────────────────
  static bool isValidLatitude(double lat) => lat >= -90 && lat <= 90;
  static bool isValidLongitude(double lon) => lon >= -180 && lon <= 180;

  static String? validateLatitude(String? value) {
    if (value == null || value.isEmpty) return 'Latitude is required';
    final lat = double.tryParse(value);
    if (lat == null || !isValidLatitude(lat)) {
      return 'Latitude must be between -90 and 90';
    }
    return null;
  }

  static String? validateLongitude(String? value) {
    if (value == null || value.isEmpty) return 'Longitude is required';
    final lon = double.tryParse(value);
    if (lon == null || !isValidLongitude(lon)) {
      return 'Longitude must be between -180 and 180';
    }
    return null;
  }

  // ── Sanitization Helpers ────────────────────────────────────────────
  /// Trims whitespace and removes null bytes (basic SQL injection guard).
  static String sanitize(String input) {
    return input.trim().replaceAll('\x00', '');
  }

  /// Sanitizes and truncates to a maximum length.
  static String sanitizeWithLimit(String input, int maxLength) {
    final clean = sanitize(input);
    return clean.length > maxLength ? clean.substring(0, maxLength) : clean;
  }
}
