import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student.dart';
import '../core/config/class_grading_config.dart';
import 'csv_binding_models.dart';

class CsvImporterService {
  static Future<void> import({
    required String classId,
    required List<Student> students,
    required ClassGradingConfig config,
    required List<List<String>> rows,
    required List<CsvColumnBinding> bindings,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 🔑 تحديد عمود الاسم من bindings
    final nameBindingIndex = bindings.indexWhere((b) => b.isName == true);
    if (nameBindingIndex == -1) {
      return Future.error('لم يتم تحديد عمود الاسم في CSV');
    }

    for (final row in rows) {
      if (row.isEmpty || nameBindingIndex >= row.length) continue;

      final studentName = row[nameBindingIndex].trim();
      if (studentName.isEmpty) continue;

      // ================= الطالب =================
      Student student;
      if (!students.any((s) => s.name == studentName)) {
        student = Student(name: studentName);
        students.add(student);
      } else {
        student = students.firstWhere((s) => s.name == studentName);
      }

      final key = 'student_detail_${student.name}_$classId';
      Map<String, dynamic> data = {};

      final old = prefs.getString(key);
      if (old != null) {
        data = jsonDecode(old);
      }

      // ================= الدرجات =================
      for (int i = 0; i < bindings.length && i < row.length; i++) {
        final b = bindings[i];

        if (b.ignore || b.isName || b.targetColumn == null) continue;

        final raw = row[i].trim().replaceAll(',', '.');
        final value = double.tryParse(raw);
        if (value == null) continue;

        if (b.subIndex != null) {
          final colId = b.targetColumn!.id;

          if (data[colId] is! List) {
            data[colId] = List<dynamic>.filled(b.targetColumn!.subCount, null);
          }

          final list = data[colId] as List;
          if (b.subIndex! >= 0 && b.subIndex! < list.length) {
            list[b.subIndex!] = value;
          }
        } else {
          data[b.targetColumn!.id] = value;
        }
      }

      await prefs.setString(key, jsonEncode(data));
    }
  }
}

dynamic parseCsvValueToDbFormat(GradeColumn col, String cellValue) {
  cellValue = cellValue.trim();
  if (cellValue.isEmpty) return null;

  // 1. معالجة الصح والخطأ (Checkbox) - هنا المشكلة والحل
  if (col.type == GradeType.checkbox) {
    // القيمة القادمة من CSV هي "الدرجة" (مثلاً 16)
    double importedScore = double.tryParse(cellValue) ?? 0.0;

    // إذا كان البند له مربعات
    if (col.subCount > 0 && col.maxScore > 0) {
      // حساب قيمة المربع الواحد
      double scorePerBox = col.maxScore / col.subCount; // 20 / 5 = 4

      // المعادلة العكسية: الدرجة / قيمة المربع = العدد
      // 16 / 4 = 4
      int count = (importedScore / scorePerBox).round();

      // أمان: التأكد أن العدد لا يتجاوز الحد الأقصى للمربعات
      if (count > col.subCount) count = col.subCount;

      return count; // نخزن 4 في قاعدة البيانات
    }
    return 0;
  }
  // 2. معالجة الأرقام العادية (Numeric)
  else if (col.type == GradeType.numeric) {
    return double.tryParse(cellValue) ?? 0.0;
  }

  // 3. معالجة القوائم الرقمية (إذا كانت موجودة في CSV كقيمة واحدة)
  // ملاحظة: استيراد القوائم معقد قليلاً ويعتمد على هيكلة ملفك،
  // لكن إذا كنت تصدر المتوسط، فلا يمكنك استيراد القائمة الأصلية بسهولة.
  // سنفترض هنا أننا نتعامل مع القيم الفردية فقط.

  // إرجاع القيمة كما هي للنصوص وغيرها
  return cellValue;
}
