// lib/lock_screen.dart

import 'dart:ui'; // For ImageFilter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For SystemChrome
import 'security/secure_services.dart';
import '../../core/utils/number_utils.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen>
    with SingleTickerProviderStateMixin {
  // 🔑 الرقم السري الماستر
  static const String _masterPin = '20202030';

  final TextEditingController _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isNewPin = false;
  bool _loading = true;
  bool _isError = false; // لتمييز حالة الخطأ وتغيير اللون
  String _message = '';

  @override
  void initState() {
    super.initState();
    _checkPinStatus();
  }

  Future<void> _checkPinStatus() async {
    final hasPin = await SecureServices.hasPin();
    if (mounted) {
      setState(() {
        _isNewPin = !hasPin;
        _message = _isNewPin ? 'يرجى تعيين رمز دخول جديد' : 'أدخل رمز الدخول';
        _loading = false;
      });
    }
  }

  String _normalizeDigits(String input) {
    const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
    const easternIndic = '۰۱۲۳۴۵۶۷۸۹';
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final ch = input[i];
      final i1 = arabicIndic.indexOf(ch);
      final i2 = easternIndic.indexOf(ch);
      if (i1 != -1) {
        buffer.write(i1.toString());
      } else if (i2 != -1)
        buffer.write(i2.toString());
      else
        buffer.write(ch);
    }
    return buffer.toString();
  }

  Future<void> _handlePin({bool manualTrigger = false}) async {
    final raw = _pinController.text.trim();
    final pin = _normalizeDigits(raw);

    // 1. حالة إنشاء رمز جديد
    if (_isNewPin) {
      if (manualTrigger) {
        if (pin.length < 4) {
          _triggerError('الرمز قصير جداً (4 أرقام على الأقل)');
          return;
        }
        await SecureServices.setPin(pin);
        widget.onUnlocked();
      }
      return;
    }

    // 2. حالة الدخول
    if (pin == _masterPin) {
      await SecureServices.setPin('');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ تم تصفير الرمز (ماستر)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      widget.onUnlocked();
      return;
    }

    bool ok = await SecureServices.validatePin(pin);
    if (!ok && raw != pin) ok = await SecureServices.validatePin(raw);

    if (ok) {
      widget.onUnlocked();
    } else {
      if (manualTrigger) {
        _triggerError('الرمز غير صحيح');
        _pinController.clear();
      }
    }
  }

  void _triggerError(String msg) {
    setState(() {
      _isError = true;
      _message = msg;
    });
    // اهتزاز بسيط أو إعادة اللون بعد فترة
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _isError = false;
          _message = _isNewPin ? 'يرجى تعيين رمز دخول جديد' : 'أدخل رمز الدخول';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // إخفاء شريط الحالة ليكون التصميم كاملاً (Immersive)
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF4A00E0),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return GestureDetector(
      onTap: () => FocusScope.of(
        context,
      ).requestFocus(_focusNode), // أي ضغطة تعيد الكيبورد
      child: Scaffold(
        body: Stack(
          children: [
            // 1. الخلفية المتدرجة العصرية
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF30c9cd), // بنفسجي
                    Color(
                      0xFF330d69,
                    ), // أزرق غامق //Color(0xFF8E2DE2), // بنفسجي
                    //Color(0xFF4A00E0), // أزرق غامق
                  ],
                ),
              ),
            ),

            // 2. دوائر خلفية للزينة (Blur Blobs)
            Positioned(
              top: -50,
              left: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              right: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // 3. المحتوى الرئيسي (Glassmorphism Card)
            Center(
              child: SingleChildScrollView(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 15,
                      sigmaY: 15,
                    ), // تأثير الزجاج
                    child: Container(
                      width: 340,
                      padding: const EdgeInsets.symmetric(
                        vertical: 40,
                        horizontal: 30,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15), // شفافية
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // الأيقونة
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isNewPin
                                  ? Icons.lock_reset
                                  : Icons.lock_outline_rounded,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // العنوان
                          Text(
                            _isNewPin ? 'إنشاء رمز جديد' : 'مرحباً بك',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // الرسالة / الخطأ
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _message,
                              key: ValueKey<String>(_message),
                              style: TextStyle(
                                fontSize: 14,
                                color: _isError
                                    ? const Color(0xFFFF8A80)
                                    : Colors.white70,
                                fontWeight: _isError
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // ================= منطقة الإدخال والدوائر =================
                          SizedBox(
                            height: 60,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // طبقة الدوائر المرئية
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(4, (index) {
                                    // إذا النص أطول من 4، نعامل الدوائر كأنها ممتلئة
                                    // لكن بما أن الرمز متغير الطول، سنظهر 4 دوائر كحد أدنى جمالي
                                    // ونملؤها بناء على طول النص
                                    final codeLength =
                                        _pinController.text.length;
                                    final isFilled = index < codeLength;

                                    // في حالة كتابة أكثر من 4 أرقام، الدوائر تبقى ممتلئة
                                    // هذا تصميم جمالي، الكود الفعلي يخزن كل الأرقام

                                    return AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: isFilled
                                            ? (_isError
                                                  ? const Color(0xFFFF8A80)
                                                  : Colors.white)
                                            : Colors.white.withOpacity(0.3),
                                        shape: BoxShape.circle,
                                        boxShadow: isFilled
                                            ? [
                                                BoxShadow(
                                                  color: Colors.white
                                                      .withOpacity(0.4),
                                                  blurRadius: 8,
                                                  spreadRadius: 1,
                                                ),
                                              ]
                                            : [],
                                      ),
                                    );
                                  }),
                                ),

                                // حقل الإدخال المخفي تماماً
                                TextField(
                                  controller: _pinController,
                                  focusNode: _focusNode,
                                  keyboardType: TextInputType.number,
                                  maxLength: 10, // للسماح بالماستر
                                  autofocus: true,
                                  cursorColor: Colors.transparent,
                                  style: const TextStyle(
                                    color: Colors.transparent,
                                    fontSize: 1,
                                  ),
                                  decoration: const InputDecoration(
                                    counterText: '',
                                    border: InputBorder.none,
                                    fillColor: Colors.transparent,
                                    filled: true,
                                  ),
                                  onChanged: (value) {
                                    setState(() {
                                      _isError = false;
                                      if (!_isError)
                                        _message = _isNewPin
                                            ? 'يرجى تعيين رمز دخول جديد'
                                            : 'أدخل رمز الدخول';
                                    });
                                    if (!_isNewPin) {
                                      _handlePin(manualTrigger: false);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),

                          // ==========================================================
                          const SizedBox(height: 30),

                          // الأزرار
                          if (_isNewPin)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () =>
                                    _handlePin(manualTrigger: true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF4A00E0),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  elevation: 5,
                                ),
                                child: const Text(
                                  'حفظ الرمز',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                          // زر شفاف للتأكيد اليدوي عند الحاجة
                          if (!_isNewPin)
                            TextButton(
                              onPressed: () => _handlePin(manualTrigger: true),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white70,
                              ),
                              child: const Text(
                                'تأكيد',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
