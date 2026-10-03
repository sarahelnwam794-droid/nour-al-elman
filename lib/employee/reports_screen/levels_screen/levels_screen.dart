import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'level_one_screen.dart';
import 'package:project1/widgets/pulse_loader.dart';
import 'package:project1/widgets/card_list_skeleton.dart';

class LevelsScreen extends StatefulWidget {
  const LevelsScreen({super.key});

  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> {
  List<dynamic> _levels = [];
  bool _isLoading = true;

  static const Color kActiveBlue = Color(0xFF1976D2);
  static const Color darkBlue = Color(0xFF2E3542);
  static const Color orangeButton = Color(0xFFC66422);
  static const Color kPrimaryBlue = Color(0xFF07427C);

  @override
  void initState() {
    super.initState();
    _fetchLevels();
  }

  Future<void> _fetchLevels() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('https://nourelman.runasp.net/api/Level/Getall?_t=${DateTime.now().millisecondsSinceEpoch}'),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            final rawLevels = decodedData['data'] is List ? List<dynamic>.from(decodedData['data']) : <dynamic>[];
            _levels = rawLevels.where((level) {
              final active = level is Map ? (level['active'] ?? level['Active']) : true;
              final status = level is Map ? (level['status'] ?? level['Status']) : true;
              return active != false && status != false;
            }).toList();
            debugPrint('📚 [Levels] Server=${rawLevels.length} | Active=${_levels.length}');
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addLevelApi(String name) async {
    if (name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("من فضلك أدخل اسم المستوى"), backgroundColor: Colors.orange),
      );
      return;
    }
    try {
      final response = await http.post(
        Uri.parse('https://nourelman.runasp.net/api/Level/Save'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"name": name.trim(), "active": true}),
      ).timeout(const Duration(seconds: 15));
      debugPrint("Add Level Response (${response.statusCode}): ${response.body}");
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("تم إضافة المستوى بنجاح ✅"), backgroundColor: Colors.green),
          );
          _fetchLevels();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("فشل الإضافة: ${response.statusCode}"), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint("Add Level Error: $e");
    }
  }

  Future<void> _deleteLevelApi(int id, String name) async {
    debugPrint('🗑️ [Levels] DELETE requested: id=$id name=$name');
    try {
      final response = await http.put(
        Uri.parse('https://nourelman.runasp.net/api/Level/Delete?id=$id'),
        headers: const {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      debugPrint('🗑️ [Levels] DELETE response: status=${response.statusCode} body=${response.body}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (!mounted) return;
        setState(() {
          _levels.removeWhere((level) => level['id'].toString() == id.toString());
        });
        debugPrint('✅ [Levels] Removed level locally: id=$id');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف المستوى بنجاح ✅'), backgroundColor: Colors.green),
        );
        // ✅ استنى شوية قبل refresh عشان السيرفر يخلص الحذف
        await Future.delayed(const Duration(milliseconds: 800));
        await _fetchLevels();
      } else {
        debugPrint('❌ [Levels] Delete failed: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل حذف المستوى: ${response.statusCode}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e, stack) {
      debugPrint('❌ [Levels] Delete exception: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء حذف المستوى'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDeleteLevelDialog(int id, String name) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد حذف المستوى', style: TextStyle(fontFamily: 'Almarai')),
          content: Text(
            'هل أنت متأكد من حذف المستوى "$name"؟\n\nسيختفي المستوى ومجموعاته المرتبطة به من قائمة المجموعات الخاصة بالشيخ بعد التحديث.',
            style: const TextStyle(fontFamily: 'Almarai'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Almarai')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _deleteLevelApi(id, name);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('حذف', style: TextStyle(color: Colors.white, fontFamily: 'Almarai')),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddLevelDialog() {
    String levelName = '';
    showDialog(
      context: context,
      builder: (dialogCtx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("إضافة مستوى جديد",
              style: TextStyle(color: kPrimaryBlue, fontWeight: FontWeight.bold, fontFamily: 'Almarai')),
          content: TextField(
            autofocus: true,
            onChanged: (value) => levelName = value,
            decoration: InputDecoration(
              hintText: "اسم المستوى",
              hintStyle: const TextStyle(fontFamily: 'Almarai'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text("إلغاء", style: TextStyle(fontFamily: 'Almarai')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _addLevelApi(levelName);
              },
              style: ElevatedButton.styleFrom(backgroundColor: orangeButton),
              child: const Text("إضافة", style: TextStyle(color: Colors.white, fontFamily: 'Almarai')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      floatingActionButton: FloatingActionButton(
        heroTag: "fab_levels_main_unique",
        onPressed: _showAddLevelDialog,
        backgroundColor: orangeButton,
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "إدارة المستويات",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Almarai',
                  color: darkBlue),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _isLoading
                  ? const CardListSkeleton(itemCount: 5, leadingCircle: false)
                  : _levels.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("لا توجد مستويات مضافة بعد",
                        style: TextStyle(fontFamily: 'Almarai')),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _fetchLevels,
                      icon: const Icon(Icons.refresh),
                      label: const Text("تحديث", style: TextStyle(fontFamily: 'Almarai')),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                itemCount: _levels.length,
                itemBuilder: (context, index) {
                  return _buildLevelCard(
                    context,
                    _levels[index]["name"] ?? "مستوى غير مسمى",
                    kActiveBlue,
                    darkBlue,
                    _levels[index]["id"],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelCard(BuildContext context, String title, Color primary, Color textCol, int id) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LevelOneScreen(levelId: id, levelName: title),
            ),
          ).then((_) => _fetchLevels());
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: primary.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.layers_outlined, color: primary, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Almarai',
                          color: textCol))),
              IconButton(
                tooltip: 'حذف المستوى',
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _showDeleteLevelDialog(id, title),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}