import 'dart:convert';

class EmployeeCertificate {
  final int? id;
  final int? empId;
  final String? cerName;
  final String? cerFile;
  final String? cerFrom;
  final String? courseName;
  final String? place;
  final String? grade;
  final String? dateFrom;
  final String? dateTo;

  EmployeeCertificate({
    this.id,
    this.empId,
    this.cerName,
    this.cerFile,
    this.cerFrom,
    this.courseName,
    this.place,
    this.grade,
    this.dateFrom,
    this.dateTo,
  });

  factory EmployeeCertificate.fromJson(Map<String, dynamic> json) => EmployeeCertificate(
        id: json['id'],
        empId: json['empId'],
        cerName: json['cerName']?.toString(),
        cerFile: (json['cerFile'] ?? json['url'])?.toString(),
        cerFrom: json['cerFrom']?.toString(),
        courseName: (json['courceName'] ?? json['courseName'])?.toString(),
        place: json['place']?.toString(),
        grade: json['grade']?.toString(),
        dateFrom: (json['dateFrom'] ?? json['DateFrom'])?.toString(),
        dateTo: (json['dateTo'] ?? json['DateTo'])?.toString(),
      );

  String get downloadPath {
    if (cerFile == null || cerFile!.isEmpty || cerFile == 'null') return '';
    if (cerFile!.startsWith('http')) return Uri.parse(cerFile!).path;
    return cerFile!.startsWith('/') ? cerFile! : '/$cerFile';
  }

  String get certificateUrl {
    if (downloadPath.isEmpty) return '';
    return 'https://nourelman.runasp.net$downloadPath';
  }
}

List<EmployeeCertificate> employeeCertificatesFromResponse(dynamic raw) {
  if (raw == null) return [];

  dynamic data = raw;
  if (raw is Map<String, dynamic>) {
    data = raw['data'];
  }

  if (data == null) return [];

  if (data is List) {
    return data
        .whereType<Map<String, dynamic>>()
        .map(EmployeeCertificate.fromJson)
        .toList();
  }

  if (data is String && data.isNotEmpty) {
    try {
      final parsed = jsonDecode(data);
      if (parsed is List) {
        return parsed
            .whereType<Map<String, dynamic>>()
            .map(EmployeeCertificate.fromJson)
            .toList();
      }
    } catch (_) {}
  }

  return [];
}
