import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../services/appreciation_certificate_service.dart';
import '../services/base_api_service.dart';
import 'student_details/student_model.dart';

const Color _primaryOrange = Color(0xFFC66422);
const Color _darkBlue = Color(0xFF2E3542);
const Color _kActiveBlue = Color(0xFF1976D2);
const Color _kBorderColor = Color(0xFFE2E8F0);

class AppreciationCertificatesScreen extends StatefulWidget {
  const AppreciationCertificatesScreen({super.key});

  @override
  State<AppreciationCertificatesScreen> createState() => _AppreciationCertificatesScreenState();
}

class _AppreciationCertificatesScreenState extends State<AppreciationCertificatesScreen> {
  final BaseApiService _apiService = BaseApiService();
  final AppreciationCertificateService _certificateService = AppreciationCertificateService();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<StudentModel> _students = [];
  List<StudentModel> _filteredStudents = [];
  StudentModel? _selectedStudent;
  bool _isLoadingStudents = true;
  bool _isExtracting = false;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
    _searchController.addListener(_filterStudents);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudents() async {
    setState(() => _isLoadingStudents = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final result = await _apiService.getWithCache(
        endpoint: '/Student/GetByStatus?status=true',
        cacheKey: 'active_students_list',
        cacheDuration: const Duration(minutes: 10),
      );

      final raw = result['data'];
      List<StudentModel> students = _parseStudents(raw);

      if (students.isEmpty && token != null) {
        final response = await http.get(
          Uri.parse('https://nourelman.runasp.net/api/Student/GetByStatus?status=true'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
        if (response.statusCode == 200) {
          students = _parseStudents(jsonDecode(utf8.decode(response.bodyBytes)));
        }
      }

      if (mounted) {
        setState(() {
          _students = students;
          _filteredStudents = students;
          _isLoadingStudents = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading students: $e');
      if (mounted) setState(() => _isLoadingStudents = false);
    }
  }

  List<StudentModel> _parseStudents(dynamic raw) {
    dynamic data = raw;
    if (raw is Map && raw['data'] != null) {
      data = raw['data'];
    }

    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(StudentModel.fromJson)
          .toList();
    }

    if (data is String && data.isNotEmpty) {
      try {
        final parsed = jsonDecode(data);
        if (parsed is List) {
          return parsed
              .whereType<Map<String, dynamic>>()
              .map(StudentModel.fromJson)
              .toList();
        }
      } catch (_) {}
    }

    return [];
  }

  void _filterStudents() {
    final query = _searchController.text.trim();
    setState(() {
      if (query.isEmpty) {
        _filteredStudents = _students;
      } else {
        _filteredStudents = _students
            .where((s) => (s.name ?? '').contains(query))
            .toList();
      }
    });
  }

  Future<void> _extractCertificate() async {
    if (_selectedStudent?.id == null) {
      _showMessage('يرجى اختيار اسم الطالب', isError: true);
      return;
    }
    if (_reasonController.text.trim().isEmpty) {
      _showMessage('يرجى كتابة سبب منح الشهادة', isError: true);
      return;
    }

    setState(() => _isExtracting = true);

    final result = await _certificateService.extractCertificate(
      studentId: _selectedStudent!.id!,
      reason: _reasonController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isExtracting = false);

    if (result['success'] == true) {
      _showMessage('تم استخراج الشهادة بنجاح', isError: false);
    } else {
      _showMessage(result['error']?.toString() ?? 'فشل استخراج الشهادة', isError: true);
    }
  }

  void _showMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Almarai')),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _openStudentPicker() {
    _searchController.clear();
    _filteredStudents = _students;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'اختر الطالب',
                    style: TextStyle(
                      fontFamily: 'Almarai',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _darkBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setModalState(() => _filterStudents()),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن اسم الطالب',
                      hintStyle: const TextStyle(fontFamily: 'Almarai'),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 320,
                    child: _filteredStudents.isEmpty
                        ? const Center(
                            child: Text(
                              'لا يوجد طلاب',
                              style: TextStyle(fontFamily: 'Almarai', color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredStudents.length,
                            itemBuilder: (context, index) {
                              final student = _filteredStudents[index];
                              return ListTile(
                                title: Text(
                                  student.name ?? '---',
                                  style: const TextStyle(fontFamily: 'Almarai'),
                                ),
                                onTap: () {
                                  setState(() => _selectedStudent = student);
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const Center(
          child: Text(
            'استخراج شهادات التقدير',
            style: TextStyle(
              fontFamily: 'Almarai',
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: _darkBlue,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'اسم الطالب *',
                style: TextStyle(
                  fontFamily: 'Almarai',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: _darkBlue,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _isLoadingStudents ? null : _openStudentPicker,
                borderRadius: BorderRadius.circular(10),
                child: InputDecorator(
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    suffixIcon: _isLoadingStudents
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _kActiveBlue),
                            ),
                          )
                        : const Icon(Icons.keyboard_arrow_down, color: _kActiveBlue),
                  ),
                  child: Text(
                    _selectedStudent?.name ?? 'اختر الطالب',
                    style: TextStyle(
                      fontFamily: 'Almarai',
                      color: _selectedStudent == null ? Colors.grey : _darkBlue,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'سبب منح الشهادة',
                style: TextStyle(
                  fontFamily: 'Almarai',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: _darkBlue,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'اكتب هنا...',
                  hintStyle: const TextStyle(fontFamily: 'Almarai', color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isExtracting ? null : _extractCertificate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryOrange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isExtracting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'استخراج الشهادة',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Almarai',
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
