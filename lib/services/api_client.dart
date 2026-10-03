
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';
import '../utils/error_messages.dart';
import '../login_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class SessionExpiredException implements Exception {
  final String message;
  SessionExpiredException([this.message = 'انتهت صلاحية الجلسة']);
  @override
  String toString() => message;
}

class ApiClient {
  static const String baseUrl = 'https://nourelman.runasp.net/api';
  static const Duration _timeout = Duration(seconds: 15);

  static bool _handlingSessionExpiry = false;

  static Uri _uri(String endpoint) =>
      Uri.parse(endpoint.startsWith('http') ? endpoint : '$baseUrl$endpoint');

  static Future<http.Response> get(String endpoint, {Map<String, String>? headers}) =>
      _wrap(() => http.get(_uri(endpoint), headers: headers ?? const {'Content-Type': 'application/json'}).timeout(_timeout));

  static Future<http.Response> post(String endpoint, {Map<String, String>? headers, Object? body}) =>
      _wrap(() => http.post(_uri(endpoint), headers: headers ?? const {'Content-Type': 'application/json'}, body: body).timeout(_timeout));

  static Future<http.Response> put(String endpoint, {Map<String, String>? headers, Object? body}) =>
      _wrap(() => http.put(_uri(endpoint), headers: headers ?? const {'Content-Type': 'application/json'}, body: body).timeout(_timeout));

  static Future<http.Response> delete(String endpoint, {Map<String, String>? headers, Object? body}) =>
      _wrap(() => http.delete(_uri(endpoint), headers: headers ?? const {'Content-Type': 'application/json'}, body: body).timeout(_timeout));

  static Future<http.Response> _wrap(Future<http.Response> Function() call) async {
    try {
      final response = await call();

      if (response.statusCode == 401) {
        await _handleSessionExpired();
        throw SessionExpiredException();
      }

      return response;
    } on SessionExpiredException {
      rethrow;
    } on SocketException {
      throw Exception(ErrorMessages.noInternet);
    } on TimeoutException {
      throw Exception(ErrorMessages.timeout);
    } on FormatException {
      throw Exception(ErrorMessages.badResponse);
    } catch (e) {

      throw Exception(ErrorMessages.translate(e));
    }
  }

  static Future<void> _handleSessionExpired() async {
    if (_handlingSessionExpiry) return;
    _handlingSessionExpiry = true;
    try {
      await AuthService.clearSession();
      final ctx = rootNavigatorKey.currentState?.overlay?.context;
      if (ctx != null) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('انتهت صلاحية جلستك، سجّل الدخول مرة أخرى'), backgroundColor: Colors.redAccent),
        );
      }
      rootNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } finally {

      Future.delayed(const Duration(seconds: 2), () => _handlingSessionExpiry = false);
    }
  }
}

