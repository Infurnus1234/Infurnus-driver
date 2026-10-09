import '../services/api_service.dart';

class DocumentRule {
  final String code;
  final bool required;
  final bool requiresExpiry;
  final int minimumPages;
  const DocumentRule(
    this.code, {
    this.required = false,
    this.requiresExpiry = false,
    this.minimumPages = 1,
  });
  factory DocumentRule.fromJson(Map<String, dynamic> json) => DocumentRule(
    json['document_code'] as String,
    required: json['required'] as bool,
    requiresExpiry: json['requires_expiry'] as bool,
    minimumPages: (json['minimum_pages'] as num).toInt(),
  );
  String get uploadType =>
      const [
        'profile_photo',
        'driver_license',
        'vehicle_rc',
        'identity',
        'pan',
      ].contains(code)
      ? code
      : 'other';
  String get label => code.replaceAll('_', ' ');
}

/// Exact server field bounds; optional personal fields remain optional.
class OnboardingRules {
  static String today() =>
      DateTime.now().toUtc().toIso8601String().substring(0, 10);
  static bool validDate(String value) {
    final parsed = DateTime.tryParse(value);
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
        parsed != null &&
        parsed.toIso8601String().substring(0, 10) == value;
  }

  static String? validateSignup(Map<String, dynamic> data) {
    for (final key in ['firstName', 'lastName']) {
      if ((data[key] as String? ?? '').trim().isEmpty ||
          (data[key] as String).length > 100) {
        return 'First and last names are required (up to 100 characters each).';
      }
    }
    final email = data['email'] as String? ?? '';
    final phone = data['phone'] as String? ?? '';
    if (email.isEmpty && phone.isEmpty) {
      return 'Enter an email address or phone number.';
    }
    if (email.isNotEmpty &&
        (email.length > 320 ||
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email))) {
      return 'Enter a valid email address.';
    }
    if (phone.isNotEmpty && !RegExp(r'^\+?[1-9]\d{7,14}$').hasMatch(phone)) {
      return 'Enter a valid phone number.';
    }
    final password = data['password'] as String? ?? '';
    if (password.length < 8 || password.length > 128) {
      return 'Password must contain 8–128 characters.';
    }
    if (password != data['confirmPassword']) return 'Passwords do not match.';
    final role = data['role'] ?? 'driver';
    if (!['driver', 'fleet_owner', 'driver_fleet_owner'].contains(role)) {
      return 'Select a supported Driver/Fleet role.';
    }
    if (role != 'driver') {
      final business = data['businessName'] as String? ?? '';
      if (business.trim().isEmpty || business.length > 150) {
        return 'Enter your business name (up to 150 characters).';
      }
    }
    return role == 'fleet_owner' ? null : validateProfile(data);
  }

  static String? validateProfile(Map<String, dynamic> data) {
    final licence = data['licenseNumber'] as String? ?? '';
    if (licence.trim().isEmpty || licence.length > 50) {
      return 'Enter your driving licence number (up to 50 characters).';
    }
    final expiry = data['licenseExpiry'] as String? ?? '';
    if (!validDate(expiry) || expiry.compareTo(today()) < 0) {
      return 'Licence expiry must be a valid date today or later.';
    }
    final dob = data['dob'] as String?;
    if (dob != null && (!validDate(dob) || dob.compareTo(today()) > 0)) {
      return 'Date of birth must be a valid date today or earlier.';
    }
    const bounds = {
      'gender': 20,
      'address': 500,
      'city': 100,
      'state': 100,
      'pinCode': 20,
      'emergencyContactName': 100,
      'emergencyContactPhone': 20,
      'emergencyContactRelationship': 100,
      'alternateContactPhone': 20,
    };
    for (final field in bounds.entries) {
      if ((data[field.key] as String? ?? '').length > field.value) {
        return '${field.key} exceeds ${field.value} characters.';
      }
    }
    return null;
  }

  static String? validateFiles(
    DocumentRule rule,
    List<DocumentFile> files,
    Map<String, String> metadata,
  ) {
    if (files.length < rule.minimumPages ||
        files.length > 5 ||
        (rule.code == 'profile_photo' && files.length != 1)) {
      return rule.code == 'profile_photo'
          ? 'Select one profile image.'
          : 'Select ${rule.minimumPages}–5 files/pages.';
    }
    final limit = (rule.code == 'profile_photo' ? 10 : 15) * 1024 * 1024;
    const images = ['image/jpeg', 'image/png', 'image/webp'];
    for (final file in files) {
      if (file.bytes.isEmpty || file.bytes.length > limit) {
        return 'Each file must be nonempty and no larger than ${limit ~/ (1024 * 1024)} MB.';
      }
      if (!images.contains(file.mimeType) &&
          !(rule.code != 'profile_photo' &&
              file.mimeType == 'application/pdf')) {
        return 'Choose JPEG, PNG, WebP${rule.code == 'profile_photo' ? '' : ' or PDF'} files.';
      }
    }
    if (files.fold<int>(0, (total, file) => total + file.bytes.length) >
        30 * 1024 * 1024) {
      return 'The combined upload must not exceed 30 MB.';
    }
    final expiry = metadata['expiresAt'];
    final issued = metadata['issuedAt'];
    if (rule.requiresExpiry && expiry == null) {
      return 'This document requires an expiry date.';
    }
    if (expiry != null &&
        (!validDate(expiry) || expiry.compareTo(today()) < 0)) {
      return 'Document expiry must be today or later.';
    }
    if (issued != null && !validDate(issued)) {
      return 'Enter a valid issue date.';
    }
    if (issued != null && expiry != null && issued.compareTo(expiry) > 0) {
      return 'Expiry must be on or after the issue date.';
    }
    if ((metadata['documentNumber']?.length ?? 0) > 100 ||
        (metadata['issuingAuthority']?.length ?? 0) > 150) {
      return 'Document metadata exceeds the allowed length.';
    }
    return null;
  }

  static Map<String, dynamic>? documentFor(
    String code,
    List<Map<String, dynamic>> documents,
  ) {
    for (final doc in documents) {
      if (((doc['documentMetadata'] as Map?)?['documentCode'] ??
              doc['documentType']) ==
          code) {
        return doc;
      }
    }
    return null;
  }

  static bool expired(Map<String, dynamic>? doc) {
    final expiry = (doc?['documentMetadata'] as Map?)?['expiresAt'];
    return expiry is String &&
        (!validDate(expiry) || expiry.compareTo(today()) < 0);
  }
}
