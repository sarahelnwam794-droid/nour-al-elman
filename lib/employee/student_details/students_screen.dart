import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'student_model.dart';
import 'student_details_screen.dart';
import '../../services/base_api_service.dart';
import 'package:project1/widgets/pulse_loader.dart';
import 'package:project1/widgets/skeleton_shimmer.dart';
import 'package:project1/widgets/smart_loading_switcher.dart';
import 'package:project1/utils/debouncer.dart';

class StudentsScreen extends StatefulWidget {
  @override
  _StudentsScreenState createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  List<StudentModel> _allStudents = [];
  List<StudentModel> _filteredStudents = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final Debouncer _searchDebouncer = Debouncer(milliseconds: 350);
  final BaseApiService _apiService = BaseApiService();

  @override
  void initState() {
    super.initState();
    _fetchStudentsData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebouncer.dispose();
    super.dispose();
  }

  Future<void> _fetchStudentsData({bool forceRefresh = false}) async {
    // الويرفريم الكامل يظهر مرة واحدة بس (أول تحميل، لما الليستة فاضية).
    // أي تحديث بعد كده (بعد حذف/تعديل/رجوع للشاشة) بيبقى تحديث هادئ
    // في الخلفية من غير ما يمسح البيانات الظاهرة على الشاشة.
    if (_allStudents.isEmpty) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isRefreshing = true);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final cached = await _apiService.getWithCache(
        endpoint: '/Student/GetByStatus?status=true',
        cacheKey: 'students_by_status_active',
        cacheDuration: const Duration(minutes: 5),
        forceRefresh: forceRefresh,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final dynamic rawData = cached['data'];
      final List<dynamic> rawList = rawData is List
          ? rawData
          : (rawData is Map ? (rawData['data'] ?? []) : []);
      final data =
      List<StudentModel>.from(rawList.map((x) => StudentModel.fromJson(x)));

      if (mounted) {
        setState(() {
          _allStudents = data;
          _filteredStudents = data;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() { _isLoading = false; _isRefreshing = false; });
    }
  }

  Future<void> _updatePassword(int studentId, String newPassword) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final url = Uri.parse('https://nourelman.runasp.net/api/Student/ResetPassword');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "id": studentId,
          "password": newPassword,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _showSnackBar("تم تغيير كلمة المرور بنجاح", Colors.green);
      } else {
        throw Exception();
      }
    } catch (e) {
      _showSnackBar("حدث خطأ أثناء التحديث", Colors.red);
    }
  }

  Future<void> _deleteStudent(int studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final url = Uri.parse('https://nourelman.runasp.net/api/Account/DeActivate?id=$studentId&type=0');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _showSnackBar("تم حذف الطالب بنجاح", Colors.green);
        _fetchStudentsData();
      } else {
        throw Exception();
      }
    } catch (e) {
      _showSnackBar("حدث خطأ أثناء الحذف", Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(fontFamily: 'Almarai')), backgroundColor: color),
    );
  }

  void _showResetPasswordDialog(int studentId, String studentName) {
    final TextEditingController _passController = TextEditingController();
    final TextEditingController _confirmPassController = TextEditingController();
    bool _isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text("إعادة تعيين كلمة السر",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Almarai')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("من فضلك، قم بإدخال كلمة المرور الجديدة للطالب: $studentName",
                      style: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Almarai')),
                  const SizedBox(height: 20),
                  _buildPopupTextField("كلمة المرور", _passController),
                  const SizedBox(height: 15),
                  _buildPopupTextField("إعادة إدخال كلمة المرور", _confirmPassController),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("إلغاء", style: TextStyle(color: Colors.red, fontFamily: 'Almarai')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E3542), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: _isSubmitting ? null : () async {
                  if (_passController.text.length < 6) return;
                  if (_passController.text != _confirmPassController.text) return;

                  setDialogState(() => _isSubmitting = true);
                  await _updatePassword(studentId, _passController.text);
                  Navigator.pop(context);
                },
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: PulseLoader(color: Colors.white, strokeWidth: 2))
                    : const Text("تغيير", style: TextStyle(color: Colors.white, fontFamily: 'Almarai')),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      _passController.dispose();
      _confirmPassController.dispose();
    });
  }

  void _showDeleteConfirmDialog(int studentId) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Text(
              "هل أنت متأكد من حذف هذا الطالب؟",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Almarai',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF2E3542)
              ),
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                  "تراجع",
                  style: TextStyle(color: Colors.grey, fontFamily: 'Almarai', fontWeight: FontWeight.bold)
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
              ),
              onPressed: () {
                Navigator.pop(context);
                _deleteStudent(studentId);
              },
              child: const Text(
                  "تأكيد الحذف",
                  style: TextStyle(color: Colors.white, fontFamily: 'Almarai')
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopupTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Almarai')),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(
            hintText: "أدخل كلمة المرور هنا",
            hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  void _filterStudents(String query) {
    _searchDebouncer.run(() {
      setState(() {
        _filteredStudents = _allStudents
            .where((student) =>
            student.name!.toLowerCase().contains(query.toLowerCase()))
            .toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          iconTheme: const IconThemeData(color: Color(0xFF2E3542)),
          title: _isSearching
              ? TextField(
            controller: _searchController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: "ابحث عن اسم الطالب...",
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            style: const TextStyle(color: Color(0xFF2E3542), fontSize: 16),
            onChanged: _filterStudents,
          )
              : const Text("قائمة الطلاب",
              style: TextStyle(
                  color: Color(0xFF2E3542),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  fontFamily: 'Almarai')),
          actions: [
            IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  if (!_isSearching) {
                    _searchController.clear();
                    _filteredStudents = _allStudents;
                  }
                });
              },
            ),
          ],
        ),
        body: SmartLoadingSwitcher(
          isLoading: _isLoading,
          skeleton: _buildStudentsSkeleton(),
          child: Stack(
            children: [
              _filteredStudents.isEmpty
                  ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text("لا يوجد نتائج مطابقة")),
                ],
              )
                  : Padding(
                padding: const EdgeInsets.all(12.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Column(
                      children: [
                        Container(
                          color: Colors.grey[100],
                          child: Row(
                            children: [
                              _buildHeaderCell("#", flex: 1),
                              _buildHeaderCell("الاسم", flex: 4, align: TextAlign.right),
                              _buildHeaderCell("بيانات", flex: 2),
                              _buildHeaderCell("كلمة المرور", flex: 2),
                              _buildHeaderCell("حذف", flex: 1),
                            ],
                          ),
                        ),

                        Expanded(
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _filteredStudents.length,
                            itemBuilder: (context, index) {
                              final StudentModel student = _filteredStudents[index];
                              return Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                      bottom: BorderSide(
                                          color: Colors.grey[200]!, width: 0.5)),
                                ),
                                child: Row(
                                  children: [
                                    _buildDataCell("${index + 1}", flex: 1),
                                    _buildDataCell(student.name ?? "---",
                                        flex: 4, align: TextAlign.right, isBold: true),
                                    _buildActionCell(Icons.person_outline, Colors.blue[800]!, flex: 2,
                                        onTap: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => StudentDetailsScreen(
                                                studentId: student.id!,
                                                studentName: student.name!,
                                              ),
                                            ),
                                          );
                                          _fetchStudentsData();
                                        }),
                                    _buildActionCell(Icons.lock_open_rounded, Colors.blue[400]!, flex: 2,
                                        onTap: () {
                                          _showResetPasswordDialog(student.id!, student.name!);
                                        }),
                                    _buildActionCell(Icons.delete_outline, Colors.red[400]!, flex: 1,
                                        onTap: () {
                                          _showDeleteConfirmDialog(student.id!);
                                        }),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // شريط رفيع بيظهر بس وقت التحديث الهادئ في الخلفية
              // (بعد حذف/تعديل/رجوع للشاشة)، من غير ما يمسح البيانات الظاهرة
              if (_isRefreshing)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC66422)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// ويرفريم بيطابق شكل شاشة الطلاب الحقيقية: نفس الكارت الأبيض، ونفس
  /// عناوين الأعمدة الثابتة، وبس الأجزاء اللي فعلاً بتيجي من السيرفر
  /// (الاسم وترتيب الصف) بتتحط لها Placeholder متحرك.
  Widget _buildStudentsSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              Container(
                color: Colors.grey[100],
                child: Row(
                  children: [
                    _buildHeaderCell("#", flex: 1),
                    _buildHeaderCell("الاسم", flex: 4, align: TextAlign.right),
                    _buildHeaderCell("بيانات", flex: 2),
                    _buildHeaderCell("كلمة المرور", flex: 2),
                    _buildHeaderCell("حذف", flex: 1),
                  ],
                ),
              ),
              Expanded(
                child: SkeletonShimmer(
                  baseColor: const Color(0xFFE6E9EF),
                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 7,
                    itemBuilder: (context, index) {
                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(
                                  color: Colors.grey[200]!, width: 0.5)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
                                child: Center(child: Bone(width: 14, height: 12)),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Bone(width: 110, height: 13),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Bone.circle(size: 22),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Bone.circle(size: 22),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Center(
                                child: Bone.circle(size: 18),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, {required int flex, TextAlign align = TextAlign.center}) {
    // سطر واحد دايمًا، ولو العمود ضيق (موبايل صغير) الخط بيصغر تلقائيًا
    // بدل ما الكلمة تنكسر على سطرين (حذ / ف).
    final Alignment boxAlign = align == TextAlign.right
        ? Alignment.centerRight
        : align == TextAlign.left
        ? Alignment.centerLeft
        : Alignment.center;
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: boxAlign,
          child: Text(
            text,
            textAlign: align,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey[700], fontFamily: 'Almarai'),
          ),
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, {required int flex, TextAlign align = TextAlign.center, bool isBold = false}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
        child: Text(text,
          textAlign: align,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.w600 : FontWeight.normal, color: const Color(0xFF2E3542), fontFamily: 'Almarai'),
        ),
      ),
    );
  }

  Widget _buildActionCell(IconData icon, Color color, {required int flex, required VoidCallback onTap}) {

    return Expanded(
      flex: flex,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: color, size: 20),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      ),
    );
  }
}