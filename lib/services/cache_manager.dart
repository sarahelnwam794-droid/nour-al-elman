// lib/services/cache_manager.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';  // ✅ إضافة هذا الاستيراد

class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  // 📦 تخزين بيانات مع وقت
  Future<void> saveData(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString('cache_$key', jsonEncode(cacheData));
      debugPrint('✅ Cache saved: $key');
    } catch (e) {
      debugPrint('❌ Cache save error: $e');
    }
  }

  // 📥 استرجاع بيانات مخزنة
  Future<dynamic> getData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cached = prefs.getString('cache_$key');
      if (cached == null) return null;
      final Map<String, dynamic> cacheMap = jsonDecode(cached);
      return cacheMap['data'];
    } catch (e) {
      debugPrint('❌ Cache get error: $e');
      return null;
    }
  }

  // 📥 استرجاع مع صلاحية
  Future<dynamic> getDataWithExpiry(String key, {Duration expiry = const Duration(minutes: 5)}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cached = prefs.getString('cache_$key');
      if (cached == null) return null;

      final Map<String, dynamic> cacheMap = jsonDecode(cached);
      final int timestamp = cacheMap['timestamp'];
      final now = DateTime.now().millisecondsSinceEpoch;

      if (now - timestamp > expiry.inMilliseconds) {
        await prefs.remove('cache_$key');
        debugPrint('⏰ Cache expired: $key');
        return null;
      }
      return cacheMap['data'];
    } catch (e) {
      debugPrint('❌ Cache get error: $e');
      return null;
    }
  }

  // 🗑️ مسح كاش معين
  Future<void> clearCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cache_$key');
    debugPrint('🗑️ Cache cleared: $key');
  }

  // 🗑️ مسح كل الكاش
  Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    final allKeys = prefs.getKeys();
    for (final key in allKeys) {
      if (key.startsWith('cache_')) {
        await prefs.remove(key);
      }
    }
    debugPrint('🗑️ All cache cleared');
  }

  // 🔍 التحقق من وجود كاش
  Future<bool> hasCache(String key) async {
    final data = await getData(key);
    return data != null;
  }
}