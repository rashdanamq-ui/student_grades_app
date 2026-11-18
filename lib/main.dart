// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:student_grades_app/core/settings/app_settings.dart';
import 'Features/home/home_page.dart';
import 'Features/security/lock_screen.dart';
import 'Features/security/security/secure_services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ======================= الحل هنا =======================
  // بدلاً من إجباره على الوضع العمودي فقط، نسمح بجميع الاتجاهات
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft, // <-- السماح بالوضع الأفقي (يسار)
    DeviceOrientation.landscapeRight, // <-- السماح بالوضع الأفقي (يمين)
  ]);
  // =======================================================
  await AppSettings.loadSettings();

  final bool hasPin = await SecureServices.hasPin();

  runApp(MyApp(startWithLock: hasPin));
}

class MyApp extends StatelessWidget {
  final bool startWithLock;

  const MyApp({super.key, required this.startWithLock});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'راصد تابع',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Amiri',
        useMaterial3: false,
      ),
      home: Builder(
        builder: (context) {
          if (startWithLock) {
            return LockScreen(
              onUnlocked: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const HomePage()),
                );
              },
            );
          } else {
            return const HomePage();
          }
        },
      ),
    );
  }
}
