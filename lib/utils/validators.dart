
class Validators {
  Validators._();

  static String? Function(String?) required([String message = 'هذا الحقل مطلوب']) {
    return (value) {
      if (value == null || value.trim().isEmpty) return message;
      return null;
    };
  }

  static String? Function(String?) phone({String message = 'رقم هاتف غير صحيح'}) {
    return (value) {
      if (value == null || value.trim().isEmpty) return 'رقم الهاتف مطلوب';
      final digitsOnly = value.trim();
      if (!RegExp(r'^[0-9+]{8,15}$').hasMatch(digitsOnly)) return message;
      return null;
    };
  }

  static String? Function(String?) positiveNumber({String message = 'أدخل رقم صحيح أكبر من صفر'}) {
    return (value) {
      if (value == null || value.trim().isEmpty) return 'هذا الحقل مطلوب';
      final n = num.tryParse(value.trim());
      if (n == null || n <= 0) return message;
      return null;
    };
  }

  static String? Function(String?) minLength(int min, [String? message]) {
    return (value) {
      if (value == null || value.trim().length < min) {
        return message ?? 'يجب أن يكون طول النص $min أحرف على الأقل';
      }
      return null;
    };
  }

  static String? Function(String?) combine(List<String? Function(String?)> validators) {
    return (value) {
      for (final v in validators) {
        final result = v(value);
        if (result != null) return result;
      }
      return null;
    };
  }
}

