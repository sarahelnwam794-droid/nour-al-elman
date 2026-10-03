import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'staff_model.dart';
import 'staff_details_screen.dart';
import '../../services/base_api_service.dart';
import 'package:project1/widgets/pulse_loader.dart';
import 'package:project1/widgets/list_skeleton_loader.dart';
import 'package:project1/utils/debouncer.dart';

class EmployeesScreen extends StatefulWidget {
  @override
  _EmployeesScreenState createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  List<StaffModel> _allEmployees = [];
  List<StaffModel> _filteredEmployees = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final Debouncer _searchDebouncer = Debouncer(milliseconds: 350);

  final Color kPrimaryBlue = const Color(0xFF07427C);
  final Color kTextDark = const Color(0xFF2E3542);
  final BaseApiService _apiService = BaseApiService();

  @override
  void initState() {
    super.initState();
    _fetchTeachersData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebouncer.dispose();
    super.dispose();
  }

  Future<void> _fetchTeachersData({bool forceRefresh = false}) async {
    if (_allEmployees.isEmpty) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isRefreshing = true);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final cached = await _apiService.getWithCache(
        endpoint: '/Employee/GetWithType/?type=1',
        cacheKey: 'teachers_type1',
        cacheDuration: const Duration(minutes: 5),
        forceRefresh: forceRefresh,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      final dynamic rawData = cached['data'];
      final List<dynamic> dataList = rawData is List
          ? rawData
          : (rawData is Map ? (rawData['data'] ?? []) : []);

      List<StaffModel> loadedTeachers = [];
      for (var item in dataList) {
        loadedTeachers.add(StaffModel.fromJson(item));
      }

      if (mounted) {
        setState(() {
          _allEmployees = loadedTeachers;
          _filteredEmployees = _allEmployees;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _isRefreshing = false; });
    }
  }
  Future<void> _deleteEmployee(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final url =Uri.parse('https://nourelman.runasp.net/api/Account/DeActivate?id=$id&type=1');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final resBody = jsonDecode(response.body);
        if (resBody['message'] == "Success") {
          _showSnackBar("تم حذف المدرس بنجاح", Colors.green);
          _fetchTeachersData();
        } else {
          _showSnackBar("فشل في الحذف: ${resBody['message']}", Colors.red);
        }
      } else {
        _showSnackBar("فشل في الاتصال بالسيرفر: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _showSnackBar("حدث خطأ غير متوقع", Colors.red);
    }
  }
  Future<void> _updatePassword(int empId, String newPassword) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('https://nourelman.runasp.net/api/Student/ResetPassword')
        ,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"id": empId, "password": newPassword}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _showSnackBar("تم تغيير كلمة المرور بنجاح", Colors.green);
      } else {
        _showSnackBar("فشل تحديث كلمة المرور", Colors.red);
      }
    } catch (e) {
      _showSnackBar("حدث خطأ أثناء التحديث", Colors.red);
    }
  }

  void _filterSearch(String query) {
    _searchDebouncer.run(() {
      setState(() {
        _filteredEmployees = _allEmployees
            .where((emp) => (emp.name ?? "").toLowerCase().contains(query.toLowerCase()))
            .toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Color(0xFF2E3542)),
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: _filterSearch,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(
              hintText: "ابحث عن موظف...",
              border: InputBorder.none,
              hintStyle: TextStyle(fontFamily: 'Almarai', fontSize: 14)),
        )
            : Text("اسماء المعلمون",
            style: TextStyle(
                fontFamily: 'Almarai',
                fontWeight: FontWeight.bold,
                color: kTextDark,
                fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: kPrimaryBlue),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _filteredEmployees = _allEmployees;
                }
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const ListSkeletonLoader(
        columnFlex: [1, 4, 2, 2, 1],
        rowCount: 7,
        wrapInCard: true,
        headerLabels: ["#", "الاسم", "بيانات", "كلمة المرور", "حذف"],
        headerAlign: [TextAlign.center, TextAlign.right, TextAlign.center, TextAlign.center, TextAlign.center],
      )
          : Stack(children: [
        _filteredEmployees.isEmpty
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 160),
            Center(child: Text("لا يوجد نتائج مطابقة")),
          ],
        )
            : Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
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
                      itemCount: _filteredEmployees.length,
                      itemBuilder: (context, index) {
                        final teacher = _filteredEmployees[index];
                        return Container(
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.grey[200]!, width: 0.5)),
                          ),
                          child: Row(
                            children: [
                              _buildDataCell("${index + 1}", flex: 1),
                              _buildDataCell(teacher.name ?? "---", flex: 4, align: TextAlign.right, isBold: true),
                              _buildActionCell(Icons.person_outline, Colors.blue[800]!, flex: 2, onTap: () async {
                                await Navigator.push(context, MaterialPageRoute(
                                  builder: (c) => StaffDetailsScreen(staffId: teacher.id!, staffName: teacher.name!),
                                ));
                                _fetchTeachersData();
                              }),
                              _buildActionCell(Icons.lock_open_rounded, Colors.blue[400]!, flex: 2, onTap: () {
                                _showResetPasswordDialog(teacher.id!, teacher.name ?? "");
                              }),
                              _buildActionCell(Icons.delete_outline, Colors.red[400]!, flex: 1, onTap: () {
                                _showDeleteConfirmDialog(teacher.id!);
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
        if (_isRefreshing)
          const Positioned(
            top: 0, left: 0, right: 0,
            child: LinearProgressIndicator(
              minHeight: 3,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC66422)),
            ),
          ),
      ]),
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
            style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
                color: kTextDark,
                fontFamily: 'Almarai')),
      ),
    );
  }

  Widget _buildActionCell(IconData icon, Color color, {required int flex, required VoidCallback onTap}) {
    return Expanded(
      flex: flex,
      child: IconButton(icon: Icon(icon, color: color, size: 22), onPressed: onTap),
    );
  }

  void _showResetPasswordDialog(int empId, String empName) {
    final TextEditingController _passController = TextEditingController();
    final TextEditingController _confirmPassController = TextEditingController();
    bool _isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text("إعادة تعيين كلمة السر",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Almarai')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("إدخال كلمة المرور الجديدة للشيخ: $empName",
                      style: const TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'Almarai')),
                  const SizedBox(height: 20),
                  _buildPopupTextField("كلمة المرور", _passController),
                  const SizedBox(height: 15),
                  _buildPopupTextField("تأكيد كلمة المرور", _confirmPassController),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("إلغاء", style: TextStyle(color: Colors.red, fontFamily: 'Almarai')),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: _isSubmitting
                    ? null
                    : () async {
                  if (_passController.text.length < 6) {
                    _showSnackBar("كلمة المرور قصيرة جداً", Colors.orange);
                    return;
                  }
                  if (_passController.text != _confirmPassController.text) {
                    _showSnackBar("كلمة المرور غير متطابقة", Colors.orange);
                    return;
                  }
                  setDialogState(() => _isSubmitting = true);
                  await _updatePassword(empId, _passController.text);
                  if (mounted) Navigator.pop(context);
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

  void _showDeleteConfirmDialog(int empId) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          content: const Text("هل أنت متأكد من حذف هذا المدرس؟",
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Almarai', fontWeight: FontWeight.bold)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("تراجع")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                Navigator.pop(context);
                _deleteEmployee(empId);
              },
              child: const Text("تأكيد الحذف", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopupTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, fontFamily: 'Almarai'),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message, style: const TextStyle(fontFamily: 'Almarai')), backgroundColor: color));
  }
}