import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_grades_app/Features/analysis/services/analysis_pdf_service.dart';

import '../../../models/student.dart';
import '../../../core/config/class_grading_config.dart';
import '../../../core/grading_levels/level_settings_service.dart';
import '../services/period_comparison_pdf_service.dart';
import '../models/analysis_view_models.dart';

class PeriodComparisonPrintDialog extends StatefulWidget {
  final String initialClassTitle;
  final ClassGradingConfig config;
  final List<Student> students;
  final Map<String, Map<String, dynamic>> allScores;
  final List<LevelConfigV2> activeLevels;
  final List<String> availableTags;

  const PeriodComparisonPrintDialog({
    super.key,
    required this.initialClassTitle,
    required this.config,
    required this.students,
    required this.allScores,
    required this.activeLevels,
    required this.availableTags,
  });

  @override
  State<PeriodComparisonPrintDialog> createState() =>
      _PeriodComparisonPrintDialogState();
}

class _PeriodComparisonPrintDialogState
    extends State<PeriodComparisonPrintDialog> {
  final _formKey = GlobalKey<FormState>();

  // حقول الديباجة
  late TextEditingController _ministryCtrl;
  late TextEditingController _schoolCtrl;
  late TextEditingController _titleCtrl;
  late TextEditingController _teacherCtrl;
  late TextEditingController _principalCtrl;

  @override
  void initState() {
    super.initState();
    _ministryCtrl = TextEditingController(text: 'وزارة التعليم');
    _schoolCtrl = TextEditingController(text: 'اسم المدرسة');
    _titleCtrl = TextEditingController(text: widget.initialClassTitle);
    _teacherCtrl = TextEditingController(text: '');
    _principalCtrl = TextEditingController(text: '');
    _loadSavedMeta();
  }

  Future<void> _loadSavedMeta() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ministryCtrl.text = prefs.getString('meta_ministry') ?? 'وزارة التعليم';
      _schoolCtrl.text = prefs.getString('meta_school') ?? 'اسم المدرسة';
      _teacherCtrl.text = prefs.getString('meta_teacher') ?? '';
      _principalCtrl.text = prefs.getString('meta_principal') ?? '';
    });
  }

  Future<void> _saveMeta() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('meta_ministry', _ministryCtrl.text);
    await prefs.setString('meta_school', _schoolCtrl.text);
    await prefs.setString('meta_teacher', _teacherCtrl.text);
    await prefs.setString('meta_principal', _principalCtrl.text);
  }

  AnalysisReportMeta _getMeta() {
    return AnalysisReportMeta(
      ministryLabel: _ministryCtrl.text,
      schoolName: _schoolCtrl.text,
      page1Title: _titleCtrl.text,
      teacherName: _teacherCtrl.text,
      principalName: _principalCtrl.text,
      // قيم افتراضية للباقي
      regionName: '',
      officeName: '',
      examTitle: '',
      stageClass: '',
      yearText: '',
      academicYear: '',
      page2Title: '',
      page3Title: '',
    );
  }

  void _print(bool isPreview) async {
    await _saveMeta();
    final pdfBytes = await PeriodComparisonPdfService.generatePdf(
      meta: _getMeta(),
      config: widget.config,
      students: widget.students,
      allScores: widget.allScores,
      activeLevels: widget.activeLevels,
      availableTags: widget.availableTags,
    );

    if (isPreview) {
      await Printing.layoutPdf(onLayout: (_) => pdfBytes);
    } else {
      await Printing.layoutPdf(onLayout: (_) => pdfBytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إعدادات طباعة المقارنة'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildField(_ministryCtrl, 'الترويسة (الوزارة)'),
              _buildField(_schoolCtrl, 'اسم المدرسة'),
              _buildField(_titleCtrl, 'عنوان التقرير'),
              const Divider(),
              _buildField(_teacherCtrl, 'اسم المعلم'),
              _buildField(_principalCtrl, 'مدير المدرسة'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.print),
          label: const Text('طباعة / معاينة'),
          onPressed: () {
            Navigator.pop(context);
            _print(true);
          },
        ),
      ],
    );
  }

  Widget _buildField(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 0,
          ),
        ),
      ),
    );
  }
}
