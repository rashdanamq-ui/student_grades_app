import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';

// ✅ تصحيح المسارات (استخدمنا package path لتجنب الأخطاء)
import 'package:student_grades_app/models/student.dart';
import 'package:student_grades_app/models/mock_student.dart';
import 'package:student_grades_app/core/utils/number_utils.dart';
import 'package:student_grades_app/Features/analysis/models/analysis_view_models.dart';
import 'package:student_grades_app/Features/analysis/services/analysis_pdf_service.dart';
// تأكد من وجود ملف المعاينة، إذا لم يكن موجوداً احذف السطر التالي واستخدم الطباعة المباشرة
import 'package:student_grades_app/Features/analysis/pages/pdf_preview_page.dart';

class AnalysisPrintDialog extends StatefulWidget {
  final String initialClassTitle;
  final AnalysisStatsV2 stats;
  final List<LevelConfigV2> activeLevels;
  final List<Student> students;
  // قمنا بتعديل نوع الدالة لتقبل List<Student> مباشرة
  final List<Student> Function(String levelLabel) getStudentsForLevel;

  const AnalysisPrintDialog({
    super.key,
    required this.initialClassTitle,
    required this.stats,
    required this.activeLevels,
    required this.students,
    required this.getStudentsForLevel,
  });

  @override
  State<AnalysisPrintDialog> createState() => _AnalysisPrintDialogState();
}

class _AnalysisPrintDialogState extends State<AnalysisPrintDialog> {
  static const _reportMetaKey = 'modern_analysis_report_meta';

  final _regionCtrl = TextEditingController();
  final _ministryCtrl = TextEditingController(text: 'وزارة التعليم');
  final _officeCtrl = TextEditingController();
  final _schoolCtrl = TextEditingController();
  final _stageCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _academicCtrl = TextEditingController();
  final _teacherCtrl = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _examTitleCtrl = TextEditingController(text: 'الاختبار');

  final String _pdfPage1Title = 'تحليل نتائج اختبار مادة';
  final String _pdfPage2Title = 'كشف بأسماء الطلاب الأوائل والمتأخرين دراسياً';
  final String _pdfPage3Title = 'قوائم الطلاب مصنفة حسب التقدير (المستوى)';

  @override
  void initState() {
    super.initState();
    _stageCtrl.text = widget.initialClassTitle;
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_reportMetaKey);
    if (str != null) {
      try {
        final Map<String, dynamic> meta = jsonDecode(str);
        setState(() {
          _schoolCtrl.text = meta['schoolName'] ?? '';
          _regionCtrl.text = meta['regionName'] ?? '';
          _officeCtrl.text = meta['officeName'] ?? '';
          _yearCtrl.text = meta['yearText'] ?? '';
          _academicCtrl.text = meta['academicYear'] ?? '';
          _teacherCtrl.text = meta['teacherName'] ?? '';
          _principalCtrl.text = meta['principalName'] ?? '';
          _examTitleCtrl.text = meta['examTitleText'] ?? 'الاختبار';
        });
      } catch (_) {}
    }
  }

  Future<void> _saveMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> meta = {
      'schoolName': _schoolCtrl.text,
      'regionName': _regionCtrl.text,
      'officeName': _officeCtrl.text,
      'yearText': _yearCtrl.text,
      'academicYear': _academicCtrl.text,
      'teacherName': _teacherCtrl.text,
      'principalName': _principalCtrl.text,
      'examTitleText': _examTitleCtrl.text,
    };
    await prefs.setString(_reportMetaKey, jsonEncode(meta));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: const Text(
          'إعدادات التقرير والطباعة',
          style: TextStyle(color: Colors.teal),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('الترويسة العامة:'),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(_regionCtrl, 'الدولة/المنطقة'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTextField(_ministryCtrl, 'الوزارة')),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildTextField(_officeCtrl, 'الإدارة')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTextField(_schoolCtrl, 'المدرسة')),
                  ],
                ),
                const Divider(),
                _buildSectionTitle('معلومات الصف:'),
                Row(
                  children: [
                    Expanded(child: _buildTextField(_stageCtrl, 'اسم الصف')),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTextField(_examTitleCtrl, 'عنوان المادة'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(_yearCtrl, 'الفصل الدراسي'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTextField(_academicCtrl, 'العام الدراسي'),
                    ),
                  ],
                ),
                const Divider(),
                _buildSectionTitle('التوقيعات:'),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(_teacherCtrl, 'معلم المادة'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTextField(_principalCtrl, 'مدير المدرسة'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),

          // ✅ زر الطباعة المباشرة
          TextButton.icon(
            icon: const Icon(Icons.print, size: 18),
            label: const Text('طباعة مباشرة'),
            style: TextButton.styleFrom(foregroundColor: Colors.teal),
            onPressed: () async {
              await _saveMeta();
              if (!mounted) return;
              Navigator.pop(context);

              await Printing.layoutPdf(
                onLayout: (format) async {
                  // 1. حساب المستويات (الحل هنا ✅)
                  final calculatedLevels = widget.stats.levelsWithRanges(
                    widget.activeLevels,
                  );

                  // 2. تجهيز الطلاب
                  final sorted = List<Student>.from(widget.students);
                  sorted.sort(
                    (a, b) => (b.tempScore ?? 0).compareTo(a.tempScore ?? 0),
                  );

                  final top10 = sorted
                      .take(15)
                      .map(
                        (s) => MockStudent(
                          id: '',
                          name: s.name,
                          exams: [],
                          className: s.className, // ✅ استخدام اسم الفصل الفعلي
                        )..tempScore = s.tempScore,
                      )
                      .toList();
                  final bottom10 = sorted.reversed
                      .take(15)
                      .map(
                        (s) => MockStudent(
                          id: '',
                          name: s.name,
                          exams: [],
                          className: s.className, // ✅ استخدام اسم الفصل الفعلي
                        )..tempScore = s.tempScore,
                      )
                      .toList();

                  // 3. توليد الـ PDF
                  return await AnalysisPdfService.generatePdf(
                    format: format,
                    meta: AnalysisReportMeta(
                      regionName: _regionCtrl.text,
                      ministryLabel: _ministryCtrl.text,
                      officeName: _officeCtrl.text,
                      schoolName: _schoolCtrl.text,
                      examTitle: _examTitleCtrl.text,
                      stageClass: _stageCtrl.text,
                      yearText: _yearCtrl.text,
                      academicYear: _academicCtrl.text,
                      teacherName: _teacherCtrl.text,
                      principalName: _principalCtrl.text,
                      page1Title: _pdfPage1Title,
                      page2Title: _pdfPage2Title,
                      page3Title: _pdfPage3Title,
                    ),
                    stats: widget.stats,

                    levels:
                        calculatedLevels, // ✅✅✅ مررنا القائمة المحسوبة بدلاً من []

                    topStudents: top10,
                    bottomStudents: bottom10,
                    activeLevelConfigs: widget.activeLevels,
                    getStudentsForLevel: (lvl) => widget
                        .getStudentsForLevel(lvl.label)
                        .map(
                          (s) => MockStudent(
                            id: '',
                            name: s.name,
                            exams: [],
                            className:
                                s.className, // ✅ استخدام اسم الفصل الفعلي
                          )..tempScore = s.tempScore,
                        )
                        .toList(),
                    formatGrade: (val) => formatNumberForDisplay(val),
                  );
                },
                name: 'تقرير_${_stageCtrl.text}',
              );
            },
          ),

          // ✅ زر المعاينة
          ElevatedButton.icon(
            icon: const Icon(Icons.preview),
            label: const Text('معاينة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await _saveMeta();
              if (!mounted) return;
              Navigator.pop(context);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PdfPreviewPage(
                    title: 'معاينة التقرير',
                    generatePdfFunction: (format) async {
                      // 1. حساب المستويات (الحل هنا ✅)
                      final calculatedLevels = widget.stats.levelsWithRanges(
                        widget.activeLevels,
                      );

                      // 2. تجهيز الطلاب
                      final sorted = List<Student>.from(widget.students);
                      sorted.sort(
                        (a, b) =>
                            (b.tempScore ?? 0).compareTo(a.tempScore ?? 0),
                      );

                      final top10 = sorted
                          .take(15)
                          .map(
                            (s) => MockStudent(
                              id: '',
                              name: s.name,
                              exams: [],
                              className:
                                  s.className, // ✅ استخدام اسم الفصل الفعلي
                            )..tempScore = s.tempScore,
                          )
                          .toList();
                      final bottom10 = sorted.reversed
                          .take(15)
                          .map(
                            (s) => MockStudent(
                              id: '',
                              name: s.name,
                              exams: [],
                              className:
                                  s.className, // ✅ استخدام اسم الفصل الفعلي
                            )..tempScore = s.tempScore,
                          )
                          .toList();

                      return await AnalysisPdfService.generatePdf(
                        format: format,
                        meta: AnalysisReportMeta(
                          regionName: _regionCtrl.text,
                          ministryLabel: _ministryCtrl.text,
                          officeName: _officeCtrl.text,
                          schoolName: _schoolCtrl.text,
                          examTitle: _examTitleCtrl.text,
                          stageClass: _stageCtrl.text,
                          yearText: _yearCtrl.text,
                          academicYear: _academicCtrl.text,
                          teacherName: _teacherCtrl.text,
                          principalName: _principalCtrl.text,
                          page1Title: _pdfPage1Title,
                          page2Title: _pdfPage2Title,
                          page3Title: _pdfPage3Title,
                        ),
                        stats: widget.stats,

                        levels:
                            calculatedLevels, // ✅✅✅ مررنا القائمة المحسوبة بدلاً من []

                        topStudents: top10,
                        bottomStudents: bottom10,
                        activeLevelConfigs: widget.activeLevels,
                        getStudentsForLevel: (lvl) => widget
                            .getStudentsForLevel(lvl.label)
                            .map(
                              (s) => MockStudent(
                                id: '',
                                name: s.name,
                                exams: [],
                                className:
                                    s.className, // ✅ استخدام اسم الفصل الفعلي
                              )..tempScore = s.tempScore,
                            )
                            .toList(),
                        formatGrade: (val) => formatNumberForDisplay(val),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
      ),
    );
  }
}
