import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'session_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project1/widgets/pulse_loader.dart';
import 'package:project1/widgets/card_list_skeleton.dart';

class _AppColors {
  static const Color primaryOrange = Color(0xFFC66422);
  static const Color darkBlue = Color(0xFF2E3542);
  static const Color kActiveBlue = Color(0xFF1976D2);
  static const Color kHeaderBg = Color(0xFFF8FAFC);
  static const Color kBorder = Color(0xFFE2E8F0);
  static const Color kTextDark = Color(0xFF334155);
  static const Color kTextHeader = Color(0xFF64748B);
  static const Color kWhite = Color(0xFFFFFFFF);
}

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = "";
  List<SessionRecord> _sessions = [];

  static const Color kActiveBlue = _AppColors.kActiveBlue;

  @override
  void initState() {
    super.initState();
    _fetchSessions();
  }

  Future<void> _fetchSessions() async {

    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = "";
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString('user_id') ?? "";

      if (id.isEmpty || id == "0" || id == "null") {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = "لم يتم العثور على بيانات المستخدم";
          });
        }
        return;
      }

      debugPrint("📡 Fetching sessions for user_id: $id");

      final response = await http.get(
        Uri.parse('https://nourelman.runasp.net/api/Employee/GetSessionRecord?emp_id=$id'),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('انتهى وقت الاتصال بالخادم');
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        try {
          final List<SessionRecord> parsedData = sessionRecordFromJson(response.body);

          setState(() {
            _sessions = parsedData;
            _isLoading = false;
            _hasError = false;
          });

          debugPrint("✅ Loaded ${_sessions.length} sessions");
        } catch (e) {
          debugPrint("❌ Parse error: $e");
          setState(() {
            _isLoading = false;
            _hasError = true;
            _errorMessage = "خطأ في قراءة البيانات";
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = "خطأ من السيرفر: ${response.statusCode}";
        });
      }
    } catch (e) {
      debugPrint("❌ Fetch error: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = "تعذر الاتصال بالسيرفر";
        });
      }
    }
  }

  Future<void> _retryFetch() async {
    await _fetchSessions();
  }

  @override
  Widget build(BuildContext context) {

    if (_isLoading) {
      return const CardListSkeleton(itemCount: 5, leadingCircle: false);
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontFamily: 'Almarai',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _retryFetch,
              icon: const Icon(Icons.refresh),
              label: const Text(
                'إعادة المحاولة',
                style: TextStyle(fontFamily: 'Almarai'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _AppColors.primaryOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "مواعيد المجموعات",
            style: TextStyle(
              color: kActiveBlue,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Almarai',
            ),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: _AppColors.kWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _AppColors.kBorder),
              ),
              child: _sessions.isEmpty
                  ? _buildEmptyState()
                  : ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        _AppColors.kHeaderBg,
                      ),
                      columns: const [
                        DataColumn(
                          label: Text(
                            'اليوم',
                            style: _headerStyle,
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'الساعة',
                            style: _headerStyle,
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'المجموعة',
                            style: _headerStyle,
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'المستوى',
                            style: _headerStyle,
                          ),
                        ),
                      ],
                      rows: _buildRows(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 60,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'لا توجد مواعيد حالياً',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontFamily: 'Almarai',
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<DataRow> _buildRows() {
    List<DataRow> rows = [];

    for (var record in _sessions) {
      if (record.groupSessions != null && record.groupSessions!.isNotEmpty) {
        for (var session in record.groupSessions!) {
          rows.add(
            DataRow(
              cells: [
                DataCell(
                  Center(
                    child: Text(
                      session.dayName,
                      style: _cellStyle,
                    ),
                  ),
                ),
                DataCell(
                  Center(
                    child: Text(
                      session.hour ?? "",
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
              ],
            ),
          );
        }
      }
    }

    return rows;
  }

  static const TextStyle _headerStyle = TextStyle(
    color: _AppColors.kTextHeader,
    fontWeight: FontWeight.bold,
    fontFamily: 'Almarai',
    fontSize: 13,
  );

  static const TextStyle _cellStyle = TextStyle(
    color: _AppColors.kTextDark,
    fontFamily: 'Almarai',
    fontSize: 12,
  );
}
