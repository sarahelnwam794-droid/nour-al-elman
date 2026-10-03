import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'session_model.dart';
import 'group_details_dashboard.dart';
import 'package:project1/widgets/card_list_skeleton.dart';
import 'package:project1/widgets/smart_loading_switcher.dart';

class GroupsScreen extends StatefulWidget {
  final int? empId;

  const GroupsScreen({super.key, this.empId});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> with WidgetsBindingObserver {
  // كل قد إيه نحدّث المجموعات تلقائياً وإحنا قدام الشاشة
  static const Duration _autoRefreshEvery = Duration(seconds: 10);

  // آخر مجموعات اتجابت (محفوظة في الذاكرة) عشان الشاشة تفتح فوراً من غير انتظار
  static final Map<int, List<GroupData>> _memoryGroups = <int, List<GroupData>>{};
  static final Map<int, String> _memorySignature = <int, String>{};

  List<GroupData> _groups = [];
  bool _isLoading = true;
  bool _isFetching = false;
  String _lastSignature = '';
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final cachedId = widget.empId;
    if (cachedId != null && _memoryGroups.containsKey(cachedId)) {
      _groups = List<GroupData>.from(_memoryGroups[cachedId]!);
      _lastSignature = _memorySignature[cachedId] ?? '';
      _isLoading = false;
    }
    _fetchGroups();
    _autoRefreshTimer = Timer.periodic(_autoRefreshEvery, (_) => _autoRefresh());
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // أول ما التطبيق يرجع من الخلفية نحدّث على طول
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _autoRefresh();
  }

  // تحديث صامت: من غير لودينج ومن غير وميض، وبيتوقف لو الشاشة مش ظاهرة
  // (تاب تاني في الـ IndexedStack أو شاشة تانية مفتوحة فوقها).
  void _autoRefresh() {
    if (!mounted || _isFetching) return;
    if (!TickerMode.of(context)) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    _fetchGroups();
  }

  bool _isActive(dynamic value) => value != false;

  int? _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  Future<Set<int>?> _fetchActiveLevelIds(int employeeId) async {
    try {
      final response = await http.get(
        Uri.parse('https://nourelman.runasp.net/api/Level/Getall?_t=${DateTime.now().millisecondsSinceEpoch}'),
      ).timeout(const Duration(seconds: 15));

      debugPrint('👨‍🏫 [TeacherGroups] Levels response=${response.statusCode}');

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      final rawLevels = decoded is Map && decoded['data'] is List
          ? List<dynamic>.from(decoded['data'])
          : <dynamic>[];

      final activeIds = <int>{};
      _levelNames.clear();
      for (final level in rawLevels) {
        if (level is! Map) continue;
        final active = level['active'] ?? level['Active'];
        final status = level['status'] ?? level['Status'];
        final id = _toInt(level['id'] ?? level['Id']);
        final levelEmpId = _toInt(level['empId'] ?? level['EmpId']);
        final levelName = (level['name'] ?? level['Name'])?.toString();
        if (id != null && levelName != null && levelName.isNotEmpty) {
          _levelNames[id] = levelName;
        }

        final belongsToTeacher = levelEmpId == null || levelEmpId == employeeId;

        if (id != null && _isActive(active) && _isActive(status) && belongsToTeacher) {
          activeIds.add(id);
        }
      }

      debugPrint('👨‍🏫 [TeacherGroups] Active levels=${activeIds.length} / server=${rawLevels.length} EmpId=$employeeId');
      return activeIds;
    } catch (e, stack) {
      debugPrint('⚠️ [TeacherGroups] Could not refresh active levels: $e\n$stack');
      return null;
    }
  }

  Future<int?> _resolveTeacherEmployeeId() async {
    if (widget.empId != null && widget.empId! > 0) {
      debugPrint('👨‍🏫 [TeacherGroups] Using Employee ID passed from TeacherHome: ${widget.empId}');
      return widget.empId;
    }

    final prefs = await SharedPreferences.getInstance();
    final storedUserId = prefs.getString('user_id') ?? '';
    final storedGuid = prefs.getString('user_guid') ?? '';
    final storedPhone = prefs.getString('user_phone') ?? '';

    debugPrint('🔑 [TeacherGroups] login user_id=$storedUserId | guid=$storedGuid | phone=$storedPhone');

    try {
      final response = await http.get(
        Uri.parse('https://nourelman.runasp.net/api/Employee/GetWithType?type=1&_t=${DateTime.now().millisecondsSinceEpoch}'),
      ).timeout(const Duration(seconds: 15));

      debugPrint('👨‍🏫 [TeacherGroups] Employee/GetWithType status=${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final raw = decoded is List
            ? decoded
            : (decoded is Map && decoded['data'] is List ? decoded['data'] : <dynamic>[]);

        int? phoneMatch;
        int? userIdMatch;
        int? guidMatch;

        for (final item in raw) {
          if (item is! Map) continue;
          final empId = _toInt(item['id'] ?? item['Id'] ?? item['empId'] ?? item['EmpId']);
          if (empId == null || empId <= 0) continue;

          final itemUserId = (item['userId'] ?? item['userID'] ?? item['user_id'] ?? '').toString();
          final itemGuid = (item['user_Id'] ?? item['userGuid'] ?? item['guid'] ?? '').toString();
          final itemPhone = (item['phone'] ?? item['phoneNumber'] ?? '').toString();

          if (storedUserId.isNotEmpty && itemUserId == storedUserId) userIdMatch = empId;
          if (storedGuid.isNotEmpty && itemGuid == storedGuid) guidMatch = empId;
          if (storedPhone.isNotEmpty && itemPhone == storedPhone) phoneMatch = empId;
          if (empId.toString() == storedUserId) userIdMatch = empId;
        }

        final resolved = userIdMatch ?? guidMatch ?? phoneMatch;
        if (resolved != null) {
          debugPrint('✅ [TeacherGroups] REAL Employee ID resolved from Employee/GetWithType = $resolved');
          return resolved;
        }

        debugPrint('⚠️ [TeacherGroups] No exact teacher match in GetWithType. count=${raw.length}');
      }
    } catch (e, stack) {
      debugPrint('⚠️ [TeacherGroups] GetWithType resolve failed: $e\n$stack');
    }

    if (storedUserId.isNotEmpty && storedUserId != '0' && storedUserId != 'null') {
      try {
        final response = await http.get(
          Uri.parse('https://nourelman.runasp.net/api/Employee/GetById?id=$storedUserId&_t=${DateTime.now().millisecondsSinceEpoch}'),
        ).timeout(const Duration(seconds: 15));
        debugPrint('👨‍🏫 [TeacherGroups] Employee/GetById status=${response.statusCode}');
        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final data = decoded is Map ? decoded['data'] : null;
          if (data is Map) {
            final id = _toInt(data['id'] ?? data['Id']);
            if (id != null && id > 0) {
              debugPrint('✅ [TeacherGroups] REAL Employee ID from GetById=$id');
              return id;
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ [TeacherGroups] GetById resolve failed: $e');
      }
    }

    final fallback = _toInt(storedUserId);
    debugPrint('⚠️ [TeacherGroups] Last fallback EmpId=$fallback');
    return fallback;
  }

  // المستويات اللي قدرنا نجيب مجموعاتها الحقيقية من السيرفر، ومعرفات المجموعات الحية فيها.
  // بنستخدمهم نمسح أي مجموعة جاية من GetAllEmployeeGroups ومش موجودة هنا (اتمسحت/اتعطلت).
  final Map<int, String> _levelNames = <int, String>{};
  final Set<int> _verifiedLevelIds = <int>{};
  final Set<int> _liveGroupIds = <int>{};

  Future<List<dynamic>> _fetchGroupsFromLevels(int employeeId, Set<int> activeLevelIds) async {
    _verifiedLevelIds.clear();
    _liveGroupIds.clear();
    if (activeLevelIds.isEmpty) {
      debugPrint('⚠️ [TeacherGroups] No active levels available for fallback group fetch');
      return <dynamic>[];
    }

    final allGroups = <dynamic>[];
    debugPrint('🔎 [TeacherGroups] FALLBACK: fetching groups from ${activeLevelIds.length} active levels for EmpId=$employeeId');

    // كل المستويات بتتجاب في نفس الوقت بدل واحد ورا التاني (ده كان سبب البطء)
    Future<void> fetchOne(int levelId) async {
      try {
        final response = await http.get(
          Uri.parse('https://nourelman.runasp.net/api/Group/Getall?levelid=$levelId&_t=${DateTime.now().millisecondsSinceEpoch}'),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode != 200) return;
        final decoded = jsonDecode(response.body);
        final groups = decoded is Map && decoded['data'] is List ? decoded['data'] as List : <dynamic>[];

        _verifiedLevelIds.add(levelId);
        for (final group in groups) {
          if (group is! Map) continue;
          final liveActive = group['active'] ?? group['Active'];
          final liveStatus = group['status'] ?? group['Status'];
          final liveId = _toInt(group['id'] ?? group['Id'] ?? group['groupId'] ?? group['groupID']);
          if (liveId != null && _isActive(liveActive) && _isActive(liveStatus)) {
            _liveGroupIds.add(liveId);
          }
          final rawEmp = group['empId'] ?? group['EmpId'] ?? group['emp']?['id'] ?? group['Emp']?['id'];
          final groupEmpId = _toInt(rawEmp);
          final active = group['active'] ?? group['Active'];
          final status = group['status'] ?? group['Status'];

          if (groupEmpId == employeeId && _isActive(active) && _isActive(status)) {
            final copy = Map<String, dynamic>.from(group);
            if (_toInt(copy['levelId'] ?? copy['LevelId'] ?? copy['levelID']) == null) {
              copy['levelId'] = levelId;
            }
            allGroups.add(copy);
          }
        }
      } catch (e) {
        debugPrint('⚠️ [TeacherGroups] Level $levelId fallback fetch failed: $e');
      }
    }

    await Future.wait(activeLevelIds.map(fetchOne));

    debugPrint('🔎 [TeacherGroups] FALLBACK result groups=${allGroups.length}');
    return allGroups;
  }

  String? _nameOf(dynamic v) {
    if (v == null) return null;
    if (v is Map) return (v['name'] ?? v['Name'])?.toString();
    final t = v.toString();
    return t.isEmpty || t == 'null' ? null : t;
  }

  // بيحوّل مجموعة جاية من Group/Getall لنفس الشكل اللي GroupData فاهمه،
  // وبيكمّل الناقص (مستوى/مكتب/مواعيد/عدد طلاب) من GetAllEmployeeGroups.
  Map<String, dynamic> _normalizeGroup(Map g, Map<int, Map> empById) {
    final gid = _toInt(g['id'] ?? g['Id'] ?? g['groupId'] ?? g['groupID']);
    final emp = gid != null ? empById[gid] : null;
    final levelId = _toInt(g['levelId'] ?? g['LevelId'] ?? g['levelID'] ?? emp?['levelId']);

    final levelName = _nameOf(emp?['levelname'] ?? emp?['levelName']) ??
        _nameOf(g['levelname'] ?? g['levelName']) ??
        _nameOf(g['level'] ?? g['Level']) ??
        (levelId != null ? _levelNames[levelId] : null) ??
        'المستوى';

    final loc = _nameOf(g['loc'] ?? g['Loc'] ?? g['location']) ??
        _nameOf(emp?['loc']) ??
        'غير محدد';

    dynamic sessions = g['groupSessions'] ?? g['GroupSessions'] ?? g['sessions'];
    if (sessions is! List || sessions.isEmpty) {
      sessions = emp?['groupSessions'] ?? emp?['GroupSessions'] ?? sessions;
    }

    return {
      'groupID': gid,
      'groupName': _nameOf(g['name'] ?? g['Name'] ?? g['groupName']) ??
          _nameOf(emp?['groupName']) ??
          'بدون اسم',
      'levelId': levelId,
      'levelname': levelName,
      'loc': loc,
      'groupSessions': sessions is List ? sessions : <dynamic>[],
      'empid': _toInt(g['empId'] ?? g['EmpId'] ?? g['empid'] ?? emp?['empid']),
      'studentCount': _toInt(emp?['studentCount'] ?? g['studentCount'] ?? g['StudentCount']) ?? 0,
      'active': g['active'] ?? g['Active'],
      'status': g['status'] ?? g['Status'],
    };
  }

  // الأيام في التطبيق كله بتبدأ من 1 = السبت
  static const Map<int, String> _dayNames = {
    1: 'السبت', 2: 'الأحد', 3: 'الإثنين', 4: 'الثلاثاء',
    5: 'الأربعاء', 6: 'الخميس', 7: 'الجمعة',
  };

  List<String> _sessionLines(GroupData g) {
    final out = <String>[];
    for (final s in g.groupSessions ?? <GroupSession>[]) {
      final day = _dayNames[s.day ?? -1];
      if (day == null) continue;
      var hour = s.hour ?? '';
      if (hour.length >= 5) hour = hour.substring(0, 5);
      out.add(hour.isEmpty ? day : '$day ($hour)');
    }
    return out;
  }

  Future<void> _fetchGroups() async {
    if (_isFetching) return;
    _isFetching = true;
    if (_groups.isEmpty) {
      if (mounted) setState(() => _isLoading = true);
    }

    try {
      final employeeId = await _resolveTeacherEmployeeId();
      debugPrint('👨‍🏫 [TeacherGroups] START sync for REAL Employee EmpId=$employeeId');

      if (employeeId == null || employeeId <= 0) {
        throw Exception('Could not resolve Employee ID');
      }

      List<dynamic> rawGroups = <dynamic>[];

      // طلب GetAllEmployeeGroups بيشتغل في الخلفية مع باقي الطلبات
      // بدل ما نستناه لحد ما يخلص الأول.
      final empGroupsFuture = http
          .get(Uri.parse(
          'https://nourelman.runasp.net/api/Group/GetAllEmployeeGroups?EmpId=$employeeId&_t=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 15))
          .then<http.Response?>((r) => r)
          .catchError((Object _) => null);

      final activeLevelIds = await _fetchActiveLevelIds(employeeId);
      final fallbackGroups = await _fetchGroupsFromLevels(employeeId, activeLevelIds ?? <int>{});
      final groupsResponse = await empGroupsFuture;

      if (groupsResponse == null && (activeLevelIds == null || _verifiedLevelIds.isEmpty)) {
        throw Exception('Could not load groups from server');
      }

      if (groupsResponse != null) {
        debugPrint('👨‍🏫 [TeacherGroups] GetAllEmployeeGroups status=${groupsResponse.statusCode}');
        if (groupsResponse.statusCode == 200) {
          final decodedGroups = jsonDecode(groupsResponse.body);
          rawGroups = decodedGroups is Map && decodedGroups['data'] is List
              ? List<dynamic>.from(decodedGroups['data'])
              : <dynamic>[];
        }
      }

      // لو قدرنا نتحقق من المستويات من السيرفر، نعتمد على Group/Getall بس
      // (هو اللي بيعكس الحذف فعلاً). GetAllEmployeeGroups بيرجّع مجموعات محذوفة
      // لأنه مبيرجّعش active/status، فمنستخدمهوش إلا لو فشل جلب المستويات.
      if (activeLevelIds != null && _verifiedLevelIds.isNotEmpty) {
        // GetAllEmployeeGroups بيدّينا اسم المستوى والمكتب والمواعيد وعدد الطلاب،
        // فبنربطهم بالمجموعات الحية (من Group/Getall) عن طريق رقم المجموعة.
        final empById = <int, Map>{};
        for (final g in rawGroups) {
          if (g is! Map) continue;
          final gid = _toInt(g['groupID'] ?? g['groupId'] ?? g['id'] ?? g['Id']);
          if (gid != null) empById[gid] = g;
        }
        rawGroups = fallbackGroups
            .whereType<Map>()
            .map((g) => _normalizeGroup(g, empById))
            .toList();
        debugPrint('🔗 [TeacherGroups] Using verified level groups only = ${rawGroups.length}');
      } else if (fallbackGroups.isNotEmpty) {
        final merged = <dynamic>[...rawGroups];
        final ids = rawGroups
            .whereType<Map>()
            .map((g) => _toInt(g['id'] ?? g['Id'] ?? g['groupId'] ?? g['groupID']))
            .whereType<int>()
            .toSet();
        for (final group in fallbackGroups) {
          if (group is! Map) continue;
          final id = _toInt(group['id'] ?? group['Id'] ?? group['groupId'] ?? group['groupID']);
          if (id == null || ids.add(id)) merged.add(group);
        }
        rawGroups = merged;
      }

      final visibleGroups = rawGroups.where((raw) {
        if (raw is! Map) return false;

        final active = raw['active'] ?? raw['Active'];
        final status = raw['status'] ?? raw['Status'];
        if (!_isActive(active) || !_isActive(status)) {
          debugPrint('🚫 [TeacherGroups] Hiding inactive/deleted group id=${raw['id'] ?? raw['groupID']}');
          return false;
        }

        final rawEmpId = raw['empId'] ?? raw['EmpId'] ?? raw['empid'] ?? raw['emp']?['id'] ?? raw['Emp']?['id'];
        final groupEmpId = _toInt(rawEmpId);
        if (groupEmpId != null && groupEmpId != employeeId) {
          debugPrint('🚫 [TeacherGroups] Hiding group=${raw['name'] ?? raw['groupName']} because empId=$groupEmpId != $employeeId');
          return false;
        }

        // GetAllEmployeeGroups مبترجعش active، فبنتأكد من Group/Getall إن المجموعة لسه موجودة
        final rawGroupId = _toInt(raw['id'] ?? raw['Id'] ?? raw['groupId'] ?? raw['groupID']);
        final rawLvl = _toInt(raw['levelId'] ?? raw['LevelId'] ?? raw['levelID'] ??
            raw['level']?['id'] ?? raw['Level']?['id']);
        if (rawGroupId != null &&
            rawLvl != null &&
            _verifiedLevelIds.contains(rawLvl) &&
            !_liveGroupIds.contains(rawGroupId)) {
          debugPrint('🚫 [TeacherGroups] Hiding group id=$rawGroupId because it was deleted/disabled on server');
          return false;
        }

        if (activeLevelIds != null) {
          final rawLevelId = raw['levelId'] ?? raw['LevelId'] ?? raw['levelID'] ??
              raw['level']?['id'] ?? raw['Level']?['id'];
          final groupLevelId = _toInt(rawLevelId);
          if (groupLevelId != null && !activeLevelIds.contains(groupLevelId)) {
            debugPrint('🚫 [TeacherGroups] Hiding group=${raw['name'] ?? raw['groupName']} because its level id=$groupLevelId was deleted');
            return false;
          }
        }

        return true;
      }).toList();

      debugPrint('📊 [TeacherGroups] FINAL serverGroups=${rawGroups.length} visibleGroups=${visibleGroups.length} EmpId=$employeeId');

      final parsedGroups = visibleGroups
          .whereType<Map>()
          .map((x) => GroupData.fromJson(Map<String, dynamic>.from(x)))
          .toList();

      // منعمل setState بس لو فيه تغيير فعلي، عشان الجدول مايرفرفش كل 20 ثانية
      final signature = parsedGroups
          .map((g) => '${g.groupId}|${g.levelId}|${g.groupName}|${g.levelName}|${g.loc}|${g.studentCount}|${_sessionLines(g).join(',')}')
          .join(';');
      _memoryGroups[employeeId] = parsedGroups;
      _memorySignature[employeeId] = signature;
      if (mounted) {
        if (signature != _lastSignature || _isLoading) {
          _lastSignature = signature;
          setState(() {
            _groups = parsedGroups;
            _isLoading = false;
          });
        }
      }

      debugPrint('✅ [TeacherGroups] UI synchronized successfully. count=${parsedGroups.length}');
    } catch (e, stack) {
      debugPrint('❌ [TeacherGroups] SYNC ERROR: $e\n$stack');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } finally {
      _isFetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SmartLoadingSwitcher(
            isLoading: _isLoading,
            skeleton: const SizedBox(height: 420, child: CardListSkeleton(itemCount: 5)),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _groups.isEmpty
                    ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text('لا توجد مجموعات حالياً'),
                )
                    : _buildTable(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'المجموعات الخاصة بالشيخ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Almarai'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('اسم المستوى', style: TextStyle(fontFamily: 'Almarai', fontWeight: FontWeight.bold))),
            DataColumn(label: Text('اسم المجموعة', style: TextStyle(fontFamily: 'Almarai', fontWeight: FontWeight.bold))),
            DataColumn(label: Text('المكتب', style: TextStyle(fontFamily: 'Almarai', fontWeight: FontWeight.bold))),
            DataColumn(label: Text('المواعيد', style: TextStyle(fontFamily: 'Almarai', fontWeight: FontWeight.bold))),
            DataColumn(label: Text('عدد الطلاب', style: TextStyle(fontFamily: 'Almarai', fontWeight: FontWeight.bold))),
          ],
          rows: _groups.map((group) {
            return DataRow(cells: [
              DataCell(
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupDetailsDashboard(
                          groupId: group.groupId ?? 0,
                          levelId: group.levelId ?? 0,
                          groupName: group.groupName ?? 'المجموعة',
                        ),
                      ),
                    ).then((_) => _fetchGroups());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Text(
                      (group.levelName == null || group.levelName == 'null') ? 'المستوى' : group.levelName!,
                      style: const TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                        fontFamily: 'Almarai',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              DataCell(Text(group.groupName ?? '---', style: const TextStyle(fontFamily: 'Almarai'))),
              DataCell(Text(group.loc ?? '---', style: const TextStyle(fontFamily: 'Almarai'))),
              DataCell(
                Builder(builder: (_) {
                  final lines = _sessionLines(group);
                  if (lines.isEmpty) {
                    return const Text('---', style: TextStyle(fontFamily: 'Almarai'));
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: lines
                        .map((l) => Text(l, style: const TextStyle(fontFamily: 'Almarai', fontSize: 12)))
                        .toList(),
                  );
                }),
              ),
              DataCell(Center(child: Text('${group.studentCount ?? 0}', style: const TextStyle(fontFamily: 'Almarai')))),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}