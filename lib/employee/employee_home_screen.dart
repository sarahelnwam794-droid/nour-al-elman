import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/login_screen.dart';
import 'employee_model.dart';
import 'employee_attendance_screen.dart';
import 'student_details/students_screen.dart';
import 'employees_details/all_employees_screen.dart';
import 'employee_attendance_history_screen.dart';
import 'reports_screen/reports_screen.dart';
import 'staff_management_screen/staff_management_screen.dart';
import 'waiting_list_screen/waiting_list_screen.dart';
import 'courses_screen/courses_screen.dart';
import 'branches_screen/branches_screen.dart';
import 'employee/employees_screen.dart';
import 'reports_screen/levels_screen/levels_screen.dart';
import 'expenses_hub_screen.dart';
import 'appreciation_certificates_screen.dart';
import '../services/base_api_service.dart';
import '../services/auth_service.dart';
import '../widgets/lazy_indexed_stack.dart';

final Color primaryOrange = Color(0xFFC66422);
final Color darkBlue = Color(0xFF2E3542);
const Color kActiveBlue = Color(0xFF1976D2);
const Color kLabelGrey = Color(0xFF718096);
const Color kBorderColor = Color(0xFFE2E8F0);

class EmployeeHomeScreen extends StatefulWidget {
  final Map<String, dynamic>? loginData;

  const EmployeeHomeScreen({super.key, this.loginData});

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  String _currentTitle = "الصفحة الرئيسية";
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isRefreshing = false;
  EmployeeData? employeeData;
  Map<String, dynamic>? _rawResponse;
  Key _historyKey = UniqueKey();

  final BaseApiService _apiService = BaseApiService();

  @override
  void initState() {
    super.initState();
    _fetchEmployeeProfile(showBlockingLoader: true);
  }

  Future<void> _fetchEmployeeProfile({bool showBlockingLoader = false}) async {
    if (showBlockingLoader && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      String? numericId = widget.loginData?['userId']?.toString() ??
          prefs.getString('user_id');

      if (numericId == null || numericId.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final cacheKey = 'employee_profile_$numericId';
      final cached = await _apiService.getWithCache(
        endpoint: '/Employee/GetById?id=$numericId',
        cacheKey: cacheKey,
        cacheDuration: const Duration(minutes: 10),
      );

      final decodedData = cached['data'];
      final employeeModel = EmployeeModel.fromJson(decodedData);

      if (mounted) {
        setState(() {
          _rawResponse = decodedData['data'];
          employeeData = employeeModel.data;
          _isLoading = false;
        });
      }

      final locId = decodedData['data']?['locId'];
      if (locId != null) {
        await prefs.setInt('user_loc_id', locId as int);
      }
    } catch (e) {
      debugPrint('Error fetching employee profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshAllData() async {
    if (_isRefreshing) return;

    if (mounted) setState(() => _isRefreshing = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      String? numericId = prefs.getString('user_id');

      if (numericId != null && numericId.isNotEmpty) {
        await _apiService.invalidateCache('employee_profile_$numericId');
        await _fetchEmployeeProfile(showBlockingLoader: false);
      }
    } catch (e) {
      debugPrint('Refresh Error: $e');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _onItemTapped(String title, int index) {
    if (!mounted) return;
    setState(() {
      _currentIndex = index;
      _currentTitle = title;
      if (index == 2) {
        _historyKey = UniqueKey();
      }
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          scrolledUnderElevation: 0,
          title: Text(
            _currentTitle,
            style: TextStyle(
              color: darkBlue,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              fontFamily: 'Almarai',
            ),
          ),
          iconTheme: IconThemeData(color: darkBlue),
          actions: [
            if (_currentIndex == 1)
              IconButton(
                icon: _isRefreshing
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: kActiveBlue),
                )
                    : Icon(Icons.refresh, color: darkBlue),
                onPressed: _isRefreshing ? null : _refreshAllData,
                tooltip: 'تحديث',
              ),
          ],
        ),
        drawer: _buildEmployeeSidebar(context),
        body: RefreshIndicator(
          onRefresh: _refreshAllData,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: kActiveBlue))
              : LazyIndexedStack(
            index: _currentIndex,
            itemBuilders: [
                  () => MainAttendanceScreen(),
                  () => _buildPersonalDataContent(),
                  () => EmployeeAttendanceHistoryScreen(key: _historyKey),
                  () => StudentsScreen(),
                  () => AllEmployeesScreen(),
                  () => EmployeesScreen(),
                  () => LevelsScreen(),
                  () => const BranchesScreen(),
                  () => const CoursesScreen(),
                  () => WaitingListScreen(),
                  () => const AppreciationCertificatesScreen(),
                  () => StaffManagementScreen(),
                  () => ReportsScreen(),
                  () => const ExpensesHubScreen(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalDataContent() {
    String rawDate = employeeData?.joinDate?.toString() ?? "---";
    String formattedDate = (rawDate != "---" && rawDate.length >= 10)
        ? rawDate.substring(0, 10)
        : rawDate;

    String jobTitle = "---";
    if (_rawResponse != null && _rawResponse!['employeeType'] != null) {
      jobTitle = _rawResponse!['employeeType']['name'] ?? "---";
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard("بيانات الموظف", Icons.person_pin_outlined, [
          _infoRow("اسم الموظف :", employeeData?.name ?? "---"),
          _infoRow("كود الموظف :", employeeData?.id?.toString() ?? "---"),
          _infoRow("المكتب التابع له :", employeeData?.loc?.name ?? "---"),
          _infoRow("موعد الالتحاق بالمدرسة :", formattedDate),
          _infoRow("المؤهل الدراسي :", employeeData?.educationDegree ?? "---"),
          _infoRow("المسمى الوظيفي :", jobTitle),
        ]),
        if (employeeData == null)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text("إعادة المحاولة", style: TextStyle(fontFamily: 'Almarai')),
              onPressed: _refreshAllData,
            ),
          ),
      ],
    );
  }

  Widget _buildInfoCard(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: kActiveBlue, size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: kActiveBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: 'Almarai',
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: kBorderColor),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: kLabelGrey, fontSize: 14, fontFamily: 'Almarai')),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: darkBlue,
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

  Widget _buildEmployeeSidebar(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 50, bottom: 20),
            child: Center(
              child: Image.asset(
                'assets/full_logo.png',
                height: 80,
                cacheWidth: 200,
                errorBuilder: (c, e, s) => const Icon(Icons.business, size: 50, color: kActiveBlue),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildSidebarItem(Icons.home_outlined, "الصفحة الرئيسية", 0),
                  _buildSidebarItem(Icons.person_outline, "البيانات الشخصية", 1),
                  _buildSidebarItem(Icons.history, "سجل الحضور والإنصراف", 2),
                  _buildSidebarItem(Icons.school_outlined, "الطلاب", 3),
                  _buildSidebarItem(Icons.badge_outlined, "الموظفون", 4),
                  _buildSidebarItem(Icons.person_search_outlined, "المعلمون", 5),
                  _buildSidebarItem(Icons.layers_outlined, "المستويات و المجموعات", 6),
                  _buildSidebarItem(Icons.location_on_outlined, "الفروع", 7),
                  _buildSidebarItem(Icons.menu_book_outlined, "الدورات", 8),
                  _buildSidebarItem(Icons.hourglass_empty, "قائمة الإنتظار", 9),
                  _buildSidebarItem(Icons.manage_accounts_outlined, "إدارة الموظفين", 10),
                  _buildSidebarItem(Icons.assessment_outlined, "التقارير", 11),
                  _buildSidebarItem(Icons.account_balance_wallet_outlined, "المصروفات", 12),
                  _buildSidebarItem(Icons.workspace_premium_outlined, "استخراج شهادات تقدير", 13),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          _buildSidebarItem(
            Icons.logout,
            "تسجيل الخروج",
            -1,
            color: Colors.redAccent,
            isLogout: true,
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
      IconData icon,
      String title,
      int index, {
        Color? color,
        bool isLogout = false,
      }) {
    bool isSelected = _currentIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? kActiveBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Colors.white, width: 0.5) : null,
        ),
        child: ListTile(
          visualDensity: VisualDensity.compact,
          leading: Icon(icon, color: isSelected ? Colors.white : (color ?? darkBlue), size: 22),
          title: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : (color ?? darkBlue),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
              fontFamily: 'Almarai',
            ),
          ),
          onTap: () {
            if (isLogout) {
              _showLogoutDialog();
            } else {
              _onItemTapped(title, index);
            }
          },
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            "تسجيل الخروج",
            style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold, fontFamily: 'Almarai'),
          ),
          content: const Text(
            "هل أنت متأكد أنك تريد تسجيل الخروج؟",
            style: TextStyle(fontFamily: 'Almarai'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("إلغاء", style: TextStyle(color: Colors.grey, fontFamily: 'Almarai')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                await AuthService.clearSession();
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (c) => const LoginScreen()),
                      (r) => false,
                );
              },
              child: const Text("خروج", style: TextStyle(color: Colors.white, fontFamily: 'Almarai')),
            ),
          ],
        ),
      ),
    );
  }
}