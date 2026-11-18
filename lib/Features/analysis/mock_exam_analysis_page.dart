// lib/mock_exam_analysis_page.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart' as ex;
import 'package:student_grades_app/models/mock_student.dart';

import '../home/home_page.dart';
import '../../../services/backup_service.dart';
import '../security/security/security_settings_page.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/main_bottom_bar.dart';

import '../../core/settings/app_settings.dart';
import 'package:student_grades_app/core/utils/number_utils.dart';
import 'package:student_grades_app/Features/analysis/widgets/wave_bar_chart.dart'; // New import

// ==========================================
// 1. الكلاسات المساعدة والموديلات
// ==========================================

class AppNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String newText = newValue.text;
    if (AppSettings.useArabicNumbers.value) {
      newText = newText.toAppNum();
    } else {
      newText = newText.toEnglishNum();
    }
    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

enum AnalysisTargetType {
  exam1,
  exam2,
  exam3,
  exam4,
  exam5,
  exam6,
  exam7,
  exam8,
  average,
}

class LevelConfig {
  String label;
  double minPercent;
  LevelConfig({required this.label, required this.minPercent});
  Map<String, dynamic> toJson() => {'label': label, 'minPercent': minPercent};
  factory LevelConfig.fromJson(Map<String, dynamic> m) => LevelConfig(
    label: m['label']?.toString() ?? '',
    minPercent: (m['minPercent'] as num?)?.toDouble() ?? 0.0,
  );
}

class AnalysisStats {
  final double maxScore;
  final int totalStudents;
  final int activeStudents;
  final double highest;
  final double lowest;
  final double average;
  final double sum;
  final double achievementPercent;
  final Map<String, int> levelCounts;
  final List<String> levelLabels;
  bool get hasData => activeStudents > 0;
  int get totalActive => activeStudents;

  AnalysisStats({
    required this.maxScore,
    required this.totalStudents,
    required this.activeStudents,
    required this.highest,
    required this.lowest,
    required this.average,
    required this.sum,
    required this.achievementPercent,
    required this.levelCounts,
    required this.levelLabels,
  });

  factory AnalysisStats.empty({
    required double maxScore,
    required int totalStudents,
    required List<String> levelLabels,
  }) => AnalysisStats(
    maxScore: maxScore,
    totalStudents: totalStudents,
    activeStudents: 0,
    highest: 0,
    lowest: 0,
    average: 0,
    sum: 0,
    achievementPercent: 0,
    levelCounts: {for (final lbl in levelLabels) lbl: 0},
    levelLabels: levelLabels,
  );

  List<_LevelRow> levelsWithRanges(List<LevelConfig> configs) {
    final max = maxScore <= 0 ? 20.0 : maxScore;
    final sorted = List<LevelConfig>.from(configs)
      ..sort((a, b) => b.minPercent.compareTo(a.minPercent));
    String fmt(double v) =>
        v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    final List<_LevelRow> rows = [];
    const colors = [
      Color(0xFF00C853), // Vibrant Green (Excellent)
      Color(0xFF2980b9), // Strong Blue (Good)
      Color(0xFF7a69d1), // Darker Orange (Acceptable)
      Color(0xFFfdcc49), // Dark Green (Very Good)
      Color(0xFFc0392b), // Darker/Stronger Red (Poor)
    ];
    for (int i = 0; i < sorted.length; i++) {
      final lvl = sorted[i];
      final minP = lvl.minPercent.clamp(0, 100);
      final maxP = i == 0
          ? 100.0
          : sorted[i - 1].minPercent.clamp(0, 100) - 0.01;
      rows.add(
        _LevelRow(
          label: lvl.label,
          rangeLabel:
              '${fmt(max * (minP / 100.0))} - ${fmt(max * (maxP / 100.0))}',
          count: levelCounts[lvl.label] ?? 0,
          color: colors[i.clamp(0, colors.length - 1)],
        ),
      );
    }
    return rows;
  }
}

class _LevelRow {
  final String label;
  final String rangeLabel;
  final int count;
  final Color color;
  _LevelRow({
    required this.label,
    required this.rangeLabel,
    required this.count,
    required this.color,
  });
}

// ==========================================
// 2. الصفحة الرئيسية (StatefulWidget)
// ==========================================

class MockExamAnalysisPage extends StatefulWidget {
  final String classId;
  final String classTitle;
  const MockExamAnalysisPage({
    super.key,
    required this.classId,
    required this.classTitle,
  });
  @override
  State<MockExamAnalysisPage> createState() => _MockExamAnalysisPageState();
}

class _MockExamAnalysisPageState extends State<MockExamAnalysisPage> {
  static const _levelsPrefsKey = 'mock_analysis_levels_v1';
  static const _reportMetaPrefix = 'mock_analysis_report_meta_v1_';
  late final String storageKey;
  late final String metaKey;
  int _bottomIndex = 0;
  List<MockStudent> students = [];
  List<double> _examMax = List<double>.filled(8, 20.0);
  List<LevelConfig> _levels = _defaultLevels();
  int _levelsCount = 5;
  AnalysisTargetType _target = AnalysisTargetType.exam1;

  String _academicYear = '';
  String _schoolName = '';
  String _regionName = '';
  String _officeName = '';
  String _stageClass = '';
  String _yearText = '';
  String _subjectName = '';
  String _examTitleText = 'الاختبار';
  String _teacherName = '';
  String _principalName = '';
  String _ministryLabel = 'وزارة التعليم';
  String _pdfPage1Title = 'تحليل نتائج اختبار مادة ';
  String _pdfPage2Title = 'كشف بأسماء الطلاب الأوائل والمتأخرين دراسياً';
  String _pdfPage3Title = 'قوائم الطلاب مصنفة حسب التقدير (المستوى)';

  String get _reportMetaKey => '$_reportMetaPrefix${widget.classId}';

  pw.Font? _cachedRegularFont;
  pw.Font? _cachedBoldFont;
  pw.MemoryImage? _cachedMinistryLogo;
  bool _assetsLoaded = false;

  @override
  void initState() {
    super.initState();
    storageKey = 'mock_exam_${widget.classId}_v1';
    metaKey = '${storageKey}_meta';
    _loadData();
    _preparePdfAssets();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(storageKey);
    if (str != null && str.isNotEmpty) {
      try {
        students = (jsonDecode(str) as List)
            .map((e) => MockStudent.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {}
    }
    final metaStr = prefs.getString(metaKey);
    if (metaStr != null && metaStr.isNotEmpty) {
      try {
        final List decoded = jsonDecode(metaStr);
        final tmp = <double>[];
        for (int i = 0; i < 8; i++) {
          tmp.add(
            (i < decoded.length
                    ? double.tryParse(decoded[i].toString())
                    : null) ??
                20.0,
          );
        }
        _examMax = tmp;
      } catch (_) {
        _examMax = List<double>.filled(8, 20.0);
      }
    }
    final lvlStr = prefs.getString(_levelsPrefsKey);
    if (lvlStr != null && lvlStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(lvlStr) as Map;
        _levelsCount = (decoded['count'] as int?)?.clamp(2, 5) ?? 5;
        if (decoded['levels'] is List) {
          _levels = _padOrTrimLevels(
            (decoded['levels'] as List)
                .map((e) => LevelConfig.fromJson(Map<String, dynamic>.from(e)))
                .toList(),
          );
        }
      } catch (_) {}
    }
    final reportStr = prefs.getString(_reportMetaKey);
    if (reportStr != null && reportStr.isNotEmpty) {
      try {
        final m = jsonDecode(reportStr) as Map<String, dynamic>;
        _schoolName = m['schoolName']?.toString() ?? '';
        _regionName = m['regionName']?.toString() ?? '';
        _ministryLabel = m['ministryLabel']?.toString() ?? 'وزارة التعليم';
        _officeName = m['officeName']?.toString() ?? '';
        _stageClass = m['stageClass']?.toString() ?? widget.classTitle;
        _yearText = m['yearText']?.toString() ?? '';
        _subjectName = m['subjectName']?.toString() ?? 'الرياضيات';
        _examTitleText = m['examTitleText']?.toString() ?? 'الاختبار';
        _teacherName = m['teacherName']?.toString() ?? '';
        _principalName = m['principalName']?.toString() ?? '';
        if (m['pdfPage1Title'] != null) _pdfPage1Title = m['pdfPage1Title'];
        if (m['pdfPage2Title'] != null) _pdfPage2Title = m['pdfPage2Title'];
        if (m['pdfPage3Title'] != null) _pdfPage3Title = m['pdfPage3Title'];
      } catch (_) {}
    } else {
      _stageClass = widget.classTitle;
    }
    setState(() {});
  }

  Future<void> _saveLevels() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _levelsPrefsKey,
      jsonEncode({
        'count': _levelsCount,
        'levels': _levels.map((e) => e.toJson()).toList(),
      }),
    );
  }

  Future<void> _saveReportMeta() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _reportMetaKey,
      jsonEncode({
        'schoolName': _schoolName,
        'regionName': _regionName,
        'ministryLabel': _ministryLabel,
        'officeName': _officeName,
        'stageClass': _stageClass,
        'yearText': _yearText,
        'academicYear': _academicYear,
        'subjectName': _subjectName,
        'examTitleText': _examTitleText,
        'teacherName': _teacherName,
        'principalName': _principalName,
        'pdfPage1Title': _pdfPage1Title,
        'pdfPage2Title': _pdfPage2Title,
        'pdfPage3Title': _pdfPage3Title,
      }),
    );
  }

  int _targetIndex() => AnalysisTargetType.values.indexOf(_target);
  double _maxScoreForTarget() =>
      _targetIndex() < 8 ? _examMax[_targetIndex()] : 20.0;
  double _scoreForStudent(MockStudent s) {
    final idx = _targetIndex();
    if (idx < 8) return s.exams[idx] ?? 0.0;
    double sum = 0.0;
    for (int i = 0; i < 8; i++) {
      sum += ((s.exams[i] ?? 0.0) / _examMax[i]) * 20.0;
    }
    return sum / 8.0;
  }

  List<LevelConfig> _activeLevels() =>
      _levels.take(_levelsCount).toList()
        ..sort((a, b) => b.minPercent.compareTo(a.minPercent));
  String _levelForScore(double score) {
    final percent = (score / _maxScoreForTarget()) * 100.0;
    final levels = _activeLevels();
    return levels
        .firstWhere(
          (lvl) => percent >= lvl.minPercent,
          orElse: () => levels.last,
        )
        .label;
  }

  AnalysisStats _calculateStats() {
    final maxScore = _maxScoreForTarget();
    final activeLevels = _activeLevels();
    final scores = students.map((s) => _scoreForStudent(s)).toList();
    if (scores.isEmpty)
      return AnalysisStats.empty(
        maxScore: maxScore,
        totalStudents: students.length,
        levelLabels: activeLevels.map((e) => e.label).toList(),
      );
    scores.sort();
    final sum = scores.fold(0.0, (p, e) => p + e);
    final avg = sum / scores.length;
    final levelCounts = {for (final l in activeLevels) l.label: 0};
    for (final s in scores) {
      final lvl = _levelForScore(s);
      levelCounts[lvl] = (levelCounts[lvl] ?? 0) + 1;
    }
    return AnalysisStats(
      maxScore: maxScore,
      totalStudents: students.length,
      activeStudents: scores.length,
      highest: scores.last,
      lowest: scores.first,
      average: avg,
      sum: sum,
      achievementPercent: (avg / maxScore) * 100.0,
      levelCounts: levelCounts,
      levelLabels: activeLevels.map((e) => e.label).toList(),
    );
  }

  List<MockStudent> _getStudentsForLevel(LevelConfig level) {
    final maxScore = _maxScoreForTarget();
    final activeLevels = _activeLevels();
    final levelIndex = activeLevels.indexOf(level);
    double upperLimitPercent = 100.001;
    if (levelIndex > 0) {
      upperLimitPercent = activeLevels[levelIndex - 1].minPercent;
    }
    return students.where((s) {
      final score = s.tempScore ?? 0.0;
      final percent = (score / maxScore) * 100.0;
      if (levelIndex == 0) return percent >= level.minPercent;
      return percent >= level.minPercent && percent < upperLimitPercent;
    }).toList()..sort((a, b) => (b.tempScore ?? 0).compareTo(a.tempScore ?? 0));
  }

  Future<void> _preparePdfAssets() async {
    if (_assetsLoaded) return;
    try {
      final regularData = await rootBundle.load(
        'assets/fonts/Amiri-Regular.ttf',
      );
      _cachedRegularFont = pw.Font.ttf(regularData);
      final boldData = await rootBundle.load('assets/fonts/Amiri-Bold.ttf');
      _cachedBoldFont = pw.Font.ttf(boldData);
      final logoData = await rootBundle.load('assets/images/ministry_logo.png');
      _cachedMinistryLogo = pw.MemoryImage(logoData.buffer.asUint8List());
      _assetsLoaded = true;
    } catch (e) {
      debugPrint('Error loading PDF assets: $e');
    }
  }

  // ----------------------------------------------------------------------
  // دالة 1: تصدير للصفوف الفردية (كما هي)
  // ----------------------------------------------------------------------
  Future<void> _exportSingleClassPdf() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          const Center(child: CircularProgressIndicator(color: Colors.teal)),
    );
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      if (!_assetsLoaded) await _preparePdfAssets();
      final stats = _calculateStats();
      if (!stats.hasData) {
        Navigator.pop(context);
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('لا توجد بيانات')));
        return;
      }

      final levels = stats.levelsWithRanges(_activeLevels());
      for (var s in students) {
        s.tempScore = _scoreForStudent(s);
      }
      students.sort((a, b) => (b.tempScore ?? -1).compareTo(a.tempScore ?? -1));

      final top10 = students.take(10).toList();
      final bottom10 = students
          .where((s) => (s.tempScore ?? 0) >= 0)
          .toList()
          .reversed
          .take(10)
          .toList();

      final amiriRegular = _cachedRegularFont ?? pw.Font.courier();
      final amiriBold = _cachedBoldFont ?? pw.Font.courierBold();
      final mainColor = pdf.PdfColor.fromInt(0xFF27ae60);
      final redColor = pdf.PdfColors.red400;

      final doc = pw.Document();

      final widgets = _PdfWidgets(
        amiriBold: amiriBold,
        amiriRegular: amiriRegular,
        mainColor: mainColor,
        redColor: redColor,
        regionName: _regionName,
        ministryLabel: _ministryLabel,
        officeName: _officeName,
        schoolName: _schoolName,
        logo: _cachedMinistryLogo,
        examTitle: _examTitleText,
        stageClass: _stageClass,
        yearText: _yearText,
        academicYear: _academicYear,
        teacherName: _teacherName,
        principalName: _principalName,
        page3Title: _pdfPage3Title,
      );

      // صفحة 1: التحليل البياني
      doc.addPage(
        pw.Page(
          pageFormat: pdf.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (ctx) => pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              children: [
                widgets.buildFullHeader(pageTitle: _pdfPage1Title),
                pw.SizedBox(height: 15),
                widgets.buildStatsSummary(stats, levels),
                pw.SizedBox(height: 15),
                widgets.buildChartsSection(stats, levels),
                pw.Spacer(),
                widgets.buildFooter(),
              ],
            ),
          ),
        ),
      );

      // صفحة 2: الأوائل والمتأخرين
      doc.addPage(
        pw.Page(
          pageFormat: pdf.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (ctx) => pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              children: [
                widgets.buildFullHeader(pageTitle: _pdfPage2Title),
                pw.SizedBox(height: 15),
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: widgets.buildStudentListTable(
                          'العشرة الأوائل'.toAppNum(),
                          top10,
                          mainColor,
                        ),
                      ),
                      pw.SizedBox(width: 15),
                      pw.Expanded(
                        child: widgets.buildStudentListTable(
                          'الطلاب الأقل أداءً'.toAppNum(),
                          bottom10.reversed.toList(),
                          redColor,
                        ),
                      ),
                    ],
                  ),
                ),
                widgets.buildFooter(),
              ],
            ),
          ),
        ),
      );

      // صفحة 3: المستويات
      doc.addPage(
        pw.MultiPage(
          pageFormat: pdf.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          theme: pw.ThemeData.withFont(base: amiriRegular, bold: amiriBold),
          textDirection: pw.TextDirection.rtl,
          header: (ctx) => widgets.buildPage3Title(),
          footer: (ctx) => widgets.buildFooter(),
          build: (ctx) {
            final activeLevels = _activeLevels();
            final List<pw.Widget> gridItems = [];
            const colors = [
              pdf.PdfColor.fromInt(0xFF2ecc71),
              pdf.PdfColor.fromInt(0xFF27ae60),
              pdf.PdfColor.fromInt(0xFF3498db),
              pdf.PdfColor.fromInt(0xFFe67e22),
              pdf.PdfColor.fromInt(0xFFe74c3c),
            ];
            for (int i = 0; i < activeLevels.length; i++) {
              gridItems.add(
                widgets.buildStudentListTable(
                  activeLevels[i].label.toAppNum(),
                  _getStudentsForLevel(activeLevels[i]),
                  colors[i % colors.length],
                ),
              );
            }
            gridItems.add(widgets.buildStatsTable(levels));

            final List<pw.Widget> pageContent = [];
            for (int i = 0; i < gridItems.length; i += 2) {
              pageContent.add(
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(child: gridItems[i]),
                    pw.SizedBox(width: 15),
                    pw.Expanded(
                      child: (i + 1 < gridItems.length)
                          ? gridItems[i + 1]
                          : pw.SizedBox(),
                    ),
                  ],
                ),
              );
              pageContent.add(pw.SizedBox(height: 15));
            }
            return pageContent;
          },
        ),
      );

      Navigator.pop(context);
      await Printing.layoutPdf(onLayout: (format) async => doc.save());
    } catch (e) {
      Navigator.pop(context);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  // ----------------------------------------------------------------------
  // دالة 2: تصدير للبيانات المجمعة (تحليل مرحلة/شامل) - أداء عالي + تكرار العنوان
  // ----------------------------------------------------------------------
  Future<void> _exportAggregatedPdf() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          const Center(child: CircularProgressIndicator(color: Colors.purple)),
    );
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      if (!_assetsLoaded) await _preparePdfAssets();
      final stats = _calculateStats();
      if (!stats.hasData) {
        Navigator.pop(context);
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('لا توجد بيانات')));
        return;
      }

      final levels = stats.levelsWithRanges(_activeLevels());
      for (var s in students) {
        s.tempScore = _scoreForStudent(s);
      }
      students.sort((a, b) => (b.tempScore ?? -1).compareTo(a.tempScore ?? -1));

      final topStudents = students.take(15).toList();
      final bottomStudents = students
          .where((s) => (s.tempScore ?? 0) >= 0)
          .toList()
          .reversed
          .take(15)
          .toList();

      final amiriRegular = _cachedRegularFont ?? pw.Font.courier();
      final amiriBold = _cachedBoldFont ?? pw.Font.courierBold();
      final mainColor = pdf.PdfColor.fromInt(0xFF27ae60);
      final redColor = pdf.PdfColors.red400;

      final doc = pw.Document();

      final widgets = _PdfWidgets(
        amiriBold: amiriBold,
        amiriRegular: amiriRegular,
        mainColor: mainColor,
        redColor: redColor,
        regionName: _regionName,
        ministryLabel: _ministryLabel,
        officeName: _officeName,
        schoolName: _schoolName,
        logo: _cachedMinistryLogo,
        examTitle: _examTitleText,
        stageClass: _stageClass,
        yearText: _yearText,
        academicYear: _academicYear,
        teacherName: _teacherName,
        principalName: _principalName,
        page3Title: _pdfPage3Title,
      );

      // صفحة 1: التحليل البياني
      doc.addPage(
        pw.Page(
          pageFormat: pdf.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (ctx) => pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              children: [
                widgets.buildFullHeader(pageTitle: _pdfPage1Title),
                pw.SizedBox(height: 15),
                widgets.buildStatsSummary(stats, levels),
                pw.SizedBox(height: 15),
                widgets.buildChartsSection(stats, levels),
                pw.Spacer(),
                widgets.buildFooter(),
              ],
            ),
          ),
        ),
      );

      // صفحة 2: الأوائل
      doc.addPage(
        pw.MultiPage(
          pageFormat: pdf.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: amiriRegular, bold: amiriBold),
          footer: (ctx) => widgets.buildFooter(),
          build: (ctx) => [
            widgets.buildFullHeader(pageTitle: _pdfPage2Title),
            pw.SizedBox(height: 15),
            widgets.buildStudentListTable(
              'الطلاب الأوائل (${topStudents.length})'.toAppNum(),
              topStudents,
              mainColor,
            ),
          ],
        ),
      );

      // صفحة 3: المتأخرين
      doc.addPage(
        pw.MultiPage(
          pageFormat: pdf.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: amiriRegular, bold: amiriBold),
          footer: (ctx) => widgets.buildFooter(),
          build: (ctx) => [
            widgets.buildFullHeader(pageTitle: 'كشف بأسماء الطلاب الأقل أداءً'),
            pw.SizedBox(height: 15),
            widgets.buildStudentListTable(
              'الطلاب الأقل أداءً (${bottomStudents.length})'.toAppNum(),
              bottomStudents,
              redColor,
            ),
          ],
        ),
      );

      // صفحة 4+: المستويات (التعديل هنا: صفحة مستقلة لكل مستوى)
      // --------------------------------------------------------
      final activeLevels = _activeLevels();
      const colors = [
        pdf.PdfColor.fromInt(0xFF2ecc71),
        pdf.PdfColor.fromInt(0xFF27ae60),
        pdf.PdfColor.fromInt(0xFF3498db),
        pdf.PdfColor.fromInt(0xFFe67e22),
        pdf.PdfColor.fromInt(0xFFe74c3c),
      ];

      for (int i = 0; i < activeLevels.length; i++) {
        final lvl = activeLevels[i];
        final list = _getStudentsForLevel(lvl);

        // إذا كان المستوى يحتوي على طلاب، ننشئ له صفحة (أو صفحات) خاصة
        if (list.isNotEmpty) {
          doc.addPage(
            pw.MultiPage(
              pageFormat: pdf.PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(20),
              theme: pw.ThemeData.withFont(base: amiriRegular, bold: amiriBold),
              textDirection: pw.TextDirection.rtl,
              // نستخدم دالة الهيدر الخاصة بالصفحات المتكررة، لكن نضيف لها العنوان الخاص بالمستوى
              header: (ctx) => widgets.buildLevelPageHeader(
                levelLabel: '${lvl.label} (${list.length})'.toAppNum(),
                headerColor: colors[i % colors.length],
              ),
              footer: (ctx) => widgets.buildFooter(),
              build: (ctx) {
                // هنا نعرض الجدول فقط (بدون عنوان، لأن العنوان أصبح في ترويسة الصفحة)
                // نستخدم headerCount: 1 لتكرار عناوين الأعمدة فقط (الاسم، الدرجة...)
                return [widgets.buildAggregatedLevelTableOnlyBody(list)];
              },
            ),
          );
        }
      }

      // جدول الإحصائيات في صفحة مستقلة أخيرة
      doc.addPage(
        pw.MultiPage(
          pageFormat: pdf.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: amiriRegular, bold: amiriBold),
          header: (ctx) => widgets.buildPage3Title(), // عنوان عام
          footer: (ctx) => widgets.buildFooter(),
          build: (ctx) => [widgets.buildAggregatedStatsTable(levels)],
        ),
      );

      Navigator.pop(context);
      await Printing.layoutPdf(onLayout: (format) async => doc.save());
    } catch (e) {
      Navigator.pop(context);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  void _exportPdfSmart() {
    if (widget.classId == 'stage_analysis' ||
        widget.classId == 'multi_skill_temp') {
      _exportAggregatedPdf();
    } else {
      _exportSingleClassPdf();
    }
  }

  Future<void> _exportAnalysisExcel() async {
    final stats = _calculateStats();
    final configs = _activeLevels();
    try {
      final ex.Excel excel = ex.Excel.createExcel();
      final ex.Sheet sheet = excel['Sheet1'];
      sheet.isRTL = true;
      sheet.appendRow([
        ex.TextCellValue('تحليل نتائج'),
        ex.TextCellValue(widget.classTitle),
      ]);
      sheet.appendRow([
        ex.TextCellValue('عدد الطلاب'),
        ex.IntCellValue(stats.totalStudents),
      ]);
      sheet.appendRow([
        ex.TextCellValue('الدرجة الكلية'),
        ex.DoubleCellValue(stats.maxScore.toDouble()),
      ]);
      sheet.appendRow([
        ex.TextCellValue('المتوسط'),
        ex.TextCellValue(stats.average.toString()),
      ]);
      sheet.appendRow([
        ex.TextCellValue('نسبة التحصيل'),
        ex.TextCellValue(stats.achievementPercent.toString()),
      ]);
      sheet.appendRow([ex.TextCellValue('')]);
      sheet.appendRow(
        [
          'المستوى',
          'أقل نسبة',
          'أعلى نسبة',
          'العدد',
          'النسبة',
          'أدنى درجة',
          'أعلى درجة',
        ].map((e) => ex.TextCellValue(e)).toList(),
      );
      for (int i = 0; i < configs.length; i++) {
        final cfg = configs[i];
        final minP = cfg.minPercent.clamp(0, 100);
        final maxP = i == 0
            ? 100.0
            : configs[i - 1].minPercent.clamp(0, 100) - 0.01;
        final count = stats.levelCounts[cfg.label] ?? 0;
        final percent = stats.totalActive == 0
            ? 0.0
            : (count / stats.totalActive) * 100.0;
        sheet.appendRow([
          ex.TextCellValue(cfg.label),
          ex.DoubleCellValue(minP.toDouble()),
          ex.DoubleCellValue(maxP.toDouble()),
          ex.IntCellValue(count),
          ex.DoubleCellValue(percent),
          ex.DoubleCellValue(stats.maxScore * (minP / 100)),
          ex.DoubleCellValue(stats.maxScore * (maxP / 100)),
        ]);
      }
      final bytes = excel.save();
      if (bytes == null) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تعذر إنشاء ملف Excel')));
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/تحليل_${widget.classTitle.replaceAll(' ', '_')}.xlsx';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(bytes, flush: true);
      final params = SaveFileDialogParams(
        sourceFilePath: tempFile.path,
        fileName: 'تحليل_${widget.classTitle}.xlsx',
      );
      final savedPath = await FlutterFileDialog.saveFile(params: params);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              savedPath == null ? 'تم إلغاء الحفظ' : 'تم الحفظ في: $savedPath',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }

  Future<void> _showEditAndExportDialog() async {
    final regionCtrl = TextEditingController(
      text: _regionName.isEmpty ? 'المملكة العربية السعودية' : _regionName,
    );
    final ministryCtrl = TextEditingController(text: _ministryLabel);
    final officeCtrl = TextEditingController(
      text: _officeName.isEmpty ? 'الإدارة العامة للتعليم بـ...' : _officeName,
    );
    final schoolCtrl = TextEditingController(text: _schoolName);
    final page1Ctrl = TextEditingController(text: _pdfPage1Title);
    final page2Ctrl = TextEditingController(text: _pdfPage2Title);
    final page3Ctrl = TextEditingController(text: _pdfPage3Title);
    final examCtrl = TextEditingController(
      text: _examTitleText.isEmpty ? 'الاختبار النهائي' : _examTitleText,
    );
    final stageCtrl = TextEditingController(
      text: _stageClass.isEmpty ? widget.classTitle : _stageClass,
    );
    final semesterCtrl = TextEditingController(text: _yearText);
    final academicYearCtrl = TextEditingController(
      text: _academicYear.isEmpty ? '1447 هـ' : _academicYear,
    );
    final teacherCtrl = TextEditingController(text: _teacherName);
    final principalCtrl = TextEditingController(text: _principalName);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إعدادات التقرير والطباعة'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الترويسة العامة:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: regionCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الدولة',
                            isDense: true,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: ministryCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الوزارة',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: officeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الإدارة',
                            isDense: true,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: schoolCtrl,
                          decoration: const InputDecoration(
                            labelText: 'المدرسة',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  const Text(
                    'عناوين صفحات التقرير:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: page1Ctrl,
                    decoration: const InputDecoration(
                      labelText: 'عنوان الصفحة 1',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: page2Ctrl,
                    decoration: const InputDecoration(
                      labelText: 'عنوان الصفحة 2',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: page3Ctrl,
                    decoration: const InputDecoration(
                      labelText: 'عنوان الصفحة 3',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const Divider(),
                  const Text(
                    'معلومات إضافية:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: examCtrl,
                          decoration: const InputDecoration(
                            labelText: 'اسم الاختبار',
                            isDense: true,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: academicYearCtrl,
                          decoration: const InputDecoration(
                            labelText: 'العام',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: stageCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الصف',
                            isDense: true,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: semesterCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الفصل',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: teacherCtrl,
                          decoration: const InputDecoration(
                            labelText: 'المعلم',
                            isDense: true,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: principalCtrl,
                          decoration: const InputDecoration(
                            labelText: 'المدير',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.print),
              label: const Text('طباعة PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                setState(() {
                  _regionName = regionCtrl.text;
                  _ministryLabel = ministryCtrl.text;
                  _officeName = officeCtrl.text;
                  _schoolName = schoolCtrl.text;
                  _examTitleText = examCtrl.text;
                  _stageClass = stageCtrl.text;
                  _yearText = semesterCtrl.text;
                  _academicYear = academicYearCtrl.text;
                  _teacherName = teacherCtrl.text;
                  _principalName = principalCtrl.text;
                  _pdfPage1Title = page1Ctrl.text;
                  _pdfPage2Title = page2Ctrl.text;
                  _pdfPage3Title = page3Ctrl.text;
                });
                await _saveReportMeta();
                Navigator.pop(ctx);

                try {
                  _exportPdfSmart();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('خطأ في إنشاء PDF: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // تحليل صف
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppSettings.useArabicNumbers,
      builder: (context, isArabic, child) {
        final stats = _calculateStats();
        for (var s in students) {
          s.tempScore = _scoreForStudent(s);
        }
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: const Color(0xFFEDF4FB),
            appBar: AppBar(
              backgroundColor: const Color(
                0xFFa2b2bf,
              ), // لون الشريط العلوي تحليل صف
              centerTitle: true,
              title: Text(
                'تحليل نتائج ${widget.classTitle}'.toAppNum(),
                style: const TextStyle(
                  color: Color(0xFF201F1F),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'تقرير PDF',
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  onPressed: _showEditAndExportDialog,
                ),
                IconButton(
                  tooltip: 'تصدير Excel',
                  icon: const Icon(Icons.table_chart),
                  onPressed: _exportAnalysisExcel,
                ),
                IconButton(
                  tooltip: 'إعدادات المستويات',
                  icon: const Icon(Icons.tune),
                  onPressed: _showLevelsSettingsDialog,
                ),
              ],
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildSummaryDashboard(stats),
                    const SizedBox(height: 20),
                    _buildCategorizedStudentGrid(stats),
                    const SizedBox(height: 24),
                    _buildAnalyticsSection(stats),
                    const SizedBox(height: 16),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: MainBottomBar(
              currentIndex: _bottomIndex,
              onIndexChange: (index) => setState(() => _bottomIndex = index),
              onHomeTap: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomePage()),
                (route) => false,
              ),
              onFileTap: () => AppDialogs.showFileDialog(
                context,
                onExportTap: () => BackupService.exportBackup(context),
                onImportTap: () => BackupService.importBackup(context),
                onSettingsTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SecuritySettingsPage(),
                  ),
                ),
              ),
              onContactTap: () => AppDialogs.showContactDialog(context),
              onHelpTap: () => AppDialogs.showInfoDialog(context),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter() => Align(
    alignment: Alignment.center,
    child: Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 20),
      child: Text(
        'تم إنشاء هذا التقرير بواسطة تطبيق راصد الدرجات',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
    ),
  );
  Widget _buildSummaryDashboard(AnalysisStats stats) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'اختر البيانات المراد تحليلها',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: AnalysisTargetType.values.map((type) {
                      String label = type == AnalysisTargetType.average
                          ? 'المتوسط'
                          : 'اختبار ${type.index + 1}';
                      bool isSelected = _target == type;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(
                            label.toAppNum(),
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor:
                              Colors.teal, // لون الاختيارات في شريط تحليل صف
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 0,
                          ),
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          onSelected: (_) => setState(() => _target = type),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: const Color(0xFFe0f2f1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildHighlightStat(
                  'عدد الطلاب',
                  stats.totalStudents.toString(),
                ),
                Container(width: 1, height: 25, color: Colors.teal.shade200),
                _buildHighlightStat(
                  'درجة القياس',
                  stats.maxScore.toStringAsFixed(0),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDashStat(
                  'أعلى درجة',
                  formatNumberForDisplay(
                    stats.highest,
                  ), // ✅ سيظهر الفاصلة واللغة الصحيحة

                  Icons.arrow_upward,
                ),
                _verticalLine(),
                _buildDashStat(
                  'أقل درجة',

                  formatNumberForDisplay(
                    stats.lowest,
                  ), // ✅ سيظهر الفاصلة واللغة الصحيحة

                  Icons.arrow_downward,
                ),
                _verticalLine(),
                _buildDashStat(
                  'المتوسط',
                  formatNumberForDisplay(
                    stats.average,
                  ), // ✅ سيظهر الفاصلة واللغة الصحيحة
                  Icons.functions,
                ),
                _verticalLine(),
                _buildDashStat(
                  'التحصيل',
                  '${stats.achievementPercent.toStringAsFixed(0)}%',
                  Icons.pie_chart,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightStat(String label, String value) => Row(
    children: [
      Text(
        '$label: ',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.teal.shade800,
        ),
      ),
      Text(
        value.toAppNum(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.teal.shade900,
        ),
      ),
    ],
  );
  Widget _buildDashStat(String label, String value, IconData icon) => Column(
    children: [
      Icon(icon, size: 18, color: Colors.grey.shade400),
      const SizedBox(height: 4),
      Text(
        value.toAppNum(),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Colors.black87,
        ),
      ),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
    ],
  );
  Widget _verticalLine() =>
      Container(height: 30, width: 1, color: Colors.grey.shade200);
  Widget _buildCategorizedStudentGrid(AnalysisStats stats) {
    final activeLevels = _activeLevels();
    const colors = [
      // الوان المستويات
      // Color(0xFF00C853), // Vibrant Green (Excellent)
      // Color(0xFF27ae60), // Dark Green (Very Good)
      //  Color(0xFF2980b9), // Strong Blue (Good)
      //  Color(0xFFf39c12), // Darker Orange (Acceptable)
      //  Color(0xFFc0392b), // Darker/Stronger Red (Poor) to avoid pale look
      //  Color(0xFF00C853), // Vibrant Green (Excellent)
      // Color(0xFF27ae60), // Dark Green (Very Good)
      // Color(0xFF2980b9), // Strong Blue (Good)
      //  Color(0xFFf39c12), // Darker Orange (Acceptable)
      //  Color(0xFFc0392b), // Darker/Stronger Red (Poor) to avoid pale look
      Color(0xFF00C853), // Vibrant Green (Excellent)
      Color(0xFF2980b9), // Strong Blue (Good)
      Color(0xFF7a69d1), // Darker Orange (Acceptable)
      Color(0xFFf28f26), //een (Very Good)
      Color(0xFFc0392b), // Darker/Stronger Red (Poor)
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 800
            ? 3
            : (constraints.maxWidth > 500 ? 2 : 1);
        List<Widget> gridItems = [];
        for (int i = 0; i < activeLevels.length; i++) {
          final lvl = activeLevels[i];
          final list = _getStudentsForLevel(lvl);
          gridItems.add(
            _buildRankedStudentsCard(
              title: lvl.label,
              students: list,
              color: colors[i % colors.length],
            ),
          );
        }
        gridItems.add(_buildDetailedStatsCard(stats));
        double width =
            (constraints.maxWidth - ((crossAxisCount - 1) * 12)) /
            crossAxisCount;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: gridItems
              .map((item) => SizedBox(width: width, height: 300, child: item))
              .toList(),
        );
      },
    );
  }

  Widget _buildDetailedStatsCard(AnalysisStats stats) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.black),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: const Text(
              'الإحصائيات التفصيلية',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            color: Colors.grey.shade100,
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'المستوى',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'النطاق',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'عدد الطلاب',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: stats.levelsWithRanges(_activeLevels()).map((lvl) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade50),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            lvl.label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            lvl.rangeLabel.toAppNum(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            lvl.count.toString().toAppNum(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankedStudentsCard({
    required String title,
    required List<MockStudent> students,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            color: Colors.grey.shade50,
            child: const Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    '#',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'الاسم',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'الصف',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'الدرجة',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: students.isEmpty
                ? const Center(
                    child: Text(
                      'لا يوجد طلاب',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  )
                : ListView.builder(
                    itemCount: students.length,
                    padding: EdgeInsets.zero,
                    itemBuilder: (ctx, idx) {
                      final s = students[idx];
                      String displayName = s.name.contains('(')
                          ? s.name.split('(')[0].trim()
                          : s.name;
                      String displayClass = s.name.contains('(')
                          ? s.name.split('(')[1].replaceAll(')', '').trim()
                          : '-';
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade50),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: Text(
                                (idx + 1).toString().toAppNum(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Text(
                                displayName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                displayClass.toAppNum(),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                (s.tempScore ?? 0)
                                    .toStringAsFixed(1)
                                    .toAppNum(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSection(AnalysisStats stats) {
    final levels = stats.levelsWithRanges(_activeLevels());
    final maxCount = levels.fold<int>(
      0,
      (prev, lvl) => lvl.count > prev ? lvl.count : prev,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'التحليل البياني للنتائج',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              bool isMobile = constraints.maxWidth < 600;
              Widget donutSection = Column(
                children: [
                  const Text(
                    'نسب الطلاب',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: levels.asMap().entries.map((entry) {
                        final index = entry.key;
                        final lvl = entry.value;
                        final percent = stats.totalActive == 0
                            ? 0.0
                            : (lvl.count / stats.totalActive) * 100.0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: _DonutChart(
                            label: lvl.label,
                            percent: percent,
                            color: lvl.color,
                            levelIndex: index,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
              Widget barSection = Column(
                children: [
                  const Text(
                    'عدد الطلاب',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  WaveBarChart(
                    items: levels
                        .map(
                          (lvl) => WaveLevelItem(
                            label: lvl.label,
                            count: lvl.count,
                            color: lvl.color,
                          ),
                        )
                        .toList(),
                    maxCount: maxCount,
                    height: 180,
                  ),
                ],
              );
              if (isMobile)
                return Column(
                  children: [
                    donutSection,
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 10),
                    barSection,
                  ],
                );
              return Row(
                children: [
                  Expanded(child: donutSection),
                  Container(width: 1, height: 150, color: Colors.grey.shade200),
                  Expanded(child: barSection),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showLevelsSettingsDialog() async {
    final active = _activeLevels();
    int tempCount = _levelsCount;
    List<LevelConfig> tempLevels = _padOrTrimLevels(
      active + _levels.skip(active.length).toList(),
    );
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          List<LevelConfig> visible = tempLevels
              .take(tempCount)
              .toList(growable: false);
          return AlertDialog(
            title: const Text('إعدادات المستويات'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'يمكنك تغيير أسماء المستويات وعددها',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        'عدد المستويات:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: tempCount,
                        items: [2, 3, 4, 5]
                            .map(
                              (v) => DropdownMenuItem<int>(
                                value: v,
                                child: Text(v.toString().toAppNum()),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setLocal(() => tempCount = v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(visible.length, (i) {
                    final lvl = visible[i];
                    final isLast = i == visible.length - 1;
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFf4f7f9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'المستوى ${(i + 1).toString().toAppNum()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: TextEditingController(text: lvl.label),
                            onChanged: (val) => tempLevels[i].label =
                                val.trim().isEmpty ? lvl.label : val.trim(),
                            decoration: const InputDecoration(
                              labelText: 'اسم المستوى',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          if (!isLast)
                            TextField(
                              controller: TextEditingController(
                                text: lvl.minPercent
                                    .toStringAsFixed(
                                      lvl.minPercent % 1 == 0 ? 0 : 1,
                                    )
                                    .toAppNum(),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [AppNumberInputFormatter()],
                              onChanged: (val) {
                                tempLevels[i].minPercent =
                                    (double.tryParse(val.toEnglishNum()) ??
                                            lvl.minPercent)
                                        .clamp(0, 100);
                              },
                              decoration: const InputDecoration(
                                labelText: 'أقل نسبة مئوية',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () {
                  if (tempLevels.isNotEmpty)
                    tempLevels[tempCount - 1].minPercent = 0;
                  setState(() {
                    _levelsCount = tempCount;
                    _levels = _padOrTrimLevels(tempLevels);
                  });
                  _saveLevels();
                  Navigator.pop(ctx);
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ===== Helper Functions inside _PdfWidgets =====
class _PdfWidgets {
  final pw.Font amiriBold;
  final pw.Font amiriRegular;
  final pdf.PdfColor mainColor;
  final pdf.PdfColor redColor;
  final String regionName;
  final String ministryLabel;
  final String officeName;
  final String schoolName;
  final pw.MemoryImage? logo;
  final String examTitle;
  final String stageClass;
  final String yearText;
  final String academicYear;
  final String teacherName;
  final String principalName;
  final String page3Title;

  _PdfWidgets({
    required this.amiriBold,
    required this.amiriRegular,
    required this.mainColor,
    required this.redColor,
    required this.regionName,
    required this.ministryLabel,
    required this.officeName,
    required this.schoolName,
    this.logo,
    required this.examTitle,
    required this.stageClass,
    required this.yearText,
    required this.academicYear,
    required this.teacherName,
    required this.principalName,
    required this.page3Title,
  });

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
                  regionName.isEmpty ? 'المملكة العربية السعودية' : regionName,
                  style: pw.TextStyle(font: amiriBold, fontSize: 10),
                ),
                pw.Text(
                  ministryLabel,
                  style: pw.TextStyle(font: amiriBold, fontSize: 10),
                ),
                pw.Text(
                  officeName.isEmpty ? 'الإدارة العامة للتعليم' : officeName,
                  style: pw.TextStyle(font: amiriBold, fontSize: 10),
                ),
                pw.Text(
                  schoolName.isEmpty ? 'المدرسة ....' : schoolName,
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
                  (examTitle.isEmpty ? 'اختبار لغتي' : 'اختبار : $examTitle')
                      .toAppNum(),
                  style: pw.TextStyle(font: amiriBold, fontSize: 10),
                ),
                pw.Text(
                  'الصف ${stageClass.toAppNum()}',
                  style: pw.TextStyle(font: amiriBold, fontSize: 10),
                ),
                pw.Text(
                  'الفصل الدراسي ${yearText.toAppNum()}',
                  style: pw.TextStyle(font: amiriBold, fontSize: 10),
                ),
                pw.Text(
                  'للعام ${academicYear.toAppNum()}',
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
            pw.Container(
              color: pdf.PdfColors.white,
              padding: const pw.EdgeInsets.symmetric(horizontal: 3),
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: mainColor, width: 0.8),
                ),
                child: pw.Text(
                  pageTitle.toAppNum(),
                  style: pw.TextStyle(font: amiriBold, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ],
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
                page3Title.toAppNum(),
                style: pw.TextStyle(font: amiriBold, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
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
                    teacherName,
                    style: pw.TextStyle(font: amiriRegular, fontSize: 10),
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
                    principalName,
                    style: pw.TextStyle(font: amiriRegular, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 10),
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

  pw.Widget buildStatsSummary(AnalysisStats stats, List<_LevelRow> levels) {
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

  pw.Widget buildChartsSection(AnalysisStats stats, List<_LevelRow> levels) {
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

  pw.Widget buildStudentListTable(
    String title,
    List<MockStudent> list,
    pdf.PdfColor headerColor,
  ) {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(
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
          pw.Table(
            border: pw.TableBorder.all(
              color: pdf.PdfColors.grey400,
              width: 0.5,
            ),
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            columnWidths: {
              3: const pw.FlexColumnWidth(0.7),
              2: const pw.FlexColumnWidth(3.0),
              1: const pw.FlexColumnWidth(1.0),
              0: const pw.FlexColumnWidth(1.7),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: pdf.PdfColors.grey100),
                children: [
                  pw.Center(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        'الدرجة',
                        style: pw.TextStyle(font: amiriBold, fontSize: 9),
                      ),
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(4),
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      'الصف ',
                      style: pw.TextStyle(font: amiriBold, fontSize: 9),
                    ),
                  ),
                  pw.Center(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        'اسم الطالب',
                        style: pw.TextStyle(font: amiriBold, fontSize: 9),
                      ),
                    ),
                  ),
                  pw.Center(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.all(4),
                      child: pw.Text(
                        'م',
                        style: pw.TextStyle(font: amiriBold, fontSize: 9),
                      ),
                    ),
                  ),
                ],
              ),
              if (list.isEmpty)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('-', textAlign: pw.TextAlign.center),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('-', textAlign: pw.TextAlign.center),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'لا يوجد طلاب',
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('-', textAlign: pw.TextAlign.center),
                    ),
                  ],
                )
              else
                ...list.asMap().entries.map((entry) {
                  int idx = entry.key + 1;
                  var s = entry.value;
                  String rawName = s.name;
                  String displayName = rawName;
                  String displayClass = '-';
                  if (rawName.contains('(')) {
                    var parts = rawName.split('(');
                    displayName = parts[0].trim();
                    displayClass = parts[1].replaceAll(')', '').trim();
                  }
                  return pw.TableRow(
                    children: [
                      pw.Center(
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 3),
                          child: pw.Text(
                            (s.tempScore ?? 0).toStringAsFixed(1).toAppNum(),
                            style: pw.TextStyle(font: amiriBold, fontSize: 9),
                          ),
                        ),
                      ),
                      pw.Center(
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 3),
                          child: pw.Text(
                            displayClass.toAppNum(),
                            style: pw.TextStyle(
                              font: amiriRegular,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          vertical: 3,
                          horizontal: 5,
                        ),
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text(
                          displayName,
                          style: pw.TextStyle(font: amiriRegular, fontSize: 9),
                          maxLines: 1,
                          overflow: pw.TextOverflow.clip,
                        ),
                      ),
                      pw.Center(
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 3),
                          child: pw.Text(
                            idx.toString().toAppNum(),
                            style: pw.TextStyle(font: amiriBold, fontSize: 9),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
            ],
          ),
        ],
      ),
    );
  }

  // ✅✅✅ هنا الحل: صفحة جديدة لكل مستوى، والعنوان هو ترويسة الصفحة ✅✅✅
  pw.Widget buildLevelPageHeader({
    required String levelLabel,
    required pdf.PdfColor headerColor,
  }) {
    return pw.Column(
      children: [
        // 1. ترويسة الصفحة العامة (قوائم الطلاب مصنفة...)
        buildPage3Title(),
        pw.SizedBox(height: 10),

        // 2. ترويسة المستوى (الشريط الملون)
        pw.Container(
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
      ],
    );
  }

  pw.Widget buildAggregatedLevelTableOnlyBody(List<MockStudent> list) {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Table(
        border: pw.TableBorder.all(color: pdf.PdfColors.grey400, width: 0.5),
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
        columnWidths: {
          3: const pw.FlexColumnWidth(0.7),
          2: const pw.FlexColumnWidth(3.0),
          1: const pw.FlexColumnWidth(1.0),
          0: const pw.FlexColumnWidth(1.7),
        },
        children: [
          // صف عناوين الأعمدة (يتكرر مع كل صفحة جديدة لأننا نستخدم headerCount: 1)
          pw.TableRow(
            decoration: pw.BoxDecoration(color: pdf.PdfColors.grey100),
            children: [
              pw.Center(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    'الدرجة',
                    style: pw.TextStyle(font: amiriBold, fontSize: 9),
                  ),
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'الصف ',
                  style: pw.TextStyle(font: amiriBold, fontSize: 9),
                ),
              ),
              pw.Center(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    'اسم الطالب',
                    style: pw.TextStyle(font: amiriBold, fontSize: 9),
                  ),
                ),
              ),
              pw.Center(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    'م',
                    style: pw.TextStyle(font: amiriBold, fontSize: 9),
                  ),
                ),
              ),
            ],
          ),
          // البيانات
          ...list.asMap().entries.map((entry) {
            int idx = entry.key + 1;
            var s = entry.value;
            String rawName = s.name;
            String displayName = rawName;
            String displayClass = '-';
            if (rawName.contains('(')) {
              var parts = rawName.split('(');
              displayName = parts[0].trim();
              displayClass = parts[1].replaceAll(')', '').trim();
            }
            return pw.TableRow(
              children: [
                pw.Center(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 3),
                    child: pw.Text(
                      (s.tempScore ?? 0).toStringAsFixed(1).toAppNum(),
                      style: pw.TextStyle(font: amiriBold, fontSize: 9),
                    ),
                  ),
                ),
                pw.Center(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 3),
                    child: pw.Text(
                      displayClass.toAppNum(),
                      style: pw.TextStyle(font: amiriRegular, fontSize: 9),
                    ),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    vertical: 3,
                    horizontal: 5,
                  ),
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    displayName,
                    style: pw.TextStyle(font: amiriRegular, fontSize: 9),
                    maxLines: 1,
                    overflow: pw.TextOverflow.clip,
                  ),
                ),
                pw.Center(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 3),
                    child: pw.Text(
                      idx.toString().toAppNum(),
                      style: pw.TextStyle(font: amiriBold, fontSize: 9),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // ✅ دالة خاصة لجدول الإحصائيات (مدمج العنوان)
  pw.Widget buildAggregatedStatsTable(List<_LevelRow> levels) {
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

  pw.Widget buildStatsTable(List<_LevelRow> levels) {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            decoration: const pw.BoxDecoration(
              color: pdf.PdfColors.black,
              borderRadius: pw.BorderRadius.vertical(
                top: pw.Radius.circular(6),
              ),
            ),
            alignment: pw.Alignment.center,
            child: pw.Text(
              'الإحصائيات التفصيلية'.toAppNum(),
              style: pw.TextStyle(
                font: amiriBold,
                fontSize: 11,
                color: pdf.PdfColors.white,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.Table(
            border: pw.TableBorder.all(
              color: pdf.PdfColors.grey400,
              width: 0.5,
            ),
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
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
        ],
      ),
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

  pw.Widget _buildDetailRow(
    String levelName,
    String range,
    String count,
    pdf.PdfColor levelColor,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              decoration: pw.BoxDecoration(
                color: levelColor,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              alignment: pw.Alignment.center,
              child: pw.Text(
                levelName,
                style: pw.TextStyle(
                  font: amiriBold,
                  fontSize: 10,
                  color: pdf.PdfColors.white,
                ),
              ),
            ),
          ),
          pw.SizedBox(width: 4),
          pw.Expanded(
            flex: 3,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: pdf.PdfColors.grey600, width: 0.5),
              ),
              alignment: pw.Alignment.center,
              child: pw.Text(
                range.toAppNum(),
                style: pw.TextStyle(font: amiriRegular, fontSize: 9),
              ),
            ),
          ),
          pw.SizedBox(width: 4),
          pw.Expanded(
            flex: 2,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: pdf.PdfColors.grey600, width: 0.5),
              ),
              alignment: pw.Alignment.center,
              child: pw.Text(
                count.toAppNum(),
                style: pw.TextStyle(font: amiriBold, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== الكلاسات المساعدة الأخيرة =====
class _DonutChart extends StatelessWidget {
  final String label;
  final double percent;
  final Color color;
  final int levelIndex; // Added levelIndex

  const _DonutChart({
    required this.label,
    required this.percent,
    required this.color,
    required this.levelIndex, // Required now
  });

  IconData get icon {
    switch (levelIndex) {
      case 0:
        return Icons.sentiment_very_satisfied_rounded; // Enthusiastic
      case 1:
        return Icons.sentiment_satisfied_alt_rounded; // Happy
      case 2:
        return Icons.sentiment_neutral_rounded; // Neutral
      case 3:
        return Icons.sentiment_dissatisfied_rounded; // Sad
      case 4:
        return Icons.mood_bad_rounded; // Upset
      default:
        return Icons.sentiment_neutral_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = (percent.clamp(0, 100)) / 100.0;
    return Column(
      children: [
        SizedBox(
          width: 85, // Increased from 70
          height: 85, // Increased from 70
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 85,
                height: 85,
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 10, // Increased from 7
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.grey.shade300,
                  ),
                ),
              ),
              SizedBox(
                width: 85,
                height: 85,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 10, // Increased from 7
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  backgroundColor: Colors.transparent,
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${percent.toStringAsFixed(0)}%'.toAppNum(),
                    style: const TextStyle(
                      fontSize: 14, // Increased from 10
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4), // Increased spacing
                  Icon(icon, color: color, size: 28), // Increased from 20
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

List<LevelConfig> _defaultLevels() => [
  LevelConfig(label: 'ممتاز', minPercent: 90),
  LevelConfig(label: 'جيد جدًا', minPercent: 80),
  LevelConfig(label: 'جيد', minPercent: 70),
  LevelConfig(label: 'مقبول', minPercent: 60),
  LevelConfig(label: 'ضعيف', minPercent: 0),
];
List<LevelConfig> _padOrTrimLevels(List<LevelConfig> list) {
  final base = _defaultLevels();
  final result = <LevelConfig>[];
  for (int i = 0; i < 5; i++) {
    result.add(
      i < list.length
          ? LevelConfig(label: list[i].label, minPercent: list[i].minPercent)
          : LevelConfig(label: base[i].label, minPercent: base[i].minPercent),
    );
  }
  return result;
}
