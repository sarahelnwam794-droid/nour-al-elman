import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:project1/widgets/list_skeleton_loader.dart';
import 'package:project1/widgets/expandable_note_panel.dart';
import 'package:project1/widgets/error_state_widget.dart';
import 'package:project1/widgets/fade_slide_in.dart';

const Color kPrimaryBlue = Color(0xFF07427C);
const Color kHeaderGrey = Color(0xFFF9FAFB);
const Color kSuccessGreen = Color(0xFF16A34A);
const Color kDangerRed = Color(0xFFDC2626);

class StudentAttendanceTab extends StatefulWidget {
  final int studentId;
  const StudentAttendanceTab({super.key, required this.studentId});

  @override
  State<StudentAttendanceTab> createState() => _StudentAttendanceTabState();
}

class _StudentAttendanceTabState extends State<StudentAttendanceTab> {
  List<dynamic> attendanceList = [];
  bool isLoading = true;
  bool hasError = false;
  int? expandedIndex;

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }
  String _mapNoteToText(dynamic noteValue) {
    if (noteValue == null) return "غير محدد";
    if (noteValue is String) {
      final trimmed = noteValue.trim();
      if (trimmed.isEmpty) return "غير محدد";

      final asInt = int.tryParse(trimmed);
      if (asInt != null) return _noteFromInt(asInt);
      return trimmed;
    }
    if (noteValue is int) return _noteFromInt(noteValue);
    return "غير محدد";
  }

  String _noteFromInt(int id) {
    switch (id) {
      case 1: return "ممتاز";
      case 2: return "جيد جداً";
      case 3: return "جيد";
      case 4: return "مقبول";
      case 5: return "ضعيف";
      default: return "غير محدد";
    }
  }

  Future<void> _fetchAttendance() async {
    if (mounted) setState(() { isLoading = true; hasError = false; });
    try {
      final String url = 'https://nourelman.runasp.net/api/Student/GetAttendaceByStudentId?id=${widget.studentId}';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (kDebugMode) {
          debugPrint("🔍 ATTENDANCE RESPONSE: ${response.body}");
        }

        final List<dynamic> list = List<dynamic>.from(responseData['data'] ?? []);

        list.sort((a, b) {
          final DateTime da =
              DateTime.tryParse(a['createDate']?.toString() ?? '') ?? DateTime(1970);
          final DateTime db =
              DateTime.tryParse(b['createDate']?.toString() ?? '') ?? DateTime(1970);
          return db.compareTo(da);
        });

        if (mounted) {
          setState(() {
            attendanceList = list;
            isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() { isLoading = false; hasError = true; });
      }
    } catch (e) {
      if (mounted) setState(() { isLoading = false; hasError = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const ListSkeletonLoader(
        key: ValueKey('loading'),
        columnFlex: [2, 1, 2, 2, 2],
        rowCount: 7,
        headerLabels: ["موعد الحلقة", "الحضور", "حفظ قديم", "حفظ جديد", "تعليق المعلم"],
      );
    }

    if (hasError) {
      return ErrorStateWidget(key: const ValueKey('error'), onRetry: _fetchAttendance);
    }

    return Directionality(
      key: const ValueKey('content'),
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: const BoxDecoration(
              color: kHeaderGrey,
              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text("موعد الحلقة", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(flex: 1, child: Text("الحضور", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(flex: 2, child: Text("حفظ قديم", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(flex: 2, child: Text("حفظ جديد", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                Expanded(flex: 2, child: Text("تعليق المعلم", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
              ],
            ),
          ),

          Expanded(
            child: attendanceList.isEmpty
                ? const Center(
                    child: Text("لا توجد بيانات حضور", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  )
                : ListView.separated(
              itemCount: attendanceList.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
              itemBuilder: (context, index) {
                final item = attendanceList[index];
                bool isExpanded = expandedIndex == index;

                return FadeSlideIn(
                  index: index,
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => setState(() => expandedIndex = isExpanded ? null : index),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8),
                          child: Row(
                            children: [
                              Expanded(flex: 2, child: Text(item['createDate']?.split('T')[0] ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10))),
                              Expanded(
                                flex: 1,
                                child: Text(
                                  item['isPresent'] == true ? "حضور" : "غياب",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: item['isPresent'] == true ? kSuccessGreen : kDangerRed, fontWeight: FontWeight.bold, fontSize: 10),
                                ),
                              ),
                              Expanded(flex: 2, child: Text(_mapNoteToText(item['oldAttendanceNote']), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10))),
                              Expanded(flex: 2, child: Text(_mapNoteToText(item['newAttendanceNote']), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10))),
                              Expanded(
                                flex: 2,
                                child: Center(
                                  child: ExpandToggleIcon(
                                    isExpanded: isExpanded,
                                    collapsedColor: kPrimaryBlue,
                                    expandedColor: kDangerRed,
                                    onTap: () => setState(() => expandedIndex = isExpanded ? null : index),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: Container(
                          width: double.infinity,
                          height: isExpanded ? null : 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          color: Colors.grey.shade50,
                          child: isExpanded
                              ? ExpandableNoteContent(
                            points: "${item['points'] ?? 0} نقاط",
                            note: "${item['note'] ?? 'لا يوجد تعليق'}",
                            accentColor: kSuccessGreen,
                          )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
