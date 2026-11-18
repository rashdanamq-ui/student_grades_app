//= (تحليل عدة فصول) //

import 'dart:typed_data';

import 'package:student_grades_app/Features/analysis/widgets/level_settings_dialog.dart';
import 'package:student_grades_app/core/config/class_grading_config.dart';
import 'package:student_grades_app/core/grading_levels/level_settings_service.dart';
import '../../../core/utils/number_utils.dart'; // تأكد من صحة المسار في مشروعك
import '../../models/mock_student.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart'; // للطباعة
import 'package:pdf/pdf.dart' as pdf;
// --- استدعاء الموديلات والخدمات والويجت ---

import 'pages/pdf_preview_page.dart';

import 'models/analysis_view_models.dart';
import 'services/analysis_calculator.dart';
import 'services/analysis_pdf_service.dart';

import 'widgets/analysis_summary_card.dart';
import 'widgets/analysis_charts_section.dart';
import 'widgets/ranked_students_grid.dart';
import 'widgets/analysis_filter_bar.dart';

class MultiClassAnalysisPage extends StatefulWidget {
  // نستقبل قائمة بأسماء ومعرفات الفصول المختارة
  final List<String> classIds;
  final List<String> classTitles;

  // ✅ إضافة متغير لنوع التحليل (اختياري، الافتراضي هو المجموع)
  final String analysisTag;

  const MultiClassAnalysisPage({
    super.key,
    required this.classIds,
    required this.classTitles,
    this.analysisTag = 'total', // القيمة الافتراضية
  });

  @override
  State<MultiClassAnalysisPage> createState() => _MultiClassAnalysisPageState();
}

class _MultiClassAnalysisPageState extends State<MultiClassAnalysisPage> {
  // البيانات
  List<MockStudent> allStudents = []; // قائمة الطلاب المدمجة
  // متغيرات التقرير الافتراضية
  String _schoolName = 'السلام الابتدائية بسيهات';
  String _regionName = 'المملكة العربية السعودية';
  String _ministryLabel = 'وزارة التعليم';
  String _officeName = 'الإدارة العامة للتعليم بالمنطقة الشرقية';
  String _yearText = 'الفصل الدراسي ...';
  String _academicYear = '1447 هـ';
  String _teacherName = 'رشيد العلقم';
  String _principalName = 'محمد الزهراني';
  String _pdfPage1Title = 'تحليل نتائج اختبار مادة ...';
  String _pdfPage2Title = 'كشف بأسماء الطلاب الأوائل والمتأخرين دراسياً';
  String _pdfPage3Title = 'قوائم الطلاب مصنفة حسب التقدير (المستوى)';
  // الإعدادات (نأخذها من أول فصل كقالب)
  List<double> _examMax = [];
  List<String> _examTags = [];
  int _examCount = 8;
  bool _isLoading =
      true; // أضف هذا المتغير في بداية _MultiClassAnalysisPageState
  // حالة الواجهة
  String _selectedTag = 'Comprehensive';
  bool _useSumInsteadOfPercent = false;
  int _bottomIndex = 0;
  List<LevelConfigV2> _dynamicLevels = [];

  // إعدادات التقرير
  String _reportTitle = 'تحليل مجمع';
  // ... (يمكنك إضافة بقية متغيرات التقرير هنا مثل اسم المعلم والمدير)

  void _updateMetaFromControllers(
    TextEditingController region,
    TextEditingController school,
    TextEditingController teacher,
    TextEditingController principal,
  ) {
    setState(() {
      _regionName = region.text;
      _schoolName = school.text;
      _teacherName = teacher.text;
      _principalName = principal.text;
    });
  }

  // دالة مشتركة لتوليد الـ PDF (تستخدمها المعاينة والحفظ المباشر)
  Future<Uint8List> _generateCurrentPdf(
    pdf.PdfPageFormat format,
    String exam,
    String stage,
    String semester,
    String year,
    String p1,
    String p2,
    String p3,
  ) async {
    // حساب الإحصائيات مباشرة بدلاً من الاعتماد على الكاش
    final currentStats = stats;
    final levelsList = currentStats.levelsWithRanges(_activeLevels());

    // تحديث tempScore لكل طالب
    for (var s in allStudents) {
      s.tempScore = AnalysisCalculator.calculateStudentScore(
        student: s,
        selectedTag: _selectedTag,
        useSum: _useSumInsteadOfPercent,
        examCount: _examCount,
        examMaxScores: _examMax,
        examTags: _examTags,
      );
    }

    allStudents.sort(
      (a, b) => (b.tempScore ?? 0.0).compareTo(a.tempScore ?? 0.0),
    );

    return await AnalysisPdfService.generatePdf(
      format: format,
      meta: AnalysisReportMeta(
        regionName: _regionName,
        ministryLabel: _ministryLabel,
        officeName: _officeName,
        schoolName: _schoolName,
        examTitle: exam,
        stageClass: stage,
        yearText: semester,
        academicYear: year,
        teacherName: _teacherName,
        principalName: _principalName,
        page1Title: p1,
        page2Title: p2,
        page3Title: p3,
      ),
      stats: currentStats,
      levels: levelsList,
      topStudents: allStudents.take(15).toList(),
      bottomStudents: allStudents.reversed.take(15).toList(),
      activeLevelConfigs: _activeLevels(),
      getStudentsForLevel: _getStudentsForLevel,
      formatGrade: (val) => formatNumberForDisplay(val),
    );
  }

  // دالة الانتقال للمعاينة
  void _navigateToPreview(
    BuildContext context,
    String exam,
    String stage,
    String semester,
    String year,
    String p1,
    String p2,
    String p3,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PdfPreviewPage(
          title: "معاينة التقرير",
          generatePdfFunction: (format) => _generateCurrentPdf(
            format,
            exam,
            stage,
            semester,
            year,
            p1,
            p2,
            p3,
          ),
        ),
      ),
    );
  }

  void _showEditAndExportDialog() {
    // تحديد العنوان الافتراضي للاختبار حسب التاق
    String defaultExamTitle = widget.analysisTag == 'total'
        ? 'المجموع الكلي'
        : (widget.analysisTag == 'perform'
              ? 'المهام الأدائية'
              : widget.analysisTag);

    // تحديد عنوان الصف الافتراضي (أسماء الفصول المدمجة)
    String defaultClassTitle = widget.classTitles.length > 3
        ? '${widget.classTitles.length} فصول'
        : widget.classTitles.join(' + ');

    // تجهيز المتحكمات (Controllers) بالقيم الحالية
    final regionCtrl = TextEditingController(text: _regionName);
    final ministryCtrl = TextEditingController(text: _ministryLabel);
    final officeCtrl = TextEditingController(text: _officeName);
    final schoolCtrl = TextEditingController(text: _schoolName);

    final page1Ctrl = TextEditingController(text: _pdfPage1Title);
    final page2Ctrl = TextEditingController(text: _pdfPage2Title);
    final page3Ctrl = TextEditingController(text: _pdfPage3Title);

    final examCtrl = TextEditingController(text: defaultExamTitle);
    final academicYearCtrl = TextEditingController(text: _academicYear);
    final stageCtrl = TextEditingController(text: defaultClassTitle);
    final semesterCtrl = TextEditingController(text: _yearText);

    final teacherCtrl = TextEditingController(text: _teacherName);
    final principalCtrl = TextEditingController(text: _principalName);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl, // ✅ 2. جعل النافذة من اليمين لليسار
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
                      const SizedBox(width: 8),
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
                      const SizedBox(width: 8),
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
                  const Divider(height: 20),

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

                  const Divider(height: 20),
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
                      const SizedBox(width: 8),
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
                  const SizedBox(height: 8),
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
                      const SizedBox(width: 8),
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
                  const SizedBox(height: 8),
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
                      const SizedBox(width: 8),
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

            // 1. زر الحفظ المباشر (Direct Save/Share)
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('حفظ PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                _updateMetaFromControllers(
                  regionCtrl,
                  schoolCtrl,
                  teacherCtrl,
                  principalCtrl,
                );
                Navigator.pop(ctx);

                // إظهار رسالة تحميل
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('جاري حفظ الملف...')),
                );

                try {
                  final bytes = await _generateCurrentPdf(
                    pdf.PdfPageFormat.a4,
                    examCtrl.text,
                    stageCtrl.text,
                    semesterCtrl.text,
                    academicYearCtrl.text,
                    page1Ctrl.text,
                    page2Ctrl.text,
                    page3Ctrl.text,
                  );

                  await Printing.layoutPdf(onLayout: (format) async => bytes);
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

            // 2. زر المعاينة (Preview)
            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('معاينة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                _updateMetaFromControllers(
                  regionCtrl,
                  schoolCtrl,
                  teacherCtrl,
                  principalCtrl,
                );
                Navigator.pop(ctx);

                try {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PdfPreviewPage(
                        title: "معاينة التقرير",
                        generatePdfFunction: (format) => _generateCurrentPdf(
                          format,
                          examCtrl.text,
                          stageCtrl.text,
                          semesterCtrl.text,
                          academicYearCtrl.text,
                          page1Ctrl.text,
                          page2Ctrl.text,
                          page3Ctrl.text,
                        ),
                      ),
                    ),
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('خطأ في المعاينة: $e'),
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

  // ✅ 1. دالة تحديث البيانات من الحقول النصية

  @override
  void initState() {
    super.initState();

    _loadLevels(); // ✅ جديد

    Future.delayed(const Duration(milliseconds: 500), () {
      _loadMultiClassData();
    });
  }

  Future<void> _loadLevels() async {
    final settings = await LevelSettingsService.load();

    setState(() {
      _dynamicLevels = settings.levels
        ..sort((a, b) => b.minPercent.compareTo(a.minPercent));
    });
  }

  /// دالة ذكية لدمج بيانات الفصول
  Future<void> _loadMultiClassData() async {
    // 1. إظهار مؤشر التحميل فوراً
    setState(() {
      _isLoading = true;
      allStudents = [];
    });

    // تأخير بسيط جداً للسماح لـ Flutter برسم دائرة التحميل قبل بدء العمليات الثقيلة
    await Future.delayed(const Duration(milliseconds: 100));

    final prefs = await SharedPreferences.getInstance();
    List<MockStudent> tempStudents = [];

    // ✅ التعديل الجديد (خطوة 1): حساب أعلى درجة عظمى بين الفصول المختارة (لضبط المقياس)
    // بدلاً من التثبيت على 100، نبحث عن "أكبر درجة عظمى" في الفصول لكي تظهر الدرجات بواقعية
    double unifiedMaxScore = 0.0;

    // نحتاج لقراءة الإعدادات أولاً لحساب المقياس الموحد
    List<double> classMaxScores = [];
    List<ClassGradingConfig> loadedConfigs = [];

    try {
      // جولة أولى: تحميل الإعدادات وتحديد المقياس الأعلى
      for (int i = 0; i < widget.classIds.length; i++) {
        final config = await ClassGradingConfig.load(widget.classIds[i]);
        loadedConfigs.add(config);

        final allCols = [...config.items, ...config.exams];
        double clsMax = 0.0;

        if (widget.analysisTag == 'total') {
          clsMax = config.getTotalMaxScore();
        } else if (widget.analysisTag == 'perform') {
          clsMax = allCols
              .where((c) => c.isPerformanceTask)
              .fold(0, (prev, c) => prev + c.maxScore);
        } else {
          clsMax = allCols
              .where((c) => c.tag == widget.analysisTag)
              .fold(0, (prev, c) => prev + c.maxScore);
        }
        classMaxScores.add(clsMax);
        if (clsMax > unifiedMaxScore) unifiedMaxScore = clsMax;
      }

      // إذا لم نجد أي درجة (كل الفصول 0)، نضع 100 كاحتياط
      if (unifiedMaxScore <= 0) unifiedMaxScore = 100.0;

      // جولة ثانية: معالجة الطلاب وتوحيد درجاتهم بناءً على المقياس الأعلى
      for (int i = 0; i < widget.classIds.length; i++) {
        final classId = widget.classIds[i];
        final classTitle = widget.classTitles[i];
        final config = loadedConfigs[i];
        final allCols = [...config.items, ...config.exams];

        // درجة هذا الفصل العظمى
        double currentClassMax = classMaxScores[i];
        // حماية من القسمة على صفر
        if (currentClassMax <= 0) currentClassMax = 1;

        // جلب قائمة الطلاب
        final studentsJson = prefs.getString('class_students_$classId');
        if (studentsJson != null) {
          final List studentList = jsonDecode(studentsJson);

          for (var studentItem in studentList) {
            String rawName = studentItem['name'] ?? '';
            String detailKey = 'student_detail_${rawName}_$classId';
            String? detailStr = prefs.getString(detailKey);

            double studentRawScore = 0.0;
            if (detailStr != null) {
              final Map<String, dynamic> data = jsonDecode(detailStr);

              // حساب المجموع الخام (Raw Score)
              for (var col in allCols) {
                bool shouldInclude =
                    (widget.analysisTag == 'total') ||
                    (widget.analysisTag == 'perform' &&
                        (col.isPerformanceTask ||
                            col.tag == 'القراءة' ||
                            col.tag == 'إملاء')) ||
                    (col.tag == widget.analysisTag);

                if (shouldInclude && data[col.id] != null) {
                  final val = data[col.id];
                  if (col.type == GradeType.numeric) {
                    studentRawScore += double.tryParse(val.toString()) ?? 0.0;
                  }
                  // 2. مربعات اختيار (الواجبات، المشاركة...)
                  else if (col.type == GradeType.checkbox) {
                    // ✅ تصحيح: دائماً نحسب بناءً على الوزن (العدد * درجة المربع الواحد)
                    // لأن القيمة المخزنة غالباً هي "عدد الصحوح" وليست الدرجة النهائية
                    int count = int.tryParse(val.toString()) ?? 0;
                    if (col.subCount > 0) {
                      studentRawScore += count * (col.maxScore / col.subCount);
                    } else {
                      // fallback لو لا يوجد عدد خانات (نادر)
                      studentRawScore += double.tryParse(val.toString()) ?? 0.0;
                    }
                  }
                  // 3. قوائم رقمية (المهام الأدائية المقسمة)
                  else if (col.type == GradeType.numericList) {
                    if (val is List && val.isNotEmpty) {
                      // ✅ تصحيح: الجمع هو الأصل، والمتوسط فقط للقراءة والإملاء
                      if (col.tag == 'القراءة' || col.tag == 'إملاء') {
                        double sum = 0;
                        int count = 0;
                        for (var v in val) {
                          double? d = double.tryParse(v.toString());
                          if (d != null) {
                            sum += d;
                            count++;
                          }
                        }
                        if (count > 0) {
                          double avg = sum / count;
                          studentRawScore += avg;
                        }
                      } else {
                        // (الوضع الطبيعي): جمع الدرجات
                        double sum = 0;
                        for (var v in val) {
                          double? d = double.tryParse(v.toString());
                          if (d != null) {
                            sum += d;
                          }
                        }
                        studentRawScore += sum;
                      }
                    }
                  }
                  // 4. ✅ إصلاح: اختبارات الفترة (متوسط درجتين)
                  else if (col.type == GradeType.averagePair) {
                    if (val is List && val.length >= 2) {
                      double v1 = double.tryParse(val[0].toString()) ?? 0.0;
                      double v2 = double.tryParse(val[1].toString()) ?? 0.0;
                      studentRawScore += (v1 + v2) / 2.0;
                    }
                  }
                }
              }
            }

            // ✅ التحويل:
            // إذا كان الطالب من فصل درجته العظمى 10، والمقياس الموحد 20 (لأن هناك فصل آخر من 20)
            // ودرجة الطالب 10/10 ---> (10 / 10) * 20 = 20 (الدرجة الكاملة)
            double normalizedScore =
                (studentRawScore / currentClassMax) * unifiedMaxScore;

            // تقريب
            normalizedScore = double.parse(normalizedScore.toStringAsFixed(2));

            if (normalizedScore > unifiedMaxScore)
              normalizedScore = unifiedMaxScore;

            tempStudents.add(
              MockStudent(
                id: '${classId}_$rawName',
                name: '$rawName ($classTitle)',
                exams: [normalizedScore, 0, 0, 0, 0, 0, 0, 0],
                className: classTitle, // ✅ استخدام اسم الفصل الفعلي
              ),
            );
          }
        }
        await Future.delayed(Duration.zero);
      }
    } catch (e) {
      debugPrint("❌ خطأ أثناء معالجة البيانات: $e");
    }

    if (mounted) {
      setState(() {
        allStudents = tempStudents;
        _isLoading = false;
        _reportTitle = 'تحليل: ${widget.classTitles.join(" + ")}';

        String displayTagName = widget.analysisTag == 'total'
            ? 'المجموع الكلي'
            : (widget.analysisTag == 'perform'
                  ? 'المهام الأدائية'
                  : widget.analysisTag);

        _examCount = 1;
        _examTags = [displayTagName, '', '', '', '', '', '', ''];

        // ✅ استخدام المقياس المحسوب ديناميكياً
        _maxTotalScoreGlobal = unifiedMaxScore;
        _examMax = [unifiedMaxScore, 0, 0, 0, 0, 0, 0, 0];

        _selectedTag = 'Comprehensive';
        _useSumInsteadOfPercent = false;
      });
    }
  }

  // متغير مساعد لتخزين الدرجة العظمى الموحدة (للاستخدام الداخلي)
  double _maxTotalScoreGlobal = 100.0;

  // --- دوال مساعدة للواجهة ---
  // نستخدم AnalysisCalculator للحسابات
  AnalysisStatsV2 get stats {
    // 1. حساب Max Score
    final maxScore = AnalysisCalculator.calculateMaxScore(
      selectedTag: _selectedTag,
      useSum: _useSumInsteadOfPercent,
      examCount: _examCount,
      examMaxScores: _examMax,
      examTags: _examTags,
      students: allStudents,
    );

    // 2. تحديث درجات الطلاب
    for (var s in allStudents) {
      s.tempScore = AnalysisCalculator.calculateStudentScore(
        student: s,
        selectedTag: _selectedTag,
        useSum: _useSumInsteadOfPercent,
        examCount: _examCount,
        examMaxScores: _examMax,
        examTags: _examTags,
      );
    }

    // 3. توليد الإحصائيات
    return AnalysisCalculator.generateStats(
      students: allStudents,
      maxScore: maxScore,
      activeLevels: _activeLevels(),
      selectedTag: _selectedTag,
      useSum: _useSumInsteadOfPercent,
    );
  }

  // مستويات ثابتة (يمكنك جلبها من الإعدادات أيضاً)
  List<LevelConfigV2> _activeLevels() => _dynamicLevels.isNotEmpty
      ? _dynamicLevels
      : [
          // fallback آمن جدًا
          LevelConfigV2(label: 'ممتاز', minPercent: 90),
          LevelConfigV2(label: 'جيد جدًا', minPercent: 80),
          LevelConfigV2(label: 'جيد', minPercent: 70),
          LevelConfigV2(label: 'مقبول', minPercent: 60),
          LevelConfigV2(label: 'ضعيف', minPercent: 0),
        ];

  // دالة لجلب طلاب مستوى معين (للواجهة)
  List<MockStudent> _getStudentsForLevel(LevelConfigV2 level) {
    // نحتاج MaxScore هنا أيضاً للمقارنة
    final maxScore = AnalysisCalculator.calculateMaxScore(
      selectedTag: _selectedTag,
      useSum: _useSumInsteadOfPercent,
      examCount: _examCount,
      examMaxScores: _examMax,
      examTags: _examTags,
      students: allStudents,
    );

    final activeLevels = _activeLevels();
    final levelIndex = activeLevels.indexOf(level);

    // نعتمد على AnalysisCalculator لتحديد مستوى كل طالب
    return allStudents.where((s) {
      final lvlLabel = AnalysisCalculator.getLevelForScore(
        score: s.tempScore ?? 0.0,
        maxScore: maxScore,
        useSum: _useSumInsteadOfPercent,
        selectedTag: _selectedTag,
        activeLevels: activeLevels,
      );
      return lvlLabel == level.label;
    }).toList()..sort((a, b) => (b.tempScore ?? 0).compareTo(a.tempScore ?? 0));
  }

  // --- الطباعة PDF ---
  Future<void> _exportPdfWithMeta({
    required String examTitle,
    required String className,
  }) async {
    final currentStats = stats;
    final levels = currentStats.levelsWithRanges(_activeLevels());

    // ترتيب الطلاب
    allStudents.sort(
      (a, b) => (b.tempScore ?? -1).compareTo(a.tempScore ?? -1),
    );
    final top10 = allStudents.take(15).toList();
    final bottom10 = allStudents
        .where((s) => (s.tempScore ?? 0) >= 0)
        .toList()
        .reversed
        .take(15)
        .toList();

    // إنشاء كائن الميتا بالبيانات التي أدخلها المستخدم
    final meta = AnalysisReportMeta(
      regionName: _regionName,
      ministryLabel: _ministryLabel,
      officeName: _officeName,
      schoolName: _schoolName,

      examTitle: examTitle, // ✅ الاسم من النافذة
      stageClass: className, // ✅ اسم الصف من النافذة

      yearText: _yearText,
      academicYear: _academicYear,
      teacherName: _teacherName,
      principalName: _principalName,
      page1Title: _pdfPage1Title,
      page2Title: _pdfPage2Title,
      page3Title: _pdfPage3Title,
    );

    final pdfBytes = await AnalysisPdfService.generatePdf(
      format: pdf.PdfPageFormat.a4,
      meta: meta,
      stats: currentStats,
      levels: levels,
      topStudents: top10,
      bottomStudents: bottom10,
      activeLevelConfigs: _activeLevels(),
      getStudentsForLevel: _getStudentsForLevel,
      formatGrade: (val) => formatNumberForDisplay(val),
      showSum: _useSumInsteadOfPercent, // ✅ تمرير خيار عرض المجموع
    );

    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf0f4f7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFa2b2bf),
        title: Text(
          _reportTitle.toAppNum(),
          style: const TextStyle(
            color: Color(0xFF201F1F),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _showEditAndExportDialog,
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () async {
              final maxScore = AnalysisCalculator.calculateMaxScore(
                selectedTag: _selectedTag,
                useSum: _useSumInsteadOfPercent,
                examCount: _examCount,
                examMaxScores: _examMax,
                examTags: _examTags,
                students: allStudents,
              );

              final changed = await showDialog<bool>(
                context: context,
                builder: (_) => LevelSettingsDialog(maxScore: maxScore),
              );

              if (changed == true) {
                await _loadLevels();
                setState(() {});
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 16),
                  Text("جاري دمج بيانات الفصول وحساب النتائج..."),
                ],
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 1. الفلتر
                    AnalysisFilterBar(
                      examTags: _examTags,
                      selectedTag: _selectedTag,
                      useSum: _useSumInsteadOfPercent,
                      onTagSelected: (tag) =>
                          setState(() => _selectedTag = tag),
                      onToggleSum: (val) =>
                          setState(() => _useSumInsteadOfPercent = val),
                    ),
                    const SizedBox(height: 12),

                    // 2. الملخص
                    AnalysisSummaryCard(stats: stats),
                    const SizedBox(height: 20),

                    // 3. الشبكة
                    RankedStudentsGrid(
                      stats: stats,
                      activeLevels: _activeLevels(),
                      isComprehensive: _selectedTag == 'Comprehensive',
                      defaultClassName:
                          '-', // لا يهم لأن الأسماء تحتوي على الصف
                      onGetStudentsForLevel: _getStudentsForLevel,
                    ),
                    const SizedBox(height: 24),

                    // 4. الرسوم البيانية
                    AnalysisChartsSection(
                      stats: stats,
                      activeLevels: _activeLevels(),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
