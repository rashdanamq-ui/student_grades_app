// lib/services/export_service.dart

import 'dart:io';
import 'package:excel/excel.dart' as ex;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_picker/file_picker.dart';
import '../models/student.dart';
import '../core/config/class_grading_config.dart';
import '../core/utils/number_utils.dart';


class ExportService {
  // ================= جزء الـ Excel (محدث) =================
  static Future<void> generateExcel({
    required BuildContext context,
    required String classTitle,
    required List<Student> students,
    required ClassGradingConfig config,
    required Map<String, Map<String, dynamic>> allScores,
    required int activePeriod,
  }) async {
    try {
      var excel = ex.Excel.createExcel();
      String sheetName = "الدرجات";
      ex.Sheet sheet = excel[sheetName];
      sheet.isRTL = true;

      sheet.merge(
        ex.CellIndex.indexByString("A1"),
        ex.CellIndex.indexByString("F1"),
        customValue: ex.TextCellValue(classTitle),
      );
      var titleCell = sheet.cell(ex.CellIndex.indexByString("A1"));
      titleCell.cellStyle = ex.CellStyle(
        bold: true,
        fontSize: 16,
        horizontalAlign: ex.HorizontalAlign.Center,
      );

      List<String> headers = ['ت', 'الاسم'];
      List<GradeColumn> allCols = [...config.items, ...config.exams];
      headers.addAll(allCols.map((col) => col.name));
      headers.add('مجموع المهام');
      headers.add('المجموع الكلي');

      sheet.appendRow(headers.map((e) => ex.TextCellValue(e)).toList());

      for (int i = 0; i < students.length; i++) {
        final s = students[i];
        List<dynamic> row = [i + 1, s.name];

        for (var col in allCols) {
          // جلب القيمة بناءً على الفترة
          final scoreRaw = _getCalculatedScoreRaw(
            s,
            col,
            allScores,
            activePeriod,
          );
          if (scoreRaw != null) {
            row.add(scoreRaw);
          } else {
            row.add('-');
          }
        }

        row.add(_getPerformanceTotal(s, config, allScores, activePeriod));
        row.add(_getTotalScore(s, config, allScores, activePeriod));

        sheet.appendRow(
          row.map((e) {
            if (e is num) return ex.DoubleCellValue(e.toDouble());
            return ex.TextCellValue(e.toString());
          }).toList(),
        );
      }

      final bytes = excel.save();
      if (bytes == null) return;

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ ملف الإكسل:',
        fileName: 'تقرير_${classTitle.replaceAll(" ", "_")}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (outputFile != null) {
        if (!outputFile.endsWith('.xlsx')) outputFile += '.xlsx';
        final file = File(outputFile);
        await file.writeAsBytes(bytes, flush: true);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم الحفظ بنجاح ✅'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء تصدير Excel: $e')),
        );
      }
    }
  }

  // ================= جزء الـ PDF (محدث لإظهار الأرقام) =================
  static Future<void> generatePdf({
    required BuildContext context,
    required String classTitle,
    required List<Student> students,
    required ClassGradingConfig config,
    required Map<String, Map<String, dynamic>> allScores,
    required int activePeriod,
  }) async {
    final orientation = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('اختيار تخطيط الصفحة', textAlign: TextAlign.center),
        children: [
          SimpleDialogOption(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            onPressed: () => Navigator.pop(context, 'portrait'),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('عمودي (رأسي)'),
                SizedBox(width: 10),
                Icon(Icons.portrait),
              ],
            ),
          ),
          SimpleDialogOption(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            onPressed: () => Navigator.pop(context, 'landscape'),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('أفقي (عرضي)'),
                SizedBox(width: 10),
                Icon(Icons.landscape),
              ],
            ),
          ),
        ],
      ),
    );
    if (orientation == null) return;

    final pageFormat = orientation == 'portrait'
        ? pdf.PdfPageFormat.a4
        : pdf.PdfPageFormat.a4.landscape;
    final doc = pw.Document();

    final regularFontData = await rootBundle.load(
      'assets/fonts/Amiri-Regular.ttf',
    );
    final boldFontData = await rootBundle.load('assets/fonts/Amiri-Bold.ttf');
    final fontRegular = pw.Font.ttf(regularFontData);
    final fontBold = pw.Font.ttf(boldFontData);

    final List<String> pdfHeaders = ['المجموع', 'م.المهام'];
    List<GradeColumn> allCols = [...config.items, ...config.exams];
    for (var col in allCols.reversed) {
      pdfHeaders.add(col.name);
    }
    pdfHeaders.add('الاسم');
    pdfHeaders.add('ت');

    pw.Widget buildMarksTable() {
      final List<pw.TableRow> rows = [];
      rows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: pdf.PdfColors.grey300),
          children: pdfHeaders
              .map(
                (h) => pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    vertical: 1.5,
                    horizontal: 2,
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Directionality(
                    textDirection: pw.TextDirection.rtl,
                    child: pw.Text(
                      h,
                      style: pw.TextStyle(font: fontBold, fontSize: 10),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      );

      for (int i = 0; i < students.length; i++) {
        final s = students[i];
        final idx = i + 1;

        // حساب المجاميع
        double total = _getTotalScore(s, config, allScores, activePeriod);
        double perfTotal = _getPerformanceTotal(
          s,
          config,
          allScores,
          activePeriod,
        );

        List<String> cellValues = [
          formatNumberForPdf(total),
          formatNumberForPdf(perfTotal),
        ];

        // القيم التفصيلية
        for (var col in allCols.reversed) {
          final raw = _getCalculatedScoreRaw(s, col, allScores, activePeriod);
          cellValues.add(raw != null ? formatNumberForPdf(raw) : '-');
        }

        cellValues.add(s.name);
        cellValues.add(idx.toString().toAppNum());

        final isOdd = i % 2 != 0;
        final rowColor = isOdd
            ? pdf.PdfColors.white
            : pdf.PdfColor.fromHex("#f5f0eb");

        List<pw.Widget> rowWidgets = [];
        for (int k = 0; k < cellValues.length; k++) {
          String txt = cellValues[k];
          if (k == cellValues.length - 2) {
            // الاسم
            rowWidgets.add(
              pw.Container(
                alignment: pw.Alignment.centerRight,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 2,
                  vertical: 1.5,
                ),
                child: pw.Text(
                  txt,
                  maxLines: 1,
                  style: pw.TextStyle(font: fontRegular, fontSize: 9),
                  textDirection: pw.TextDirection.rtl,
                ),
              ),
            );
          } else if (k == cellValues.length - 1) {
            // التسلسل
            rowWidgets.add(_buildCell(txt, fontRegular)); // تسلسل عادي
          } else {
            // الدرجات والمجاميع (Bold للمجاميع)
            bool isTotalCol = k == 0 || k == 1;
            rowWidgets.add(
              _buildCell(
                txt,
                isTotalCol ? fontBold : fontRegular,
                isBold: isTotalCol,
              ),
            );
          }
        }
        rows.add(
          pw.TableRow(
            decoration: pw.BoxDecoration(color: rowColor),
            children: rowWidgets,
          ),
        );
      }

      return pw.Table(
        border: pw.TableBorder.all(color: pdf.PdfColors.grey600, width: 0.5),
        columnWidths: {
          pdfHeaders.length - 1: const pw.FixedColumnWidth(25),
          pdfHeaders.length - 2: const pw.FixedColumnWidth(120),
          0: const pw.FixedColumnWidth(35),
          1: const pw.FixedColumnWidth(35),
        },
        defaultColumnWidth: const pw.FixedColumnWidth(28),
        children: rows,
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(20),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (context) => [
          // 🔥 العنوان
          pw.Center(
            child: pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Text(
                'تقرير درجات: $classTitle'.toAppNum(),
                style: pw.TextStyle(font: fontBold, fontSize: 18),
              ),
            ),
          ),

          pw.SizedBox(height: 10),

          // 🔥 الجدول (تأكد أنك عدلته بنفس الطريقة)
          buildMarksTable(),

          pw.SizedBox(height: 10),

          // 🔥 التاريخ
          pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Text(
                'تاريخ الطباعة: ${DateTime.now().toString().split(' ')[0]}'
                    .toAppNum(),
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 8,
                  color: pdf.PdfColors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'Grade_Report_$classTitle',
    );
  }

  static pw.Widget _buildCell(
    String text,
    pw.Font font, {
    bool isBold = false,
  }) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 1),
      child: pw.Directionality(
        textDirection: pw.TextDirection.rtl,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            font: font,
            fontSize: 9,
            fontWeight: isBold ? pw.FontWeight.bold : null,
          ),
        ),
      ),
    );
  }

  // ================= دوال المنطق والحسابات (التي تم إصلاحها) =================

  // التحقق من الاختبار النهائي
  static bool _isFinalExam(GradeColumn col) {
    return col.tag == 'اختبار نهائي' || col.name.contains('نهائي');
  }

  // استخراج القيمة من البيانات الخام (String/List -> Double)
  static double _parseVal(GradeColumn col, dynamic val) {
    if (val == null) return 0.0;

    if (col.type == GradeType.numeric) {
      return double.tryParse(val.toString().toEnglishNum()) ?? 0.0;
    }
    if (col.type == GradeType.checkbox) {
      int count = int.tryParse(val.toString().toEnglishNum()) ?? 0;
      if (col.subCount > 0) return count * (col.maxScore / col.subCount);
    }
    if (col.type == GradeType.numericList) {
      if (val is List && val.isNotEmpty) {
        double sum = 0;
        int count = 0;
        for (var v in val) {
          double? d = double.tryParse(v.toString().toEnglishNum());
          if (d != null) {
            sum += d;
            count++;
          }
        }
        if (count > 0) return sum / count;
      }
    }
    if (col.type == GradeType.averagePair) {
      if (val is List && val.length >= 2) {
        double v1 = double.tryParse(val[0].toString().toEnglishNum()) ?? 0.0;
        double v2 = double.tryParse(val[1].toString().toEnglishNum()) ?? 0.0;
        return (v1 + v2) / 2.0;
      }
    }
    return 0.0;
  }

  // ✅ الدالة الأساسية لجلب الدرجة الصحيحة بناءً على الفترة
  static double? _getCalculatedScoreRaw(
    Student s,
    GradeColumn col,
    Map<String, dynamic> allScores,
    int activePeriod,
  ) {
    final data = allScores[s.name] ?? {};

    // إذا كانت فترة محددة (1 أو 2) وكان العمود "اختبار نهائي"، نخفيه (نرجع null)
    if (activePeriod != 0 && _isFinalExam(col)) {
      return null;
    }

    if (activePeriod == 0) {
      // === المحصلة (ختامي) ===
      if (_isFinalExam(col)) {
        // النهائي نأخذه من الفترة 2 (حسب منطق حفظ البيانات)
        return data['${col.id}_p2'] != null
            ? _parseVal(col, data['${col.id}_p2'])
            : null;
      } else {
        // بقية الأعمدة: متوسط الفترتين
        final val1 = data['${col.id}_p1'];
        final val2 = data['${col.id}_p2'];
        if (val1 == null && val2 == null) return null;

        double v1 = val1 != null ? _parseVal(col, val1) : 0.0;
        double v2 = val2 != null ? _parseVal(col, val2) : 0.0;
        return (v1 + v2) / 2;
      }
    } else {
      // === فترة محددة ===
      String suffix = activePeriod == 1 ? '_p1' : '_p2';
      final val = data['${col.id}$suffix'];
      if (val == null) return null;
      return _parseVal(col, val);
    }
  }

  // ✅ حساب مجموع المهام (الأدائية)
  static double _getPerformanceTotal(
    Student s,
    ClassGradingConfig config,
    Map<String, dynamic> allScores,
    int activePeriod,
  ) {
    final data = allScores[s.name] ?? {};
    double total = 0.0;

    for (var col in [...config.items, ...config.exams]) {
      // نجمع فقط إذا كانت "مهمة أدائية" وليست اختباراً
      // (ملاحظة: في الكود الأصلي أنت تفحص isPerformanceTask، سنلتزم بذلك)
      if (col.isPerformanceTask) {
        if (activePeriod == 0) {
          // المحصلة
          double v1 = _parseVal(col, data['${col.id}_p1']);
          double v2 = _parseVal(col, data['${col.id}_p2']);
          total += (v1 + v2) / 2;
        } else {
          // فترة
          String suffix = activePeriod == 1 ? '_p1' : '_p2';
          if (!_isFinalExam(col)) {
            // تجاهل النهائي في مجموع الفترات
            total += _parseVal(col, data['${col.id}$suffix']);
          }
        }
      }
    }
    return total;
  }

  // ✅ حساب المجموع الكلي
  static double _getTotalScore(
    Student s,
    ClassGradingConfig config,
    Map<String, dynamic> allScores,
    int activePeriod,
  ) {
    final data = allScores[s.name] ?? {};

    if (activePeriod == 0) {
      // === المحصلة النهائية ===
      double p1 = 0;
      double p2 = 0;
      double finalExam = 0;

      for (var col in [...config.items, ...config.exams]) {
        if (_isFinalExam(col)) {
          finalExam += _parseVal(col, data['${col.id}_p2']);
        } else {
          p1 += _parseVal(col, data['${col.id}_p1']);
          p2 += _parseVal(col, data['${col.id}_p2']);
        }
      }
      return ((p1 + p2) / 2) + finalExam;
    } else {
      // === فترة محددة ===
      double total = 0.0;
      String suffix = activePeriod == 1 ? '_p1' : '_p2';

      for (var col in [...config.items, ...config.exams]) {
        if (_isFinalExam(col)) continue; // لا نجمع النهائي في الفترات
        total += _parseVal(col, data['${col.id}$suffix']);
      }
      return total;
    }
  }

  // ================= دوال مساعدة للاستخدام الخارجي (CSV) =================
  static double calculatePerformanceTotal({
    required Student student,
    required ClassGradingConfig config,
    required Map<String, Map<String, dynamic>> allScores,
    required int activePeriod,
  }) {
    return _getPerformanceTotal(student, config, allScores, activePeriod);
  }

  static double calculateTotalScore({
    required Student student,
    required ClassGradingConfig config,
    required Map<String, Map<String, dynamic>> allScores,
    required int activePeriod,
  }) {
    return _getTotalScore(student, config, allScores, activePeriod);
  }
}
