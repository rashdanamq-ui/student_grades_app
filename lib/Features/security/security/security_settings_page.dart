// lib/security/security_settings_page.dart
import 'package:flutter/material.dart';
import 'secure_services.dart'; // تأكد أن الاستيراد صحيح

class SecuritySettingsPage extends StatefulWidget {
  const SecuritySettingsPage({super.key});

  @override
  State<SecuritySettingsPage> createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  final TextEditingController _oldPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();

  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    _checkPinStatus();
  }

  Future<void> _checkPinStatus() async {
    final has = await SecureServices.hasPin();
    setState(() {
      _hasPin = has;
    });
  }

  Future<void> _changePin() async {
    final oldPin = _oldPinController.text.trim();
    final newPin = _newPinController.text.trim();

    // 1. التحقق من الرمز القديم (فقط إذا كان هناك رمز محفوظ مسبقاً)
    if (_hasPin) {
      if (oldPin.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء إدخال الرمز القديم')),
        );
        return;
      }
      final isCorrect = await SecureServices.validatePin(oldPin);
      if (!isCorrect) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرمز القديم غير صحيح')),
        );
        return;
      }
    }

    // 2. التحقق من الرمز الجديد
    if (newPin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرمز الجديد يجب أن يكون 4 أرقام فأكثر')),
      );
      return;
    }

    // 3. الحفظ
    await SecureServices.setPin(newPin);

    // تحديث الحالة
    await _checkPinStatus();

    _oldPinController.clear();
    _newPinController.clear();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تغيير رمز الدخول بنجاح ✅')),
    );
  }

  @override
  void dispose() {
    _oldPinController.dispose();
    _newPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7EFFA),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7EFFA),
          elevation: 0,
          foregroundColor: Colors.black87,
          title: const Text('إعدادات الأمان'),
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'إدارة رمز الدخول',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // إظهار حقل "الرمز القديم" فقط إذا كان هناك رمز محفوظ
                      if (_hasPin) ...[
                        TextField(
                          controller: _oldPinController,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            labelText: 'الرمز الحالي',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(16)),
                            ),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // حقل الرمز الجديد
                      TextField(
                        controller: _newPinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          labelText: 'الرمز الجديد',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                          ),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _changePin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A4FBF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 16),
                          ),
                          child: Text(_hasPin ? 'تغيير الرمز' : 'تعيين رمز'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
