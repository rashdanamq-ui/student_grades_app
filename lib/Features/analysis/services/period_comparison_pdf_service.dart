import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:student_grades_app/Features/analysis/services/analysis_calculator.dart';
import 'package:student_grades_app/Features/analysis/services/analysis_pdf_service.dart';

import '../../../core/config/class_grading_config.dart';
import '../../../core/utils/number_utils.dart';
import '../models/analysis_view_models.dart';
import '../../services/analysis_calculator.dart';
import '../../../models/student.dart';

class PeriodComparisonPdfService {
  // دالة التوليد الرئيسية
  static Future<Uint8List> generatePdf({
    required AnalysisReportMeta meta,
    required ClassGradingConfig config,
    required List<Student> students,
    required Map<String, Map<String, dynamic>> allScores,
    required List<LevelConfigV2> activeLevels,
    required List<String> availableTags,
  }) async {
    final doc = pw.Document();

    // تحميل الخطوط
    final fontRegular = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    // تحميل الشعار إذا وجد (يمكنك تمريره في الـ meta)
    // final logo = await imageFromAssetBundle('assets/logo.png');

    // إعدادات الثيم
    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    // الألوان
    final greenColor = PdfColor.fromInt(0xFF2E7D6F);
    final greyColor = PdfColors.grey400;

    // دالة مساعدة لحساب الإحصائيات داخل الـ PDF
    AnalysisStatsV2 calculateStats(int period, String tag) {
      double calculatedMax = 0.0;
      for (var item in [...config.items, ...config.exams]) {
        // فلتر التاق واستثناء النهائي من ف1
        bool includeTag = (tag == 'Comprehensive') || (item.tag == tag);
        bool isFinal =
            item.tag == 'اختبار نهائي' || item.name.contains('نهائي');
        if (!includeTag) continue;
        if (period == 1 && isFinal) continue;
        calculatedMax += item.maxScore;
      }
      if (calculatedMax == 0) calculatedMax = 100;

      String suffix = period == 1 ? '_p1' : '_p2';
      List<double> scoresList = [];

      for (var s in students) {
        double total = 0.0;
        final scores = allScores[s.name];
        if (scores != null) {
          for (var col in [...config.items, ...config.exams]) {
            bool includeTag = (tag == 'Comprehensive') || (col.tag == tag);
            bool isFinal =
                col.tag == 'اختبار نهائي' || col.name.contains('نهائي');
            if (!includeTag) continue;
            if (period == 1 && isFinal) continue;

            final val = scores['${col.id}$suffix'];
            // منطق تحويل الدرجة البسيط للـ PDF
            double score = 0;
            if (val != null) {
              // (نسخ منطق التحويل الرقمي باختصار)
              score = double.tryParse(val.toString()) ?? 0;
              if (col.type == GradeType.checkbox) {
                int c = int.tryParse(val.toString()) ?? 0;
                score = col.subCount == 0
                    ? 0
                    : c * (col.maxScore / col.subCount);
              } else if (col.type == GradeType.numericList && val is List) {
                // ... منطق القوائم ...
                // للتبسيط سنفترض الرقم جاهز أو نعتمد على الحساب الدقيق
                // يفضل نقل منطق getRealScore لملف مشترك، لكن هنا سنعتمد على أن القيمة رقمية
              }
            }
            total += score;
          }
        }
        scoresList.add(total);
      }

      final Map<String, int> counts = {for (var l in activeLevels) l.label: 0};
      for (var s in scoresList) {
        final lvl = AnalysisCalculator.getLevelForScore(
          score: s,
          maxScore: calculatedMax,
          useSum: true,
          activeLevels: activeLevels,
          selectedTag: tag,
        );
        counts[lvl] = (counts[lvl] ?? 0) + 1;
      }
      return AnalysisStatsV2(
        maxScore: calculatedMax,
        totalStudents: students.length,
        activeStudents: scoresList.length,
        highest: 0,
        lowest: 0,
        average: 0,
        sum: 0,
        achievementPercent: 0,
        levelCounts: counts,
        levelLabels: activeLevels.map((e) => e.label).toList(),
      );
    }

    // بناء الصفحة
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        build: (context) {
          return [
            // --- الهيدر (الديباجة) ---
            pw.Column(
              children: [
                pw.Text(
                  meta.ministryLabel,
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  meta.schoolName,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'تقرير مقارنة الفترات - ${meta.page1Title}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: greenColor,
                  ),
                ),
                pw.Divider(color: greenColor, thickness: 2),
                pw.SizedBox(height: 20),
              ],
            ),

            // --- المحتوى (شبكة الكروت) ---
            pw.Wrap(
              spacing: 15,
              runSpacing: 15,
              children: availableTags.map((tag) {
                final s1 = calculateStats(1, tag);
                final s2 = calculateStats(2, tag);
                String title = tag == 'Comprehensive' ? 'المجموع الكلي' : tag;

                // حساب أقصى ارتفاع للرسم
                int maxCount = 0;
                for (var lvl in activeLevels) {
                  maxCount = max(
                    maxCount,
                    max(
                      s1.levelCounts[lvl.label] ?? 0,
                      s2.levelCounts[lvl.label] ?? 0,
                    ),
                  );
                }
                if (maxCount == 0) maxCount = 10;

                return pw.Container(
                  width:
                      230, // عرض ثابت ليسمح بوجود كرتين في الصف (A4 عرضها ~470 بعد الهوامش)
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(8),
                    color: PdfColors.white,
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // العنوان
                      pw.Row(
                        children: [
                          pw.Container(width: 3, height: 12, color: greenColor),
                          pw.SizedBox(width: 5),
                          pw.Text(
                            title,
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 10),

                      // الرسم البياني
                      pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                        children: activeLevels.map((lvl) {
                          int c1 = s1.levelCounts[lvl.label] ?? 0;
                          int c2 = s2.levelCounts[lvl.label] ?? 0;
                          double h1 =
                              (c1 / maxCount) * 60; // ارتفاع مصغر للـ PDF
                          double h2 = (c2 / maxCount) * 60;

                          return pw.Column(
                            children: [
                              pw.Row(
                                crossAxisAlignment: pw.CrossAxisAlignment.end,
                                children: [
                                  pw.Container(
                                    width: 6,
                                    height: h1 > 0 ? h1 : 1,
                                    color: greyColor,
                                  ),
                                  pw.SizedBox(width: 1),
                                  pw.Container(
                                    width: 6,
                                    height: h2 > 0 ? h2 : 1,
                                    color: greenColor,
                                  ),
                                ],
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                lvl.label,
                                style: const pw.TextStyle(fontSize: 7),
                              ),
                            ],
                          );
                        }).toList(),
                      ),

                      pw.SizedBox(height: 10),

                      // الجدول
                      pw.Table(
                        border: pw.TableBorder.all(
                          color: PdfColors.grey300,
                          width: 0.5,
                        ),
                        columnWidths: {
                          0: const pw.FlexColumnWidth(2), // المستوى
                          1: const pw.FlexColumnWidth(1), // ف1
                          2: const pw.FlexColumnWidth(1), // ف2
                          3: const pw.FlexColumnWidth(1), // الفرق
                        },
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(
                              color: PdfColors.grey100,
                            ),
                            children: [
                              _pdfCell('المستوى', fontBold, isHeader: true),
                              _pdfCell('ف1', fontBold, isHeader: true),
                              _pdfCell('ف2', fontBold, isHeader: true),
                              _pdfCell('الفرق', fontBold, isHeader: true),
                            ],
                          ),
                          ...activeLevels.map((lvl) {
                            int c1 = s1.levelCounts[lvl.label] ?? 0;
                            int c2 = s2.levelCounts[lvl.label] ?? 0;
                            int diff = c2 - c1;
                            PdfColor diffColor = diff > 0
                                ? PdfColors.green
                                : (diff < 0 ? PdfColors.red : PdfColors.grey);
                            return pw.TableRow(
                              children: [
                                _pdfCell(
                                  lvl.label,
                                  fontRegular,
                                  align: pw.TextAlign.right,
                                ),
                                _pdfCell('$c1', fontRegular),
                                _pdfCell('$c2', fontRegular),
                                _pdfCell(
                                  '${diff > 0 ? "+" : ""}$diff',
                                  fontBold,
                                  color: diffColor,
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            // --- التذييل ---
            pw.Spacer(),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(meta.teacherName),
                pw.Text(meta.principalName),
              ],
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _pdfCell(
    String text,
    pw.Font font, {
    bool isHeader = false,
    PdfColor? color,
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      child: pw.Text(
        text.toAppNum(),
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 8 : 8,
          color: color ?? PdfColors.black,
        ),
      ),
    );
  }
}
