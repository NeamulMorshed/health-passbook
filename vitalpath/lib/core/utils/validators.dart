/// Form validation utilities for VitalPath.
abstract final class Validators {
  static String? requiredField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  static String? numericRange(
    String? value, {
    required double min,
    required double max,
    required String fieldName,
  }) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    final parsed = double.tryParse(value);
    if (parsed == null) return '$fieldName must be a number';
    if (parsed < min || parsed > max) {
      return '$fieldName must be between ${min.toInt()} and ${max.toInt()}';
    }
    return null;
  }

  static String? positiveNumber(String? value, {String? fieldName}) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? 'Value'} is required';
    }
    final parsed = double.tryParse(value);
    if (parsed == null || parsed <= 0) {
      return '${fieldName ?? 'Value'} must be a positive number';
    }
    return null;
  }

  static String? dateNotBefore(DateTime? startDate, DateTime? endDate) {
    if (startDate == null || endDate == null) return null;
    if (endDate.isBefore(startDate)) {
      return 'End date cannot be before start date';
    }
    return null;
  }

  static String? phoneNumber(String? value) {
    if (value == null || value.isEmpty) return 'Phone number is required';
    if (value.length < 7) return 'Invalid phone number';
    return null;
  }
}
