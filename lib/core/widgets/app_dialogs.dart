// lib/widgets/app_dialogs.dart
import 'package:flutter/material.dart';

class AppDialogs {


  // داخل class AppDialogs في ملف lib/widgets/app_dialogs.dart

  static void showConfirmDialog(
      BuildContext context, {
        required String title,
        required String content,
        required VoidCallback onConfirm,
      }) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                onConfirm(); // تنفيذ الأمر
              },
              child: const Text('نعم، نفذ'),
            ),
          ],
        ),
      ),
    );
  }


  /// حوار شرح استخدام البرنامج
  static Future<void> showInfoDialog(
      BuildContext context, {
        VoidCallback? onRestoreHidden,
      }) async {
    await showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFFE7EEF8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'طريقة استخدام البرنامج',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
            textAlign: TextAlign.right,
          ),
          content: const SingleChildScrollView(
            child: Text(
              '''
• من قسم "الصفوف":
  - اضغط على كرت الصف لفتح كشف المتابعة.
  - من داخل الصف يمكنك تسجيل الغياب والمشاغبة وإدخال الدرجات من صفحة الطالب.
  - استخدم زر الحفظ في أعلى صفحة الصف لحفظ البيانات.

• من قسم "القرعة":
  - اضغط على كرت القرعة لفتح صفحة القرعة.
  - زر "اختيار اسم بالقرعة" لبدء السحب.
  - يمكن تعديل قائمة أسماء القرعة من زر إدارة الأسماء.

• الصفوف والقرعات الأساسية:
  - اضغط على أيقونة ✏️ الصغيرة أعلى الكرت:
    ▫️ لتعديل الاسم أو الوصف أو الأيقونة.
    ▫️ أو إخفاء الكرت من الصفحة الرئيسية.

• النسخ الاحتياطي:
  - زر "تصدير" لحفظ نسخة احتياطية من بياناتك.
  - زر "استيراد" لاسترجاع البيانات (يفضَّل إعادة تشغيل التطبيق بعد الاستيراد).
''',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Color(0xFF37474F),
              ),
              textAlign: TextAlign.right,
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (onRestoreHidden != null) {
                  onRestoreHidden();
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2E7D32),
              ),
              child: const Text('إرجاع الصفوف والقرعات المخفية'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF37474F),
              ),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  /// حوار معلومات عن البرنامج
  static Future<void> showAboutDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFFE7EEF8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'About',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
            textAlign: TextAlign.right,
          ),
          content: const Text(
            'اسم البرنامج: نظام متابعة الطلاب\n'
                'الإصدار: 1.0.0',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF37474F),
            ),
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFF37474F),
              ),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  /// حوار "الملف": تصدير/استيراد/إعدادات
  static Future<void> showFileDialog(
      BuildContext context, {
        required VoidCallback onExportTap,
        required VoidCallback onImportTap,
        required VoidCallback onSettingsTap,
      }) async {
    await showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('الملف'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onExportTap();
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('تصدير بيانات البرنامج'),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onImportTap();
                },
                icon: const Icon(Icons.download),
                label: const Text('استيراد بيانات من ملف'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onSettingsTap();
                },
                icon: const Icon(Icons.settings),
                label: const Text('إعدادات شخصية وإعدادات الصف'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  /// حوار بيانات التواصل
  static Future<void> showContactDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: const AlertDialog(
          title: Text('بيانات التواصل'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('جوال: 0500000000'),
              SizedBox(height: 4),
              Text('البريد: example@mail.com'),
              SizedBox(height: 4),
              Text('واتساب: 0500000000'),
              SizedBox(height: 4),
              Text('تليجرام: @example'),
            ],
          ),
        ),
      ),
    );
  }
}
