import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import '../services/certificate_builder.dart';
import '../services/base_api_service.dart';
import 'student_details/student_model.dart';
import 'package:project1/widgets/pulse_loader.dart';

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
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<StudentModel> _students = [];
  List<StudentModel> _filteredStudents = [];
  StudentModel? _selectedStudent;
  bool _isLoadingStudents = true;
  bool _isExtracting = false;
  bool _isSaving = false;

  Uint8List? _certificateBytes;
  String _certificateExtension = 'pdf';

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
          Uri.parse(
              'https://nourelman.runasp.net/api/Student/GetByStatus?status=true'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          students =
              _parseStudents(jsonDecode(utf8.decode(response.bodyBytes)));
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
    if (_reasonController.text
        .trim()
        .isEmpty) {
      _showMessage('يرجى كتابة سبب منح الشهادة', isError: true);
      return;
    }

    setState(() => _isExtracting = true);

    try {
      final bytes = await CertificateBuilder.build(
        studentName: _selectedStudent!.name ?? '',
        reason: _reasonController.text.trim(),
        date: DateTime.now(),
      );

      if (!mounted) return;
      setState(() {
        _isExtracting = false;
        _certificateBytes = bytes;
        _certificateExtension = 'pdf';
      });
    } catch (e) {
      debugPrint('Certificate build error: $e');
      if (!mounted) return;
      setState(() => _isExtracting = false);
      _showMessage(
          'تعذر بناء الشهادة، تأكدي من وجود ملفات الخط والشعار', isError: true);
    }
  }
  void _backToForm() {
    setState(() {
      _certificateBytes = null;
    });
  }

  Future<void> _downloadCertificate() async {
    if (_certificateBytes == null) return;
    setState(() => _isSaving = true);

    try {
      final studentName = _selectedStudent?.name ?? 'certificate';
      final fileName = 'شهادة_$studentName.pdf';
      await Printing.sharePdf(bytes: _certificateBytes!, filename: fileName);

      if (mounted) _showMessage('تم تجهيز الشهادة للتحميل', isError: false);
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) _showMessage('تعذر تحميل الشهادة', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
                bottom: MediaQuery
                    .of(context)
                    .viewInsets
                    .bottom + 16,
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
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 320,
                    child: _filteredStudents.isEmpty
                        ? const Center(
                      child: Text(
                        'لا يوجد طلاب',
                        style: TextStyle(fontFamily: 'Almarai',
                            color: Colors.grey),
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
    if (_certificateBytes != null) {
      return _buildCertificatePreview();
    }
    return _buildForm();
  }

  Widget _buildForm() {
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
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    suffixIcon: _isLoadingStudents
                        ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: PulseLoader(
                            strokeWidth: 2, color: _kActiveBlue),
                      ),
                    )
                        : const Icon(
                        Icons.keyboard_arrow_down, color: _kActiveBlue),
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
                  hintStyle: const TextStyle(
                      fontFamily: 'Almarai', color: Colors.grey),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isExtracting ? null : _extractCertificate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryOrange,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isExtracting
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: PulseLoader(
                        strokeWidth: 2, color: Colors.white),
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
  Widget _buildCertificatePreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _backToForm,
              icon: const Icon(Icons.arrow_forward, size: 18, color: _kActiveBlue),
              label: const Text(
                'رجوع وتعديل',
                style: TextStyle(
                  fontFamily: 'Almarai',
                  color: _kActiveBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _kActiveBlue),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        Flexible(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorderColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: _certificateExtension == 'pdf'
                  ? PdfPreview(
                build: (format) async => _certificateBytes!,
                useActions: false,
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                scrollViewDecoration: const BoxDecoration(color: Colors.white),
              )
                  : InteractiveViewer(
                child: Image.memory(_certificateBytes!, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _downloadCertificate,
              icon: _isSaving
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: PulseLoader(
                    strokeWidth: 2.5, color: Colors.white),
              )
                  : const Icon(Icons.download, color: Colors.white),
              label: const Text(
                'تحميل الشهادة',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Almarai',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryOrange,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 90),
      ],
    );
  }
}
