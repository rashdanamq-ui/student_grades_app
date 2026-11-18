import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static ValueNotifier<bool> useArabicNumbers = ValueNotifier(true);

  // ✅ 1. متغير جديد لنظام التحليل
  static ValueNotifier<bool> useModernAnalysis = ValueNotifier(true);

  static ValueNotifier<bool> showQuickGradingButtons = ValueNotifier(true);

  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    useArabicNumbers.value = prefs.getBool('use_arabic_numbers') ?? true;
    showQuickGradingButtons.value = prefs.getBool('show_quick_grading') ?? true;

    // ✅ 2. تحميل القيمة المحفوظة
    useModernAnalysis.value = prefs.getBool('use_modern_analysis') ?? true;
  }

  static Future<void> setArabicNumbers(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    useArabicNumbers.value = value;
    await prefs.setBool('use_arabic_numbers', value);
  }

  static Future<void> setQuickGradingButtons(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    showQuickGradingButtons.value = value;
    await prefs.setBool('show_quick_grading', value);
  }

  // ✅ 3. دالة لحفظ اختيار النظام (مودرن/كلاسيك)
  static Future<void> setModernAnalysis(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    useModernAnalysis.value = value;
    await prefs.setBool('use_modern_analysis', value);
  }
}
