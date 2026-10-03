
class EmployeeCertificate {
  int? id;
  int? empId;
  String? cerName;
  String? cerFrom;
  String? courseName;
  String? place;
  String? grade;
  String? dateFrom;
  String? dateTo;
  String? downloadPath;

  EmployeeCertificate({
    this.id,
    this.empId,
    this.cerName,
    this.cerFrom,
    this.courseName,
    this.place,
    this.grade,
    this.dateFrom,
    this.dateTo,
    this.downloadPath,
  });

  factory EmployeeCertificate.fromJson(Map<String, dynamic> json) {
    return EmployeeCertificate(
      id: json['id'],
      empId: json['empId'],
      cerName: json['cerName'],
      cerFrom: json['cerFrom'],
      courseName: json['courseName'],
      place: json['place'],
      grade: json['grade'],
      dateFrom: json['dateFrom'],
      dateTo: json['dateTo'],
      downloadPath: json['downloadPath'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'empId': empId,
      'cerName': cerName,
      'cerFrom': cerFrom,
      'courseName': courseName,
      'place': place,
      'grade': grade,
      'dateFrom': dateFrom,
      'dateTo': dateTo,
      'downloadPath': downloadPath,
    };
  }
}

List<EmployeeCertificate> employeeCertificatesFromResponse(dynamic data) {
  if (data == null) return [];

  if (data is List) {
    return data.map((item) => EmployeeCertificate.fromJson(item)).toList();
  }

  if (data is Map && data.containsKey('data')) {
    final list = data['data'];
    if (list is List) {
      return list.map((item) => EmployeeCertificate.fromJson(item)).toList();
    }
  }

  return [];
}
