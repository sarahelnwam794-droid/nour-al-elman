import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project1/widgets/list_skeleton_loader.dart';
import 'package:project1/widgets/expandable_note_panel.dart';
import 'package:project1/widgets/error_state_widget.dart';
import 'package:project1/widgets/fade_slide_in.dart';

class StudentTestsTab extends StatefulWidget {
  final int studentId;
  const StudentTestsTab({super.key, required this.studentId});

  @override
  State<StudentTestsTab> createState() => _StudentTestsTabState();
}

class _StudentTestsTabState extends State<StudentTestsTab> {
  List<dynamic> tests = [];
  bool isLoading = true;
  bool hasError = false;
  int? expandedIndex;

  @override
  void initState() {
    super.initState();
    _fetchTests();
  }

  Future<void> _fetchTests() async {
    if (mounted) setState(() { isLoading = true; hasError = false; });
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('https://nourelman.runasp.net/api/Student/GetAllExamBsedOnStId?StId=${widget.studentId}'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        setState(() {
          tests = responseData['data'] ?? [];
          isLoading = false;
        });
      } else {
        setState(() { isLoading = false; hasError = true; });
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
        columnFlex: [2, 2, 2],
        rowCount: 6,
        headerLabels: ["اسم الاختبار", "وصف الاختبار", "تعليق المعلم"],
      );
    }

    if (hasError) {
      return ErrorStateWidget(key: const ValueKey('error'), onRetry: _fetchTests);
    }

    if (tests.isEmpty) {
      return const Center(
        key: ValueKey('empty'),
        child: Text(
          "لا يوجد بيانات بعد!",
          style: TextStyle(
            fontFamily: 'Almarai',
            color: Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      );
    }

    return Directionality(
      key: const ValueKey('content'),
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: const [
                Expanded(flex: 2, child: Text("اسم الاختبار", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Almarai', color: Color(0xFF07427C)))),
                Expanded(flex: 2, child: Text("وصف الاختبار", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Almarai', color: Color(0xFF07427C)))),
                Expanded(flex: 2, child: Text("تعليق المعلم", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Almarai', color: Color(0xFF07427C)))),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: tests.length,
              itemBuilder: (context, index) {
                final test = tests[index];
                final examInfo = test['exam'] ?? {};
                bool isExpanded = expandedIndex == index;

                return FadeSlideIn(
                  index: index,
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              _buildCell(examInfo['name'] ?? "---", 2),
                              _buildCell(examInfo['description'] ?? "---", 2),
                              Expanded(
                                flex: 2,
                                child: Center(
                                  child: ExpandToggleIcon(
                                    isExpanded: isExpanded,
                                    collapsedColor: const Color(0xFF2E7D32),
                                    expandedColor: Colors.red,
                                    onTap: () => setState(() => expandedIndex = isExpanded ? null : index),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          child: isExpanded
                              ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.05),
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                            ),
                            child: ExpandableNoteContent(
                              points: "${test['grade'] ?? '0'}",
                              note: "${test['note'] ?? 'لا توجد ملاحظات إضافية'}",
                              accentColor: Colors.blue.shade800,
                              noteColor: Colors.black87,
                            ),
                          )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, fontFamily: 'Almarai', color: Colors.black87),
      ),
    );
  }

}
