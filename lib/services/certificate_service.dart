import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class CertificateService {
  static const String baseUrl = 'https://nourelman.runasp.net/api';

  Future<Map<String, dynamic>> saveCertificate({
    required int empId,
    required String cerName,
    required String cerFrom,
    required String courseName,
    required String place,
    required String grade,
    required DateTime dateFrom,
    required DateTime dateTo,
    required String filePath,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/EmployeeCertificate/Save'),
    );

    _applyFields(
      request: request,
      empId: empId,
      cerName: cerName,
      cerFrom: cerFrom,
      courseName: courseName,
      place: place,
      grade: grade,
      dateFrom: dateFrom,
      dateTo: dateTo,
      isUpdate: false,
    );

    request.files.add(await http.MultipartFile.fromPath('CerFile', filePath));

    return _send(request);
  }

  Future<Map<String, dynamic>> updateCertificate({
    required int id,
    required int empId,
    required String cerName,
    required String cerFrom,
    required String courseName,
    required String place,
    required String grade,
    required DateTime dateFrom,
    required DateTime dateTo,
    String? filePath,
  }) async {
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('$baseUrl/EmployeeCertificate/Update?id=$id'),
    );

    _applyFields(
      request: request,
      empId: empId,
      cerName: cerName,
      cerFrom: cerFrom,
      courseName: courseName,
      place: place,
      grade: grade,
      dateFrom: dateFrom,
      dateTo: dateTo,
      isUpdate: true,
    );

    if (filePath != null && filePath.isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath('CerFile', filePath));
    }

    return _send(request);
  }

  void _applyFields({
    required http.MultipartRequest request,
    required int empId,
    required String cerName,
    required String cerFrom,
    required String courseName,
    required String place,
    required String grade,
    required DateTime dateFrom,
    required DateTime dateTo,
    required bool isUpdate,
  }) {
    request.fields['EmpId'] = empId.toString();
    request.fields['CerName'] = cerName;
    request.fields['CerFrom'] = cerFrom;
    request.fields[isUpdate ? 'CourseName' : 'CourceName'] = courseName;
    request.fields['Place'] = place;
    request.fields['Grade'] = grade;
    request.fields['DateFrom'] = dateFrom.toUtc().toIso8601String();
    request.fields['DateTo'] = dateTo.toUtc().toIso8601String();
  }

  Future<Map<String, dynamic>> _send(http.MultipartRequest request) async {
    try {
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      debugPrint('Certificate API ${request.method} ${response.statusCode}: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        dynamic data;
        try {
          data = jsonDecode(response.body);
        } catch (_) {
          data = response.body;
        }
        return {'success': true, 'data': data};
      }

      return {
        'success': false,
        'error': 'Status: ${response.statusCode}',
        'body': response.body,
      };
    } catch (e) {
      debugPrint('Certificate API error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> downloadCertificate(String filePath) async {
    if (filePath.isEmpty) {
      return {'success': false, 'error': 'مسار الملف غير متوفر'};
    }

    final normalizedPath = filePath.startsWith('http')
        ? Uri.parse(filePath).path
        : (filePath.startsWith('/') ? filePath : '/$filePath');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/EmployeeCertificate/Download?url=${Uri.encodeComponent(normalizedPath)}'),
      );

      debugPrint('Certificate Download ${response.statusCode} for $normalizedPath');

      if (response.statusCode != 200) {
        return {
          'success': false,
          'error': 'Status: ${response.statusCode}',
        };
      }

      final fileName = normalizedPath.split('/').last;
      final dir = await getTemporaryDirectory();
      final localFile = File('${dir.path}/$fileName');
      await localFile.writeAsBytes(response.bodyBytes);

      final openResult = await OpenFilex.open(localFile.path);
      return {
        'success': openResult.type == ResultType.done,
        'path': localFile.path,
        'error': openResult.message,
      };
    } catch (e) {
      debugPrint('Certificate download error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
