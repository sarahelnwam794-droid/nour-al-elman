import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:local_auth/local_auth.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:project1/widgets/pulse_loader.dart';
import 'package:project1/widgets/skeleton_shimmer.dart';
import 'package:project1/widgets/smart_loading_switcher.dart';

final Color darkBlue = Color(0xFF2E3542);
const Color kActiveBlue = Color(0xFF1976D2);
const Color kLabelGrey = Color(0xFF718096);
const Color kBorderColor = Color(0xFFE2E8F0);

class MainAttendanceScreen extends StatefulWidget {
  @override
  _MainAttendanceScreenState createState() => _MainAttendanceScreenState();
}

class _MainAttendanceScreenState extends State<MainAttendanceScreen>
    with WidgetsBindingObserver {
  final LocalAuthentication auth = LocalAuthentication();

  String _currentLocationText = "جاري تحديد موقعك...";
  String _currentTime = "";
  String _checkType = "check-in";
  late Timer _timer;
  Position? _myPosition;
  Map<String, dynamic>? _selectedOffice;
  String? _selectedLocationName;
  bool _isInRange = false;
  bool _isLoadingStatus = false;
  bool _isLoading = false;
  bool _statusCallInFlight = false;
  List<dynamic> _apiOffices = [];

  @override
  void initState() {
    super.initState();
    _checkUserGuid();
    WidgetsBinding.instance.addObserver(this);
    _updateTime();
    _timer = Timer.periodic(
        const Duration(seconds: 1), (timer) => _updateTime());
    Future.microtask(() async {

      await Future.wait([
        _initLocation(),
        _fetchOffices(),
      ]);
    });
  }

  Future<void> _checkUserGuid() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_guid');
    debugPrint("👤 Stored user_guid: $userId");
  }

  @override
  void dispose() {
    _timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _selectedOffice != null &&
        !_isLoading) {

      debugPrint("🔄 App resumed: refreshing status...");
      _checkCurrentStatus();
    }
  }

  void _updateTime() {
    final now = DateTime.now();
    final formatted = intl.DateFormat('hh:mm a')
        .format(now)
        .replaceFirst('AM', 'ص')
        .replaceFirst('PM', 'م');
    if (mounted) setState(() => _currentTime = formatted);
  }

  Future<void> _fetchOffices() async {
    try {
      final response = await http
          .get(Uri.parse('https://nourelman.runasp.net/api/Locations/Getall'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> newOffices = data['data'] ?? data;
        setState(() {
          _apiOffices = newOffices;
          if (_selectedOffice != null) {
            final matched = newOffices.firstWhere(
                  (o) => o['id'].toString() == _selectedOffice!['id'].toString(),
              orElse: () => null,
            );
            _selectedOffice = matched;
          }
        });
      }
    } catch (e) {
      _showSnackBar("تعذر الاتصال بالسيرفر", Colors.red);
    }
  }

  Future<void> _checkCurrentStatus({bool silent = false}) async {
    if (_selectedOffice == null) {
      if (!silent && mounted) setState(() => _isLoadingStatus = false);
      return;
    }

    if (_statusCallInFlight) {
      debugPrint("⏭️ تجاهل نداء status مكرر - فيه واحد شغال بالفعل");
      return;
    }
    _statusCallInFlight = true;

    if (!silent && mounted) setState(() => _isLoadingStatus = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userGuid = prefs.getString('user_guid');
      final String token = prefs.getString('user_token') ?? '';

      if (userGuid == null || userGuid.isEmpty || userGuid == 'null') {
        debugPrint("❌ userGuid غير صالح: $userGuid");
        if (!silent && mounted) setState(() => _isLoadingStatus = false);
        return;
      }

      final int locId = int.parse(_selectedOffice!['id'].toString());

      // نفس الـ endpoint اللي الموقع بينادّيه بالظبط (get-employee-attendance-status)
      // عشان السيرفر يكون هو مصدر الحقيقة الوحيد للحالة، ومتحسبش يدويًا
      // في التطبيق بمنطق مختلف عن اللي في الموقع.
      final url =
          'https://nourelman.runasp.net/api/Locations/get-employee-attendance-status?userId=$userGuid&locId=$locId';

      debugPrint("🌐 Calling API: $url");

      final response = await http.get(
        Uri.parse(url),
        headers: {
          if (token.isNotEmpty && token != 'no_token')
            'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint("📦 Status Code: ${response.statusCode}");
      debugPrint("📦 RAW BODY: ${response.body}");

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        final Map<String, dynamic>? statusData =
        decoded is Map ? (decoded['data'] as Map<String, dynamic>?) : null;

        // checkType الراجع من السيرفر بيمثل آخر حركة اتسجلت فعليًا
        // (زي ما الموقع بيستخدمها بالظبط):
        // - لو آخر حركة "check-in" => المدرس داخل حاليًا => الخطوة الجاية "انصراف"
        // - أي حاجة تانية (أو مفيش بيانات) => الخطوة الجاية "حضور"
        final String? lastCheckType = statusData?['checkType']?.toString();
        final String newCheckType =
        (lastCheckType == 'check-in') ? 'check-out' : 'check-in';

        debugPrint("✅ آخر حركة من السيرفر = '$lastCheckType' | newCheckType = '$newCheckType'");

        if (mounted && newCheckType != _checkType) {
          debugPrint("🔄 _checkType: $_checkType => $newCheckType");
          setState(() => _checkType = newCheckType);
        }
      } else {
        debugPrint("❌ Non-200 response: ${response.statusCode}");
        debugPrint("❌ Response body: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Status check error: $e");
    } finally {
      _statusCallInFlight = false;
      if (!silent && mounted) setState(() => _isLoadingStatus = false);
    }
  }

  DateTime? _parseRecordDate(String? raw, {DateTime? fallbackDate}) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return DateTime.parse(raw);
    } catch (_) {}
    for (final fmt in [
      'M/d/yyyy h:mm:ss a',
      'M/d/yyyy h:mm a',
      'M/d/yyyy',
      'MM/dd/yyyy',
      'M/dd/yyyy'
    ]) {
      try {
        return intl.DateFormat(fmt).parse(raw);
      } catch (_) {}
    }
    if (fallbackDate != null) {

      for (final fmt in ['h:mm:ss a', 'HH:mm:ss', 'h:mm a', 'HH:mm']) {
        try {
          final t = intl.DateFormat(fmt).parse(raw);
          return DateTime(fallbackDate.year, fallbackDate.month,
              fallbackDate.day, t.hour, t.minute, t.second);
        } catch (_) {}
      }
    }
    return null;
  }
  Future<void> _initLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium);
      _myPosition = position;
      List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude, position.longitude);
      if (mounted && placemarks.isNotEmpty) {
        setState(() {
          _currentLocationText =
          "${placemarks[0].locality ?? ''} - ${placemarks[0].administrativeArea ?? ''}";
        });
      }
    } catch (e) {
      if (mounted) setState(() => _currentLocationText = "تعذر تحديد الموقع");
    }
  }

  bool _isPointInPolygon(
      double lat, double lng, List<Map<String, double>> polygon) {
    bool inside = false;
    int j = polygon.length - 1;

    for (int i = 0; i < polygon.length; i++) {
      final double xi = polygon[i]['lat']!;
      final double yi = polygon[i]['lng']!;
      final double xj = polygon[j]['lat']!;
      final double yj = polygon[j]['lng']!;

      final bool intersect = ((yi > lng) != (yj > lng)) &&
          (lat < (xj - xi) * (lng - yi) / (yj - yi) + xi);

      if (intersect) inside = !inside;
      j = i;
    }
    return inside;
  }

  List<Map<String, double>> _parsePolygon(Map<String, dynamic> office) {
    final String rawCoords =
    (office['coordinates'] ?? "").toString().replaceAll(',', ';');
    final List<String> parts =
    rawCoords.split(';').where((s) => s.trim().isNotEmpty).toList();

    final List<Map<String, double>> polygonPoints = [];
    for (int i = 0; i + 1 < parts.length; i += 2) {
      final double? lat = double.tryParse(parts[i].trim());
      final double? lng = double.tryParse(parts[i + 1].trim());
      if (lat != null && lng != null) {
        polygonPoints.add({'lat': lat, 'lng': lng});
      }
    }
    return polygonPoints;
  }

  void _checkDistance(Map<String, dynamic> office) {
    if (_myPosition == null) {
      _showSnackBar(
          "جاري تحديد موقعك، حاول مرة أخرى خلال ثوانٍ", Colors.orange);
      return;
    }

    final List<Map<String, double>> polygonPoints = _parsePolygon(office);

    bool result = false;

    if (polygonPoints.length >= 3) {

      result = _isPointInPolygon(
        _myPosition!.latitude,
        _myPosition!.longitude,
        polygonPoints,
      );
    } else if (polygonPoints.length == 1) {

      final double dist = Geolocator.distanceBetween(
        _myPosition!.latitude,
        _myPosition!.longitude,
        polygonPoints[0]['lat']!,
        polygonPoints[0]['lng']!,
      );
      result = dist <= 50;
    } else if (polygonPoints.length == 2) {

      final double dist1 = Geolocator.distanceBetween(_myPosition!.latitude,
          _myPosition!.longitude, polygonPoints[0]['lat']!, polygonPoints[0]['lng']!);
      final double dist2 = Geolocator.distanceBetween(_myPosition!.latitude,
          _myPosition!.longitude, polygonPoints[1]['lat']!, polygonPoints[1]['lng']!);
      result = (dist1 <= 50) || (dist2 <= 50);
    }

    setState(() {
      _selectedOffice = office;
      _selectedLocationName = office['name'];
      _isInRange = result;
    });

    if (!_isInRange) {
      _showSnackBar("أنت خارج النطاق لـ $_selectedLocationName", Colors.red);
    } else {
      _showSnackBar("أنت داخل نطاق $_selectedLocationName ✅", Colors.green);

      _checkCurrentStatus(silent: true);
    }
  }

  Future<void> _startBiometricAuth() async {
    if (!_isInRange) {
      _showSnackBar("لا يمكنك البصم لأنك خارج النطاق", Colors.red);
      return;
    }
    try {
      final bool canAuth =
          await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!canAuth) {
        _showSnackBar(
            "البصمة غير مدعومة أو غير مفعلة على هذا الجهاز. يرجى تفعيلها من إعدادات الهاتف.",
            Colors.red);
        return;
      }

      bool authenticated = false;
      try {
        authenticated = await auth.authenticate(
          localizedReason: 'تأكيد الحضور في $_selectedLocationName',
        );
      } on Exception catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('user_cancel') ||
            msg.contains('notavailable') ||
            msg.contains('canceled')) {
          return;
        }
        _showSnackBar(
            "يرجى التأكد من نظافة الحساس ووضع إصبعك بشكل صحيح، أو تأكد من تسجيل بصمتك في إعدادات الهاتف.",
            Colors.orange);
        return;
      }

      if (authenticated) await _sendAttendanceToServer();
    } catch (e) {
      debugPrint("خطأ غير متوقع في البصمة: $e");
    }
  }

  Future<void> _sendAttendanceToServer() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userGuid = prefs.getString('user_guid');
      final String token = prefs.getString('user_token') ?? '';

      if (_selectedOffice == null || _myPosition == null) {
        _showSnackBar("بيانات الموقع أو المكتب غير مكتملة", Colors.orange);
        return;
      }

      final int selectedLocId = int.parse(_selectedOffice!['id'].toString());

      final Map<String, dynamic> attendanceData = {
        "id": 0,
        "userId": userGuid,
        "checkType": _checkType,
        "locId": selectedLocId,
        "hisCoordinate": {
          "latitude": _myPosition!.latitude,
          "longitude": _myPosition!.longitude,
        },
      };

      debugPrint("📤 Sending attendance: ${json.encode(attendanceData)}");

      final response = await http
          .post(
        Uri.parse('https://nourelman.runasp.net/api/Locations/employee-attendance'),
        headers: {
          'Content-Type': 'application/json',
          if (token.isNotEmpty && token != 'no_token')
            'Authorization': 'Bearer $token',
        },
        body: json.encode(attendanceData),
      ).timeout(const Duration(seconds: 15));

      debugPrint("📦 Attendance response: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnackBar(
          _checkType == "check-in"
              ? "✅ تم تسجيل الحضور بنجاح"
              : "✅ تم تسجيل الانصراف بنجاح",
          Colors.green,
        );
        await _checkCurrentStatus();

      } else {
        _showSnackBar("فشل في تسجيل العملية (${response.statusCode})", Colors.red);
      }
    } catch (e) {
      debugPrint("❌ Send attendance error: $e");
      _showSnackBar("لا يوجد اتصال بالإنترنت", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontFamily: 'Almarai')),
      backgroundColor: color,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text("  "),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: SmartLoadingSwitcher(
          isLoading: _isLoadingStatus,
          skeleton: SkeletonShimmer(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  Container(
                    height: 84,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Bone(height: 46, radius: 10),
                  const SizedBox(height: 40),
                  const Bone(width: 180, height: 46),
                  const SizedBox(height: 40),
                  const Bone.circle(size: 110),
                ],
              ),
            ),
          ),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10)
                    ],
                    border: Border.all(color: kBorderColor),
                  ),
                  child: Column(
                    children: [
                      _buildMiniRow(
                          Icons.location_on, _currentLocationText),
                      const Divider(height: 25, color: kBorderColor),
                      _buildMiniRow(Icons.access_time_filled,
                          "ساعات العمل: 00:00 ص - 00:00 م"),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildModernDropdown(),
                const SizedBox(height: 40),
                Text(_currentTime,
                    style: TextStyle(
                        fontSize: 50,
                        fontWeight: FontWeight.bold,
                        color: darkBlue,
                        fontFamily: 'Almarai')),
                const SizedBox(height: 40),
                _buildFingerprintButton(),
                const SizedBox(height: 20),
                if (_isLoading)
                  const Padding(
                      padding: EdgeInsets.only(top: 15),
                      child: PulseLoader(
                          color: kActiveBlue)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: kActiveBlue, size: 22),
        const SizedBox(width: 12),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 14, color: darkBlue, fontFamily: 'Almarai'))),
      ],
    );
  }

  Widget _buildModernDropdown() {
    final Map<dynamic, bool> seen = {};
    final List<dynamic> uniqueOffices = [];
    for (var office in _apiOffices) {
      final key = office['id'];
      if (!seen.containsKey(key)) {
        seen[key] = true;
        uniqueOffices.add(office);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("اختيار المكتب / الموقع",
            style: TextStyle(
                fontSize: 13,
                color: kLabelGrey,
                fontWeight: FontWeight.bold,
                fontFamily: 'Almarai')),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _selectedOffice != null ? kActiveBlue : kBorderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<Map<String, dynamic>>(
              isExpanded: true,
              value: _selectedOffice,
              hint: const Text("اختر مكان تواجدك الحالي",
                  style: TextStyle(fontFamily: 'Almarai')),
              items: uniqueOffices.map((office) {
                return DropdownMenuItem<Map<String, dynamic>>(
                  value: office as Map<String, dynamic>,
                  child: Text(office['name'] ?? "",
                      style: const TextStyle(fontFamily: 'Almarai')),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) _checkDistance(val);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFingerprintButton() {
    bool canPress = _selectedOffice != null && _isInRange;
    String statusText = _checkType == "check-in"
        ? "اضغط لتسجيل الحضور"
        : "اضغط لتسجيل الانصراف";
    Color activeColor = (_checkType == "check-in") ? kActiveBlue : Colors.red;

    return Column(
      children: [
        GestureDetector(
          onTap: canPress
              ? _startBiometricAuth
              : () {
            if (_selectedOffice == null) {
              _showSnackBar("برجاء اختيار المكتب أولاً", Colors.orange);
            } else if (!_isInRange) {
              _showSnackBar(
                  "أنت خارج النطاق، لا يمكنك البصم", Colors.red);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(35),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                  color: canPress ? activeColor : Colors.grey.shade300,
                  width: 5),
              boxShadow: [
                if (canPress)
                  BoxShadow(
                      color: activeColor.withOpacity(0.3), blurRadius: 20)
              ],
            ),
            child: Icon(
              _checkType == "check-in"
                  ? Icons.fingerprint
                  : Icons.exit_to_app,
              size: 80,
              color: canPress ? activeColor : Colors.grey.shade300,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          statusText,
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: canPress ? activeColor : Colors.grey,
              fontFamily: 'Almarai'),
        ),
      ],
    );
  }
}
