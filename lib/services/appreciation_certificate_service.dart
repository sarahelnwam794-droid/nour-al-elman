import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AppreciationCertificateService {
  static const String baseUrl = 'https://nourelman.runasp.net/api';

  Future<Map<String, dynamic>> extractCertificate({
    required int studentId,
    required String reason,
  }) async {
    final encodedReason = Uri.encodeComponent(reason.trim());

    final getEndpoints = [
      '/Student/GetAppreciationCertificate?studentId=$studentId&reason=$encodedReason',
      '/Student/ExtractAppreciationCertificate?studentId=$studentId&reason=$encodedReason',
      '/Student/DownloadAppreciationCertificate?studentId=$studentId&reason=$encodedReason',
    ];

    for (final endpoint in getEndpoints) {
      final result = await _tryGetDownload('$baseUrl$endpoint');
      if (result['success'] == true) return result;
      if (result['notFound'] != true && result['error'] != null) {
        return result;
      }
    }

    return _tryPostDownload(
      '$baseUrl/Student/ExtractAppreciationCertificate',
      {'studentId': studentId, 'reason': reason.trim()},
    );
  }

  Future<Map<String, dynamic>> _tryGetDownload(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      debugPrint('Appreciation GET $url -> ${response.statusCode}');

      if (response.statusCode == 404) {
        return {'success': false, 'notFound': true};
      }

      return _handleDownloadResponse(response);
    } catch (e) {
      debugPrint('Appreciation GET error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _tryPostDownload(
      String url,
      Map<String, dynamic> body,
      ) async {
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      debugPrint('Appreciation POST $url -> ${response.statusCode}');

      if (response.statusCode == 404) {
        return {
          'success': false,
          'error': 'خدمة استخراج الشهادة غير متوفرة على السيرفر',
        };
      }

      return _handleDownloadResponse(response);
    } catch (e) {
      debugPrint('Appreciation POST error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _handleDownloadResponse(http.Response response) async {
    if (response.statusCode != 200) {
      return {
        'success': false,
        'error': 'Status: ${response.statusCode}',
        'body': response.body,
      };
    }

    final contentType = response.headers['content-type']?.toLowerCase() ?? '';

    if (contentType.contains('json') || response.body.trimLeft().startsWith('{')) {
      final decoded = jsonDecode(response.body);
      final dynamic data = decoded is Map ? decoded['data'] : decoded;

      if (data == null) {
        return {
          'success': false,
          'error': decoded['error']?.toString() ?? 'فشل استخراج الشهادة',
        };
      }

      final filePath = data.toString();

      if (filePath.startsWith('http')) {
        final fileResponse = await http.get(Uri.parse(filePath)).timeout(const Duration(seconds: 15));
        if (fileResponse.statusCode != 200) {
          return {'success': false, 'error': 'تعذر تحميل ملف الشهادة'};
        }
        return _bytesResult(fileResponse.bodyBytes, filePath);
      }

      if (filePath.startsWith('/')) {
        final fileResponse = await http.get(
          Uri.parse('$baseUrl/EmployeeCertificate/Download?url=${Uri.encodeComponent(filePath)}'),
        ).timeout(const Duration(seconds: 15));
        if (fileResponse.statusCode != 200) {
          return {'success': false, 'error': 'تعذر تحميل ملف الشهادة'};
        }
        return _bytesResult(fileResponse.bodyBytes, filePath);
      }

      return {'success': false, 'error': 'استجابة غير متوقعة من السيرفر'};
    }

    return _bytesResult(response.bodyBytes, _guessFileName(contentType));
  }

  Map<String, dynamic> _bytesResult(List<int> bytes, String nameHint) {
    final lower = nameHint.toLowerCase();
    String extension = 'pdf';
    if (lower.contains('.png')) {
      extension = 'png';
    } else if (lower.contains('.jpg') || lower.contains('.jpeg')) {
      extension = 'jpg';
    } else if (lower.contains('.pdf')) {
      extension = 'pdf';
    }

    return {
      'success': true,
      'bytes': Uint8List.fromList(bytes),
      'extension': extension,
    };
  }

  String _guessFileName(String contentType) {
    if (contentType.contains('png')) return 'certificate.png';
    if (contentType.contains('jpeg') || contentType.contains('jpg')) return 'certificate.jpg';
    return 'certificate.pdf';
  }
}
