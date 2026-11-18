// lib/backup_service.dart
// حفظ نسخة

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة النسخ الاحتياطي للتطبيق
class BackupService {
  // 👈 هنا الامتداد الخاص بتطبيقك (تقدر تغيّره مثلاً إلى sga أو salem)
  static const String _backupExtension = 'sga';
  static const String _defaultBaseName = 'student_grades_backup';

  /// نقرأ كل مفاتيح SharedPreferences ونحوّلها إلى Map
  static Future<Map<String, dynamic>> _dumpPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final Map<String, dynamic> data = {};
    for (final k in keys) {
      final v = prefs.get(k);
      if (v != null) data[k] = v;
    }
    return data;
  }

  /// تصدير نسخة احتياطية – يسأل المستخدم أين يحفظ الملف
  static Future<void> exportBackup(BuildContext context) async {
    try {
      // نجمع كل بيانات SharedPreferences
      final data = await _dumpPrefs();
      final jsonStr = jsonEncode(data);

      // نحولها إلى بايتات عشان file_picker على الجوال يرضى يحفظ الملف
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));

      final fileName =
          '$_defaultBaseName-${DateTime.now().millisecondsSinceEpoch}.$_backupExtension';

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'اختر مكان حفظ النسخة الاحتياطية',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [_backupExtension],
      );

      if (savePath != null) {
        final file = File(savePath);
        await file.writeAsBytes(bytes); // ← هنا يتم حفظ النسخة فعليًا
      }

      if (savePath == null) {
        // المستخدم ألغى العملية
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم التصدير بنجاح إلى:\n$savePath')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل التصدير: $e')));
    }
  }

  /// استيراد نسخة احتياطية من ملف
  /// استيراد نسخة احتياطية من ملف
  static Future<void> importBackup(BuildContext context) async {
    try {
      // 👈 نسمح بأي نوع ملف (حل لمشكلة Unsupported filter)
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'اختر ملف النسخة الاحتياطية',
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) {
        return; // المستخدم ألغى الاختيار
      }

      final path = result.files.single.path!;
      final file = File(path);

      // 👈 نتأكد يدوياً أن الامتداد صحيح .sga
      final ext = path.split('.').last.toLowerCase();
      if (ext != _backupExtension.toLowerCase()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'الملف المختار ليس من نوع ($_backupExtension).\nالرجاء اختيار ملف نسخة احتياطية صحيح.',
            ),
          ),
        );
        return;
      }

      final jsonStr = await file.readAsString();
      final Map<String, dynamic> data =
          jsonDecode(jsonStr) as Map<String, dynamic>;

      final prefs = await SharedPreferences.getInstance();

      // لو حاب تمسح كل القديم قبل الاستيراد فعّل السطر التالي
      // await prefs.clear();

      for (final entry in data.entries) {
        final k = entry.key;
        final v = entry.value;

        if (v is bool) {
          await prefs.setBool(k, v);
        } else if (v is int) {
          await prefs.setInt(k, v);
        } else if (v is double) {
          await prefs.setDouble(k, v);
        } else if (v is String) {
          await prefs.setString(k, v);
        } else if (v is List) {
          await prefs.setStringList(k, v.map((e) => e.toString()).toList());
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم استيراد البيانات بنجاح، يُفضَّل إعادة تشغيل التطبيق',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل الاستيراد: $e')));
    }
  }
}
