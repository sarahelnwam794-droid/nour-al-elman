import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

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
      if (result['success'] == true || result['notFound'] != true) {
        if (result['success'] == true) return result;
        if (result['notFound'] != true && result['error'] != null) {
          return result;
        }
      }
    }

    return _tryPostDownload(
      '$baseUrl/Student/ExtractAppreciationCertificate',
      {'studentId': studentId, 'reason': reason.trim()},
    );
  }

  Future<Map<String, dynamic>> _tryGetDownload(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
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
      );
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
        return {'success': false, 'error': decoded['error']?.toString() ?? 'فشل استخراج الشهادة'};
      }

      final filePath = data.toString();
      if (filePath.startsWith('http')) {
        final fileResponse = await http.get(Uri.parse(filePath));
        if (fileResponse.statusCode != 200) {
          return {'success': false, 'error': 'تعذر تحميل ملف الشهادة'};
        }
        return _saveAndOpenBytes(fileResponse.bodyBytes, filePath);
      }

      if (filePath.startsWith('/')) {
        final fileResponse = await http.get(
          Uri.parse('$baseUrl/EmployeeCertificate/Download?url=${Uri.encodeComponent(filePath)}'),
        );
        if (fileResponse.statusCode != 200) {
          return {'success': false, 'error': 'تعذر تحميل ملف الشهادة'};
        }
        return _saveAndOpenBytes(fileResponse.bodyBytes, filePath);
      }

      return {'success': false, 'error': 'استجابة غير متوقعة من السيرفر'};
    }

    return _saveAndOpenBytes(response.bodyBytes, _guessFileName(contentType));
  }

  Future<Map<String, dynamic>> _saveAndOpenBytes(List<int> bytes, String nameHint) async {
    final fileName = nameHint.contains('.') ? nameHint.split('/').last : '$nameHint.pdf';
    final dir = await getTemporaryDirectory();
    final localFile = File('${dir.path}/$fileName');
    await localFile.writeAsBytes(bytes);

    final openResult = await OpenFilex.open(localFile.path);
    return {
      'success': openResult.type == ResultType.done,
      'path': localFile.path,
      'error': openResult.message,
    };
  }

  String _guessFileName(String contentType) {
    if (contentType.contains('png')) return 'certificate.png';
    if (contentType.contains('jpeg') || contentType.contains('jpg')) return 'certificate.jpg';
    return 'certificate.pdf';
  }
}
