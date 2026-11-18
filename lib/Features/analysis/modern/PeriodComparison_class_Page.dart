import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// استيرادات المشروع
import '../../../core/settings/app_settings.dart';
import '../../../models/student.dart';
import '../../../core/config/class_grading_config.dart';
import '../../../core/grading_levels/level_settings_service.dart';
import '../../../core/utils/number_utils.dart';
import '../models/analysis_view_models.dart';
import '../services/analysis_calculator.dart';

import '../widgets/period_comparison_print_dialog.dart';
import '../services/period_comparison_pdf_service.dart';
import '../models/analysis_view_models.dart'; // لـ AnalysisReportMeta

class PeriodComparisonClassPage extends StatefulWidget {
  final String classId;
  final String classTitle;

  const PeriodComparisonClassPage({
    super.key,
    required this.classId,
    required this.classTitle,
  });

  @override
  State<PeriodComparisonClassPage> createState() =>
      _PeriodComparisonClassPageState();
}

class _PeriodComparisonClassPageState extends State<PeriodComparisonClassPage> {
  // === البيانات ===
  ClassGradingConfig _config = ClassGradingConfig();
  List<Student> _students = [];
  final Map<String, Map<String, dynamic>> _allScores = {};

  List<LevelConfigV2> _activeLevels = [];
  List<String> _availableTags = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // 1. تحميل الإعدادات
    final prefs = await SharedPreferences.getInstance();
    final levelSettings = await LevelSettingsService.load();
    _activeLevels = levelSettings.levels
      ..sort((a, b) => b.minPercent.compareTo(a.minPercent));
    _config = await ClassGradingConfig.load(widget.classId);

    // تجهيز التاقات (المجموع الكلي + بقية التاقات)
    final Set<String> tags = {};
    for (var item in _config.items) tags.add(item.tag);
    for (var item in _config.exams) tags.add(item.tag);

    // استثناء "اختبار نهائي" من التاقات إذا وجد
    tags.removeWhere((t) => t == 'اختبار نهائي');

    _availableTags = [
      'Comprehensive',
      ...tags.where((t) => t.trim().isNotEmpty),
    ];

    // 2. تحميل الطلاب
    final studentsJson = prefs.getString('class_students_${widget.classId}');
    if (studentsJson != null) {
      final List list = jsonDecode(studentsJson);
      _students = list.map((e) => Student.fromJson(e)).toList();
    }

    _allScores.clear();
    for (var s in _students) {
      final sKey = 'student_detail_${s.name}_${widget.classId}';
      final sStr = prefs.getString(sKey);
      if (sStr != null) _allScores[s.name] = jsonDecode(sStr);
    }

    setState(() => _isLoading = false);
  }

  // === محرك الحسابات (يحسب لفترة معينة وتاق معين) ===
  AnalysisStatsV2 _calculateStats(int period, String targetTag) {
    double calculatedMax = 0.0;

    // 1. حساب الدرجة العظمى (مع استثناء النهائي دائماً)
    for (var item in [..._config.items, ..._config.exams]) {
      // استثناء الاختبار النهائي كلياً من المقارنة
      if (item.tag == 'اختبار نهائي' || item.name.contains('نهائي')) continue;

      // فلتر التاق
      bool include = (targetTag == 'Comprehensive') || (item.tag == targetTag);
      if (include) {
        calculatedMax += item.maxScore;
      }
    }
    if (calculatedMax == 0) calculatedMax = 100;

    String suffix = period == 1 ? '_p1' : '_p2';
    List<double> scoresList = [];

    for (var s in _students) {
      double total = 0.0;
      final scores = _allScores[s.name];
      if (scores != null) {
        for (var col in [..._config.items, ..._config.exams]) {
          // استثناء النهائي
          if (col.tag == 'اختبار نهائي' || col.name.contains('نهائي')) continue;

          // فلتر التاق
          bool include =
              (targetTag == 'Comprehensive') || (col.tag == targetTag);

          if (include) {
            final val = scores['${col.id}$suffix'];
            total += _getRealScoreForColumn(col, val);
          }
        }
      }
      scoresList.add(total);
    }

    scoresList.sort();

    // توزيع المستويات
    final Map<String, int> counts = {for (var l in _activeLevels) l.label: 0};
    for (var s in scoresList) {
      final lvl = AnalysisCalculator.getLevelForScore(
        score: s,
        maxScore: calculatedMax,
        useSum: true,
        activeLevels: _activeLevels,
        selectedTag:
            'Comprehensive', // نثبت التاق هنا لأننا حسبنا الدرجة يدوياً
      );
      counts[lvl] = (counts[lvl] ?? 0) + 1;
    }

    double sum = scoresList.fold(0, (a, b) => a + b);

    return AnalysisStatsV2(
      maxScore: calculatedMax,
      totalStudents: _students.length,
      activeStudents: scoresList.length,
      highest: scoresList.isEmpty ? 0 : scoresList.last,
      lowest: scoresList.isEmpty ? 0 : scoresList.first,
      average: scoresList.isEmpty ? 0 : sum / scoresList.length,
      sum: sum,
      achievementPercent: calculatedMax == 0
          ? 0
          : (sum / (_students.length * calculatedMax)) * 100,
      levelCounts: counts,
      levelLabels: _activeLevels.map((e) => e.label).toList(),
    );
  }

  double _getRealScoreForColumn(GradeColumn col, dynamic val) {
    if (val == null) return 0.0;
    if (col.type == GradeType.numeric)
      return double.tryParse(val.toString().toEnglishNum()) ?? 0.0;
    if (col.type == GradeType.checkbox) {
      int count = int.tryParse(val.toString().toEnglishNum()) ?? 0;
      return col.subCount == 0 ? 0.0 : count * (col.maxScore / col.subCount);
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
        return count > 0 ? sum / count : 0.0;
      }
      return 0.0;
    }
    if (col.type == GradeType.averagePair) {
      if (val is List && val.length >= 2) {
        double v1 = double.tryParse(val[0].toString().toEnglishNum()) ?? 0.0;
        double v2 = double.tryParse(val[1].toString().toEnglishNum()) ?? 0.0;
        return (v1 + v2) / 2.0;
      }
      return 0.0;
    }
    return double.tryParse(val.toString().toEnglishNum()) ?? 0.0;
  }

  @override
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppSettings.useArabicNumbers,
      builder: (context, isArabic, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(
              title: const Text(
                'مقارنة الفترات (لوحة القيادة)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
              backgroundColor: const Color(0xFF2E7D6F),
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.print),
                  tooltip: 'طباعة المقارنة',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => PeriodComparisonPrintDialog(
                        initialClassTitle: widget.classTitle,
                        config: _config,
                        students: _students,
                        allScores: _allScores,
                        activeLevels: _activeLevels,
                        availableTags: _availableTags,
                      ),
                    );
                  },
                ),
              ],
            ),
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // 1. الكروت العلوية (ملخص عام)
                        const SizedBox(height: 5),
                        const Divider(),
                        const SizedBox(height: 5),

                        // 2. شبكة الأقسام (Grid of Tag Sections)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            // تحديد عدد الأعمدة بناءً على عرض الشاشة
                            int crossAxisCount = 1;
                            if (constraints.maxWidth > 1200)
                              crossAxisCount = 3; // شاشة عريضة جداً
                            else if (constraints.maxWidth > 800)
                              crossAxisCount = 2; // تابلت

                            if (crossAxisCount == 1) {
                              // للموبايل: قائمة عمودية عادية
                              return Column(
                                children: _availableTags
                                    .map((tag) => _buildTagSection(tag))
                                    .toList(),
                              );
                            } else {
                              // للشاشات العريضة: Wrap أو Grid
                              // نستخدم Wrap لمرونة أكبر في الارتفاع
                              return Wrap(
                                spacing: 20, // مسافة أفقية
                                runSpacing: 20, // مسافة عمودية
                                children: _availableTags.map((tag) {
                                  // حساب عرض البطاقة الواحدة
                                  // العرض الكلي - المسافات / عدد الأعمدة
                                  double cardWidth =
                                      (constraints.maxWidth -
                                          (20 * (crossAxisCount - 1))) /
                                      crossAxisCount;
                                  return SizedBox(
                                    width: cardWidth,
                                    child: _buildTagSection(
                                      tag,
                                      isCompact: true,
                                    ), // نمرر مؤشر لتصغير المحتوى قليلاً
                                  );
                                }).toList(),
                              );
                            }
                          },
                        ),

                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  // === 2. قسم التاق الواحد (رسم + جدول) ===
  // === 2. قسم التاق الواحد (معدل) ===
  Widget _buildTagSection(String tag, {bool isCompact = false}) {
    // حساب الإحصائيات
    final s1 = _calculateStats(1, tag);
    final s2 = _calculateStats(2, tag);

    String title = tag == 'Comprehensive' ? 'المجموع الكلي' : tag;

    return Card(
      elevation: 3,
      // margin تم إزالته لأن الـ Wrap يتكفل بالمسافات
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // مهم للـ Wrap
          children: [
            // العنوان
            Row(
              children: [
                Container(width: 4, height: 20, color: const Color(0xFF2E7D6F)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D6F),
                  ),
                ),
              ],
            ),
            const Divider(height: 5),

            // المحتوى: دائماً عمودي داخل البطاقة الصغيرة للحفاظ على التنسيق
            _buildComparisonChart(s1, s2, title),

            _buildDetailedTable(s1, s2),
          ],
        ),
      ),
    );
  }

  // === الرسم البياني ===
  Widget _buildComparisonChart(
    AnalysisStatsV2 s1,
    AnalysisStatsV2 s2,
    String title,
  ) {
    int maxCount = 0;
    for (var lvl in _activeLevels) {
      int c1 = s1.levelCounts[lvl.label] ?? 0;
      int c2 = s2.levelCounts[lvl.label] ?? 0;
      maxCount = max(maxCount, max(c1, c2));
    }
    if (maxCount == 0) maxCount = 10;

    return Column(
      children: [
        // الرأس: العنوان يمين + المفتاح يسار
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'مقارنة أعداد الطلاب',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),

            // المفتاح (Legend) هنا
            Row(
              children: [
                _buildLegendItem(Colors.grey.shade400, 'ف1'),
                const SizedBox(width: 8),
                _buildLegendItem(const Color(0xFF2E7D6F), 'ف2'),
              ],
            ),
          ],
        ),

        const SizedBox(height: 10), // مسافة صغيرة تحت العنوان
        // الرسم البياني
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _activeLevels.map((lvl) {
              int c1 = s1.levelCounts[lvl.label] ?? 0;
              int c2 = s2.levelCounts[lvl.label] ?? 0;

              double h1 =
                  (c1 / maxCount) *
                  120; // تقليل ارتفاع الرسم قليلاً ليناسب البطاقة
              double h2 = (c2 / maxCount) * 120;
              if (h1 == 0 && c1 > 0) h1 = 4;
              if (h2 == 0 && c2 > 0) h2 = 4;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                ), // تقليل المسافات بين الأعمدة
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildBar(h1, c1, Colors.grey.shade400),
                        const SizedBox(width: 2),
                        _buildBar(h2, c2, const Color(0xFF2E7D6F)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      lvl.label,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),

        // مسافة صغيرة جداً قبل الجدول (كما طلبت 2 بكسل)
      ],
    );
  }

  Widget _buildBar(double height, int value, Color color) {
    return Column(
      children: [
        if (value > 0)
          Text(
            '$value'.toAppNum(),
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
          ),
        Container(
          width: 16,
          height: height > 0 ? height : 1, // Avoid 0 height
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(width: 10, height: 10, color: color),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  // === الجدول التفصيلي ===
  // === الويدجت: جدول تفصيلي (مصغر) ===
  Widget _buildDetailedTable(AnalysisStatsV2 s1, AnalysisStatsV2 s2) {
    return Table(
      border: TableBorder.all(
        color: Colors.grey.shade200,
        width: 0.5,
      ), // حدود أرق
      columnWidths: const {
        0: FlexColumnWidth(2.5), // المستوى (أعرض قليلاً)
        1: FlexColumnWidth(1), // ف1
        2: FlexColumnWidth(1), // ف2
        3: FlexColumnWidth(1), // الفرق
      },
      children: [
        // الرأس
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade50),
          children: const [
            _TableCell('المستوى', isHeader: true),
            _TableCell('ف1', isHeader: true),
            _TableCell('ف2', isHeader: true),
            _TableCell('الفرق', isHeader: true),
          ],
        ),
        // الصفوف
        ..._activeLevels.map((lvl) {
          int c1 = s1.levelCounts[lvl.label] ?? 0;
          int c2 = s2.levelCounts[lvl.label] ?? 0;
          int diff = c2 - c1;
          Color diffColor = diff > 0
              ? Colors.green
              : (diff < 0 ? Colors.red : Colors.grey);

          return TableRow(
            children: [
              _TableCell(lvl.label, align: TextAlign.right),
              _TableCell('$c1'),
              _TableCell('$c2'),
              _TableCell(
                '${diff > 0 ? "+" : ""}$diff',
                color: diffColor,
                isBold: true,
              ),
            ],
          );
        }),
      ],
    );
  }
}

// === خلية الجدول (مصغرة) ===
class _TableCell extends StatelessWidget {
  final String text;
  final bool isHeader;
  final bool isBold;
  final Color? color;
  final TextAlign align;

  const _TableCell(
    this.text, {
    this.isHeader = false,
    this.isBold = false,
    this.color,
    this.align = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      // تقليل الحشو لتقليص ارتفاع الصفوف
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
      child: Text(
        text.toAppNum(),
        textAlign: align,
        style: TextStyle(
          fontWeight: isHeader || isBold ? FontWeight.bold : FontWeight.normal,
          color: color ?? (isHeader ? const Color(0xFF2E7D6F) : Colors.black87),
          // تصغير الخط (11 للرأس، 10 للبيانات)
          fontSize: isHeader ? 8 : 12,
        ),
      ),
    );
  }
}
