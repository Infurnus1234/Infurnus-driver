/// Signup makes the country explicit; never send a national number to SMS.
String normalizeSignupPhone(String input, {String countryCode = '+91'}) {
  final value = input.trim().replaceAll(RegExp(r'[\s().-]'), '');
  if (value.isEmpty) return '';
  if (value.startsWith('+')) {
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value)) {
      throw const FormatException('Enter a valid international phone number.');
    }
    if (value.startsWith('+91') &&
        !RegExp(r'^\+91[6-9]\d{9}$').hasMatch(value)) {
      throw const FormatException(
        'Enter a valid 10-digit Indian mobile number.',
      );
    }
    return value;
  }
  if (!RegExp(r'^\+[1-9]\d{0,2}$').hasMatch(countryCode)) {
    throw const FormatException('Enter a valid country code, such as +91.');
  }
  // Accept an already-prefixed Indian number without duplicating 91.
  if (countryCode == '+91') {
    final national = value.length == 12 && value.startsWith('91')
        ? value.substring(2)
        : value;
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(national)) {
      throw const FormatException(
        'Enter a valid 10-digit Indian mobile number.',
      );
    }
    return '+91$national';
  }
  final result = '$countryCode$value';
  if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(result)) {
    throw const FormatException(
      'Enter a valid phone number with country code.',
    );
  }
  return result;
}
