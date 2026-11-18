import 'dart:io';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';

import '../core/config/class_grading_config.dart';
import '../core/utils/number_utils.dart'; // اختياري لتنسيق الأرقام

Future<void> exportClassCsvGeneric({
  required String fileName,
  required List<String> headers,
  required List<List<dynamic>> rows,
}) async {
  const sep = ';';
  final buffer = StringBuffer();

  // العناوين
  buffer.writeln(headers.join(sep));

  // الصفوف
  for (final row in rows) {
    buffer.writeln(row.map((e) => e ?? '').join(sep));
  }

  String? outputFile = await FilePicker.platform.saveFile(
    dialogTitle: 'حفظ ملف CSV',
    fileName: '$fileName.csv',
    type: FileType.custom,
    allowedExtensions: ['csv'],
  );

  if (outputFile == null) return;
  if (!outputFile.endsWith('.csv')) outputFile += '.csv';

  final file = File(outputFile);

  // BOM لضمان العربية
  final bytes = utf8.encode('\uFEFF${buffer.toString()}');
  await file.writeAsBytes(bytes, flush: true);
}

/// ✅ دالة جديدة: تحسب الدرجة الصحيحة لملف CSV
/// تستخدم هذه الدالة داخل الحلقة التي تجهز البيانات
String calculateCellForCsv(GradeColumn col, dynamic rawVal) {
  if (rawVal == null) return '0';

  // 1. معالجة الصح والخطأ (Checkbox)
  if (col.type == GradeType.checkbox) {
    int count = int.tryParse(rawVal.toString()) ?? 0;

    // المعادلة: عدد الصحوح * (الدرجة الكلية / عدد المربعات)
    if (col.subCount > 0) {
      double score = count * (col.maxScore / col.subCount);
      // إرجاع الرقم (بدون كسور إذا كان صحيحاً)
      return score % 1 == 0
          ? score.toInt().toString()
          : score.toStringAsFixed(1);
    }
    return '0';
  }
  // 2. معالجة القوائم الرقمية (Numeric List)
  else if (col.type == GradeType.numericList) {
    if (rawVal is List && rawVal.isNotEmpty) {
      double sum = 0;
      int count = 0;
      for (var v in rawVal) {
        double? d = double.tryParse(v.toString());
        if (d != null) {
          sum += d;
          count++;
        }
      }
      if (count > 0) {
        double avg = sum / count;
        return avg % 1 == 0 ? avg.toInt().toString() : avg.toStringAsFixed(1);
      }
    }
    return '0';
  }

  // 3. البقية (رقم عادي)
  return rawVal.toString();
}
