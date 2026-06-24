import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'student/student_home_screen.dart';
import 'teacher/teacher_home_screen.dart';
import 'employee/employee_home_screen.dart';
import 'account_selection_dialog.dart';
import 'services/cache_manager.dart';
import 'services/auth_service.dart';


class AppColors {
  static const Color primaryOrange = Color(0xFFC66422);
  static const Color darkBlue = Color(0xFF2E3542);
  static const Color greyText = Color(0xFF707070);
  static const Color successGreen = Color(0xFF2D8A63);
  static const Color white = Color(0xFFFFFFFF);
  static const Color red = Color(0xFFFF0000);
  static const Color greyBorder = Color(0xFFE2E8F0);
}

const String baseUrl = 'https://nourelman.runasp.net/api';
final Logger logger = Logger();


class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 80, color: AppColors.successGreen),
              const SizedBox(height: 20),
              Text(
                'تم تسجيل الحساب بنجاح',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.successGreen,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              Text(
                'برجاء الانتظار حتى يقوم المشرف بالموافقة على الحساب',
                style: TextStyle(fontSize: 16, color: AppColors.darkBlue),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: Text(
                  'العودة لتسجيل الدخول',
                  style: TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}



class PendingApprovalScreen extends StatefulWidget {
  final String phone;
  final String password;
  final String userId;

  const PendingApprovalScreen({
    super.key,
    required this.phone,
    required this.password,
    this.userId = "",
  });

  @override
  State<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends State<PendingApprovalScreen> {
  bool _isPolling = true;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _isPolling = false;
    super.dispose();
  }

  void _startPolling() async {
    while (_isPolling && mounted) {
      await Future.delayed(const Duration(seconds: 10));
      if (!mounted || !_isPolling) return;
      await _checkIfApproved();
    }
  }

  Future<void> _checkIfApproved() async {
    try {
      debugPrint("⏳ POLLING: phone=${widget.phone}, userId=${widget.userId}");

      final response = await http.post(
        Uri.parse('$baseUrl/Account/UserLogin'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "Phone": widget.phone,
          "Password": widget.password,
          "UserId": widget.userId,
        }),
      );

      debugPrint("📥 POLL_RESPONSE: status=${response.statusCode}");

      if (response.statusCode == 200 && mounted) {
        final dynamic decodedBody = jsonDecode(response.body);
        Widget nextScreen;

        if (decodedBody is Map<String, dynamic>) {
          final int userType = int.tryParse(decodedBody['userType']?.toString() ?? "0") ?? 0;
          nextScreen = _getHomeScreen(userType, decodedBody);
        } else if (decodedBody is List && decodedBody.isNotEmpty) {
          final first = Map<String, dynamic>.from(decodedBody[0]);
          final int userType = int.tryParse(first['userType']?.toString() ?? "0") ?? 0;
          nextScreen = _getHomeScreen(userType, first);
        } else {
          return;
        }

        _isPolling = false;
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => nextScreen),
              (route) => false,
        );
      }
    } catch (e) {
      debugPrint("❌ POLL_ERROR: $e");
    }
  }

  Widget _getHomeScreen(int userType, Map<String, dynamic> data) {
    if (userType == 1 || userType == 4) {
      return TeacherHomeScreen();
    } else if (userType == 2 || userType == 3) {
      return EmployeeHomeScreen();
    } else {
      return StudentHomeScreen(loginData: data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: AppColors.successGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.hourglass_top_rounded, size: 56, color: AppColors.successGreen),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'في انتظار الموافقة',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.successGreen,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.successGreen.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.successGreen.withOpacity(0.3), width: 1.2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppColors.successGreen, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'رجاء الانتظار حتى يقوم المشرف بالموافقة على الحساب',
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.successGreen,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isObscured = true;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final CacheManager _cache = CacheManager();

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ============================================================================
  // 📦 حفظ بيانات المستخدم
  // ============================================================================

  Future<void> _saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('loginData', jsonEncode(userData));
    await prefs.setBool('is_logged_in', true);

    await _cache.saveData('user_profile', userData);
    await _cache.saveData('user_type', userData['userType']);

    final int userType = int.tryParse(userData['userType']?.toString() ?? "0") ?? 0;
    if (userType == 0) {
      await _cache.saveData('student_data', userData);
    } else {
      await _cache.saveData('employee_data', userData);
    }

    await AuthService.markSessionActive();

    debugPrint("✅ User data cached");
  }

  // ============================================================================
  // 🔑 معالجة تسجيل الدخول
  // ============================================================================

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final String phone = _phoneController.text.trim();
      final String password = _passwordController.text;

      final response = await http.post(
        Uri.parse('$baseUrl/Account/ValidateUserLogin'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "phone": phone,
          "password": password,
          "userId": ""
        }),
      );

      debugPrint("📥 VALIDATE_LOGIN: status=${response.statusCode}");

      if (response.statusCode == 200) {
        final dynamic decodedBody = jsonDecode(response.body);

        if (decodedBody is List) {
          if (decodedBody.isEmpty) {
            _showErrorSnackBar("لا يوجد مستخدم مسجل بهذا الرقم");
            setState(() => _isLoading = false);
            return;
          }

          if (decodedBody.length == 1) {
            await _handleSelectedAccount(
              phone: phone,
              password: password,
              selected: Map<String, dynamic>.from(decodedBody[0]),
            );
          } else {
            setState(() => _isLoading = false);
            if (!mounted) return;

            showGeneralDialog(
              context: context,
              barrierDismissible: false,
              barrierLabel: '',
              barrierColor: Colors.transparent,
              transitionDuration: Duration.zero,
              pageBuilder: (_, __, ___) => AccountSelectionDialog(
                accounts: decodedBody,
                onSelect: (selected) async {
                  setState(() => _isLoading = true);
                  await _handleSelectedAccount(
                    phone: phone,
                    password: password,
                    selected: Map<String, dynamic>.from(selected),
                  );
                },
              ),
            );
          }
        } else {
          await _loginWithAccount(Map<String, dynamic>.from(decodedBody));
        }
      } else {
        _handleLoginError(response);
      }
    } catch (e) {
      debugPrint("❌ FATAL_ERROR: $e");
      _showErrorSnackBar("حدث خطأ في الاتصال بالسيرفر");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================================
  // 🎯 معالجة الحساب المحدد
  // ============================================================================

  Future<void> _handleSelectedAccount({
    required String phone,
    required String password,
    required Map<String, dynamic> selected,
  }) async {
    final int selUserType = int.tryParse(selected['userType']?.toString() ?? "0") ?? 0;
    final String selUserId = selected['id']?.toString() ?? "";

    debugPrint("🔍 handleSelectedAccount: userType=$selUserType, userId=$selUserId");

    try {
      final userLoginResponse = await http.post(
        Uri.parse('$baseUrl/Account/UserLogin'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "Phone": phone,
          "Password": password,
          "UserId": selUserId,
        }),
      );

      debugPrint("📥 USER_LOGIN_RESPONSE: status=${userLoginResponse.statusCode}");

      if (userLoginResponse.statusCode == 200) {
        final dynamic decoded = jsonDecode(userLoginResponse.body);
        if (decoded is Map<String, dynamic>) {
          await _loginWithAccount(decoded);
          return;
        }
        if (decoded is List && decoded.isNotEmpty) {
          await _loginWithAccount(Map<String, dynamic>.from(decoded[0]));
          return;
        }
      }

      if (userLoginResponse.statusCode == 401) {
        try {
          final errBody = jsonDecode(userLoginResponse.body);
          if (errBody['message']?.toString() == 'Waiting for Approve') {
            if (mounted) {
              setState(() => _isLoading = false);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PendingApprovalScreen(
                    phone: phone,
                    password: password,
                    userId: selUserId,
                  ),
                ),
              );
            }
            return;
          }
        } catch (_) {}

        if (mounted) {
          setState(() => _isLoading = false);
        }

        if (mounted) {
          _showErrorSnackBar("رقم الهاتف أو كلمة المرور غير صحيحة");
        }
        return;
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }

      if (mounted) {
        _showErrorSnackBar("حدث خطأ غير متوقع، حاول مرة أخرى");
      }
    } catch (e) {
      debugPrint("❌ handleSelectedAccount error: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }

      if (mounted) {
        _showErrorSnackBar("حدث خطأ في الاتصال بالسيرفر");
      }
    }
  }

  // ============================================================================
  // 👨‍🎓 تسجيل الدخول بحساب محدد
  // ============================================================================

  Future<void> _loginWithAccount(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();

    String correctUserId = userData['user_Id']?.toString() ??
        userData['id']?.toString() ?? "";
    String numericId = userData['userId']?.toString() ?? "";
    String phone = userData['phoneNumber']?.toString() ?? "";

    await prefs.setString('user_id', numericId);
    await prefs.setString('user_guid', correctUserId);
    await prefs.setString('user_phone', phone);
    await prefs.setString('user_token', userData['token']?.toString() ?? "no_token");

    await _saveUserData(userData);

    debugPrint("✅ Saved user_guid (GUID): $correctUserId | numeric_id: $numericId");

    int userType = int.tryParse(userData['userType']?.toString() ?? "0") ?? 0;
    Widget nextScreen = _getHomeScreen(userType, userData);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تم تسجيل الدخول بنجاح", style: TextStyle(fontFamily: 'Almarai')),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => nextScreen),
      );
    }
  }

  // ============================================================================
  // 🏠 الحصول على الشاشة المناسبة حسب نوع المستخدم
  // ============================================================================

  Widget _getHomeScreen(int userType, Map<String, dynamic> data) {
    if (userType == 1 || userType == 4) {
      return TeacherHomeScreen();
    } else if (userType == 2 || userType == 3) {
      return EmployeeHomeScreen();
    } else {
      return StudentHomeScreen(loginData: data);
    }
  }

  // ============================================================================
  // ⚠️ معالجة أخطاء تسجيل الدخول
  // ============================================================================

  void _handleLoginError(http.Response response) {
    debugPrint("❌ VALIDATE_LOGIN FAILED: status=${response.statusCode}");

    if (response.statusCode == 401) {
      try {
        final body = jsonDecode(response.body);
        final msg = body['message']?.toString().trim() ?? "";
        if (msg == 'Waiting for Approve') {
          if (mounted) {
            setState(() => _isLoading = false);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PendingApprovalScreen(
                  phone: _phoneController.text.trim(),
                  password: _passwordController.text,
                  userId: "",
                ),
              ),
            );
          }
          return;
        }
      } catch (e) {
        debugPrint("❌ parse error: $e");
      }
    }
    _showErrorSnackBar("رقم الهاتف أو كلمة المرور غير صحيحة");
  }

  // ============================================================================
  // 📢 عرض رسائل الخطأ
  // ============================================================================

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Almarai')),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ============================================================================
  // 🎨 بناء واجهة المستخدم
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  _buildLogoSection(),
                  const SizedBox(height: 30),
                  _buildPhoneField(),
                  const SizedBox(height: 20),
                  _buildPasswordField(),
                  const SizedBox(height: 25),
                  _buildLoginButton(),
                  const SizedBox(height: 25),
                  _buildRegisterLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // 🧩 مكونات واجهة المستخدم
  // ============================================================================

  Widget _buildLogoSection() {
    return Center(
      child: Column(
        children: [
          Image.asset(
            'assets/full_logo.png',
            height: 120,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                Icon(Icons.school, size: 80, color: AppColors.primaryOrange),
          ),
          const SizedBox(height: 15),
          Text(
            'تسجيل الدخول',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.darkBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel("رقم الهاتف", isRequired: true),
        TextFormField(
          controller: _phoneController,
          decoration: _buildInputDecoration("أدخل رقم الهاتف"),
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          validator: (value) => (value == null || value.isEmpty) ? "مطلوب" : null,
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel("كلمه السر", isRequired: true),
        TextFormField(
          controller: _passwordController,
          obscureText: _isObscured,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _handleLogin(),
          decoration: _buildInputDecoration("أدخل كلمة السر").copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _isObscured ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF9E9E9E),
              ),
              onPressed: () => setState(() => _isObscured = !_isObscured),
            ),
          ),
          validator: (value) => (value == null || value.isEmpty) ? "مطلوب" : null,
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return _isLoading
        ? Center(child: CircularProgressIndicator(color: AppColors.primaryOrange))
        : _buildPrimaryButton(context, "الدخول", _handleLogin);
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(' ليس لديك حساب ؟ ', style: TextStyle(fontSize: 14, color: AppColors.greyText)),
        GestureDetector(
          onTap: () => Navigator.push(context, _createRoute(const UserTypeScreen())),
          child: Text(
            'انشاء حساب',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: AppColors.darkBlue,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.darkBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isRequired) Text(' *', style: TextStyle(color: Colors.red)),
        ],
      ),
    );
  }

  // ============================================================================
  // 🛠️ دوال مساعدة
  // ============================================================================

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.primaryOrange),
      ),
      errorStyle: const TextStyle(fontSize: 12, height: 0.8),
    );
  }

  Widget _buildPrimaryButton(BuildContext context, String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryOrange,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 18,
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Route _createRoute(Widget screen) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutQuart;
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);
        return SlideTransition(position: offsetAnimation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}

// ============================================================================
// 👤 شاشة اختيار نوع المستخدم
// ============================================================================

class UserTypeScreen extends StatefulWidget {
  const UserTypeScreen({super.key});

  @override
  State<UserTypeScreen> createState() => _UserTypeScreenState();
}

class _UserTypeScreenState extends State<UserTypeScreen> {
  String? selectedType;

  void _handleTypeSelection(String type) async {
    setState(() => selectedType = type);
    await Future.delayed(const Duration(milliseconds: 50));

    if (mounted) {
      if (type == 'student') {
        Navigator.push(context, _createRoute(const StudentRegistrationScreen()));
      } else {
        Navigator.push(context, _createRoute(const EmployeeRegistrationScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.darkBlue),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'انضم إلينا',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'اختر نوع الحساب للمتابعة',
                style: TextStyle(fontSize: 16, color: AppColors.greyText),
              ),
              const SizedBox(height: 40),
              _buildTypeCard(
                'طالب',
                'للتسجيل في الدورات ومتابعة الدروس',
                Icons.school_rounded,
                'student',
              ),
              const SizedBox(height: 20),
              _buildTypeCard(
                'موظف',
                'لإدارة النظام والمحتوى التعليمي',
                Icons.work_rounded,
                'employee',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeCard(String title, String desc, IconData icon, String type) {
    bool isSelected = selectedType == type;

    return GestureDetector(
      onTap: () => _handleTypeSelection(type),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryOrange.withOpacity(0.05) : AppColors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? AppColors.primaryOrange : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryOrange : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? AppColors.white : AppColors.darkBlue),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkBlue,
                    ),
                  ),
                  Text(desc, style: TextStyle(fontSize: 13, color: AppColors.greyText)),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: AppColors.primaryOrange),
          ],
        ),
      ),
    );
  }

  Route _createRoute(Widget screen) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => screen,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutQuart;
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);
        return SlideTransition(position: offsetAnimation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}

// ============================================================================
// 📝 دوال التسجيل العامة
// ============================================================================

Future<void> _handleRegistration({
  required BuildContext context,
  required Map<String, dynamic> data,
}) async {
  try {
    logger.i("API_REQUEST: RegisterUser | Data: ${jsonEncode(data)}");

    final response = await http.post(
      Uri.parse('$baseUrl/Account/RegisterUser'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );

    logger.d("API_RESPONSE: Code ${response.statusCode}");

    if (response.statusCode == 200 || response.statusCode == 201) {
      if (context.mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const SuccessScreen()));
      }
    } else {
      _handleRegistrationError(context, response);
    }
  } catch (e) {
    logger.e("FATAL_ERROR_REG: $e");
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("حدث خطأ غير متوقع"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

void _handleRegistrationError(BuildContext context, http.Response response) {
  logger.e("API_ERROR: ${response.statusCode} | Body: ${response.body}");

  String displayError = "فشل التسجيل: تفقد البيانات المدخلة";

  try {
    var body = jsonDecode(response.body);
    String rawError = body['error']?.toString() ?? "";

    if (rawError.contains('IX_Employees_Ssn') || rawError.contains('Ssn') || rawError.contains('duplicate key')) {
      displayError = "الرقم القومي مسجل مسبقاً، تحقق من البيانات";
    } else if (rawError.contains('phone') || rawError.contains('Phone')) {
      displayError = "رقم الهاتف مسجل مسبقاً";
    } else if (rawError.contains('email') || rawError.contains('Email')) {
      displayError = "البريد الإلكتروني مسجل مسبقاً";
    } else if (body['message'] != null) {
      displayError = body['message'].toString();
    }
  } catch (_) {}

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(displayError, style: const TextStyle(fontFamily: 'Almarai')),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// ============================================================================
// 🧑‍🎓 شاشة تسجيل الطالب
// ============================================================================

class StudentRegistrationScreen extends StatefulWidget {
  const StudentRegistrationScreen({super.key});

  @override
  State<StudentRegistrationScreen> createState() => _StudentRegistrationScreenState();
}

class _StudentRegistrationScreenState extends State<StudentRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordObscured = true;
  bool _isConfirmObscured = true;
  bool _isLoading = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _parentJobController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _parentPhoneController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _dayController = TextEditingController();
  final TextEditingController _monthController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();

  String? _selectedAttendance;
  List<dynamic> _locations = [];
  bool _isLoadingLocations = true;
  int? _selectedLocId;

  @override
  void initState() {
    super.initState();
    _fetchLocations();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _parentJobController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _parentPhoneController.dispose();
    _phoneController.dispose();
    _schoolController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocations() async {
    try {
      final response = await http.get(
        Uri.parse('https://nourelman.runasp.net/api/Locations/GetAll'),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (mounted) {
          setState(() {
            _locations = decoded is List ? decoded : (decoded['data'] ?? []);
            _isLoadingLocations = false;
          });
        }
      } else if (mounted) {
        setState(() => _isLoadingLocations = false);
      }
    } catch (e) {
      debugPrint("❌ Error fetching locations: $e");
      if (mounted) setState(() => _isLoadingLocations = false);
    }
  }

  void _registerStudent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("كلمات السر غير متطابقة"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    String birthDate =
        "${_yearController.text}-${_monthController.text.padLeft(2, '0')}-${_dayController.text.padLeft(2, '0')}T00:00:00.000Z";

    Map<String, dynamic> studentData = {
      "name": _nameController.text.trim(),
      "Phone": _parentPhoneController.text.trim(),
      "phone2": _phoneController.text.trim(),
      "address": _addressController.text.trim(),
      "ParentJob": _parentJobController.text.trim(),
      "email": _emailController.text.trim().isEmpty ? "" : _emailController.text.trim(),
      "governmentSchool": _schoolController.text.trim(),
      "attendanceType": _selectedAttendance ?? "أوفلاين",
      "birthDate": birthDate,
      "locId": _selectedLocId ?? 1,
      "ssn": "",
      "employeeTypeId": 0,
      "educationDegree": "",
      "Password": _passwordController.text,
    };

    logger.i("SENDING STUDENT DATA: ${jsonEncode(studentData)}");
    await _handleRegistration(context: context, data: studentData);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return _BaseRegistrationScreen(
      formKey: _formKey,
      title: 'إنشاء حساب طالب',
      buttonText: "انشاء حساب",
      isLoading: _isLoading,
      onButtonPressed: _registerStudent,
      children: [
        _buildInputField("الإسم", "الإسم", controller: _nameController),
        _buildInputField("وظيفة الأب", "وظيفة الأب", isRequired: false, controller: _parentJobController),
        _isLoadingLocations
            ? const Center(child: CircularProgressIndicator())
            : _buildLocationDropdown(_locations, _selectedLocId, (val) => setState(() => _selectedLocId = val)),
        _buildInputField("العنوان", "العنوان", controller: _addressController),
        _buildInputField("البريد الإلكتروني", "example@mail.com", isRequired: false, controller: _emailController),
        _buildBirthdayRow(
          dayCtrl: _dayController,
          monthCtrl: _monthController,
          yearCtrl: _yearController,
        ),
        _buildInputField(
          "رقم هاتف ولي الأمر",
          "01xxxxxxxxx",
          isPhone: true,
          isRequired: true,
          controller: _parentPhoneController,
        ),
        _buildInputField(
          "رقم الهاتف (اختياري)",
          "01xxxxxxxxx",
          isPhone: true,
          isRequired: false,
          controller: _phoneController,
        ),
        _buildInputField("اسم المدرسة الحكومية", "اسم المدرسة", controller: _schoolController),
        _buildDropdownField("الحضور", ["أونلاين", "أوفلاين"], onChanged: (val) => _selectedAttendance = val),
        _buildInputField(
          "كلمة السر",
          "كلمة السر",
          isPassword: true,
          isObscured: _isPasswordObscured,
          onToggle: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
          controller: _passwordController,
        ),
        _buildInputField(
          "تأكيد كلمة السر",
          "تأكيد كلمة السر",
          isPassword: true,
          isObscured: _isConfirmObscured,
          onToggle: () => setState(() => _isConfirmObscured = !_isConfirmObscured),
          controller: _confirmPasswordController,
        ),
      ],
    );
  }

  // ============================================================================
  // 🧩 دوال مساعدة لتسجيل الطالب
  // ============================================================================

  Widget _buildInputField(
      String label,
      String hint, {
        bool isRequired = true,
        bool isPhone = false,
        bool isPassword = false,
        bool isObscured = false,
        VoidCallback? onToggle,
        TextEditingController? controller,
        TextInputAction? textInputAction,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 16),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 14, color: AppColors.darkBlue, fontWeight: FontWeight.w600),
              ),
              if (isRequired) Text(' *', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? isObscured : false,
          keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
          textInputAction: textInputAction ?? TextInputAction.next,
          validator: (value) {
            if (isRequired && (value == null || value.trim().isEmpty)) return "مطلوب";
            if (label == "البريد الإلكتروني" && value != null && value.isNotEmpty) {
              if (!value.contains("@")) return "بريد غير صالح";
            }
            return null;
          },
          decoration: _buildInputDecoration(hint).copyWith(
            suffixIcon: isPassword
                ? IconButton(
              icon: Icon(
                isObscured ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF9E9E9E),
              ),
              onPressed: onToggle,
            )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, List<String> items, {Function(String?)? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 16),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 14, color: AppColors.darkBlue, fontWeight: FontWeight.w600),
              ),
              Text(' *', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        DropdownButtonFormField<String>(
          dropdownColor: AppColors.white,
          decoration: _buildInputDecoration("اختيار $label"),
          validator: (value) => (value == null) ? "مطلوب" : null,
          onChanged: onChanged,
          items: items.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
        ),
      ],
    );
  }

  Widget _buildBirthdayRow({
    TextEditingController? dayCtrl,
    TextEditingController? monthCtrl,
    TextEditingController? yearCtrl,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 16),
          child: Row(
            children: [
              Text(
                "تاريخ الميلاد",
                style: TextStyle(fontSize: 14, color: AppColors.darkBlue, fontWeight: FontWeight.w600),
              ),
              Text(' *', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(child: _NumberInputField(hint: "يوم", controller: dayCtrl)),
            const SizedBox(width: 10),
            Expanded(child: _NumberInputField(hint: "شهر", controller: monthCtrl)),
            const SizedBox(width: 10),
            Expanded(child: _NumberInputField(hint: "سنة", controller: yearCtrl)),
          ],
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.primaryOrange),
      ),
      errorStyle: const TextStyle(fontSize: 12, height: 0.8),
    );
  }
}

// ============================================================================
// 👔 شاشة تسجيل الموظف
// ============================================================================

class EmployeeRegistrationScreen extends StatefulWidget {
  const EmployeeRegistrationScreen({super.key});

  @override
  State<EmployeeRegistrationScreen> createState() => _EmployeeRegistrationScreenState();
}

class _EmployeeRegistrationScreenState extends State<EmployeeRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isPasswordObscured = true;
  bool _isConfirmObscured = true;
  bool _isLoading = false;

  List<dynamic> _locations = [];
  bool _isLoadingLocations = true;
  int? _selectedLocId;

  List<dynamic> _jobTypes = [];
  bool _isLoadingJobTypes = true;
  int? _selectedJobTypeId;

  String _fileNames = "لم يتم اختيار ملفات";

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ssnController = TextEditingController();
  final TextEditingController _eduController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchLocations();
    _fetchJobTypes();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _ssnController.dispose();
    _eduController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocations() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/Locations/Getall'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _locations = data is List ? data : (data['data'] ?? []);
            _isLoadingLocations = false;
          });
        }
      } else if (mounted) {
        setState(() => _isLoadingLocations = false);
      }
    } catch (e) {
      debugPrint("❌ Error fetching locations: $e");
      if (mounted) setState(() => _isLoadingLocations = false);
    }
  }

  Future<void> _fetchJobTypes() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/EmployeeType/GetAll'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _jobTypes = data is List ? data : (data['data'] ?? []);
            _isLoadingJobTypes = false;
          });
        }
      } else if (mounted) {
        setState(() => _isLoadingJobTypes = false);
      }
    } catch (e) {
      debugPrint("❌ Error fetching job types: $e");
      if (mounted) setState(() => _isLoadingJobTypes = false);
    }
  }

  void _registerEmployee() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("كلمات السر غير متطابقة"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    int empTypeId = _selectedJobTypeId ?? 1;
    int userType = (empTypeId == 1) ? 1 : 2;

    Map<String, dynamic> employeeData = {
      "name": _nameController.text.trim(),
      "phone": _phoneController.text.trim(),
      "address": "",
      "ParentJob": "",
      "email": _emailController.text.trim().isEmpty ? "" : _emailController.text.trim(),
      "governmentSchool": "",
      "attendanceType": "",
      "birthDate": DateTime.now().toIso8601String(),
      "locId": _selectedLocId ?? 1,
      "phone2": "",
      "ssn": _ssnController.text.trim(),
      "employeeTypeId": empTypeId,
      "educationDegree": _eduController.text.trim(),
      "Password": _passwordController.text,
      "type": userType,
    };

    logger.i("SENDING EMPLOYEE DATA: ${jsonEncode(employeeData)}");
    await _handleRegistration(context: context, data: employeeData);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
    );

    if (result != null) {
      if (mounted) {
        setState(() {
          _fileNames = result.files.map((f) => f.name).join(', ');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BaseRegistrationScreen(
      formKey: _formKey,
      title: 'إنشاء حساب موظف',
      buttonText: "انشاء حساب موظف",
      isLoading: _isLoading,
      onButtonPressed: _registerEmployee,
      children: [
        _buildInputField("الإسم", "الإسم", controller: _nameController),
        _buildInputField("رقم الهاتف", "01xxxxxxxxx", isPhone: true, controller: _phoneController),
        _buildInputField("الرقم القومي", "14 رقم", controller: _ssnController),
        _isLoadingLocations
            ? const Center(child: CircularProgressIndicator())
            : _buildLocationDropdown(_locations, _selectedLocId, (val) => setState(() => _selectedLocId = val)),
        _buildInputField("المؤهل الدراسي", "المؤهل", controller: _eduController),
        _buildInputField("البريد الإلكتروني", "example@staff.com", isRequired: false, controller: _emailController),
        _isLoadingJobTypes
            ? const Center(child: CircularProgressIndicator())
            : _buildJobTypeDropdown(),

        if (_selectedJobTypeId == 1) ...[
          _buildFilePickerSection(),
        ],

        _buildInputField(
          "كلمة السر",
          "كلمة السر",
          isPassword: true,
          isObscured: _isPasswordObscured,
          onToggle: () => setState(() => _isPasswordObscured = !_isPasswordObscured),
          controller: _passwordController,
        ),
        _buildInputField(
          "تأكيد كلمة السر",
          "تأكيد كلمة السر",
          isPassword: true,
          isObscured: _isConfirmObscured,
          onToggle: () => setState(() => _isConfirmObscured = !_isConfirmObscured),
          controller: _confirmPasswordController,
        ),
      ],
    );
  }

  // ============================================================================
  // 🧩 دوال مساعدة لتسجيل الموظف
  // ============================================================================

  Widget _buildInputField(
      String label,
      String hint, {
        bool isRequired = true,
        bool isPhone = false,
        bool isPassword = false,
        bool isObscured = false,
        VoidCallback? onToggle,
        TextEditingController? controller,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 16),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 14, color: AppColors.darkBlue, fontWeight: FontWeight.w600),
              ),
              if (isRequired) Text(' *', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: isPassword ? isObscured : false,
          keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
          validator: (value) {
            if (isRequired && (value == null || value.trim().isEmpty)) return "مطلوب";
            if (label == "البريد الإلكتروني" && value != null && value.isNotEmpty) {
              if (!value.contains("@")) return "بريد غير صالح";
            }
            return null;
          },
          decoration: _buildInputDecoration(hint).copyWith(
            suffixIcon: isPassword
                ? IconButton(
              icon: Icon(
                isObscured ? Icons.visibility_off : Icons.visibility,
                color: const Color(0xFF9E9E9E),
              ),
              onPressed: onToggle,
            )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildJobTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 16),
          child: Row(
            children: [
              Text(
                "المسمى الوظيفي",
                style: TextStyle(fontSize: 14, color: AppColors.darkBlue, fontWeight: FontWeight.w600),
              ),
              Text(' *', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        DropdownButtonFormField<int>(
          dropdownColor: AppColors.white,
          decoration: _buildInputDecoration("اختر المسمى الوظيفي"),
          validator: (value) => value == null ? "مطلوب" : null,
          value: _selectedJobTypeId,
          items: _jobTypes.map<DropdownMenuItem<int>>((job) {
            return DropdownMenuItem<int>(
              value: job['id'] as int,
              child: Text(
                job['name']?.toString() ?? "",
                style: const TextStyle(fontFamily: 'Almarai'),
              ),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedJobTypeId = val;
            });
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildFilePickerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 16),
          child: Text(
            "الدورات الخاصة بك",
            style: TextStyle(fontSize: 14, color: AppColors.darkBlue, fontWeight: FontWeight.w600),
          ),
        ),
        InkWell(
          onTap: _pickFiles,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_upload_outlined, color: AppColors.primaryOrange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _fileNames,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  "اختيار ملفات",
                  style: TextStyle(color: AppColors.darkBlue, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.primaryOrange),
      ),
      errorStyle: const TextStyle(fontSize: 12, height: 0.8),
    );
  }
}

// ============================================================================
// 🏗️ القاعدة المشتركة لشاشات التسجيل
// ============================================================================

class _BaseRegistrationScreen extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final GlobalKey<FormState> formKey;
  final String buttonText;
  final VoidCallback onButtonPressed;
  final bool isLoading;

  const _BaseRegistrationScreen({
    required this.title,
    required this.children,
    required this.formKey,
    required this.buttonText,
    required this.onButtonPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          surfaceTintColor: AppColors.white,
          scrolledUnderElevation: 0,
          title: Text(
            title,
            style: TextStyle(color: AppColors.darkBlue, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.darkBlue),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Form(
          key: formKey,
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      ...children,
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(top: 20, bottom: 40.0),
                        child: isLoading
                            ? CircularProgressIndicator(color: AppColors.primaryOrange)
                            : _buildPrimaryButton(context, buttonText, onButtonPressed),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(BuildContext context, String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryOrange,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 18,
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 🧩 ويدجتات مساعدة
// ============================================================================

class _NumberInputField extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;

  const _NumberInputField({required this.hint, this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primaryOrange),
        ),
        errorStyle: const TextStyle(fontSize: 12, height: 0.8),
      ),
      validator: (value) => (value == null || value.isEmpty) ? "!" : null,
    );
  }
}

Widget _buildLocationDropdown(List<dynamic> locations, int? selectedId, Function(int?) onChanged) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        "المكتب التابع له *",
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Almarai'),
      ),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: locations.any((l) => l['id'] == selectedId) ? selectedId : null,
            isExpanded: true,
            hint: const Text("اختر المكتب", style: TextStyle(fontFamily: 'Almarai')),
            items: locations.map<DropdownMenuItem<int>>((loc) {
              return DropdownMenuItem<int>(
                value: loc['id'] as int,
                child: Text(
                  loc['name']?.toString() ?? "",
                  style: const TextStyle(fontFamily: 'Almarai'),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
      const SizedBox(height: 20),
    ],
  );
}