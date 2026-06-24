import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '/login_screen.dart';
import 'teacher_model.dart';
import 'employee_certificate_model.dart';
import 'certificate_form_dialog.dart';
import 'attendance_history_screen.dart';
import 'package:project1/teacher/curriculum/curriculum_screen.dart';
import 'groups_screen.dart';
import 'main_attendance_widget.dart';
import '../services/base_api_service.dart';
import '../services/auth_service.dart';
import '../services/certificate_service.dart';
import '../utils/server_date_utils.dart';



const Color _primaryOrange = Color(0xFFC66422);
const Color _darkBlue = Color(0xFF2E3542);
const Color _kActiveBlue = Color(0xFF1976D2);
const Color _kLabelGrey = Color(0xFF718096);
const Color _kBorderColor = Color(0xFFE2E8F0);
const Color _kBgLight = Color(0xFFF9FAFB);
const Color _kWhite = Color(0xFFFFFFFF);



class Level {
  String? name;
  Level({this.name});
  factory Level.fromJson(Map<String, dynamic> json) => Level(name: json["name"]);
}

class Location {
  String? name;
  Location({this.name});
  factory Location.fromJson(Map<String, dynamic> json) => Location(name: json["name"]);
}

class GroupSession {
  int? day;
  String? hour;
  GroupSession({this.day, this.hour});
  factory GroupSession.fromJson(Map<String, dynamic> json) => GroupSession(
    day: json["day"],
    hour: json["hour"]?.toString(),
  );

  String get dayName {
    switch (day) {
      case 1: return "السبت";
      case 2: return "الأحد";
      case 3: return "الإثنين";
      case 4: return "الثلاثاء";
      case 5: return "الأربعاء";
      case 6: return "الخميس";
      case 7: return "الجمعة";
      default: return "";
    }
  }
}

class SessionRecord {
  int? id;
  String? name;
  Level? level;
  Location? loc;
  List<GroupSession>? groupSessions;

  SessionRecord({this.id, this.name, this.level, this.loc, this.groupSessions});

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
    id: json["id"],
    name: json["name"],
    level: json["level"] == null ? null : Level.fromJson(json["level"]),
    loc: json["loc"] == null ? null : Location.fromJson(json["loc"]),
    groupSessions: json["groupSessions"] == null
        ? null
        : List<GroupSession>.from(json["groupSessions"].map((x) => GroupSession.fromJson(x))),
  );
}

List<SessionRecord> sessionRecordFromJson(String str) =>
    List<SessionRecord>.from(json.decode(str).map((x) => SessionRecord.fromJson(x)));



class TeacherHomeScreen extends StatefulWidget {
  final Map<String, dynamic>? loginData;
  const TeacherHomeScreen({super.key, this.loginData});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  String _currentTitle = "الرئيسية";
  bool _isLoading = true;
  bool _isRefreshing = false;
  TeacherData? teacherData;
  List<SessionRecord> _sessions = [];
  List<EmployeeCertificate> _certificates = [];
  bool _isCertificatesLoading = false;
  bool _isCertificatesExpanded = false;
  bool _isDownloadingCertificate = false;
  final BaseApiService _apiService = BaseApiService();
  final CertificateService _certificateService = CertificateService();
  final Set<String> _loadedSections = {'الرئيسية'};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ============================================================================
  // 📦 تحميل البيانات
  // ============================================================================

  Future<void> _loadInitialData() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    String? numericId = widget.loginData?['userId']?.toString() ??
        prefs.getString('user_id');

    if (numericId != null && numericId.isNotEmpty) {
      final cached = await _apiService.getWithCache(
        endpoint: '/Employee/GetById?id=$numericId',
        cacheKey: 'teacher_profile_$numericId',
        cacheDuration: const Duration(minutes: 10),
      );
      if (mounted && cached['fromCache'] == true) {
        final decoded = cached['data'];
        setState(() {
          teacherData = TeacherModel.fromJson(decoded).data;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = true);
      }
    } else if (mounted) {
      setState(() => _isLoading = true);
    }

    await _fetchTeacherProfile();
    await _fetchCertificates();

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchTeacherProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loginDataStr = prefs.getString('loginData');
      if (loginDataStr == null) return;

      final loginData = jsonDecode(loginDataStr);
      String? numericId = loginData['userId']?.toString();
      String? guid = loginData['user_Id']?.toString() ?? loginData['id']?.toString();

      debugPrint("🔑 numericId=$numericId | guid=$guid");

      if (numericId != null && numericId.isNotEmpty && numericId != "null" && numericId != "0") {
        final result = await _apiService.getWithCache(
          endpoint: '/Employee/GetById?id=$numericId',
          cacheKey: 'teacher_profile_$numericId',
          cacheDuration: const Duration(minutes: 10),
        );

        final decoded = result['data'];
        final bool fromCache = result['fromCache'] ?? false;

        if (fromCache) {
          debugPrint('📦 Displaying cached teacher profile');
        }

        if (mounted) {
          setState(() {
            teacherData = TeacherModel.fromJson(decoded).data;
          });
        }

        final locId = decoded['data']?['locId'];
        if (locId != null) {
          await prefs.setInt('user_loc_id', locId as int);
          debugPrint("✅ Teacher Saved user_loc_id: $locId");
        }
      } else if (guid != null && guid.isNotEmpty) {
        debugPrint("ℹ️ No numeric ID, using loginData directly");
        if (mounted) {
          setState(() {
            teacherData = TeacherData(
              id: null,
              name: loginData['userName']?.toString(),
              phone: loginData['phoneNumber']?.toString(),
              joinDate: null,
              educationDegree: null,
              loc: null,
              courses: null,
            );
          });
        }
      }
    } catch (e) {
      debugPrint("❌ Error fetching teacher profile: $e");
    }
  }

  Future<int?> _getEmpId() async {
    if (teacherData?.id != null) return teacherData!.id;

    final fromLogin = int.tryParse(widget.loginData?['userId']?.toString() ?? '');
    if (fromLogin != null) return fromLogin;

    final prefs = await SharedPreferences.getInstance();
    return int.tryParse(prefs.getString('user_id') ?? '');
  }

  Future<void> _fetchCertificates() async {
    if (!mounted) return;

    final empId = await _getEmpId();
    if (empId == null) return;

    setState(() => _isCertificatesLoading = true);

    try {
      final result = await _apiService.getWithCache(
        endpoint: '/EmployeeCertificate/GetByEmpId?empId=$empId',
        cacheKey: 'teacher_certificates_$empId',
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
    final empId = await _getEmpId();
    if (empId == null) {
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

  Future<void> _fetchSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString('user_id');

      if (id == null || id.isEmpty) {
        debugPrint("❌ Error: No User ID found");
        return;
      }

      final result = await _apiService.getWithCache(
        endpoint: '/Employee/GetSessionRecord?emp_id=$id',
        cacheKey: 'teacher_sessions_$id',
        cacheDuration: const Duration(minutes: 5),
      );

      final data = result['data'];
      final bool fromCache = result['fromCache'] ?? false;

      if (fromCache) {
        debugPrint('📦 Displaying cached sessions');
      }

      if (mounted) {
        setState(() => _sessions = sessionRecordFromJson(jsonEncode(data)));
      }
    } catch (e) {
      debugPrint("❌ Error fetching sessions: $e");
    }
  }

  // ============================================================================
  // 🔄 تحديث البيانات
  // ============================================================================

  Future<void> _refreshAllData() async {
    if (_isRefreshing) return;

    if (mounted) setState(() => _isRefreshing = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final loginDataStr = prefs.getString('loginData');
      if (loginDataStr == null) return;

      final loginData = jsonDecode(loginDataStr);
      String? numericId = loginData['userId']?.toString();

      if (numericId != null && numericId.isNotEmpty) {
        await _apiService.invalidateCache('teacher_profile_$numericId');
        await _apiService.invalidateCache('teacher_sessions_${prefs.getString('user_id')}');
        await _apiService.invalidateCache('teacher_certificates_$numericId');

        await _fetchTeacherProfile();
        await _fetchCertificates();
        await _fetchSessions();
      }
    } catch (e) {
      debugPrint("❌ Refresh Error: $e");
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  // ============================================================================
  // 🏗️ بناء الواجهة
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _kBgLight,
        appBar: _buildAppBar(),
        drawer: _buildTeacherSidebar(context),
        body: RefreshIndicator(
          onRefresh: _refreshAllData,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: _isLoading
                ? const Center(
              key: ValueKey('loading'),
              child: CircularProgressIndicator(color: _kActiveBlue),
            )
                : KeyedSubtree(
              key: ValueKey(_currentTitle),
              child: _buildBody(),
            ),
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _kWhite,
      elevation: 0.5,
      title: Text(
        _currentTitle,
        style: TextStyle(
          color: _darkBlue,
          fontWeight: FontWeight.bold,
          fontFamily: 'Almarai',
          fontSize: 16,
        ),
      ),
      centerTitle: true,
      iconTheme: IconThemeData(color: _darkBlue),
      actions: [
        if (_currentTitle == "مواعيد الدرس" || _currentTitle == "البيانات الشخصية")
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _kActiveBlue,
              ),
            )
                : Icon(Icons.refresh, color: _darkBlue),
            onPressed: _isRefreshing ? null : _refreshAllData,
            tooltip: 'تحديث',
          ),
      ],
    );
  }

  // ============================================================================
  // 📄 محتوى الصفحات
  // ============================================================================

  Widget _buildBody() {
    switch (_currentTitle) {
      case "الرئيسية":
        return MainAttendanceScreen();
      case "البيانات الشخصية":
        return _buildProfileBody();
      case "المنهج / المقرر":
        return CurriculumScreen();
      case "المجموعات":
        return GroupsScreen();
      case "مواعيد الدرس":
        return _buildSessionsBody();
      default:
        return Center(
          child: Text(
            "قريباً: $_currentTitle",
            style: TextStyle(fontFamily: 'Almarai', color: _darkBlue),
          ),
        );
    }
  }

  // ============================================================================
  // 👤 صفحة الملف الشخصي
  // ============================================================================

  Widget _buildProfileBody() {
    if (teacherData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            const Text(
              "تعذر تحميل البيانات",
              style: TextStyle(
                fontFamily: 'Almarai',
                color: Colors.red,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text(
                "إعادة المحاولة",
                style: TextStyle(fontFamily: 'Almarai'),
              ),
              onPressed: () async {
                if (mounted) setState(() => _isLoading = true);
                await _fetchTeacherProfile();
                if (mounted) setState(() => _isLoading = false);
              },
            ),
          ],
        ),
      );
    }

    String joinDateStr = ServerDateUtils.formatJoinDate(teacherData!.joinDate);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard("بيانات المعلم", Icons.badge_outlined, [
          _infoRow("اسم المعلم :", teacherData?.name ?? "---"),
          _infoRow("كود المعلم :", teacherData?.id?.toString() ?? "---"),
          _infoRow("المكتب التابع له :", teacherData?.loc?.name ?? "---"),
          _infoRow("موعد الالتحاق بالمدرسة :", joinDateStr),
          _infoRow("المؤهل الدراسي :", teacherData?.educationDegree ?? "---"),
        ]),
        const SizedBox(height: 16),
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
                      child: const Icon(Icons.keyboard_arrow_down, color: _kActiveBlue, size: 26),
                    ),
                  ),
                ),
                const Icon(Icons.school_outlined, color: _kActiveBlue, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isCertificatesExpanded = !_isCertificatesExpanded),
                    child: Text(
                      "الدورات التدريبية الحاصل عليها",
                      style: TextStyle(
                        color: _kActiveBlue,
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: _kActiveBlue),
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
          child: CircularProgressIndicator(color: _kActiveBlue),
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
              style: TextStyle(color: Colors.red, fontFamily: 'Almarai', fontWeight: FontWeight.bold),
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
        headingRowColor: WidgetStateProperty.all(_kActiveBlue.withOpacity(0.05)),
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
          cert.downloadPath.isNotEmpty
              ? TextButton(
            onPressed: _isDownloadingCertificate ? null : () => _openCertificate(cert),
            child: Text(
              _isDownloadingCertificate ? '...' : 'الشهادة',
              style: const TextStyle(fontFamily: 'Almarai', color: _kActiveBlue),
            ),
          )
              : const Text('---', style: _cellStyle),
        ),
        DataCell(Text(cert.cerFrom ?? '---', style: _cellStyle)),
        DataCell(Text(cert.courseName ?? '---', style: _cellStyle)),
        DataCell(Text(cert.place ?? '---', style: _cellStyle)),
        DataCell(Text(cert.grade ?? '---', style: _cellStyle)),
        DataCell(Text(ServerDateUtils.formatDisplayDate(cert.dateFrom), style: _cellStyle)),
        DataCell(Text(ServerDateUtils.formatDisplayDate(cert.dateTo), style: _cellStyle)),
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

  Future<void> _openCertificate(EmployeeCertificate cert) async {
    if (cert.downloadPath.isEmpty) return;

    setState(() => _isDownloadingCertificate = true);

    final result = await _certificateService.downloadCertificate(cert.downloadPath);

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

  // ============================================================================
  // 📅 صفحة المواعيد
  // ============================================================================

  Widget _buildSessionsBody() {
    final bool hasNoData = _sessions.isEmpty ||
        _sessions.every((s) => s.groupSessions == null || s.groupSessions!.isEmpty);

    if (hasNoData) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            const Text(
              'لم يتم تحديد المواعيد أو المجموعات بعد',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Almarai',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text(
                "تحديث",
                style: TextStyle(fontFamily: 'Almarai'),
              ),
              onPressed: _refreshAllData,
            ),
          ],
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "جدول المواعيد",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _darkBlue,
                fontFamily: 'Almarai',
              ),
            ),
            if (_isRefreshing)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _kActiveBlue,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: _kWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: DataTable(
              columnSpacing: 25,
              headingRowHeight: 50,
              dataRowHeight: 60,
              headingRowColor: WidgetStateProperty.all(
                _kActiveBlue.withOpacity(0.05),
              ),
              columns: const [
                DataColumn(label: Text('اليوم', style: _headerStyle)),
                DataColumn(label: Text('الساعة', style: _headerStyle)),
                DataColumn(label: Text('المجموعة', style: _headerStyle)),
                DataColumn(label: Text('المستوى', style: _headerStyle)),
                DataColumn(label: Text('المكتب', style: _headerStyle)),
              ],
              rows: _buildSessionRows(),
            ),
          ),
        ),
      ],
    );
  }

  List<DataRow> _buildSessionRows() {
    List<DataRow> rows = [];
    for (var record in _sessions) {
      if (record.groupSessions != null) {
        for (var s in record.groupSessions!) {
          rows.add(
            DataRow(
              cells: [
                DataCell(
                  Center(
                    child: Text(
                      s.dayName,
                      style: _cellStyleBold,
                    ),
                  ),
                ),
                DataCell(
                  Center(
                    child: Text(
                      s.hour ?? "",
                      style: _cellStyle,
                    ),
                  ),
                ),
                DataCell(
                  Center(
                    child: Text(
                      record.name ?? "",
                      style: _cellStyle,
                    ),
                  ),
                ),
                DataCell(
                  Center(
                    child: Text(
                      record.level?.name ?? "",
                      style: _cellStyle,
                    ),
                  ),
                ),
                DataCell(
                  Center(
                    child: Text(
                      record.loc?.name ?? "",
                      style: _cellStyle,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      }
    }
    return rows;
  }

  // ============================================================================
  // 🧭 القائمة الجانبية
  // ============================================================================

  Widget _buildTeacherSidebar(BuildContext context) {
    return Drawer(
      backgroundColor: _kWhite,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 50, bottom: 20),
            child: Center(
              child:Image.asset(
                'assets/full_logo.png',
                height: 80,
                cacheWidth: 200, // مهم!
                errorBuilder: (c, e, s) => Icon(Icons.school, size: 60, color: _primaryOrange),              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildSidebarItem(Icons.home_outlined, "الرئيسية"),
                _buildSidebarItem(Icons.person_outline, "البيانات الشخصية"),
                _buildSidebarItem(
                  Icons.fact_check_outlined,
                  "الحضور و الإنصراف",
                  isPushScreen: true,
                  screen: const AttendanceHistoryScreen(),
                ),
                _buildSidebarItem(Icons.menu_book_outlined, "المنهج / المقرر"),
                _buildSidebarItem(Icons.groups_outlined, "المجموعات"),
                _buildSidebarItem(Icons.access_time, "مواعيد الدرس"),
              ],
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: _buildSidebarItem(
                Icons.logout,
                "تسجيل الخروج",
                color: Colors.redAccent,
                isLogout: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
      IconData icon,
      String title, {
        Color? color,
        bool isLogout = false,
        bool isPushScreen = false,
        Widget? screen,
      }) {
    bool isSelected = _currentTitle == title;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? _kActiveBlue.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        leading: Icon(
          icon,
          color: isSelected ? _kActiveBlue : (color ?? _darkBlue),
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? _kActiveBlue : (color ?? _darkBlue),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontFamily: 'Almarai',
          ),
        ),
        onTap: () async {
          if (isLogout) {
            Navigator.pop(context);
            _showLogoutDialog();
            return;
          }

          if (isPushScreen && screen != null) {
            if (mounted) setState(() => _currentTitle = "الرئيسية");
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => screen),
            );
            return;
          }

          if (_currentTitle != title) {
            if (mounted) setState(() => _currentTitle = title);
          }
          Navigator.pop(context);

          if (title == "مواعيد الدرس" && !_loadedSections.contains(title)) {
            _loadedSections.add(title);
            await _fetchSessions();
          }

          if (title == "البيانات الشخصية" && teacherData == null) {
            await _fetchTeacherProfile();
          }

          if (title == "البيانات الشخصية") {
            await _fetchCertificates();
          }
        },
      ),
    );
  }

  // ============================================================================
  // 🚪 تسجيل الخروج
  // ============================================================================

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _kWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            "تسجيل الخروج",
            style: TextStyle(
              fontFamily: 'Almarai',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            "هل أنت متأكد؟",
            style: TextStyle(fontFamily: 'Almarai'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                elevation: 0,
              ),
              onPressed: () async {
                await AuthService.clearSession();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (c) => const LoginScreen()),
                      (r) => false,
                );
              },
              child: const Text(
                "خروج",
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Almarai',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // 🧩 ويدجتات مساعدة
  // ============================================================================

  Widget _buildInfoCard(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _kWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: _kActiveBlue, size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    color: _kActiveBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: 'Almarai',
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorderColor),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _kLabelGrey,
              fontSize: 14,
              fontFamily: 'Almarai',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: _darkBlue,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                fontFamily: 'Almarai',
              ),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }


  static const TextStyle _headerStyle = TextStyle(
    fontFamily: 'Almarai',
    fontWeight: FontWeight.bold,
    color: _kActiveBlue,
    fontSize: 14,
  );

  static const TextStyle _cellStyle = TextStyle(
    fontFamily: 'Almarai',
    color: _darkBlue,
    fontSize: 13,
  );

  static const TextStyle _cellStyleBold = TextStyle(
    fontFamily: 'Almarai',
    fontWeight: FontWeight.bold,
    color: _kActiveBlue,
    fontSize: 13,
  );
}