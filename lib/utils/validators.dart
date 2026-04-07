/// Email validation regex — matches standard email format.
final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// Validates an email address. Returns error message or null if valid.
String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Email is required';
  }
  if (!_emailRegex.hasMatch(value.trim())) {
    return 'Enter a valid email address';
  }
  return null;
}

/// Validates password with strength requirements.
/// Returns error message or null if valid.
String? validatePassword(String? value, {bool requireStrength = false}) {
  if (value == null || value.isEmpty) {
    return 'Password is required';
  }
  if (value.length < 8) {
    return 'Password must be at least 8 characters';
  }
  if (requireStrength) {
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Include at least one uppercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Include at least one number';
    }
    if (!RegExp(r'[!@#\$%\^&\*\(\),.?":{}|<>]').hasMatch(value)) {
      return 'Include at least one special character';
    }
  }
  return null;
}
