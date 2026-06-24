// lib/services/base_api_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';  // ✅ إضافة هذا الاستيراد
import 'cache_manager.dart';

class BaseApiService {
  final CacheManager _cache = CacheManager();
  static const String baseUrl = 'https://nourelman.runasp.net/api';

  // 🌐 GET مع التخزين المؤقت
  Future<Map<String, dynamic>> getWithCache({
    required String endpoint,
    required String cacheKey,
    Duration cacheDuration = const Duration(minutes: 5),
    Map<String, String>? headers,
    bool forceRefresh = false,
  }) async {
    // 1️⃣ عرض البيانات المخزنة أولاً
    if (!forceRefresh) {
      final cachedData = await _cache.getDataWithExpiry(cacheKey, expiry: cacheDuration);
      if (cachedData != null) {
        debugPrint('📦 Using cached data for: $cacheKey');
        return {
          'data': cachedData,
          'fromCache': true,
          'isExpired': false,
        };
      }
    }

    // 2️⃣ جلب بيانات جديدة من API
    debugPrint('🌐 Fetching fresh from: $endpoint');
    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers ?? {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _cache.saveData(cacheKey, data);
        debugPrint('✅ Fresh data saved to cache: $cacheKey');
        return {
          'data': data,
          'fromCache': false,
          'isExpired': false,
        };
      } else {
        // إذا فشل API، استخدم الكاش مهما كانت صلاحيته
        final expiredCache = await _cache.getData(cacheKey);
        if (expiredCache != null) {
          debugPrint('⚠️ Using expired cache for: $cacheKey');
          return {
            'data': expiredCache,
            'fromCache': true,
            'isExpired': true,
          };
        }
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ API Error: $e');
      final expiredCache = await _cache.getData(cacheKey);
      if (expiredCache != null) {
        debugPrint('⚠️ Using expired cache due to error');
        return {
          'data': expiredCache,
          'fromCache': true,
          'isExpired': true,
        };
      }
      rethrow;
    }
  }

  // 📤 POST مع تحديث الكاش
  Future<Map<String, dynamic>> postWithCache({
    required String endpoint,
    required String cacheKey,
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers ?? {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        await _cache.clearCache(cacheKey);
        return {
          'data': data,
          'success': true,
        };
      } else {
        return {
          'data': null,
          'success': false,
          'error': 'Status: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'data': null,
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // 📝 PUT مع تحديث الكاش
  Future<Map<String, dynamic>> putWithCache({
    required String endpoint,
    required String cacheKey,
    required Map<String, dynamic> body,
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: headers ?? {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _cache.clearCache(cacheKey);
        return {
          'data': data,
          'success': true,
        };
      } else {
        return {
          'data': null,
          'success': false,
          'error': 'Status: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'data': null,
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // 🗑️ مسح كاش معين
  Future<void> invalidateCache(String cacheKey) async {
    await _cache.clearCache(cacheKey);
  }

  // 🗑️ مسح كل الكاش
  Future<void> clearAllCache() async {
    await _cache.clearAllCache();
  }
}