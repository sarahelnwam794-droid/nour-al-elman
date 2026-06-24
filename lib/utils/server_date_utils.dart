class ServerDateUtils {
  static bool isValidJoinDate(String dateStr) {
    if (dateStr.isEmpty || dateStr == 'null') return false;
    if (dateStr.startsWith('0001')) return false;
    if (dateStr.contains('_')) return false;
    if (!dateStr.startsWith('20')) return false;

    final datePart = dateStr.split('T').first;
    final match = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(datePart);
    if (match == null) return false;

    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) return false;
    if (month < 1 || month > 12 || day < 1 || day > 31) return false;

    return true;
  }

  static DateTime parseJoinDate(dynamic value) {
    if (value == null) return DateTime.now();

    final dateStr = value.toString().trim();
    if (!isValidJoinDate(dateStr)) return DateTime.now();

    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return DateTime.now();
    }
  }

  static String formatJoinDate(DateTime? date) {
    final d = date ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String formatDisplayDate(dynamic value) {
    if (value == null) return '---';

    final dateStr = value.toString().trim();
    if (dateStr.isEmpty || dateStr == 'null') return '---';

    final parsed = parseFlexibleDate(dateStr);
    if (parsed == null) return '---';

    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  static DateTime? parseFlexibleDate(dynamic value) {
    if (value == null) return null;

    final dateStr = value.toString().trim();
    if (dateStr.isEmpty || dateStr == 'null') return null;

    try {
      return DateTime.parse(dateStr);
    } catch (_) {}

    final slashMatch = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(dateStr);
    if (slashMatch != null) {
      final day = int.tryParse(slashMatch.group(1)!);
      final month = int.tryParse(slashMatch.group(2)!);
      final year = int.tryParse(slashMatch.group(3)!);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }

    return null;
  }
}
