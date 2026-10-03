import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'student_details_screen.dart';
import 'staff_details_screen.dart';
import 'package:project1/widgets/pulse_loader.dart';
import 'package:project1/widgets/skeleton_shimmer.dart';
import 'package:project1/widgets/list_skeleton_loader.dart';

class GroupDetailsScreen extends StatefulWidget {
  final int groupId;
  final int levelId;
  final String groupName;
  final String teacherName;
  final int teacherId;

  const GroupDetailsScreen({
    super.key,
    required this.groupId,
    required this.levelId,
    required this.groupName,
    required this.teacherName,
    required this.teacherId,
  });

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  List<dynamic> _students = [];
  List<dynamic> _filteredStudents = [];
  final TextEditingController _studentSearchController = TextEditingController();
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? displayGroupName;
  String? displayTeacherName;
  int _resolvedTeacherId = 0;

  Map<String, dynamic> _currentGroupData = {};

  final Color kPrimaryBlue = const Color(0xFF07427C);
  final Color kTextDark = const Color(0xFF2E3542);
  final Color orangeButton = const Color(0xFFC66422);

  List<dynamic> teachersList = [];
  List<dynamic> locationsList = [];
  int? selectedTeacherId;
  int? selectedLocationId;
  List<int> selectedDays = [];
  TimeOfDay? selectedTime;
  bool _editDataLoaded = false;

  @override
  void initState() {
    super.initState();
    displayGroupName = widget.groupName;
    displayTeacherName = widget.teacherName;
    _resolvedTeacherId = widget.teacherId;
    _fetchGroupData();
  }

  @override
  void dispose() {
    _studentSearchController.dispose();
    super.dispose();
  }

  List<dynamic> _applyStudentSearch(List<dynamic> source, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List.from(source);
    return source
        .where((s) => (s['name'] ?? "").toString().toLowerCase().contains(q))
        .toList();
  }

  void _onStudentSearchChanged(String value) {
    setState(() {
      _filteredStudents = _applyStudentSearch(_students, value);
    });
  }

  Future<void> _fetchGroupData() async {
    if (!mounted) return;
    if (_students.isEmpty) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isRefreshing = true);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      print('🔵 [GroupDetails] groupId=${widget.groupId} levelId=${widget.levelId}');
      print('🔵 [GroupDetails] token=$token');

      final studentsUrl = 'https://nourelman.runasp.net/api/Group/GetGroupDetails?GroupId=${widget.groupId}&LevelId=${widget.levelId}';
      final groupsUrl = 'https://nourelman.runasp.net/api/Group/Getall?levelid=${widget.levelId}';
      print('🔵 [GroupDetails] requesting: $studentsUrl');
      print('🔵 [GroupDetails] requesting: $groupsUrl');

      final results = await Future.wait([
        http.get(
          Uri.parse(studentsUrl),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 15)),
        http.get(
          Uri.parse(groupsUrl),
        ).timeout(const Duration(seconds: 15)),
      ]);
      final studentsResponse = results[0];
      final groupResponse = results[1];

      print('🟢 [GroupDetails] studentsResponse status=${studentsResponse.statusCode}');
      print('🟢 [GroupDetails] studentsResponse body=${studentsResponse.body}');
      print('🟢 [GroupDetails] groupResponse status=${groupResponse.statusCode}');
      print('🟢 [GroupDetails] groupResponse body=${groupResponse.body}');

      if (studentsResponse.statusCode == 200 && mounted) {
        final Map<String, dynamic> studentsData = json.decode(studentsResponse.body);
        final List<dynamic> studentsList = studentsData['data'] ?? [];
        print('🟡 [GroupDetails] parsed studentsList.length=${studentsList.length}');

        Map<String, dynamic> groupInfo = {};
        if (groupResponse.statusCode == 200) {
          final groupsData = json.decode(groupResponse.body);
          final List<dynamic> allGroups = groupsData['data'] ?? [];
          print('🟡 [GroupDetails] allGroups.length=${allGroups.length}');
          final matchedGroups = allGroups.where((g) => g['id'] == widget.groupId).toList();
          print('🟡 [GroupDetails] matchedGroups.length=${matchedGroups.length} (looking for id == ${widget.groupId})');
          if (matchedGroups.isNotEmpty) {
            groupInfo = Map<String, dynamic>.from(matchedGroups.first);
          }
        } else {
          print('🔴 [GroupDetails] groupResponse FAILED with status ${groupResponse.statusCode} -> groupInfo stays empty');
        }

        if (mounted) {
          setState(() {
            _students = studentsList;
            _filteredStudents = _applyStudentSearch(studentsList, _studentSearchController.text);
            _currentGroupData = groupInfo.isNotEmpty ? groupInfo : {};
            if (groupInfo['name'] != null) displayGroupName = groupInfo['name'];
            final dynamic rawEmpId = groupInfo['empId'] ?? groupInfo['emp']?['id'];
            if (rawEmpId != null) {
              final int parsedId = int.tryParse(rawEmpId.toString()) ?? 0;
              if (parsedId > 0) _resolvedTeacherId = parsedId;
            }
            if (_resolvedTeacherId == 0 && widget.teacherId > 0) {
              _resolvedTeacherId = widget.teacherId;
            }
            if (groupInfo['emp']?['name'] != null) displayTeacherName = groupInfo['emp']['name'];
            _isLoading = false;
            _isRefreshing = false;
          });
          print('✅ [GroupDetails] setState done. _students=${_students.length} displayGroupName=$displayGroupName displayTeacherName=$displayTeacherName _resolvedTeacherId=$_resolvedTeacherId');
        }
      } else {

        print('🔴 [GroupDetails] studentsResponse FAILED with status ${studentsResponse.statusCode}');
        print('🔴 [GroupDetails] body: ${studentsResponse.body}');
        if (mounted) {
          setState(() { _isLoading = false; _isRefreshing = false; });
        }
      }
    } catch (e, st) {
      print('❌ [GroupDetails] EXCEPTION: $e');
      print('❌ [GroupDetails] STACK: $st');
      if (mounted) setState(() { _isLoading = false; _isRefreshing = false; });
    }
  }

  Future<void> _loadInitialDataForEdit() async {
    if (_editDataLoaded) return;
    try {
      final res = await Future.wait([
        http.get(Uri.parse('https://nourelman.runasp.net/api/Locations/Getall')).timeout(const Duration(seconds: 15)),
        http.get(Uri.parse('https://nourelman.runasp.net/api/Employee/GetWithType?type=1')).timeout(const Duration(seconds: 15)),
      ]);
      final locRes = res[0];
      final techRes = res[1];
      if (mounted) {
        final techBody2 = jsonDecode(techRes.body);
        final teachers = techBody2 is List ? techBody2 : (techBody2['data'] ?? []);
        final locations = jsonDecode(locRes.body)['data'] ?? [];
        _editDataLoaded = true;
        final List<dynamic> finalTeachers = List.from(teachers);
        final List<dynamic> finalLocations = List.from(locations);
        if (_resolvedTeacherId > 0) {
          final teacherExists = finalTeachers.any((t) => t['id'] == _resolvedTeacherId);
          if (!teacherExists && _currentGroupData['emp'] != null) {
            finalTeachers.add({
              'id': _resolvedTeacherId,
              'name': _currentGroupData['emp']['name'] ?? displayTeacherName ?? widget.teacherName ?? '',
            });
          }
        }
        final dynamic rawLocId2 = _currentGroupData['locId'] ?? _currentGroupData['loc']?['id'];
        if (rawLocId2 != null) {
          final int? locId2 = int.tryParse(rawLocId2.toString());
          if (locId2 != null && locId2 > 0) {
            final locExists = finalLocations.any((l) => l['id'] == locId2);
            if (!locExists && _currentGroupData['loc'] != null) {
              finalLocations.add({
                'id': locId2,
                'name': _currentGroupData['loc']['name'] ?? 'مكتب $locId2',
              });
            }
          }
        }
        setState(() {
          locationsList = finalLocations;
          teachersList = finalTeachers;
        });
      }
    } catch (e) {}
  }

  Future<void> _updateGroupApi(String name, BuildContext dialogContext) async {
    if (name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("من فضلك أدخل اسم المجموعة"), backgroundColor: Colors.orange),
      );
      return;
    }
    if (selectedTeacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("من فضلك اختر الشيخ"), backgroundColor: Colors.orange),
      );
      return;
    }
    if (selectedLocationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("من فضلك اختر المكتب"), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      String formattedTime = selectedTime != null
          ? "${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}"
          : "20:00";

      final Map<String, dynamic> requestBody = {
        "Id": widget.groupId,
        "Name": name.trim(),
        "LevelId": widget.levelId,
        "EmpId": selectedTeacherId,
        "LocId": selectedLocationId,
        "Active": true,
        "Status": true,
        "Days": selectedDays.isEmpty ? [1] : selectedDays,
        "Time": formattedTime,
        "GroupSessions": (selectedDays.isEmpty ? [1] : selectedDays).asMap().entries.map((entry) => {
          "Day": entry.value,
          "Hour": formattedTime,
          "Status": true,
          "Serial": entry.key + 1,
        }).toList(),
      };

      final response = await http.put(
        Uri.parse('https://nourelman.runasp.net/api/Group/Update'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (mounted) Navigator.pop(dialogContext);
        _showSnackBar("تم التحديث بنجاح ✅", Colors.green);
        _fetchGroupData();
      } else {
        _showSnackBar("فشل التحديث: ${response.statusCode}", Colors.orange);
      }
    } catch (e) {
      _showSnackBar("خطأ في الاتصال بالسيرفر", Colors.red);
    }
  }
  Future<void> _showEditGroupDialog() async {
    if (!_editDataLoaded) {
      _showSnackBar("جاري تحميل البيانات...", Colors.blueGrey);
      await _loadInitialDataForEdit();
    }
    if (!mounted) return;
    TextEditingController nameCont = TextEditingController(text: displayGroupName ?? widget.groupName);
    final dynamic rawEmpId = _currentGroupData['empId'] ?? _currentGroupData['emp']?['id'];
    final int? parsedTeacherId = rawEmpId != null
        ? int.tryParse(rawEmpId.toString())
        : (_resolvedTeacherId > 0 ? _resolvedTeacherId : null);
    final teacherIds = teachersList.map((t) => t['id'] as int?).toSet();
    selectedTeacherId = (parsedTeacherId != null && teacherIds.contains(parsedTeacherId))
        ? parsedTeacherId
        : null;
    final dynamic rawLocId = _currentGroupData['locId'] ?? _currentGroupData['loc']?['id'];
    final int? parsedLocId = rawLocId != null ? int.tryParse(rawLocId.toString()) : null;
    final locationIds = locationsList.map((l) => l['id'] as int?).toSet();
    selectedLocationId = (parsedLocId != null && locationIds.contains(parsedLocId))
        ? parsedLocId
        : null;

    final List sessions = _currentGroupData['groupSessions'] ?? _currentGroupData['sessions'] ?? [];
    selectedDays = sessions
        .map<int>((s) {
      final d = s['day'] ?? s['Day'];
      return int.tryParse(d.toString()) ?? 0;
    })
        .where((d) => d > 0)
        .toSet()
        .toList();
    String? rawTime = _currentGroupData['time'];
    if (sessions.isNotEmpty) {
      rawTime = sessions[0]['hour'] ?? sessions[0]['Hour'] ?? rawTime;
    }
    if (rawTime != null) {
      final parts = rawTime.toString().split(':');
      if (parts.length >= 2) {
        selectedTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 0,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDs) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Center(
              child: Text("تعديل المجموعة",
                  style: TextStyle(color: kPrimaryBlue, fontWeight: FontWeight.bold, fontFamily: 'Almarai')),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel("اسم المجموعة"),
                    TextField(controller: nameCont, decoration: _inputDecoration("الاسم")),
                    const SizedBox(height: 15),
                    _buildLabel("الشيخ"),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: selectedTeacherId,
                      decoration: _inputDecoration("اختر الشيخ"),
                      items: teachersList.map((t) => DropdownMenuItem<int>(
                        value: t['id'],
                        child: Text(t['fullName'] ?? t['name'] ?? "", style: const TextStyle(fontFamily: 'Almarai')),
                      )).toList(),
                      onChanged: (val) {
                        setDs(() => selectedTeacherId = val);
                        setState(() => selectedTeacherId = val);
                      },
                    ),
                    const SizedBox(height: 15),
                    _buildLabel("وقت الحصة"),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.access_time),
                      label: Text(
                        selectedTime == null ? "اختر الوقت" : selectedTime!.format(context),
                        style: const TextStyle(fontFamily: 'Almarai'),
                      ),
                      onPressed: () async {
                        TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setDs(() => selectedTime = picked);
                          setState(() => selectedTime = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 15),
                    _buildLabel("المكتب"),
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: selectedLocationId,
                      decoration: _inputDecoration("اختر المكتب"),
                      items: locationsList.map((l) => DropdownMenuItem<int>(
                        value: l['id'],
                        child: Text(l['name'] ?? "", style: const TextStyle(fontFamily: 'Almarai')),
                      )).toList(),
                      onChanged: (val) {
                        setDs(() => selectedLocationId = val);
                        setState(() => selectedLocationId = val);
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildLabel("الأيام"),
                    Wrap(
                      spacing: 5,
                      children: List.generate(7, (i) {
                        final days = ["السبت", "الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة"];
                        bool isSel = selectedDays.contains(i + 1);
                        return FilterChip(
                          label: Text(days[i],
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isSel ? Colors.white : Colors.black,
                                  fontFamily: 'Almarai')),
                          selected: isSel,
                          selectedColor: orangeButton,
                          onSelected: (v) => setDs(() =>
                          v ? selectedDays.add(i + 1) : selectedDays.remove(i + 1)),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("إلغاء", style: TextStyle(fontFamily: 'Almarai')),
              ),
              ElevatedButton(
                onPressed: () => _updateGroupApi(nameCont.text, context),
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryBlue),
                child: const Text("حفظ", style: TextStyle(color: Colors.white, fontFamily: 'Almarai')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<dynamic>> _fetchAvailableStudents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final url = Uri.parse('https://nourelman.runasp.net/api/Student/GetByStatus?status=true');
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      }).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        if (decodedData is List) return decodedData;
        if (decodedData is Map && decodedData['data'] != null) return decodedData['data'];
      }
    } catch (e) {
      debugPrint("Exception during fetch: $e");
    }
    return [];
  }

  Future<void> _addStudentToGroup(dynamic studentData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');
      final url = Uri.parse('https://nourelman.runasp.net/api/Student/Update');

      Map<String, dynamic> updatedPayload = Map<String, dynamic>.from(studentData);
      updatedPayload['groupId'] = widget.groupId;
      updatedPayload['levelId'] = widget.levelId;

      final response = await http.put(
        url,
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(updatedPayload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _showSnackBar("تم نقل الطالب للمجموعة بنجاح", Colors.green);
        _fetchGroupData();
      } else {
        _showSnackBar("حدث خطأ في تحديث بيانات الطالب", Colors.orange);
      }
    } catch (e) {
      _showSnackBar("حدث خطأ في الاتصال", Colors.red);
    }
  }

  void _showAddStudentDialog() {
    List<dynamic> allAvailable = [];
    List<dynamic> filteredAvailable = [];
    bool isFetching = true;
    final TextEditingController searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (allAvailable.isEmpty && isFetching) {
            _fetchAvailableStudents().then((data) {
              setDialogState(() {
                allAvailable = data;
                filteredAvailable = data;
                isFetching = false;
              });
            });
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Text("إضافة طالب للمجموعة",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Almarai')),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: "ابحث باسم الطالب...",
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          filteredAvailable = allAvailable
                              .where((s) => s['name'].toString().toLowerCase().contains(value.toLowerCase()))
                              .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 15),
                    Expanded(
                      child: isFetching
                          ? const ListSkeletonLoader(showHeader: false, columnFlex: [1], rowCount: 5, padding: EdgeInsets.zero)
                          : filteredAvailable.isEmpty
                          ? const Center(child: Text("لا توجد نتائج"))
                          : ListView.separated(
                        itemCount: filteredAvailable.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final student = filteredAvailable[index];
                          return ListTile(
                            title: Text(student['name'],
                                style: const TextStyle(fontSize: 13, fontFamily: 'Almarai')),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle, color: Colors.green),
                              onPressed: () {
                                Navigator.pop(context);
                                _addStudentToGroup(student);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _updatePassword(int studentId, String newPassword) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = Uri.parse('https://nourelman.runasp.net/api/Student/Update');
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer ${prefs.getString('token')}',
          'Content-Type': 'application/json',
        },
        body: json.encode({"id": studentId, "password": newPassword}),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        _showSnackBar("تم تحديث كلمة المرور", Colors.green);
      }
    } catch (e) {
      _showSnackBar("حدث خطأ", Colors.red);
    }
  }

  Future<void> _deleteStudent(int studentId, String studentName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final url = Uri.parse(
          'https://nourelman.runasp.net/api/Student/RemoveFromGroup?StId=$studentId');

      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 204) {
        _showSnackBar("تم حذف الطالب من المجموعة ✅", Colors.green);
        await _fetchGroupData();
      } else {
        String errorMsg = "فشل الحذف: ${response.statusCode}";
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          } else if (errorData['message'] != null) {
            errorMsg = errorData['message'].toString();
          }
        } catch (_) {}
        _showSnackBar(errorMsg, Colors.red);
      }
    } catch (e) {
      _showSnackBar("حدث خطأ في الاتصال: $e", Colors.red);
    }
  }
  static const List<Map<String, dynamic>> _noteOptions = [
    {'label': 'بدون تقييم', 'value': 0},
    {'label': 'ممتاز',    'value': 1},
    {'label': 'جيد جداً', 'value': 2},
    {'label': 'جيد',      'value': 3},
    {'label': 'مقبول',    'value': 4},
    {'label': 'ضعيف',     'value': 5},
  ];

  static int _safeNoteValue(int? raw) {
    if (raw == null) return 0;
    const validValues = {0, 1, 2, 3, 4, 5};
    return validValues.contains(raw) ? raw : 0;
  }

  Future<void> _openGroupAttendanceDialog() async {
    final List<int> studentIds = _students
        .map<int>((s) => (s['id'] as num).toInt())
        .toList();

    if (studentIds.isEmpty) {
      _showSnackBar("لا يوجد طلاب في المجموعة", Colors.orange);
      return;
    }

    final idsQuery = studentIds.map((id) => 'ids=$id').join('&');
    final url = Uri.parse(
      'https://nourelman.runasp.net/api/Group/GetGroupAttendace?GroupId=${widget.groupId}&$idsQuery',
    );

    Map<int, Map<String, dynamic>> existing = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final res = await http.get(url, headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final List data = body['data'] ?? [];
        for (var item in data) {
          final id = (item['studentId'] as num?)?.toInt() ?? 0;
          if (id != 0) existing[id] = item;
        }
      }
    } catch (_) {}

    final List<_StudentAttendanceState> states = _students.map((s) {
      final id = (s['id'] as num).toInt();
      final prev = existing[id];
      return _StudentAttendanceState(
        studentId:   id,
        studentName: s['name']?.toString() ?? '',
        isPresent:   prev?['isPresent'] as bool? ?? false,
        oldNote:     _safeNoteValue((prev?['oldAttendanceNote'] as num?)?.toInt()),
        newNote:     _safeNoteValue((prev?['newAttendanceNote'] as num?)?.toInt()),
        comment:     prev?['note']?.toString() ?? '',
      );
    }).toList();

    if (!mounted) return;
    _showGroupAttendanceDialog(states);
  }
  void _showGroupAttendanceDialog(List<_StudentAttendanceState> states) {
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                maxWidth: MediaQuery.of(ctx).size.width,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "غياب الطلاب",
                          style: TextStyle(
                            fontFamily: 'Almarai',
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: kPrimaryBlue,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    color: Colors.grey.shade50,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Column(
                      children: [
                        Row(
                          children: const [
                            SizedBox(width: 90, child: Text("الاسم", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Almarai', fontSize: 11, color: Colors.grey))),
                            SizedBox(width: 6),
                            SizedBox(width: 60, child: Text("الحضور", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Almarai', fontSize: 11, color: Colors.grey))),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                "التقييم",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Almarai', fontSize: 11, color: Colors.red),
                              ),
                            ),
                            SizedBox(width: 6),
                            SizedBox(width: 70, child: Text("التعليق*", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Almarai', fontSize: 11, color: Colors.red))),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: const [
                            SizedBox(width: 90),
                            SizedBox(width: 6),
                            SizedBox(width: 60),
                            SizedBox(width: 6),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(child: Text("القديم", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Almarai', fontSize: 10, color: Colors.grey))),
                                  SizedBox(width: 4),
                                  Expanded(child: Text("الجديد*", textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Almarai', fontSize: 10, color: Colors.red))),
                                ],
                              ),
                            ),
                            SizedBox(width: 6),
                            SizedBox(width: 70),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: states.map((st) {
                          return _buildAttendanceRow(st, setDs);
                        }).toList(),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("إلغاء", style: TextStyle(fontFamily: 'Almarai')),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16A34A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          ),
                          onPressed: isSubmitting
                              ? null
                              : () async {
                            setDs(() => isSubmitting = true);
                            await _submitGroupAttendance(states);
                            if (mounted) Navigator.pop(ctx);
                          },
                          child: isSubmitting
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: PulseLoader(color: Colors.white, strokeWidth: 2),
                          )
                              : const Text("تأكيد",
                              style: TextStyle(
                                  fontFamily: 'Almarai',
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
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

  Widget _buildAttendanceRow(_StudentAttendanceState st, StateSetter setDs) {
    final noteDropdownItems = _noteOptions
        .map((n) => DropdownMenuItem<int>(
      value: n['value'] as int,
      child: Text(n['label'] as String,
          style: const TextStyle(fontFamily: 'Almarai', fontSize: 11)),
    ))
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          SizedBox(
            width: 90,
            child: Text(
              st.studentName,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Almarai', fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 60,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  st.isPresent ? "حضور" : "غياب",
                  style: TextStyle(
                    fontFamily: 'Almarai',
                    fontSize: 10,
                    color: st.isPresent ? const Color(0xFF16A34A) : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Checkbox(
                  value: st.isPresent,
                  activeColor: const Color(0xFF16A34A),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  onChanged: (v) => setDs(() => st.isPresent = v ?? false),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildNoteDropdown(
                    value: st.oldNote,
                    items: noteDropdownItems,
                    onChanged: (v) => setDs(() => st.oldNote = v ?? 1),
                    borderColor: Colors.grey.shade300,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildNoteDropdown(
                    value: st.newNote,
                    items: noteDropdownItems,
                    onChanged: (v) => setDs(() => st.newNote = v ?? 1),
                    borderColor: Colors.red.shade200,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 70,
            height: 36,
            child: TextField(
              controller: st.commentController,
              style: const TextStyle(fontFamily: 'Almarai', fontSize: 11),
              decoration: InputDecoration(
                hintText: "تعليق",
                hintStyle: const TextStyle(
                    fontFamily: 'Almarai', fontSize: 10, color: Colors.grey),
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteDropdown({
    required int value,
    required List<DropdownMenuItem<int>> items,
    required ValueChanged<int?> onChanged,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: value,
          isDense: true,
          style: const TextStyle(
              fontFamily: 'Almarai', fontSize: 11, color: Colors.black87),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Future<void> _submitGroupAttendance(List<_StudentAttendanceState> states) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final String nowIso = DateTime.now().toIso8601String();
      final List<Map<String, dynamic>> payload = states
          .map((st) => {
        "id": 0,
        "studentId": st.studentId,
        "groupId": widget.groupId,
        "isPresent": st.isPresent,
        "points": st.isPresent ? st.newNote : -1,
        "note": st.commentController.text,
        "newAttendanceNote": st.newNote,
        "oldAttendanceNote": st.oldNote,
        "createDate": nowIso,
        "createBy": "Employee",
        "createFrom": "Mobile",
      })
          .toList();

      if (kDebugMode) {
        debugPrint('🔵 [Attendance] submitting payload: ${jsonEncode(payload)}');
      }

      final response = await http.post(
        Uri.parse('https://nourelman.runasp.net/api/StudentAttendance/Submit'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      debugPrint('🟢 [Attendance] status=${response.statusCode}');
      debugPrint('🟢 [Attendance] body=${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnackBar("تم تسجيل الغياب بنجاح ✅", Colors.green);
      } else {
        _showSnackBar("فشل تسجيل الغياب: ${response.statusCode}", Colors.red);
      }
    } catch (e, st) {
      debugPrint('❌ [Attendance] EXCEPTION: $e');
      debugPrint('❌ [Attendance] STACK: $st');
      _showSnackBar("حدث خطأ في الاتصال", Colors.red);
    }
  }

  void _showResetPasswordDialog(int studentId, String studentName) {
    final TextEditingController passController = TextEditingController();
    final TextEditingController confirmPassController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text("إعادة تعيين كلمة السر", style: TextStyle(fontFamily: 'Almarai')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPopupTextField("كلمة المرور الجديدة", passController),
                const SizedBox(height: 10),
                _buildPopupTextField("تأكيد كلمة المرور", confirmPassController),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
              ElevatedButton(
                onPressed: () async {
                  if (passController.text == confirmPassController.text) {
                    setDialogState(() => isSubmitting = true);
                    await _updatePassword(studentId, passController.text);
                    if (mounted) Navigator.pop(context);
                  }
                },
                child: isSubmitting
                    ? const PulseLoader()
                    : const Text("تغيير"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(int studentId, String studentName) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text("تأكيد الحذف"),
          content: Text("هل أنت متأكد من حذف $studentName من المجموعة؟"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(context);
                await _deleteStudent(studentId, studentName);
              },
              child: const Text("حذف"),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white.withOpacity(0.5),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade200)),
  );

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 5, top: 5),
    child: Text(text,
        style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Almarai')),
  );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text("طلاب مجموعة: ${displayGroupName ?? widget.groupName}",
              style: const TextStyle(fontFamily: 'Almarai', fontSize: 16)),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              heroTag: "edit_btn",
              onPressed: _showEditGroupDialog,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.edit, color: Colors.white),
            ),
            const SizedBox(height: 10),
            FloatingActionButton.small(
              heroTag: "attendance_btn",
              onPressed: _students.isEmpty ? null : _openGroupAttendanceDialog,
              backgroundColor: const Color(0xFF1976D2),
              child: const Icon(Icons.how_to_reg_outlined, color: Colors.white),
            ),
            const SizedBox(height: 10),
            FloatingActionButton(
              heroTag: "add_student_btn",
              onPressed: _showAddStudentDialog,
              backgroundColor: orangeButton,
              child: const Icon(Icons.person_add, color: Colors.white, size: 28),
            ),
          ],
        ),
        body: Stack(
          children: [
            _isLoading
            ? SkeletonShimmer(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 54,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                const Bone(height: 44, radius: 10),
                const SizedBox(height: 16),
                Expanded(
                  child: ListSkeletonLoader(
                    columnFlex: const [1, 4, 2, 2, 2],
                    rowCount: 8,
                    wrapInCard: true,
                    headerLabels: const ["#", "الاسم", "بيانات", "كلمة المرور", "حذف"],
                    headerAlign: const [TextAlign.center, TextAlign.right, TextAlign.center, TextAlign.center, TextAlign.center],
                  ),
                ),
              ],
            ),
          ),
        )
            : Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              InkWell(
                onTap: () {
                  if (_resolvedTeacherId == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            "لا يوجد معرّف للشيخ، تأكد من ربط الشيخ بهذه المجموعة",
                            style: TextStyle(fontFamily: 'Almarai')),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StaffDetailsScreen(
                        staffId: _resolvedTeacherId,
                        staffName: displayTeacherName ?? widget.teacherName,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: kPrimaryBlue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kPrimaryBlue.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person, color: kPrimaryBlue),
                      const SizedBox(width: 10),
                      Text("الشيخ: ",
                          style: TextStyle(
                              fontFamily: 'Almarai',
                              fontWeight: FontWeight.bold,
                              color: kPrimaryBlue)),
                      Expanded(
                        child: Text(
                          displayTeacherName ?? widget.teacherName,
                          style: TextStyle(fontFamily: 'Almarai', color: kTextDark),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios,
                          size: 14, color: kPrimaryBlue.withOpacity(0.5)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _studentSearchController,
                onChanged: _onStudentSearchChanged,
                style: const TextStyle(fontFamily: 'Almarai'),
                decoration: InputDecoration(
                  hintText: "ابحث باسم الطالب",
                  hintStyle: const TextStyle(fontFamily: 'Almarai'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _studentSearchController.text.isEmpty
                      ? null
                      : IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _studentSearchController.clear();
                      _onStudentSearchChanged('');
                    },
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10)
                    ],
                  ),
                  child: _filteredStudents.isEmpty
                      ? Center(
                      child: Text(
                          _students.isEmpty ? "المجموعة فارغة" : "لا توجد نتائج",
                          style: TextStyle(fontFamily: 'Almarai')))
                      : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SingleChildScrollView(
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1),
                          1: FlexColumnWidth(4),
                          2: FlexColumnWidth(2),
                          3: FlexColumnWidth(2),
                          4: FlexColumnWidth(2),
                        },
                        children: [
                          TableRow(
                            decoration:
                            BoxDecoration(color: Colors.grey[100]),
                            children: [
                              _buildHeaderCell("#"),
                              _buildHeaderCell("الاسم",
                                  align: TextAlign.right),
                              _buildHeaderCell("بيانات"),
                              _buildHeaderCell("كلمة المرور"),
                              _buildHeaderCell("حذف"),
                            ],
                          ),
                          ..._filteredStudents.asMap().entries.map((entry) {
                            int index = entry.key;
                            var student = entry.value;
                            return TableRow(
                              children: [
                                _buildDataCell("${index + 1}"),
                                _buildDataCell(
                                    student['name'] ?? "بدون اسم",
                                    align: TextAlign.right),
                                _buildActionIcon(
                                    Icons.person_outline, Colors.blue,
                                        () {
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                StudentDetailsScreen(
                                                  studentId: student['id'],
                                                  studentName:
                                                  student['name'] ?? "",
                                                ),
                                          ));
                                    }),
                                _buildActionIcon(
                                    Icons.lock_open, Colors.orange, () {
                                  _showResetPasswordDialog(student['id'],
                                      student['name'] ?? "");
                                }),
                                _buildActionIcon(
                                    Icons.delete_outline, Colors.red,
                                        () {
                                      _showDeleteDialog(student['id'],
                                          student['name'] ?? "");
                                    }),
                              ],
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
      ],
    ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, {TextAlign align = TextAlign.center}) =>
      Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text,
            textAlign: align,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                fontFamily: 'Almarai')),
      );

  Widget _buildDataCell(String text, {TextAlign align = TextAlign.center}) =>
      Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text,
            textAlign: align,
            style: const TextStyle(fontSize: 13, fontFamily: 'Almarai')),
      );

  Widget _buildActionIcon(IconData icon, Color color, VoidCallback onTap) =>
      IconButton(icon: Icon(icon, color: color, size: 20), onPressed: onTap);

  Widget _buildPopupTextField(
      String label, TextEditingController controller) =>
      TextField(
        controller: controller,
        obscureText: true,
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

  void _showSnackBar(String message, Color color) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontFamily: 'Almarai')),
          backgroundColor: color,
        ),
      );
}
class _StudentAttendanceState {
  final int    studentId;
  final String studentName;
  bool         isPresent;
  int          oldNote;
  int          newNote;
  final TextEditingController commentController;

  _StudentAttendanceState({
    required this.studentId,
    required this.studentName,
    required this.isPresent,
    required this.oldNote,
    required this.newNote,
    String comment = '',
  }) : commentController = TextEditingController(text: comment);
}
