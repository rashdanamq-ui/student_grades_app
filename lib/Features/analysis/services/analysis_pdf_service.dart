// lib/features/analysis/services/analysis_pdf_service.dart

import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/utils/number_utils.dart';

// استبدل المسارات التالية بمسارات مشروعك الصحيحة
import '../../../models/mock_student.dart';
import '../models/analysis_view_models.dart';

class AnalysisReportMeta {
  final String regionName;
  final String ministryLabel;
  final String officeName;
  final String schoolName;
  final String examTitle;
  final String stageClass;
  final String yearText;
  final String academicYear;
  final String teacherName;
  final String principalName;
  final String page1Title;
  final String page2Title;
  final String page3Title;

  AnalysisReportMeta({
    required this.regionName,
    required this.ministryLabel,
    required this.officeName,
    required this.schoolName,
    required this.examTitle,
    required this.stageClass,
    required this.yearText,
    required this.academicYear,
    required this.teacherName,
    required this.principalName,
    required this.page1Title,
    required this.page2Title,
    required this.page3Title,
  });
}

class AnalysisPdfService {
  static pw.Font? _cachedRegularFont;
  static pw.Font? _cachedBoldFont;
  static pw.MemoryImage? _cachedMinistryLogo;
  static bool _assetsLoaded = false;
  static pw.Font? _iconFont; // متغير جديد

  /// تحميل الخطوط والصور مرة واحدة
  static Future<void> prepareAssets() async {
    if (_assetsLoaded) return;
    try {
      // تحميل الخطوط العربية (موجود سابقاً)
      final regularData = await rootBundle.load(
        'assets/fonts/Amiri-Regular.ttf',
      );
      _cachedRegularFont = pw.Font.ttf(regularData);

      final boldData = await rootBundle.load('assets/fonts/Amiri-Bold.ttf');
      _cachedBoldFont = pw.Font.ttf(boldData);

      // ✅✅✅ تحميل خط الأيقونات (الجديد) ✅✅✅
      final iconData = await rootBundle.load(
        'assets/fonts/MaterialIcons-Regular.ttf',
      );
      _iconFont = pw.Font.ttf(iconData);

      // تحميل الشعار (موجود سابقاً)
      try {
        final logoData = await rootBundle.load(
          'assets/images/ministry_logo.png',
        );
        _cachedMinistryLogo = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (_) {}

      _assetsLoaded = true;
    } catch (e) {
      debugPrint('Error loading assets: $e');
    }
  }

  /// الدالة الرئيسية لتوليد ملف PDF
  static Future<Uint8List> generatePdf({
    required pdf.PdfPageFormat format,
    required AnalysisReportMeta meta,
    required AnalysisStatsV2 stats,
    required List<LevelRowV2> levels,
    required List<MockStudent> topStudents,
    required List<MockStudent> bottomStudents,
    required List<LevelConfigV2> activeLevelConfigs,
    required Function(LevelConfigV2) getStudentsForLevel,
    required Function(double) formatGrade,
    bool showSum = false, // ✅ بارميتر جديد
  }) async {
    try {
      await prepareAssets();
      // 1. تحميل خط Segoe UI
      final segoeData = await rootBundle.load("assets/fonts/seguisb.ttf");
      final segoeFont = pw.Font.ttf(segoeData);

      final amiriRegular = _cachedRegularFont ?? pw.Font.courier();
      final amiriBold = _cachedBoldFont ?? pw.Font.courierBold();
      final mainColor = pdf.PdfColor.fromInt(0xFF27ae60);
      final redColor = pdf.PdfColors.red400;

      final doc = pw.Document();

      final widgetsHelper = _AnalysisPdfWidgets(
        amiriBold: amiriBold,
        amiriRegular: amiriRegular,
        segoeFont: segoeFont,
        mainColor: mainColor,
        redColor: redColor,
        iconFont: _iconFont,

        meta: meta,
        logo: _cachedMinistryLogo,
        formatGrade: formatGrade,
        showSum: showSum, // ✅ نمرر خاصية المجموع
      );

      // --- الصفحة 1 (الملخص) ---
      // الصفحة 1: الداشبورد الحديث
      doc.addPage(
        pw.Page(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(20),
          theme: pw.ThemeData.withFont(base: amiriRegular, bold: amiriBold),
          build: (ctx) {
            // ✅ حماية: إذا لم تكن هناك مستويات، نعرض رسالة بدلاً من الداشبورد لتجنب الخطأ
            if (levels.isEmpty) {
              return pw.Center(
                child: pw.Text(
                  'لا توجد بيانات كافية لعرض التحليل',
                  style: pw.TextStyle(font: amiriBold, fontSize: 14),
                ),
              );
            }

            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                children: [
                  widgetsHelper.buildFullHeader(pageTitle: ''),
                  pw.SizedBox(height: 10),

                  // استدعاء الداشبورد (الآن نحن متأكدون أن levels ليست فارغة)
                  widgetsHelper.buildModernDashboardPage(
                    stats,
                    levels,
                    meta.examTitle, // ✅ تمرير اسم المادة/الاختبار هنا
                  ),

                  pw.Spacer(),
                  widgetsHelper.buildFooter(),
                ],
              ),
            );
          },
        ),
      );

      // --- الصفحة 2 (الأوائل) ---
      if (topStudents.isNotEmpty) {
        doc.addPage(
          pw.MultiPage(
            pageFormat: format,
            margin: const pw.EdgeInsets.all(20),
            textDirection: pw.TextDirection.rtl,
            theme: pw.ThemeData.withFont(base: amiriRegular, bold: amiriBold),
            footer: (ctx) => widgetsHelper.buildFooter(),
            build: (ctx) => [
              widgetsHelper.buildFullHeader(pageTitle: meta.page2Title),
              pw.SizedBox(height: 15),
              ...widgetsHelper.buildStudentListTable(
                'الطلاب المتقنين / الأوائل'.toAppNum(),
                topStudents,
                mainColor,
              ),
            ],
          ),
        );
      }

      // --- الصفحة 3 (المتعثرين) ---
      if (bottomStudents.isNotEmpty) {
        doc.addPage(
          pw.MultiPage(
            pageFormat: format,
            margin: const pw.EdgeInsets.all(20),
            textDirection: pw.TextDirection.rtl,
            theme: pw.ThemeData.withFont(base: amiriRegular, bold: amiriBold),
            footer: (ctx) => widgetsHelper.buildFooter(),
            build: (ctx) => [
              widgetsHelper.buildFullHeader(
                pageTitle: 'كشف بأسماء الطلاب الأقل أداءً',
              ),
              pw.SizedBox(height: 15),
              ...widgetsHelper.buildStudentListTable(
                'الطلاب غير المتقنين'.toAppNum(),
                bottomStudents,
                redColor,
              ),
            ],
          ),
        );
      }

      // --- صفحات المستويات (التعديل الذكي للتكرار) ---
      // --- الصفحة الرابعة وما بعدها: جميع المستويات ---
      const colors = [
        pdf.PdfColor.fromInt(0xFF2ecc71), // ممتاز
        pdf.PdfColor.fromInt(0xFF27ae60), // جيد جداً
        pdf.PdfColor.fromInt(0xFF3498db),
        pdf.PdfColor.fromInt(0xFFe67e22),
        pdf.PdfColor.fromInt(0xFFe74c3c),
      ];

      doc.addPage(
        pw.MultiPage(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(20),
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: amiriRegular, bold: amiriBold),
          footer: (ctx) => widgetsHelper.buildFooter(),

          build: (ctx) {
            final widgets = <pw.Widget>[];

            for (int i = 0; i < activeLevelConfigs.length; i++) {
              final lvl = activeLevelConfigs[i];
              final list = getStudentsForLevel(lvl) as List<MockStudent>;
              if (list.isEmpty) continue;

              final color = colors[i % colors.length];

              // 🔹 عنوان المستوى
              widgets.add(
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: color,
                    borderRadius: const pw.BorderRadius.vertical(
                      top: pw.Radius.circular(6),
                    ),
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    '${lvl.label} (${list.length})'.toAppNum(),
                    style: pw.TextStyle(
                      font: amiriBold,
                      fontSize: 11,
                      color: pdf.PdfColors.white,
                    ),
                  ),
                ),
              );

              // 🔹 جدول الطلاب
              widgets.add(
                pw.Table.fromTextArray(
                  border: pw.TableBorder.all(
                    color: pdf.PdfColors.grey400,
                    width: 0.5,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: pdf.PdfColors.grey100,
                  ),
                  headerStyle: pw.TextStyle(font: amiriBold, fontSize: 9),
                  cellStyle: pw.TextStyle(font: amiriRegular, fontSize: 9),
                  cellAlignment: pw.Alignment.center,
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.2), // م
                    1: const pw.FlexColumnWidth(1.2), // اسم الطالب
                    2: const pw.FlexColumnWidth(3), // الصف
                    3: const pw.FlexColumnWidth(0.8), // الدرجة
                  },
                  headers: const ['الدرجة', ' الصف', 'اسم الطالب', 'م'],
                  data: list.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final s = entry.value;
                    return [
                      formatGrade(s.tempScore ?? 0),
                      s.className.toAppNum(), // 👈 مرتبط بالطالب
                      s.name.replaceAll('\n', ' ').trim(),
                      idx.toString().toAppNum(),
                    ];
                  }).toList(),
                ),
              );

              // 🔹 فاصل بين المستويات
              widgets.add(pw.SizedBox(height: 20));
            }

            return widgets;
          },
        ),
      );

      // --- الصفحة الأخيرة (الاحصائيات) ---
      /*
    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(20),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: amiriRegular, bold: amiriBold),
        header: (ctx) => widgets.buildPage3Title(),
        footer: (ctx) => widgets.buildFooter(),
        build: (ctx) => [widgets.buildAggregatedStatsTable(levels)],
      ),
    );
    */
      return doc.save();
    } catch (e, stack) {
      debugPrint('CRITICAL ERROR in PDF generation: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }
}

class _AnalysisPdfWidgets {
  final pw.Font amiriBold;
  final pw.Font amiriRegular;
  final pw.Font segoeFont; // ✅ 3. إضافة المتغير هنا

  final pdf.PdfColor mainColor;
  final pdf.PdfColor redColor;
  final AnalysisReportMeta meta;
  final pw.MemoryImage? logo;
  final Function(double) formatGrade;
  final pw.Font? iconFont;
  final bool showSum; // ✅ متغير المجموع

  _AnalysisPdfWidgets({
    required this.amiriBold,
    required this.amiriRegular,
    required this.segoeFont, // ✅ 4. إضافته في البناء (Constructor)

    required this.mainColor,
    required this.redColor,
    required this.meta,
    this.logo,
    required this.formatGrade,
    this.iconFont,
    this.showSum = false, // ✅
  });

  // ✅✅✅ أضف تعريف الألوان هنا ✅✅✅
  static const PdfColor colorGreen = PdfColor.fromInt(0xFF2EAD8B);
  static const PdfColor colorBlue = PdfColor.fromInt(0xFF2979FF);
  static const PdfColor colorPurple = PdfColor.fromInt(0xFF7E57C2);
  static const PdfColor colorOrange = PdfColor.fromInt(0xFFFFA726);
  static const PdfColor colorRed = PdfColor.fromInt(0xFFEF5350);

  List<pw.Widget> _buildAbsoluteLabels(
    List<LevelRowV2> levels,
    double total,
    double achievement,
    double size,
    List<PdfColor> colors,
    double strokeWidth, {
    double radiusOffset = 30,
    double? layoutSize, // ✅ معلمة اختيارية لحجم الحاوية
  }) {
    final labels = <pw.Widget>[];

    // إذا تم تمرير layoutSize نستخدمه للمركز، وإلا نستخدم حجم المخطط نفسه
    final finalSize = layoutSize ?? size;
    final center = finalSize / 2;

    // نصف القطر البصري يعتمد دائماً على حجم المخطط (size)
    final visualRadius = (size / 2) - (strokeWidth / 2);
    final labelRadius = visualRadius + radiusOffset;

    // ✅ 1. تحديث زاوية البداية لتكون من الأعلى (مثل الرسم)
    double currentAngle = pi / 2;

    // لا نحتاج totalAvailableAngle لأننا نحسب الزاوية الكاملة 2*pi ونضرب بالنسبة
    // final totalAvailableAngle = (achievement / 100) * 2 * pi;

    for (int i = 0; i < levels.length; i++) {
      final lvl = levels[i];
      if (lvl.count <= 0) continue;

      final percentOfTotal = lvl.count / total;

      // ✅ 2. تحديث زاوية المسح لتكون سالبة (مع عقارب الساعة)
      final sweepAngle = -1 * percentOfTotal * 2 * pi;

      if (percentOfTotal * 100 >= 3) {
        final midAngle = currentAngle + sweepAngle / 2;

        final x = center + labelRadius * cos(midAngle);
        final y = center + labelRadius * sin(midAngle);

        final color = i < colors.length ? colors[i] : PdfColors.grey;

        labels.add(
          pw.Positioned(
            left: x,
            top: y,
            child: pw.Transform.translate(
              offset: const PdfPoint(-14, -10),
              child: pw.Text(
                '${(percentOfTotal * 100).toStringAsFixed(0)}%'.toAppNum(),
                style: pw.TextStyle(
                  font: amiriBold,
                  fontSize: 10,
                  color: color,
                ),
              ),
            ),
          ),
        );
      }

      currentAngle += sweepAngle;
    }

    // ===== نسبة غير المتقن =====
    final remaining = 100 - achievement;
    if (remaining > 2) {
      // الزاوية المتبقية: من currentAngle حتى نعود إلى pi/2 (بسالب 2pi)
      // لأننا نمشي بالسالب (مع العقارب)، فالدورة الكاملة هي -2pi
      // النهاية هي (pi/2) - 2pi
      double targetAngle = (pi / 2) - 2 * pi;
      double remainingAngle = targetAngle - currentAngle;

      double midGrayAngle = currentAngle + (remainingAngle / 2);

      final x = center + labelRadius * cos(midGrayAngle);
      final y = center + labelRadius * sin(midGrayAngle);

      labels.add(
        pw.Positioned(
          left: x,
          top: y,
          child: pw.Transform.translate(
            offset: const PdfPoint(-14, -10),
            child: pw.Text(
              '${remaining.toStringAsFixed(0)}%'.toAppNum(),
              style: pw.TextStyle(
                font: amiriBold,
                fontSize: 10,
                color: PdfColors.grey,
              ),
            ),
          ),
        ),
      );
    }

    return labels;
  }

  void _drawArcApproximation(
    pdf.PdfGraphics canvas,
    double center,
    double radius,
    double startAngle,
    double sweepAngle,
  ) {
    if (sweepAngle == 0) return;

    final steps = (sweepAngle.abs() * 60).ceil().clamp(8, 200);

    canvas.moveTo(
      center + radius * cos(startAngle),
      center + radius * sin(startAngle),
    );

    for (int i = 1; i <= steps; i++) {
      final t = i / steps;
      final angle = startAngle + sweepAngle * t;

      canvas.lineTo(center + radius * cos(angle), center + radius * sin(angle));
    }
  }

  PdfColor _mixColorWithWhite(PdfColor color, double factor) {
    return PdfColor(
      color.red + (1 - color.red) * factor,
      color.green + (1 - color.green) * factor,
      color.blue + (1 - color.blue) * factor,
    );
  }

  // ... (buildDetailRow, buildSummaryRow نفسهم لم يتغيروا) ...
  // لتوفير المساحة سأضع فقط الدوال التي تحتاجها أو تم تعديلها،
  // الدوال المساعدة الصغيرة التي لم تتغير موجودة لديك.

  // 1. كرت الإحصائيات العلوي (مثل: عدد الطلاب، أعلى درجة...)
  pw.Widget _buildModernStatCard(
    String title,
    String value,
    PdfColor color,
    pw.IconData icon,
  ) {
    return pw.Container(
      width: 75,
      height: 75,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          // ✅ رسم الأيقونة باستخدام الخط
          pw.Text(
            String.fromCharCode(icon.codePoint),
            style: pw.TextStyle(
              font: iconFont, // استخدام الخط المحمل
              fontSize: 20, // حجم الأيقونة
              color: color,
            ),
          ),

          pw.SizedBox(height: 6),
          pw.Text(
            value.toAppNum(),
            style: pw.TextStyle(
              font: amiriBold,
              fontSize: 16,
              color: PdfColors.black,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            title,
            style: pw.TextStyle(
              font: amiriRegular,
              fontSize: 8,
              color: PdfColors.grey600,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 2. صف واحد في جدول المستويات (الزر الملون + النطاق + العدد)
  // ✅ دالة بناء جدول النطاق كاملاً (النسخة الحديثة المطابقة للتطبيق)
  pw.Widget _buildModernLevelsTable(List<LevelRowV2> levels) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        children: [
          // ترويسة الجدول
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Text(
                    'المستوى',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: amiriBold, fontSize: 10),
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Text(
                    'النطاق',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: amiriBold, fontSize: 10),
                  ),
                ),
                pw.Expanded(
                  flex: 1,
                  child: pw.Text(
                    'العدد',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: amiriBold, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          pw.Divider(color: PdfColors.grey300),

          // بناء الصفوف (الأزرار الملونة)
          ...List.generate(levels.length, (i) {
            final lvl = levels[i];
            // الألوان (نفس ألوان التطبيق)
            final colors = [
              colorGreen,
              colorBlue,
              colorPurple,
              colorOrange,
              colorRed,
            ];
            final color = i < colors.length ? colors[i] : PdfColors.grey;

            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Row(
                children: [
                  // زر المستوى (تصميم الزر)
                  pw.Expanded(
                    flex: 3,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: color,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Text(
                        lvl.label,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          font: amiriBold,
                          fontSize: 9,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                  ),
                  // النطاق
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      lvl.rangeLabel.toAppNum(),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        font: amiriRegular,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),

                  // العدد
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      lvl.count.toString().toAppNum(),
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(font: amiriBold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // 3. الرسم البياني الدائري (محاكاة للدونات)
  //✅ بناء الدائرة الحديثة والمطابقة للتطبيق (3D + نسب خارجية + خلفية رمادية)

  // ✅ بناء الدائرة الحديثة والمطابقة للتطبيق (حسب طلب المستخدم)
  pw.Widget _buildModernDonutChart(
    AnalysisStatsV2 stats,
    List<LevelRowV2> levels,
  ) {
    const double size = 140.0;
    const double strokeWidth = 14.0;

    final colors = [colorGreen, colorBlue, colorPurple, colorOrange, colorRed];

    double totalStudents = stats.totalActive.toDouble();
    if (totalStudents <= 0) totalStudents = 1;

    final double achievement = stats.achievementPercent;

    // نحول levels إلى segments مثل UI
    final segments = <_PdfDonutSegment>[];
    for (int i = 0; i < levels.length; i++) {
      final lvl = levels[i];
      if (lvl.count <= 0) continue;

      segments.add(
        _PdfDonutSegment(
          label: lvl.label,
          percent: (lvl.count / totalStudents) * 100,
          color: i < colors.length ? colors[i] : PdfColors.grey,
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'مستوى الإتقان لدى الطالب',
            style: pw.TextStyle(font: segoeFont, fontSize: 12),
          ),
          pw.SizedBox(height: 20),

          pw.SizedBox(
            width: size + 100,
            height: size + 5,
            child: pw.Stack(
              alignment: pw.Alignment.center,
              children: [
                pw.CustomPaint(
                  size: PdfPoint(size, size),
                  painter: (canvas, size) {
                    final center = size.x / 2;
                    final radius = (size.x / 2) - (strokeWidth / 2);

                    // خلفية خفيفة
                    canvas
                      ..setColor(PdfColors.grey200)
                      ..setLineWidth(strokeWidth - 6)
                      ..setLineCap(PdfLineCap.round)
                      ..drawEllipse(center, center, radius, radius)
                      ..strokePath();

                    double startAngle = pi / 2;

                    final totalAvailableAngle = (achievement / 100) * 2 * pi;

                    // ===== الأقواس الملوّنة (الإتقان) =====
                    for (final seg in segments) {
                      final sweepAngle =
                          -1 * (seg.percent / 100) * totalAvailableAngle;

                      // طبقة خارجية
                      canvas
                        ..setColor(_mixColorWithWhite(seg.color, 0.2))
                        ..setLineWidth(strokeWidth + 2)
                        ..setLineCap(PdfLineCap.butt);

                      _drawArcApproximation(
                        canvas,
                        center,
                        radius,
                        startAngle,
                        sweepAngle,
                      );
                      canvas.strokePath();

                      // الطبقة الأساسية
                      canvas
                        ..setColor(seg.color)
                        ..setLineWidth(strokeWidth - 6)
                        ..setLineCap(PdfLineCap.round);

                      _drawArcApproximation(
                        canvas,
                        center,
                        radius,
                        startAngle,
                        sweepAngle,
                      );
                      canvas.strokePath();

                      startAngle += sweepAngle;
                    }

                    // ===== غير المتقن (رمادي) =====
                    final remainingAngle = (-2 * pi) - totalAvailableAngle;

                    if (remainingAngle > 0.001) {
                      canvas
                        ..setColor(PdfColors.grey400)
                        ..setLineWidth(strokeWidth - 6)
                        ..setLineCap(PdfLineCap.round);

                      _drawArcApproximation(
                        canvas,
                        center,
                        radius,
                        startAngle,
                        remainingAngle,
                      );
                      canvas.strokePath();
                    }
                  },
                ),

                // النسبة الوسطية
                pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      '${achievement.toStringAsFixed(1)}%'.toAppNum(),
                      style: pw.TextStyle(font: amiriBold, fontSize: 22),
                    ),
                    pw.Text(
                      'الإتقان',
                      style: pw.TextStyle(
                        font: amiriRegular,
                        fontSize: 10,
                        color: PdfColors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 15),

          // ===== المفاتيح (Legend) =====
          // إضافة مفتاح لكل مستوى + مفتاح "غير متقن"
          pw.Wrap(
            spacing: 8,
            runSpacing: 5,
            alignment: pw.WrapAlignment.center,
            children: [
              // مفاتيح المستويات
              ...segments.map((seg) {
                return pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Container(
                      width: 10,
                      height: 10,
                      decoration: pw.BoxDecoration(
                        color: seg.color,
                        borderRadius: pw.BorderRadius.circular(3),
                      ),
                    ),
                    pw.SizedBox(width: 4),
                    pw.Text(
                      '${seg.label} (${seg.percent.toStringAsFixed(0)}%)'
                          .toAppNum(),
                      style: pw.TextStyle(font: amiriRegular, fontSize: 10),
                    ),
                  ],
                );
              }),

              // مفتاح "غير متقن" (إذا وجد)
              if ((100 - achievement) > 1)
                pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Container(
                      width: 10,
                      height: 10,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey300, // نفس لون الجزء الرمادي
                        borderRadius: pw.BorderRadius.circular(3),
                      ),
                    ),
                    pw.SizedBox(width: 4),
                    pw.Text(
                      'غير متقن (${(100 - achievement).toStringAsFixed(0)}%)'
                          .toAppNum(),
                      style: pw.TextStyle(font: amiriRegular, fontSize: 10),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  // 4. الرسم البياني العمودي
  // ✅ دالة الرسم البياني العمودي (النسخة النهائية المطابقة للتطبيق)
  pw.Widget _buildModernBarChart(List<LevelRowV2> levels) {
    final colors = [colorGreen, colorBlue, colorPurple, colorOrange, colorRed];

    // حساب إجمالي الطلاب لتحديد المقياس ديناميكياً
    int totalStudents = 0;
    for (var lvl in levels) {
      totalStudents += lvl.count;
    }

    // ✅ المقياس: المضاعف التالي لـ 10 (مثلاً إذا كان 30 أو 38 يصبح المقياس 40)
    final int axisMax = ((totalStudents / 10).floor() + 1) * 10;
    const int step = 10;
    final int stepsCount = axisMax ~/ step;

    // ارتفاع منطقة الرسم
    const double chartBodyHeight = 120.0;

    return pw.Container(
      height: 190,
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.grey200),
      ),
      child: pw.Column(
        children: [
          // منطقة الرسم
          pw.SizedBox(
            height: chartBodyHeight,
            child: pw.Stack(
              children: [
                // 1. شبكة الخطوط (رسم الخطوط فقط في طبقة الخلفية)
                ...List.generate(stepsCount + 1, (index) {
                  final double bottomOffset =
                      (index / stepsCount) * chartBodyHeight;
                  return pw.Positioned(
                    bottom: bottomOffset,
                    left: 25, // إزاحة للبدء بعد الأرقام
                    right: 0,
                    child: pw.Container(height: 1, color: PdfColors.grey100),
                  );
                }),

                // 2. الأرقام الجانبية (طبقة منفصلة)
                ...List.generate(stepsCount + 1, (index) {
                  final int value = index * step;
                  final double bottomOffset =
                      (index / stepsCount) * chartBodyHeight;
                  return pw.Positioned(
                    bottom: bottomOffset - 4,
                    left: 0, // الأرقام في أقصى اليسار
                    child: pw.SizedBox(
                      width: 20,
                      child: pw.Text(
                        value.toString().toAppNum(),
                        style: pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey500,
                        ),
                        textAlign: pw
                            .TextAlign
                            .right, // محاذاة الرقم لليمين باتجاه الخط
                      ),
                    ),
                  );
                }),

                // 2. الأعمدة
                pw.Positioned(
                  left: 25, // البدء بعد الأرقام
                  right: 0,
                  bottom: 0,
                  top: 0,
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: List.generate(levels.length, (i) {
                      final lvl = levels[i];
                      final color = i < colors.length
                          ? colors[i]
                          : PdfColors.grey;

                      double heightRatio = (lvl.count / axisMax);
                      if (heightRatio > 1) heightRatio = 1;
                      double barHeight = chartBodyHeight * heightRatio;

                      return pw.Expanded(
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.end,
                          children: [
                            if (lvl.count > 0)
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(bottom: 2),
                                child: pw.Text(
                                  lvl.count.toString().toAppNum(),
                                  style: pw.TextStyle(
                                    font: amiriBold,
                                    fontSize: 10,
                                    color: PdfColors.black,
                                  ),
                                ),
                              ),
                            pw.Container(
                              width: 30,
                              height: barHeight,
                              decoration: pw.BoxDecoration(
                                color: color,
                                borderRadius: const pw.BorderRadius.vertical(
                                  top: pw.Radius.circular(4),
                                ),
                              ),
                            ),
                            // إضافة مساحة صغيرة لكي لا يغطي العمود خط الصفر الأسود تماماً أو العكس حسب الرغبة
                            // هنا نخليه يقف بالضبط فوقه
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          // 3. الجزء السفلي: المسميات
          pw.SizedBox(height: 8),
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 25), // نفس إزاحة الأعمدة
            child: pw.Row(
              children: List.generate(levels.length, (i) {
                return pw.Expanded(
                  child: pw.Text(
                    levels[i].label,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: amiriRegular,
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget buildModernDashboardPage(
    AnalysisStatsV2 stats,
    List<LevelRowV2> levels,
    String subjectName,
  ) {
    // حماية إضافية: إذا لم تكن هناك مستويات، لا تحاول الرسم
    if (levels.isEmpty) return pw.SizedBox();

    return pw.Column(
      children: [
        // العناوين
        pw.Text(
          'تحليل الأداء التحصيلي',
          style: pw.TextStyle(font: segoeFont, fontSize: 16),
        ),

        pw.Text(
          'قراءة شاملة لنتائج الطلاب حسب $subjectName',
          style: pw.TextStyle(
            font: segoeFont,
            fontSize: 9,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Divider(color: PdfColors.grey300, indent: 40, endIndent: 40),
        pw.SizedBox(height: 5),

        // الكروت العلوية (استخدم Wrap لتجنب overflow إذا كانت الشاشة صغيرة)
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, // توزيع متساوي
          children: [
            // 1. عدد الطلاب
            _buildModernStatCard(
              'عدد الطلاب',
              stats.totalStudents.toString().toAppNum(),
              colorGreen,
              const pw.IconData(0xe7fb),
            ), // Groups
            // 2. درجة القياس (العظمى)
            _buildModernStatCard(
              'درجة القياس',
              stats.maxScore.toStringAsFixed(0).toAppNum(),
              colorPurple,
              const pw.IconData(0xe41c),
            ), // Straighten
            // 3. أعلى درجة
            _buildModernStatCard(
              'أعلى درجة',
              stats.highest.toStringAsFixed(0).toAppNum(),
              colorOrange,
              const pw.IconData(0xe838),
            ), // Trophy
            // 4. أقل درجة
            _buildModernStatCard(
              'أقل درجة',
              stats.lowest.toStringAsFixed(0).toAppNum(),
              colorRed,
              const pw.IconData(0xe5db),
            ), // Arrow Down
            // 5. المتوسط
            _buildModernStatCard(
              'المتوسط',
              (stats.average % 1 == 0
                      ? stats.average.toStringAsFixed(0)
                      : stats.average.toStringAsFixed(1))
                  .toAppNum(),
              colorBlue,
              const pw.IconData(0xe6e1),
            ), // Bar Chart
            // 6. نسبة الإتقان (أو المجموع إذا تم اختياره)
            showSum
                ? _buildModernStatCard(
                    'الدرجة الكلية',
                    stats.sum.toStringAsFixed(0).toAppNum(),
                    colorGreen,
                    const pw.IconData(0xe86c),
                  )
                : _buildModernStatCard(
                    'نسبة الإتقان',
                    '${stats.achievementPercent % 1 == 0 ? stats.achievementPercent.toStringAsFixed(0) : stats.achievementPercent.toStringAsFixed(1)}%'
                        .toAppNum(),
                    colorGreen,
                    const pw.IconData(0xe86c),
                  ), // Check Circle
            // 7. مجموع الدرجات (أو عنوان آخر)
            _buildModernStatCard(
              'مجموع الدرجات',
              stats.sum.toStringAsFixed(0).toAppNum(),
              colorPurple,
              const pw.IconData(0xe86c),
            ), // Functions (Sigma)
          ],
        ),
        pw.SizedBox(height: 8),

        // القسم الأوسط (الدائرة والجدول)
        // ✅ استخدمنا Row بارتفاع محدد لتجنب مشاكل Layout
        pw.Container(
          height: 265, // ارتفاع ثابت للقسم الأوسط
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // الدائرة
              pw.Expanded(
                flex: 3,
                child: _buildModernDonutChart(stats, levels),
              ),
              pw.SizedBox(width: 05),
              // الجدول
              pw.Expanded(flex: 2, child: _buildModernLevelsTable(levels)),
            ],
          ),
        ),

        pw.SizedBox(height: 5),

        // الرسم البياني السفلي
        pw.Container(
          height: 190, // ارتفاع ثابت
          child: _buildModernBarChart(levels),
        ),
      ],
    );
  }

  pw.Widget _buildSummaryRow(String title, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 5,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: mainColor, width: 0.8),
              ),
              alignment: pw.Alignment.center,
              child: pw.Text(
                title,
                style: pw.TextStyle(
                  font: amiriBold,
                  fontSize: 10,
                  color: mainColor,
                ),
              ),
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            flex: 4,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: pdf.PdfColors.grey600, width: 0.5),
              ),
              alignment: pw.Alignment.center,
              child: pw.Text(
                value.toAppNum(),
                style: pw.TextStyle(font: amiriRegular, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget buildFullHeader({required String pageTitle}) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  meta.regionName.isEmpty
                      ? 'المملكة العربية السعودية'
                      : meta.regionName,
                  style: pw.TextStyle(font: amiriBold, fontSize: 10),
                ),
                pw.Text(
                  meta.ministryLabel,
                  style: pw.TextStyle(font: amiriBold, fontSize: 10),
                ),
                pw.Text(
                  meta.officeName.isEmpty
                      ? 'الإدارة العامة للتعليم'
                      : meta.officeName,
                  style: pw.TextStyle(font: amiriBold, fontSize: 10),
                ),
                pw.Text(
                  meta.schoolName.isEmpty ? 'المدرسة ....' : meta.schoolName,
                  style: pw.TextStyle(font: amiriBold, fontSize: 10),
                ),
              ],
            ),
            pw.Container(
              height: 60,
              width: 100,
              child: logo != null
                  ? pw.Image(logo!, fit: pw.BoxFit.contain)
                  : pw.SizedBox(),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  (meta.examTitle.isEmpty
                          ? 'اختبار'
                          : 'المادة : ${meta.examTitle}')
                      .toAppNum(),
                  style: pw.TextStyle(font: amiriBold, fontSize: 10),
                ),
                pw.Text(
                  'الصف ${meta.stageClass.toAppNum()}',
                  style: pw.TextStyle(font: amiriBold, fontSize: 10),
                ),
                pw.Text(
                  'الفصل الدراسي ${meta.yearText.toAppNum()}',
                  style: pw.TextStyle(font: amiriBold, fontSize: 10),
                ),
                pw.Text(
                  'للعام ${meta.academicYear.toAppNum()}',
                  style: pw.TextStyle(font: amiriBold, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Stack(
          alignment: pw.Alignment.center,
          children: [
            pw.Column(
              children: [
                pw.Container(height: 0.5, color: pdf.PdfColors.grey400),
                pw.SizedBox(height: 1.5),
                pw.Container(height: 0.5, color: pdf.PdfColors.grey400),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget buildFooter() {
    return pw.Column(
      children: [
        pw.SizedBox(height: 20),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 50.0),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                children: [
                  pw.Text(
                    'معلم المادة',
                    style: pw.TextStyle(font: amiriBold, fontSize: 10),
                  ),
                  pw.Text(
                    meta.teacherName,
                    style: pw.TextStyle(font: amiriRegular, fontSize: 14),
                  ),
                ],
              ),
              pw.Column(
                children: [
                  pw.Text(
                    'مدير المدرسة',
                    style: pw.TextStyle(font: amiriBold, fontSize: 10),
                  ),
                  pw.Text(
                    meta.principalName,
                    style: pw.TextStyle(font: amiriRegular, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          color: pdf.PdfColors.grey300,
          alignment: pw.Alignment.center,
          child: pw.Text(
            'حقوق النشر محفوظة - RASHEED ALQAM'.toAppNum(),
            style: pw.TextStyle(
              font: amiriRegular,
              fontSize: 9,
              color: pdf.PdfColors.grey900,
            ),
          ),
        ),
      ],
    );
  }

  // 👇👇👇👇 تم التعديل هنا (الحل الجذري) 👇👇👇👇
  pw.Widget buildLevelPageHeader({
    required String levelLabel,
    required pdf.PdfColor headerColor,
  }) {
    // ⚠️ أزلنا استدعاء buildPage3Title() من هنا
    // الآن هذه الدالة ترسم الشريط الملون فقط
    return pw.Header(
      child: pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        decoration: pw.BoxDecoration(
          color: headerColor,
          borderRadius: const pw.BorderRadius.vertical(
            top: pw.Radius.circular(6),
          ),
        ),
        alignment: pw.Alignment.center,
        child: pw.Text(
          levelLabel,
          style: pw.TextStyle(
            font: amiriBold,
            fontSize: 11,
            color: pdf.PdfColors.white,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ),
    );
  }

  // بقية الدوال كما هي (buildStudentListTable, buildAggregatedLevelTableOnlyBody, etc)
  // ... (تأكد من نسخها من الكود السابق أو تركها كما كانت لديك)
  // سأعيد كتابتها للتأكد من أن الملف يعمل مباشرة عند النسخ

  List<pw.Widget> buildStudentListTable(
    String title,
    List<MockStudent> list,
    pdf.PdfColor headerColor,
  ) {
    return [
      pw.Header(
        child: pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          decoration: pw.BoxDecoration(
            color: headerColor,
            borderRadius: const pw.BorderRadius.vertical(
              top: pw.Radius.circular(6),
            ),
          ),
          alignment: pw.Alignment.center,
          child: pw.Text(
            title,
            style: pw.TextStyle(
              font: amiriBold,
              fontSize: 11,
              color: pdf.PdfColors.white,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ),
      pw.Table.fromTextArray(
        border: pw.TableBorder.all(color: pdf.PdfColors.grey400, width: 0.5),
        headerDecoration: pw.BoxDecoration(color: pdf.PdfColors.grey100),
        headerStyle: pw.TextStyle(font: amiriBold, fontSize: 9),
        cellStyle: pw.TextStyle(font: amiriRegular, fontSize: 9),
        cellAlignment: pw.Alignment.center,
        cellAlignments: {2: pw.Alignment.centerRight},
        columnWidths: {
          3: const pw.FlexColumnWidth(0.7),
          2: const pw.FlexColumnWidth(3.0),
          1: const pw.FlexColumnWidth(1.0),
          0: const pw.FlexColumnWidth(1.7),
        },
        headers: <String>['الدرجة', 'الصف ', 'اسم الطالب', 'م'],
        data: list.asMap().entries.map((entry) {
          int idx = entry.key + 1;
          var s = entry.value;
          String displayName = (s.name.isNotEmpty ? s.name : '—')
              .replaceAll('\n', ' ')
              .trim();

          // 1. محاولة استخراج اسم الصف من الاسم إذا كان موجوداً بين قوسين
          String? extractedClass;
          if (displayName.contains('(') && displayName.contains(')')) {
            try {
              final start = displayName.lastIndexOf('(');
              final end = displayName.indexOf(')', start);
              if (end > start) {
                extractedClass = displayName.substring(start + 1, end).trim();
                displayName = displayName.substring(0, start).trim();
              }
            } catch (_) {}
          }

          // 2. استخدام className المباشر أو المستخرج
          String displayClass = s.className.isNotEmpty
              ? s.className
              : (extractedClass != null && extractedClass.isNotEmpty
                    ? extractedClass
                    : meta.stageClass);

          return [
            formatGrade(s.tempScore ?? 0),
            displayClass.toAppNum(),
            displayName,
            idx.toString().toAppNum(),
          ];
        }).toList(),
      ),
    ];
  }

  List<pw.Widget> buildAggregatedLevelTableOnlyBody(
    List<MockStudent> list, {
    String? levelTitle,
    PdfColor? levelColor,
  }) {
    final widgets = <pw.Widget>[];

    // تعديل: استخدام Container بدل Header لإزالة الفراغ السفلي ولصقه بالجدول
    if (levelTitle != null && levelColor != null) {
      widgets.add(
        pw.Container(
          width: double.infinity,
          // إزالة الهوامش السفلية لضمان الالتصاق
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          decoration: pw.BoxDecoration(
            color: levelColor,
            // جعل الزوايا العلوية فقط دائرية، والسفلية حادة لتلتحم مع الجدول
            borderRadius: const pw.BorderRadius.vertical(
              top: pw.Radius.circular(6),
            ),
          ),
          alignment: pw.Alignment.center,
          child: pw.Text(
            levelTitle,
            style: pw.TextStyle(
              font: amiriBold,
              fontSize: 11,
              color: pdf.PdfColors.white,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
      );
    }

    // إضافة الجدول
    widgets.add(
      pw.Table.fromTextArray(
        // تنسيق الحدود لتتناسب مع الترويسة
        border: pw.TableBorder.all(color: pdf.PdfColors.grey400, width: 0.5),
        headerDecoration: const pw.BoxDecoration(color: pdf.PdfColors.grey100),
        headerStyle: pw.TextStyle(font: amiriBold, fontSize: 9),
        cellStyle: pw.TextStyle(font: amiriRegular, fontSize: 9),
        cellAlignment: pw.Alignment.center,
        cellAlignments: {2: pw.Alignment.centerRight},
        columnWidths: {
          3: const pw.FlexColumnWidth(0.7),
          2: const pw.FlexColumnWidth(3.0),
          1: const pw.FlexColumnWidth(1.0),
          0: const pw.FlexColumnWidth(1.7),
        },
        headers: <String>['الدرجة', 'الصف', 'اسم الطالب', 'م'],
        data: list.asMap().entries.map((entry) {
          int idx = entry.key + 1;
          var s = entry.value;
          String displayName = (s.name.isNotEmpty ? s.name : '—')
              .replaceAll('\n', ' ')
              .trim();

          // 1. محاولة استخراج اسم الصف من الاسم إذا كان موجوداً بين قوسين
          String? extractedClass;
          if (displayName.contains('(') && displayName.contains(')')) {
            try {
              final start = displayName.lastIndexOf('(');
              final end = displayName.indexOf(')', start);
              if (end > start) {
                extractedClass = displayName.substring(start + 1, end).trim();
                displayName = displayName.substring(0, start).trim();
              }
            } catch (_) {}
          }

          // 2. استخدام className المباشر أو المستخرج
          String displayClass = s.className.isNotEmpty
              ? s.className
              : (extractedClass != null && extractedClass.isNotEmpty
                    ? extractedClass
                    : meta.stageClass);

          return [
            formatGrade(s.tempScore ?? 0),
            displayClass.toAppNum(),
            displayName,
            idx.toString().toAppNum(),
          ];
        }).toList(),
      ),
    );

    return widgets;
  }

  pw.Widget _buildDetailRow(
    String label,
    String range,
    String count,
    PdfColor color,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              decoration: pw.BoxDecoration(
                color: color,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                label,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  font: amiriBold,
                  fontSize: 9,
                  color: PdfColors.white,
                ),
              ),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              range,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: amiriRegular, fontSize: 10),
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              count,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: amiriBold, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget buildStatsSummary(AnalysisStatsV2 stats, List<LevelRowV2> levels) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            children: [
              pw.SizedBox(height: 22),
              _buildSummaryRow(
                'عدد الطــلاب',
                stats.totalStudents.toString().toAppNum(),
              ),
              _buildSummaryRow(
                'أعلى درجــــة',
                stats.highest
                    .toStringAsFixed(stats.highest % 1 == 0 ? 0 : 1)
                    .toAppNum(),
              ),
              _buildSummaryRow(
                'أقل درجـــــــة',
                stats.lowest
                    .toStringAsFixed(stats.lowest % 1 == 0 ? 0 : 1)
                    .toAppNum(),
              ),
              _buildSummaryRow(
                'متوسط الدرجات',
                stats.average.toStringAsFixed(1).toAppNum(),
              ),
              _buildSummaryRow(
                'نسبة التحصيل',
                '${stats.achievementPercent.toStringAsFixed(1)}%'.toAppNum(),
              ),
              _buildSummaryRow(
                'مجموع الدرجات',
                stats.sum.toStringAsFixed(0).toAppNum(),
              ),
            ],
          ),
        ),
        pw.SizedBox(width: 15),
        pw.Expanded(
          flex: 5,
          child: pw.Column(
            children: [
              pw.Text(
                'الإحصائيات التفصيلية',
                style: pw.TextStyle(
                  font: amiriBold,
                  fontSize: 11,
                  color: mainColor,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Center(
                      child: pw.Text(
                        'المستوى',
                        style: pw.TextStyle(font: amiriRegular, fontSize: 9),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Center(
                      child: pw.Text(
                        'النطاق',
                        style: pw.TextStyle(font: amiriRegular, fontSize: 9),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Center(
                      child: pw.Text(
                        'عدد الطلاب',
                        style: pw.TextStyle(font: amiriRegular, fontSize: 9),
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              ...levels.map(
                (row) => _buildDetailRow(
                  row.label,
                  row.rangeLabel.toAppNum(),
                  row.count.toString().toAppNum(),
                  pdf.PdfColor.fromInt(row.color.value & 0xFFFFFF),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget buildChartsSection(AnalysisStatsV2 stats, List<LevelRowV2> levels) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: mainColor, width: 1.5),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
        children: [
          pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                'رسم بياني (نسب الطلاب لكل تقدير)'.toAppNum(),
                style: pw.TextStyle(
                  font: amiriBold,
                  fontSize: 10,
                  color: mainColor,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: levels.map((lvl) {
                  final percent = stats.totalActive == 0
                      ? 0.0
                      : (lvl.count / stats.totalActive);
                  final color = pdf.PdfColor.fromInt(
                    lvl.color.value & 0xFFFFFF,
                  );
                  return pw.Column(
                    children: [
                      pw.Container(
                        width: 50,
                        height: 50,
                        child: pw.Stack(
                          alignment: pw.Alignment.center,
                          children: [
                            pw.CircularProgressIndicator(
                              value: percent,
                              color: color,
                              backgroundColor: pdf.PdfColors.grey300,
                              strokeWidth: 5,
                            ),
                            pw.Text(
                              '${(percent * 100).toStringAsFixed(0)}%'
                                  .toAppNum(),
                              style: pw.TextStyle(font: amiriBold, fontSize: 9),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        lvl.label,
                        style: pw.TextStyle(font: amiriRegular, fontSize: 9),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
          pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.SizedBox(height: 10),
              pw.Text(
                'رسم بياني (عدد الطلاب لكل تقدير)'.toAppNum(),
                style: pw.TextStyle(
                  font: amiriBold,
                  fontSize: 10,
                  color: mainColor,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.SizedBox(
                height: 90,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: levels.map((lvl) {
                    final maxCount = levels.fold<int>(
                      0,
                      (p, l) => l.count > p ? l.count : p,
                    );
                    final h = maxCount == 0
                        ? 0.0
                        : (lvl.count / maxCount) * 60.0;
                    final color = pdf.PdfColor.fromInt(
                      lvl.color.value & 0xFFFFFF,
                    );
                    return pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.end,
                      children: [
                        pw.Text(
                          lvl.count.toString().toAppNum(),
                          style: pw.TextStyle(font: amiriBold, fontSize: 9),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Stack(
                          alignment: pw.Alignment.bottomCenter,
                          children: [
                            pw.Container(
                              width: 30,
                              height: 60,
                              decoration: pw.BoxDecoration(
                                color: pdf.PdfColors.grey300,
                                borderRadius: const pw.BorderRadius.vertical(
                                  top: pw.Radius.circular(4),
                                ),
                              ),
                            ),
                            pw.Container(
                              width: 30,
                              height: h + 1,
                              decoration: pw.BoxDecoration(
                                color: color,
                                borderRadius: const pw.BorderRadius.vertical(
                                  top: pw.Radius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 3),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget buildPage3Title() {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Stack(
        alignment: pw.Alignment.center,
        children: [
          pw.Column(
            children: [
              pw.Container(height: 0.5, color: pdf.PdfColors.grey400),
              pw.SizedBox(height: 1.5),
              pw.Container(height: 0.5, color: pdf.PdfColors.grey400),
            ],
          ),
          pw.Container(
            color: pdf.PdfColors.white,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10),
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 30,
                vertical: 5,
              ),
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: mainColor, width: 0.8),
              ),
              child: pw.Text(
                meta.page3Title.toAppNum(),
                style: pw.TextStyle(font: amiriBold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget buildAggregatedStatsTable(List<LevelRowV2> levels) {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Table(
        border: pw.TableBorder.all(color: pdf.PdfColors.grey400, width: 0.5),
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(
              color: pdf.PdfColors.black,
              borderRadius: pw.BorderRadius.vertical(
                top: pw.Radius.circular(6),
              ),
            ),
            children: [
              pw.Container(height: 30),
              pw.Container(
                height: 30,
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'الإحصائيات التفصيلية'.toAppNum(),
                  style: pw.TextStyle(
                    font: amiriBold,
                    fontSize: 11,
                    color: pdf.PdfColors.white,
                  ),
                ),
              ),
              pw.Container(height: 30),
            ],
          ),
          pw.TableRow(
            decoration: pw.BoxDecoration(color: pdf.PdfColors.grey100),
            children: [
              pw.Center(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    'المستوى',
                    style: pw.TextStyle(font: amiriBold, fontSize: 9),
                  ),
                ),
              ),
              pw.Center(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    'النطاق',
                    style: pw.TextStyle(font: amiriBold, fontSize: 9),
                  ),
                ),
              ),
              pw.Center(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    'عدد الطلاب',
                    style: pw.TextStyle(font: amiriBold, fontSize: 9),
                  ),
                ),
              ),
            ],
          ),
          ...levels.map(
            (lvl) => pw.TableRow(
              children: [
                pw.Center(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      lvl.label.toAppNum(),
                      style: pw.TextStyle(font: amiriBold, fontSize: 9),
                    ),
                  ),
                ),
                pw.Center(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      lvl.rangeLabel.toAppNum(),
                      style: pw.TextStyle(font: amiriRegular, fontSize: 9),
                    ),
                  ),
                ),
                pw.Center(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(4),
                    child: pw.Text(
                      lvl.count.toString().toAppNum(),
                      style: pw.TextStyle(font: amiriBold, fontSize: 9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PdfDonutSegment {
  final String label;
  final double percent;
  final PdfColor color;

  _PdfDonutSegment({
    required this.label,
    required this.percent,
    required this.color,
  });
}
