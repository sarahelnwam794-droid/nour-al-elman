import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// تحميل وفتح الملفات بدون FlutterDownloader وبدون أي صلاحيات تخزين.
/// بيجرب أكتر من رابط بالترتيب لحد ما واحد يرجع 200، ولو كلهم فشلوا
/// بيرجع رسالة فيها كود كل محاولة (عشان نعرف المشكلة بالظبط).
class FileDownloadService {
  static const String host = 'https://nourelman.runasp.net';

  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString('user_token');
    return (t == null || t == 'no_token') ? null : t;
  }

  /// [serverPath] مثال: /uploads/3/xxxx.pdf
  static List<String> candidatesForPath(String serverPath) {
    final p = serverPath.startsWith('http')
        ? Uri.parse(serverPath).path
        : (serverPath.startsWith('/') ? serverPath : '/$serverPath');
    final enc = Uri.encodeComponent(p);
    return [
      '$host/api/StudentCources/Download?url=$enc',
      '$host/api/EmployeeCertificate/Download?url=$enc',
      '$host$p',
    ];
  }

  static const MethodChannel _channel = MethodChannel('project1/downloads');

  /// بيحفظ نسخة في مجلد "التنزيلات" في الموبايل (أندرويد بس).
  static Future<bool> _saveToDownloads(File file, String name, String? mime) async {
    if (!Platform.isAndroid) return false;
    try {
      await _channel.invokeMethod('saveToDownloads', {
        'path': file.path,
        'name': name,
        'mime': mime ?? 'application/octet-stream',
      });
      return true;
    } catch (e) {
      debugPrint('⬇️ save to Downloads failed: $e');
      return false;
    }
  }

  /// بيحمّل الملف، يحفظه في تنزيلات الموبايل، ويفتحه. بيرجّع تفاصيل النتيجة.
  static Future<DownloadResult> download({
    required List<String> urls,
    required String fileName,
  }) async {
    final token = await _token();
    final tried = <String>[];

    for (final url in urls) {
      try {
        final res = await http.get(Uri.parse(url), headers: {
          if (token != null) 'Authorization': 'Bearer $token',
          'Accept': '*/*',
        }).timeout(const Duration(seconds: 60));

        debugPrint('⬇️ GET $url -> ${res.statusCode} (${res.bodyBytes.length} bytes)');

        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          final dir = await getApplicationDocumentsDirectory();
          // الامتداد الحقيقي بيتحدد من محتوى الملف نفسه، عشان صورة png
          // ماتتحفظش باسم .pdf وبعدين مافيش تطبيق يفتحها.
          final ext = _detectExt(res.bodyBytes) ?? _extOf(fileName);
          final base = _baseName(fileName);
          final finalName = ext.isEmpty ? base : '$base.$ext';
          final mime = _mimeTypes[ext];
          final file = File('${dir.path}/$finalName');
          await file.writeAsBytes(res.bodyBytes, flush: true);

          final saved = await _saveToDownloads(file, finalName, mime);

          final r = await OpenFilex.open(file.path, type: mime);
          if (r.type == ResultType.done) return DownloadResult(saved: saved);
          return DownloadResult(
            saved: saved,
            openError: saved
                ? 'تم حفظ الملف في التنزيلات لكن لا يوجد تطبيق لفتحه (${r.message})'
                : 'تم تحميل الملف لكن لا يوجد تطبيق لفتحه (${r.message})',
          );
        }
        tried.add('${res.statusCode}');
      } catch (e) {
        debugPrint('⬇️ GET $url failed: $e');
        tried.add('خطأ اتصال');
      }
    }
    return DownloadResult(
      error: 'تعذر تحميل الملف (أكواد المحاولات: ${tried.join(' / ')})',
    );
  }

  /// يرجع null لو نجح، أو رسالة الخطأ. (نفس الشكل القديم)
  static Future<String?> downloadAndOpen({
    required List<String> urls,
    required String fileName,
  }) async {
    final r = await download(urls: urls, fileName: fileName);
    return r.error ?? r.openError;
  }

  static const Map<String, String> _mimeTypes = {
    'pdf': 'application/pdf',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'txt': 'text/plain',
    'zip': 'application/zip',
    'mp3': 'audio/mpeg',
    'mp4': 'video/mp4',
  };

  /// بيتعرف على نوع الملف من أول بايتات فيه. بيرجع null لو مش متأكد.
  static String? _detectExt(List<int> b) {
    if (b.length < 4) return null;
    if (b[0] == 0x25 && b[1] == 0x50 && b[2] == 0x44 && b[3] == 0x46) return 'pdf';
    if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return 'png';
    if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'jpg';
    if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x38) return 'gif';
    if (b.length > 11 &&
        b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 &&
        b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) {
      return 'webp';
    }
    return null;
  }

  static String _extOf(String name) {
    final i = name.lastIndexOf('.');
    if (i < 0 || i == name.length - 1) return '';
    final e = name.substring(i + 1).toLowerCase();
    return e.length <= 5 && !e.contains('/') ? e : '';
  }

  static String _baseName(String name) {
    final i = name.lastIndexOf('.');
    final b = i > 0 ? name.substring(0, i) : name;
    return b.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_');
  }
}

class DownloadResult {
  /// فشل التحميل نفسه (كل الروابط فشلت).
  final String? error;

  /// الملف اتحمّل بس مافيش تطبيق يفتحه.
  final String? openError;

  /// اتحفظ نسخة في مجلد التنزيلات في الموبايل.
  final bool saved;

  const DownloadResult({this.error, this.openError, this.saved = false});
}