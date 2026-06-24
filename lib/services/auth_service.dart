import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cache_manager.dart';

/// Centralized session management to prevent stale auto-login and ensure consistent logout.
class AuthService {
  static const String loginDataKey = 'loginData';
  static const String isLoggedInKey = 'is_logged_in';
  static const String sessionTimestampKey = 'session_timestamp';
  static const Duration maxSessionAge = Duration(days: 30);

  /// Returns login data only when the stored session looks valid.
  static Future<Map<String, dynamic>?> getValidSession() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(isLoggedInKey) ?? false;
    if (!isLoggedIn) return null;

    final loginDataString = prefs.getString(loginDataKey);
    if (loginDataString == null || loginDataString.isEmpty) {
      await clearSession();
      return null;
    }

    try {
      final data = Map<String, dynamic>.from(jsonDecode(loginDataString));
      final token = prefs.getString('user_token');
      final userId = prefs.getString('user_id');

      if (token == null || token.isEmpty || token == 'no_token') {
        await clearSession();
        return null;
      }

      if (userId == null || userId.isEmpty || userId == '0' || userId == 'null') {
        await clearSession();
        return null;
      }

      final sessionTimestamp = prefs.getInt(sessionTimestampKey);
      if (sessionTimestamp != null) {
        final age = DateTime.now().millisecondsSinceEpoch - sessionTimestamp;
        if (age > maxSessionAge.inMilliseconds) {
          await clearSession();
          return null;
        }
      }

      return data;
    } catch (e) {
      debugPrint('AuthService: invalid session data: $e');
      await clearSession();
      return null;
    }
  }

  static Future<void> markSessionActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(sessionTimestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<void> clearSession({bool keepLocalAttendance = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().toList();
    for (final key in keys) {
      if (keepLocalAttendance && key.startsWith('local_attendance_')) continue;
      await prefs.remove(key);
    }
    await CacheManager().clearAllCache();
  }

  static int resolveUserType(Map<String, dynamic> data) {
    return int.tryParse(data['userType']?.toString() ?? '0') ?? 0;
  }
}
