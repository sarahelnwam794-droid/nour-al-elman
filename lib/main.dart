import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:async';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, PlatformDispatcher;
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'login_screen.dart';
import 'student/student_home_screen.dart';
import 'teacher/teacher_home_screen.dart';
import 'employee/employee_home_screen.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Uncaught platform error: $error\n$stack');
    return true;
  };

  await runZonedGuarded(() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e, stack) {
      debugPrint('Firebase initialization failed: $e\n$stack');
    }

    if (!kIsWeb) {
      try {
        await FlutterDownloader.initialize(debug: kDebugMode, ignoreSsl: true);
      } catch (e, stack) {
        debugPrint('FlutterDownloader initialization failed: $e\n$stack');
      }
    }

    await initializeDateFormatting('ar', null);
    runApp(const MyApp());
  }, (Object error, StackTrace stack) {
    debugPrint('Uncaught zone error: $error\n$stack');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'نور الإيمان',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar', 'AE')],
      locale: const Locale('ar', 'AE'),
      theme: ThemeData(
        primarySwatch: Colors.orange,
        fontFamily: 'Almarai',
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final session = await AuthService.getValidSession();

      if (!mounted) return;

      if (session != null) {
        await AuthService.markSessionActive();
        final int userType = AuthService.resolveUserType(session);
        final Widget nextScreen;

        if (userType == 1 || userType == 4) {
          nextScreen = TeacherHomeScreen(loginData: session);
        } else if (userType == 2 || userType == 3) {
          nextScreen = EmployeeHomeScreen(loginData: session);
        } else {
          nextScreen = StudentHomeScreen(loginData: session);
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => nextScreen,
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        }
      } else if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const LoginScreen(),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('Splash Error: $e\n$stack');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Image.asset(
              'assets/full_logo.png',
              width: MediaQuery.of(context).size.width * 0.45,
              errorBuilder: (_, __, ___) =>
              const Icon(Icons.school, size: 100, color: Colors.orange),
            ),
          ),
        ),
      ),
    );
  }
}
