import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'group_details_screen.dart';
import 'package:project1/widgets/pulse_loader.dart';
import 'package:project1/widgets/list_skeleton_loader.dart';
import 'package:project1/widgets/smart_loading_switcher.dart';

class LevelOneScreen extends StatefulWidget {
  final int levelId;
  final String levelName;

  const LevelOneScreen({super.key, required this.levelId, required this.levelName});

  @override
  State<LevelOneScreen> createState() => _LevelOneScreenState();
}

class _LevelOneScreenState extends State<LevelOneScreen> {
  final Color darkBlue = const Color(0xFF2E3542);
  final Color orangeButton = const Color(0xFFC66422);
  final Color kPrimaryBlue = const Color(0xFF07427C);

  late String displayedLevelName;
  List<dynamic> teachersList = [];
  List<dynamic> locationsList = [];

  List<dynamic> groupsList = [];
  bool isLoadingGroups = true;
  bool isRefreshingGroups = false;
  bool _isSubmittingGroup = false;

  int? selectedTeacherId;
  int? selectedLocationId;
  List<int> selectedDays = [];
  TimeOfDay? selectedTime;

  @override
  void initState() {
    super.initState();
    displayedLevelName = widget.levelName;
    _loadData();
    _fetchGroups();
  }

  Future<void> _fetchGroups() async {
    if (groupsList.isEmpty) {
      if (mounted) setState(() => isLoadingGroups = true);
    } else {
      if (mounted) setState(() => isRefreshingGroups = true);
    }
    try {
      final response = await http.get(
        Uri.parse('https://nourelman.runasp.net/api/Group/Getall?levelid=${widget.levelId}&_t=${DateTime.now().millisecondsSinceEpoch}'),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 && mounted) {
        final decoded = jsonDecode(response.body);
        final List<dynamic> allGroups = decoded is Map && decoded['data'] is List
            ? List<dynamic>.from(decoded['data'])
            : <dynamic>[];
        debugPrint('📦 [Groups] levelId=${widget.levelId} serverCount=${allGroups.length}');
        // بعض المجموعات بتترجع من السيرفر وهي محذوفة (Active = false)
        // لأن الـ Getall مش بيستبعدها من عنده، فبنفلترها هنا عشان ما تفضلش
        // ظاهرة في الشاشة رغم إنها اتحذفت فعليًا في الداتابيز.
        final List<dynamic> activeGroups = allGroups.where((g) {
          final active = g['active'] ?? g['Active'];
          final status = g['status'] ?? g['Status'];
          // The API uses soft-delete for groups. Treat explicit false as deleted.
          return active != false && status != false;
        }).toList();
        debugPrint('📦 [Groups] levelId=${widget.levelId} activeCount=${activeGroups.length}');
        setState(() {
          groupsList = activeGroups;
          isLoadingGroups = false;
          isRefreshingGroups = false;
        });
      } else {
        if (mounted) setState(() { isLoadingGroups = false; isRefreshingGroups = false; });
      }
    } catch (e) {
      debugPrint("Fetch Groups Error: $e");
      if (mounted) setState(() { isLoadingGroups = false; isRefreshingGroups = false; });
    }
  }

  Future<void> _loadData() async {
    try {
      final locRes = await http.get(Uri.parse('https://nourelman.runasp.net/api/Locations/Getall')).timeout(const Duration(seconds: 15));
      final techRes = await http.get(Uri.parse('https://nourelman.runasp.net/api/Employee/GetWithType?type=1')).timeout(const Duration(seconds: 15));
      if (mounted) {
        setState(() {
          locationsList = jsonDecode(locRes.body)['data'] ?? [];
          final techBody = jsonDecode(techRes.body);
          teachersList = techBody is List ? techBody : (techBody['data'] ?? []);
        });
      }
    } catch (e) {
      debugPrint("Data Load Error: $e");
    }
  }

  String _getDayName(dynamic day) {
    int dayInt = int.tryParse(day.toString()) ?? 0;
    const days = {1: "السبت", 2: "الأحد", 3: "الاثنين", 4: "الثلاثاء", 5: "الأربعاء", 6: "الخميس", 7: "الجمعة"};
    return days[dayInt] ?? "";
  }

  Future<void> _addGroupApi(String name, BuildContext dialogContext) async {
    if (_isSubmittingGroup) {
      debugPrint('⚠️ [Groups] Add ignored: request already in progress');
      return;
    }

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
    if (selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("من فضلك اختر يوم واحد على الأقل"), backgroundColor: Colors.orange),
      );
      return;
    }

    if (mounted) setState(() => _isSubmittingGroup = true);

    final formattedTime = selectedTime != null
        ? "${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}"
        : "00:00";

    final payload = <String, dynamic>{
      "name": name.trim(),
      "levelId": widget.levelId,
      "empId": selectedTeacherId,
      "LocId": selectedLocationId,
      "Active": true,
      "Status": true,
      "days": List<int>.from(selectedDays),
      "time": formattedTime,
      "GroupSessions": selectedDays.map((dayId) => <String, dynamic>{
        "Day": dayId,
        "Hour": formattedTime,
        "Status": true,
        "Serial": 1,
      }).toList(),
    };

    debugPrint('➕ [Groups] ADD START');
    debugPrint('➕ [Groups] levelId=${widget.levelId}, teacherId=$selectedTeacherId, locationId=$selectedLocationId');
    debugPrint('➕ [Groups] payload=${jsonEncode(payload)}');

    try {
      final response = await http.post(
        Uri.parse('https://nourelman.runasp.net/api/Group/Save'),
        headers: const {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      debugPrint('➕ [Groups] ADD RESPONSE status=${response.statusCode} body=${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted && Navigator.of(dialogContext).canPop()) {
          Navigator.pop(dialogContext);
        }

        selectedDays = [];
        selectedTime = null;
        selectedTeacherId = null;
        selectedLocationId = null;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("تم إضافة المجموعة بنجاح ✅"), backgroundColor: Colors.green),
          );
        }

        // مهم: نعيد قراءة البيانات من السيرفر بدل الاعتماد على الحالة المحلية.
        await _fetchGroups();
        debugPrint('✅ [Groups] ADD FINISHED + list synchronized from server');
      } else {
        debugPrint('❌ [Groups] ADD FAILED status=${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("فشل الإضافة: ${response.statusCode}"), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e, stack) {
      debugPrint('❌ [Groups] ADD EXCEPTION: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("حدث خطأ أثناء إضافة المجموعة"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingGroup = false);
    }
  }

  Future<void> _updateLevelApi(String newName) async {
    final response = await http.put(
      Uri.parse('https://nourelman.runasp.net/api/Level/Update'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"id": widget.levelId, "name": newName}),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      setState(() => displayedLevelName = newName);
    }
  }

  Future<void> _deleteGroupApi(int id, String name) async {
    try {
      final response = await http.put(
        Uri.parse('https://nourelman.runasp.net/api/Group/Delete?id=$id'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      debugPrint("🗑️ [Groups] DELETE id=$id status=${response.statusCode} body=${response.body}");

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (mounted) {
          setState(() {
            groupsList.removeWhere((g) => g['id'].toString() == id.toString());
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("تم حذف المجموعة بنجاح ✅"), backgroundColor: Colors.green),
          );
        }
        debugPrint('✅ [Groups] DELETE finished; refreshing from server');
        // ✅ استنى شوية عشان السيرفر يخلص الحذف
        await Future.delayed(const Duration(milliseconds: 800));
        await _fetchGroups();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("فشل الحذف: ${response.statusCode}"), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint("Delete Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("حدث خطأ في الاتصال"), backgroundColor: Colors.red),
        );
      }
    }
  }
  void _showAddGroupDialog() {
    selectedTeacherId = null;
    selectedLocationId = null;
    selectedDays = [];
    selectedTime = null;
    String groupName = '';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDs) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Center(
              child: Text("إضافة مجموعة",
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
                    TextField(
                      decoration: _inputDecoration("الاسم"),
                      onChanged: (value) => groupName = value,
                    ),
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
                        selectedTime == null ? "اختر الوقت" : selectedTime!.format(dialogCtx),
                        style: const TextStyle(fontFamily: 'Almarai'),
                      ),
                      onPressed: () async {
                        TimeOfDay? picked = await showTimePicker(
                          context: dialogCtx,
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
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text("إلغاء", style: TextStyle(fontFamily: 'Almarai')),
              ),
              ElevatedButton(
                onPressed: _isSubmittingGroup ? null : () => _addGroupApi(groupName, dialogCtx),
                style: ElevatedButton.styleFrom(backgroundColor: kPrimaryBlue),
                child: _isSubmittingGroup
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("إضافة", style: TextStyle(color: Colors.white, fontFamily: 'Almarai')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditLevelDialog() {
    String levelName = displayedLevelName;
    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text("تعديل اسم المستوى", style: TextStyle(fontFamily: 'Almarai')),
          content: TextFormField(
            initialValue: levelName,
            decoration: _inputDecoration("اسم المستوى الجديد"),
            onChanged: (value) => levelName = value,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text("إلغاء")),
            ElevatedButton(
              onPressed: () {
                _updateLevelApi(levelName);
                Navigator.pop(dialogCtx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text("حفظ", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(int groupId, String name) {
    showDialog(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text("تأكيد الحذف", style: TextStyle(fontFamily: 'Almarai')),
          content: Text("هل أنت متأكد من حذف $name؟", style: const TextStyle(fontFamily: 'Almarai')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(
              onPressed: () { _deleteGroupApi(groupId, name); Navigator.pop(context); },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("حذف", style: TextStyle(color: Colors.white)),
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
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Almarai')),
  );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text(displayedLevelName,
              style: TextStyle(color: darkBlue, fontWeight: FontWeight.bold, fontFamily: 'Almarai')),
          iconTheme: IconThemeData(color: darkBlue),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton.small(
              heroTag: "edit",
              onPressed: _showEditLevelDialog,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.edit, color: Colors.white),
            ),
            const SizedBox(height: 10),
            FloatingActionButton(
              heroTag: "add",
              onPressed: _showAddGroupDialog,
              backgroundColor: orangeButton,
              child: const Icon(Icons.add, color: Colors.white, size: 30),
            ),
          ],
        ),
        body: SmartLoadingSwitcher(
          isLoading: isLoadingGroups,
          skeleton: const ListSkeletonLoader(
            columnFlex: [2, 2, 2, 1, 2, 1],
            rowCount: 6,
            wrapInCard: true,
            headerLabels: ["المجموعة", "الشيخ", "المكان", "الطلاب", "المواعيد", "إجراءات"],
          ),
          child: groupsList.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("لا توجد مجموعات", style: TextStyle(fontFamily: 'Almarai')),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _fetchGroups,
                  icon: const Icon(Icons.refresh),
                  label: const Text("تحديث", style: TextStyle(fontFamily: 'Almarai')),
                ),
              ],
            ),
          )
              : Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        dataRowMinHeight: 60,
                        dataRowMaxHeight: 120,
                        headingRowColor: WidgetStateProperty.all(kPrimaryBlue.withOpacity(0.05)),
                        columns: const [
                          DataColumn(label: Text('المجموعة', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Almarai'))),
                          DataColumn(label: Text('الشيخ', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Almarai'))),
                          DataColumn(label: Text('المكان', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Almarai'))),
                          DataColumn(label: Text('الطلاب', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Almarai'))),
                          DataColumn(label: Text('المواعيد', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Almarai'))),
                          DataColumn(label: Text('إجراءات', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Almarai'))),
                        ],
                        rows: groupsList.map((group) {
                          List sessions = group['sessions'] ?? group['groupSessions'] ?? [];
                          return DataRow(cells: [
                            DataCell(InkWell(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => GroupDetailsScreen(
                                    groupId: group['id'],
                                    levelId: widget.levelId,
                                    groupName: group['name'],
                                    teacherName: group['emp']?['name'] ?? "غير محدد",
                                    teacherId: group['empId'] ?? group['emp']?['id'] ?? 0,
                                  ),
                                ),
                              ).then((_) => _fetchGroups()),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  group['name'] ?? "---",
                                  style: TextStyle(
                                    color: kPrimaryBlue,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                    fontFamily: 'Almarai',
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            )),
                            DataCell(Text(group['emp']?['name'] ?? "---", style: const TextStyle(fontFamily: 'Almarai'))),
                            DataCell(Text(group['loc']?['name'] ?? "---", style: const TextStyle(fontFamily: 'Almarai'))),
                            DataCell(Center(child: Text(group['studentCount']?.toString() ?? "0", style: const TextStyle(fontFamily: 'Almarai')))),
                            DataCell(Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: sessions.map<Widget>((s) => Text(
                                  "${_getDayName(s['day'])} (${s['hour']})",
                                  style: const TextStyle(fontSize: 11, fontFamily: 'Almarai'),
                                )).toList(),
                              ),
                            )),
                            DataCell(IconButton(
                              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                              onPressed: () => _showDeleteDialog(group['id'], group['name']),
                            )),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
              if (isRefreshingGroups)
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
      ),
    );
  }
}
