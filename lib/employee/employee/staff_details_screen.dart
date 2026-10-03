import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'attendance_logs_tab.dart';
import 'teacher_schedule_tab.dart';
import 'edit_teacher_screen.dart';

import '../../services/base_api_service.dart';
import '../../services/certificate_service.dart';
import '../../teacher/employee_certificate_model.dart';
import '../../teacher/certificate_form_dialog.dart';
import 'package:project1/widgets/pulse_loader.dart';
import 'package:project1/widgets/profile_header_skeleton.dart';
const Color kPrimaryBlue = Color(0xFF07427C);
const Color kTextDark = Color(0xFF2E3542);
const Color kBgGrey = Color(0xFFF8FAFC);
const Color _primaryOrange = Color(0xFFC66422);
const Color _kBorderColor = Color(0xFFE2E8F0);
const Color _kWhite = Color(0xFFFFFFFF);

class StaffDetailsScreen extends StatefulWidget {
  final int staffId;
  final String staffName;

  const StaffDetailsScreen({super.key, required this.staffId, required this.staffName});

  @override
  _StaffDetailsScreenState createState() => _StaffDetailsScreenState();
}

class _StaffDetailsScreenState extends State<StaffDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? staffData;
  bool isLoadingInfo = true;
  String errorMessage = "";

  List<EmployeeCertificate> _certificates = [];
  bool _isCertificatesLoading = false;
  bool _isCertificatesExpanded = false;
  bool _isDownloadingCertificate = false;
  final BaseApiService _apiService = BaseApiService();
  final CertificateService _certificateService = CertificateService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchStaffInfo();
    _fetchCertificates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchStaffInfo() async {
    setState(() {
      isLoadingInfo = true;
      errorMessage = "";
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('https://nourelman.runasp.net/api/Employee/GetById?id=${widget.staffId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          staffData = data['data'];
          isLoadingInfo = false;
        });
      } else {
        setState(() {
          errorMessage = "فشل في جلب البيانات: ${response.statusCode}";
          isLoadingInfo = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "حدث خطأ في الاتصال: $e";
        isLoadingInfo = false;
      });
    }
  }

  Future<void> _fetchCertificates() async {
    if (!mounted) return;

    setState(() => _isCertificatesLoading = true);

    try {
      final result = await _apiService.getWithCache(
        endpoint: '/EmployeeCertificate/GetByEmpId?empId=${widget.staffId}',
        cacheKey: 'teacher_certificates_${widget.staffId}',
        cacheDuration: const Duration(minutes: 10),
      );

      if (mounted) {
        setState(() {
          _certificates = employeeCertificatesFromResponse(result['data']);
          _isCertificatesLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching certificates: $e");
      if (mounted) setState(() => _isCertificatesLoading = false);
    }
  }

  Future<void> _openCertificateForm({EmployeeCertificate? certificate}) async {
    final empId = widget.staffId;
    if (empId == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحديد كود المعلم', style: TextStyle(fontFamily: 'Almarai')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final saved = await showCertificateFormDialog(
      context: context,
      empId: empId,
      certificate: certificate,
    );

    if (saved == true && mounted) {
      await _apiService.invalidateCache('teacher_certificates_$empId');
      setState(() => _isCertificatesExpanded = true);
      await _fetchCertificates();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            certificate == null ? 'تمت إضافة الدورة بنجاح' : 'تم تعديل الدورة بنجاح',
            style: const TextStyle(fontFamily: 'Almarai'),
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _openCertificate(EmployeeCertificate cert) async {
    if (cert.downloadPath?.isEmpty ?? true) return;

    setState(() => _isDownloadingCertificate = true);

    final result = await _certificateService.downloadCertificate(cert.downloadPath!);

    if (!mounted) return;
    setState(() => _isDownloadingCertificate = false);

    if (result['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['error']?.toString() ?? 'تعذر فتح الشهادة',
            style: const TextStyle(fontFamily: 'Almarai'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: kBgGrey,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          centerTitle: false,
          title: Text(
            staffData?['name'] ?? widget.staffName,
            style: const TextStyle(
              color: kTextDark,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              fontFamily: 'Almarai',
            ),
          ),
          iconTheme: const IconThemeData(color: kTextDark),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_note, color: Color(0xFF1976D2), size: 26),
              onPressed: () {
                if (staffData != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditTeacherScreen(staffData: staffData!),
                    ),
                  ).then((_) => _fetchStaffInfo());
                }
              },
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: kPrimaryBlue,
            indicatorColor: kPrimaryBlue,
            labelStyle: const TextStyle(fontFamily: 'Almarai', fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: "البيانات الشخصية"),
              Tab(text: "سجل الحضور"),
              Tab(text: "جدول الشيخ"),
            ],
          ),
        ),
        body: isLoadingInfo
            ? const ProfileHeaderSkeleton()
            : errorMessage.isNotEmpty
            ? _buildErrorWidget()
            : TabBarView(
          controller: _tabController,
          children: [
            _buildInfoTab(),
            AttendanceLogsTab(empId: widget.staffId),
            TeacherScheduleTab(empId: widget.staffId),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Almarai', fontSize: 15),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchStaffInfo,
            style: ElevatedButton.styleFrom(backgroundColor: kPrimaryBlue),
            child: const Text(
              "إعادة المحاولة",
              style: TextStyle(color: Colors.white, fontFamily: 'Almarai'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTab() {
    String formatDateTime(dynamic dateValue) {
      if (dateValue == null) return "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";
      String dateStr = dateValue.toString();
      if (dateStr.startsWith("0001") || dateStr.isEmpty) {
        return "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";
      }
      return dateStr.split('T')[0];
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [

        _buildSectionCard("بيانات المعلم", Icons.badge_outlined, [
          _infoRow("اسم المعلم :", staffData!['name'] ?? "---"),
          _infoRow("كود المعلم :", staffData!['id']?.toString() ?? "---"),
          _infoRow("المكتب التابع له :", staffData!['loc']?['name'] ?? "---"),
          _infoRow("موعد الالتحاق بالمدرسة :", formatDateTime(staffData!['joinDate'])),
          _infoRow("المؤهل الدراسي :", staffData!['educationDegree'] ?? "---"),
        ]),

        const SizedBox(height: 20),

        _buildCertificatesCard(),
      ],
    );
  }

  Widget _buildCertificatesCard() {
    return Container(
      decoration: BoxDecoration(
        color: _kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            child: Row(
              children: [

                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _isCertificatesExpanded = !_isCertificatesExpanded),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: AnimatedRotation(
                      turns: _isCertificatesExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: const Icon(Icons.keyboard_arrow_down, color: kPrimaryBlue, size: 26),
                    ),
                  ),
                ),
                const Icon(Icons.school_outlined, color: kPrimaryBlue, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isCertificatesExpanded = !_isCertificatesExpanded),
                    child: Text(
                      "الدورات التدريبية الحاصل عليها",
                      style: TextStyle(
                        color: kPrimaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        fontFamily: 'Almarai',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (_isCertificatesLoading)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: PulseLoader(strokeWidth: 2, color: kPrimaryBlue),
                    ),
                  ),

                IconButton(
                  onPressed: _isCertificatesLoading ? null : () => _openCertificateForm(),
                  icon: const Icon(Icons.add_circle_outline),
                  color: _primaryOrange,
                  tooltip: 'إضافة دورة',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _isCertificatesExpanded
                ? Column(
              children: [
                const Divider(height: 1, color: _kBorderColor),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildCertificatesContent(),
                ),
              ],
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificatesContent() {
    if (_isCertificatesLoading && _certificates.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: PulseLoader(color: kPrimaryBlue),
        ),
      );
    }

    if (_certificates.isEmpty) {
      return Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'لا توجد دورات تدريبية',
              style: TextStyle(
                color: Colors.red,
                fontFamily: 'Almarai',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),

          ElevatedButton(
            onPressed: () => _openCertificateForm(),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryOrange,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'إضافة دورة',
              style: TextStyle(color: Colors.white, fontFamily: 'Almarai'),
            ),
          ),
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: DataTable(
        columnSpacing: 20,
        headingRowHeight: 48,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 72,
        headingRowColor: WidgetStateProperty.all(kPrimaryBlue.withOpacity(0.05)),
        columns: const [
          DataColumn(label: Text('الاسم', style: _headerStyle)),
          DataColumn(label: Text('الشهادة', style: _headerStyle)),
          DataColumn(label: Text('الجهة', style: _headerStyle)),
          DataColumn(label: Text('الدورة', style: _headerStyle)),
          DataColumn(label: Text('المكان', style: _headerStyle)),
          DataColumn(label: Text('الدرجة', style: _headerStyle)),
          DataColumn(label: Text('تاريخ البدء', style: _headerStyle)),
          DataColumn(label: Text('تاريخ الانتهاء', style: _headerStyle)),
          DataColumn(label: Text('تعديل', style: _headerStyle)),
        ],
        rows: _certificates.map(_buildCertificateRow).toList(),
      ),
    );
  }

  DataRow _buildCertificateRow(EmployeeCertificate cert) {
    return DataRow(
      cells: [
        DataCell(Text(cert.cerName ?? '---', style: _cellStyle)),
        DataCell(
          (cert.downloadPath?.isNotEmpty ?? false)
              ? TextButton(
            onPressed: _isDownloadingCertificate ? null : () => _openCertificate(cert),
            child: Text(
              _isDownloadingCertificate ? '...' : 'الشهادة',
              style: const TextStyle(fontFamily: 'Almarai', color: kPrimaryBlue),
            ),
          )
              : const Text('---', style: _cellStyle),
        ),
        DataCell(Text(cert.cerFrom ?? '---', style: _cellStyle)),
        DataCell(Text(cert.courseName ?? '---', style: _cellStyle)),
        DataCell(Text(cert.place ?? '---', style: _cellStyle)),
        DataCell(Text(cert.grade ?? '---', style: _cellStyle)),
        DataCell(Text(_formatDate(cert.dateFrom), style: _cellStyle)),
        DataCell(Text(_formatDate(cert.dateTo), style: _cellStyle)),

        DataCell(
          IconButton(
            icon: const Icon(Icons.edit_note, color: Color(0xFFF59E0B)),
            onPressed: () => _openCertificateForm(certificate: cert),
            tooltip: 'تعديل',
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(icon, color: kPrimaryBlue, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: kPrimaryBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    fontFamily: 'Almarai',
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
              fontFamily: 'Almarai',
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: kTextDark,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                fontFamily: 'Almarai',
              ),
              textAlign: TextAlign.left,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '---';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  static const TextStyle _headerStyle = TextStyle(
    fontFamily: 'Almarai',
    fontWeight: FontWeight.bold,
    color: kPrimaryBlue,
    fontSize: 13,
  );

  static const TextStyle _cellStyle = TextStyle(
    fontFamily: 'Almarai',
    color: kTextDark,
    fontSize: 12,
  );
}
