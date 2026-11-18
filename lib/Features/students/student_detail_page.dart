// lib/features/analysis/students/student_detail_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
// تأكد من المسارات
import '../../core/config/class_grading_config.dart';
import '../../core/utils/number_utils.dart';
import '../../core/settings/app_settings.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ============================================================================
// ويدجت حقل الإدخال المحسن (يقبل الكتابة ويظهر خطأ إذا تجاوز الحد)
// ============================================================================
class ScoreInputField extends StatefulWidget {
  final String label;
  final String initialValue;
  final double? max;
  final Function(String) onChanged;

  const ScoreInputField({
    super.key,
    required this.label,
    required this.initialValue,
    this.max,
    required this.onChanged,
  });

  @override
  State<ScoreInputField> createState() => _ScoreInputFieldState();
}

class _ScoreInputFieldState extends State<ScoreInputField> {
  late TextEditingController _controller;
  String? _errorText;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    String text = widget.initialValue;
    double? val = double.tryParse(text);
    if (val == null || val == 0) {
      text = "";
    } else {
      text = val % 1 == 0
          ? val.toInt().toString().toAppNum()
          : val.toString().toAppNum();
    }

    _controller = TextEditingController(text: text);

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _validateAndFormat();
      }
    });
  }

  void _validateAndFormat() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final double? val = double.tryParse(text.toEnglishNum());

    if (val == null) {
      _controller.clear();
      widget.onChanged("0");
      return;
    }

    if (widget.max != null && val > widget.max!) {
      _controller.clear();
      widget.onChanged("0");
      return;
    }

    _controller.text = val % 1 == 0
        ? val.toInt().toString().toAppNum()
        : val.toString().toAppNum();

    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9\u0660-\u0669.,]')),
      ],
      decoration: InputDecoration(
        label: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(widget.label),
        ),
        floatingLabelAlignment: FloatingLabelAlignment.center,
        errorText: _errorText,
        errorStyle: const TextStyle(height: 0, fontSize: 0),
        hintText: '0',
        hintStyle: TextStyle(color: Colors.grey.shade300),
        labelStyle: const TextStyle(fontSize: 12, color: Colors.black54),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: _errorText != null ? const Color(0xFFFFEBEE) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
      ),
      onChanged: (val) {
        widget.onChanged(val.replaceAll(',', '.').toEnglishNum());
      },
    );
  }
}

// ============================================================================
// الصفحة الرئيسية للطالب

class StudentDetailPage extends StatefulWidget {
  final String name;
  final String classId;
  final List<String> allNames;
  final int initialIndex;

  const StudentDetailPage({
    super.key,
    required this.name,
    required this.classId,
    this.allNames = const [],
    this.initialIndex = 0,
  });

  @override
  State<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage>
    with SingleTickerProviderStateMixin {
  final Color kPrimaryColor = const Color(0xFF2E7D6F);
  final Color kSectionBg = const Color(0xFFF5F7FA);

  late TabController _tabController;
  ClassGradingConfig _config = ClassGradingConfig();
  Map<String, dynamic> _studentData = {};

  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _seqController = TextEditingController();

  bool _isLoading = true;
  late int _currentIndex;
  late String _currentStudentName;

  // درجة الاختبار النهائي (تظهر فقط في الفترة الثانية)
  double _finalExamMaxScore = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentIndex = widget.initialIndex;
    _currentStudentName = widget.name;
    _seqController.text = (_currentIndex + 1).toString().toAppNum();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _notesController.dispose();
    _seqController.dispose();
    super.dispose();
  }

  // --- دالة الطباعة ---
  void _printReport() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('طباعة تقرير الطالب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.looks_one, color: Colors.blue),
              title: const Text('تقرير الفترة الأولى'),
              onTap: () {
                Navigator.pop(ctx);
                _generateStudentPdf(period: 1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.looks_two, color: Colors.blue),
              title: const Text('تقرير الفترة الثانية'),
              onTap: () {
                Navigator.pop(ctx);
                _generateStudentPdf(period: 2);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.summarize, color: Colors.green),
              title: const Text('التقرير الختامي (الشامل)'),
              onTap: () {
                Navigator.pop(ctx);
                _generateStudentPdf(period: 0); // 0 تعني شامل
              },
            ),
          ],
        ),
      ),
    );
  }

  // دالة وهمية حالياً لتوليد الـ PDF (سنفعلها لاحقاً)
  // --- دالة توليد PDF (الشهادة) ---
  // --- دالة توليد PDF (التقرير) ---
  // --- دالة توليد PDF (تقرير الطالب - النسخة النهائية) ---
  Future<void> _generateStudentPdf({required int period}) async {
    final doc = pw.Document();

    // تحميل الخطوط
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    // 1. العناوين
    String periodTitle = '';
    if (period == 1)
      periodTitle = 'الفترة الأولى';
    else if (period == 2)
      periodTitle = 'الفترة الثانية';
    else
      periodTitle = 'التقرير الختامي (شامل)';

    // 2. تجهيز البيانات
    final p1TableData = <List<String>>[];
    final p2TableData = <List<String>>[];
    final summaryTableData = <List<String>>[];

    final singlePeriodData = <List<String>>[];
    final singlePeriodHeaders = <String>[
      'الملاحظات',
      'درجة الطالب',
      'الدرجة العظمى',
      'البند',
    ];

    if (period == 0) {
      // --- تجهيز بيانات التقرير الشامل ---

      // جدول الفترة 1
      for (var col in _config.items) {
        if (!_isFinalExam(col)) {
          p1TableData.add([
            '',
            formatNumberForDisplay(_getColumnVal(col, '_p1')),
            formatNumberForDisplay(col.maxScore),
            col.name,
          ]);
        }
      }
      for (var col in _config.exams) {
        if (!_isFinalExam(col)) {
          p1TableData.add([
            '',
            formatNumberForDisplay(_getColumnVal(col, '_p1')),
            formatNumberForDisplay(col.maxScore),
            col.name,
          ]);
        }
      }
      double t1 = _calculatePeriodTotal('_p1');
      double periodMax = _getPeriodWorkMaxScore();
      p1TableData.add([
        '',
        formatNumberForDisplay(t1),
        formatNumberForDisplay(periodMax),
        'المجموع الكلي',
      ]);

      // جدول الفترة 2
      for (var col in _config.items) {
        if (!_isFinalExam(col)) {
          p2TableData.add([
            '',
            formatNumberForDisplay(_getColumnVal(col, '_p2')),
            formatNumberForDisplay(col.maxScore),
            col.name,
          ]);
        }
      }
      for (var col in _config.exams) {
        if (!_isFinalExam(col)) {
          p2TableData.add([
            '',
            formatNumberForDisplay(_getColumnVal(col, '_p2')),
            formatNumberForDisplay(col.maxScore),
            col.name,
          ]);
        }
      }
      double t2 = _calculatePeriodTotal('_p2');
      p2TableData.add([
        '',
        formatNumberForDisplay(t2),
        formatNumberForDisplay(periodMax),
        'المجموع الكلي',
      ]);

      // جدول الملخص
      double fin = _getFinalExamScore();
      double avgPeriods = (t1 + t2) / 2;
      double grandTotal = avgPeriods + fin;
      summaryTableData.add([
        '',
        formatNumberForDisplay(grandTotal),
        formatNumberForDisplay(fin),
        formatNumberForDisplay(avgPeriods),
        formatNumberForDisplay(t2),
        formatNumberForDisplay(t1),
        'المجموع العام',
      ]);
    } else {
      // --- تجهيز بيانات تقرير الفترة الواحدة ---
      String suffix = period == 1 ? '_p1' : '_p2';
      for (var col in _config.items) {
        if (!_isFinalExam(col)) {
          singlePeriodData.add([
            '',
            formatNumberForDisplay(_getColumnVal(col, suffix)),
            formatNumberForDisplay(col.maxScore),
            col.name,
          ]);
        }
      }
      for (var col in _config.exams) {
        if (!_isFinalExam(col)) {
          singlePeriodData.add([
            '',
            formatNumberForDisplay(_getColumnVal(col, suffix)),
            formatNumberForDisplay(col.maxScore),
            col.name,
          ]);
        }
      }
      double total = _calculatePeriodTotal(suffix);
      double periodMax = _getPeriodWorkMaxScore();
      singlePeriodData.add([
        '',
        formatNumberForDisplay(total),
        formatNumberForDisplay(periodMax),
        'المجموع الكلي',
      ]);
    }

    // 3. بناء ملف PDF
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return [
            // ================= الرأس (تم التعديل هنا) =================
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    periodTitle,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      // اسم الطالب
                      pw.Text(
                        _currentStudentName,
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      // مسافة
                      pw.SizedBox(height: 4),
                      // العبارة مصغرة
                      pw.Text(
                        'كشف درجات الطالب',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ==========================================================
            pw.SizedBox(height: 10),

            // المحتوى (الجداول)
            if (period == 0) ...[
              // ... جدول الفترة 1 ...
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'الفترة الأولى',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Table.fromTextArray(
                headers: ['الملاحظات', 'درجة الطالب', 'الدرجة العظمى', 'البند'],
                data: p1TableData,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 10,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.center,
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(3),
                },
                cellPadding: const pw.EdgeInsets.symmetric(
                  vertical: 2,
                  horizontal: 4,
                ),
              ),

              pw.SizedBox(height: 15),

              // ... جدول الفترة 2 ...
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'الفترة الثانية',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Table.fromTextArray(
                headers: ['الملاحظات', 'درجة الطالب', 'الدرجة العظمى', 'البند'],
                data: p2TableData,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 10,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.center,
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(3),
                },
                cellPadding: const pw.EdgeInsets.symmetric(
                  vertical: 2,
                  horizontal: 4,
                ),
              ),

              pw.SizedBox(height: 15),

              // ... جدول الملخص ...
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'التقرير الختامي',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Table.fromTextArray(
                headers: [
                  'الملاحظات',
                  'المحصلة',
                  'النهائي',
                  'معدل الفترتين',
                  'فترة 2',
                  'فترة 1',
                  'البند',
                ],
                data: summaryTableData,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 10,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.center,
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  6: const pw.FlexColumnWidth(2),
                },
                cellPadding: const pw.EdgeInsets.symmetric(
                  vertical: 3,
                  horizontal: 4,
                ),
              ),
            ] else ...[
              // ... جدول الفترة الواحدة ...
              pw.Table.fromTextArray(
                headers: singlePeriodHeaders,
                data: singlePeriodData,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
                cellStyle: const pw.TextStyle(fontSize: 11),
                cellAlignment: pw.Alignment.center,
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(3),
                },
                cellPadding: const pw.EdgeInsets.symmetric(
                  vertical: 3,
                  horizontal: 5,
                ),
              ),
            ],

            pw.SizedBox(height: 20),

            // الملاحظات
            if (_notesController.text.isNotEmpty)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'ملاحظات:',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    pw.Text(
                      _notesController.text,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),

            pw.Spacer(),

            // التذييل
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  children: [
                    pw.Text(
                      ' ولي أمر الطالب',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 1),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text(
                      'معلم المادة',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 1),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text(
                      'مدير المدرسة',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.SizedBox(height: 1),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _config = await ClassGradingConfig.load(widget.classId);
    final prefs = await SharedPreferences.getInstance();
    final key = 'student_detail_${_currentStudentName}_${widget.classId}';
    final str = prefs.getString(key);

    if (str != null) {
      _studentData = jsonDecode(str);
      _notesController.text = (_studentData['notes'] ?? '').toString();
    } else {
      _studentData = {};
      _notesController.clear();
    }
    setState(() => _isLoading = false);
  }

  // دالة مساعدة لمعرفة هل هذا العمود هو اختبار نهائي أم لا
  bool _isFinalExam(GradeColumn col) {
    return col.tag == 'اختبار نهائي' || col.name.contains('نهائي');
  }

  Future<void> _saveData({bool showSnackBar = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'student_detail_${_currentStudentName}_${widget.classId}';

    // 1. حساب الفترات (بدون نهائي)
    double p1 = _calculatePeriodTotal('_p1');
    double p2 = _calculatePeriodTotal('_p2');

    // 2. جلب درجة النهائي
    double finalExam = _getFinalExamScore();

    // 3. المعادلة: متوسط الفترتين + النهائي
    double grandTotal = ((p1 + p2) / 2) + finalExam;

    _studentData['total_score'] = grandTotal;
    _studentData['notes'] = _notesController.text;

    await prefs.setString(key, jsonEncode(_studentData));

    if (mounted && showSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم الحفظ'),
          duration: Duration(milliseconds: 800),
        ),
      );
    }
  }

  // دالة لتنظيف البيانات (تأكد أن لا توجد درجة أكبر من الحد)
  void _sanitizeData() {
    // يمكنك تنفيذ منطق هنا يمر على كل الحقول ويصححها إذا زادت عن الحد
    // حالياً سنكتفي بتنبيه المستخدم بصرياً
  }

  void _navigate(int newIndex) async {
    if (newIndex < 0 || newIndex >= widget.allNames.length) return;
    await _saveData(showSnackBar: false);
    setState(() {
      _currentIndex = newIndex;
      _currentStudentName = widget.allNames[_currentIndex];
      _seqController.text = (_currentIndex + 1).toString().toAppNum();
    });
    _loadData();
  }

  // --- الحسابات ---
  double _getColumnVal(GradeColumn col, String suffix) {
    final key = '${col.id}$suffix';
    final val = _studentData[key];

    if (col.type == GradeType.numeric) {
      return double.tryParse(val.toString().toEnglishNum()) ?? 0.0;
    } else if (col.type == GradeType.checkbox) {
      int checkedCount = int.tryParse(val.toString().toEnglishNum()) ?? 0;
      if (col.subCount == 0) return 0.0;
      return checkedCount * (col.maxScore / col.subCount);
    } else if (col.type == GradeType.numericList) {
      if (val is! List || val.isEmpty) return 0.0;
      double sum = 0;
      int count = 0;
      for (var v in val) {
        double? d = double.tryParse(v.toString().toEnglishNum());
        if (d != null) {
          sum += d;
          count++;
        }
      }
      return count == 0 ? 0.0 : sum / count;
    } else if (col.type == GradeType.averagePair) {
      if (val is! List || val.length < 2) return 0.0;
      double v1 = double.tryParse(val[0].toString().toEnglishNum()) ?? 0.0;
      double v2 = double.tryParse(val[1].toString().toEnglishNum()) ?? 0.0;
      return (v1 + v2) / 2.0;
    }
    return 0.0;
  }

  // 1. حساب مجموع أعمال الفترة (يستثني الاختبار النهائي)
  double _calculatePeriodTotal(String suffix) {
    double total = 0.0;
    // جمع المهام
    for (var col in _config.items) {
      if (!_isFinalExam(col)) total += _getColumnVal(col, suffix);
    }
    // جمع الاختبارات (باستثناء النهائي)
    for (var col in _config.exams) {
      if (!_isFinalExam(col)) total += _getColumnVal(col, suffix);
    }
    return total;
  }

  // 2. دالة جديدة: جلب درجة الاختبار النهائي (من الفترة الثانية حصراً)
  // دالة جديدة لحساب الدرجة العظمى للفترة الواحدة (بدون النهائي)
  double _getPeriodWorkMaxScore() {
    double total = 0.0;
    // نجمع المهام
    for (var col in _config.items) {
      if (!_isFinalExam(col)) total += col.maxScore;
    }
    // نجمع الاختبارات (ما عدا النهائي)
    for (var col in _config.exams) {
      if (!_isFinalExam(col)) total += col.maxScore;
    }
    return total;
  }

  // 4. جلب درجة الطالب في الاختبار النهائي (من الفترة الثانية)
  double _getFinalExamScore() {
    double total = 0.0;
    for (var col in [..._config.items, ..._config.exams]) {
      if (_isFinalExam(col)) {
        total += _getColumnVal(col, '_p2');
      }
    }
    return total;
  }

  // 5. حساب الدرجة العظمى للاختبار النهائي (يجب أن تكون 40)
  double _getFinalExamMaxScore() {
    double total = 0.0;
    for (var col in [..._config.items, ..._config.exams]) {
      if (_isFinalExam(col)) total += col.maxScore;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    // --- 1. حسابات الطالب ---
    // مجموع درجات الفترة 1 (بدون نهائي)
    double totalP1 = _calculatePeriodTotal('_p1');
    // مجموع درجات الفترة 2 (بدون نهائي)
    double totalP2 = _calculatePeriodTotal('_p2');

    // درجة الطالب في النهائي (من الإعدادات)
    double finalExamScore = _getFinalExamScore();

    // --- 2. حسابات الدرجات العظمى (من الإعدادات) ---
    // العظمى للفترة (مثلاً 60)
    double periodMax = _getPeriodWorkMaxScore();
    // العظمى للنهائي (مثلاً 40)
    double finalExamMax = _getFinalExamMaxScore();

    // --- 3. المعادلة النهائية ---
    // معدل الفترتين
    double avgPeriods = (totalP1 + totalP2) / 2;

    // المحصلة النهائية = معدل الفترتين + درجة النهائي
    double grandTotal = avgPeriods + finalExamScore;

    // المجموع الكلي العظمى = درجة الفترة الواحدة + درجة النهائي (60 + 40 = 100)
    double grandMax = periodMax + finalExamMax;

    return ValueListenableBuilder<bool>(
      valueListenable: AppSettings.useArabicNumbers,
      builder: (context, isArabic, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: kPrimaryColor,
              foregroundColor: Colors.white,
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      _currentStudentName,
                      style: const TextStyle(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _currentIndex > 0
                            ? () => _navigate(_currentIndex - 1)
                            : null,
                      ),
                      SizedBox(
                        width: 40,
                        child: TextField(
                          controller: _seqController,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onSubmitted: (val) {
                            int? idx = int.tryParse(val.toEnglishNum());
                            if (idx != null) _navigate(idx - 1);
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _currentIndex < widget.allNames.length - 1
                            ? () => _navigate(_currentIndex + 1)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.print),
                  onPressed: _printReport,
                  tooltip: 'طباعة التقرير',
                ),

                IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: () => _saveData(),
                ),
              ],
            ),
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      _buildTopSummary(
                        totalP1,
                        totalP2,
                        avgPeriods,
                        finalExamScore,
                        grandTotal,
                        grandMax,
                      ),
                      Container(
                        color: kPrimaryColor,
                        child: TabBar(
                          controller: _tabController,
                          indicatorColor: Colors.white,
                          indicatorWeight: 4,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white60,
                          tabs: const [
                            Tab(text: 'الفترة الأولى'),
                            Tab(text: 'الفترة الثانية'),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildPeriodContent('_p1'), // محتوى الفترة الأولى
                            _buildPeriodContent('_p2'), // محتوى الفترة الثانية
                          ],
                        ),
                      ),
                      // الملاحظات فقط في الأسفل (أزلنا الاختبار النهائي من هنا)
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.white,
                        child: TextField(
                          controller: _notesController,
                          maxLines: 1,
                          decoration: InputDecoration(
                            labelText: 'ملاحظات عامة',
                            filled: true,
                            fillColor: kSectionBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(
                              Icons.note_alt_outlined,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  // كرت الملخص العلوي
  Widget _buildTopSummary(
    double p1,
    double p2,
    double avg,
    double fin,
    double total,
    double max,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      color: const Color(0xFFE0F2F1), // خلفية سماوي فاتح
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMiniScore('ف1', p1),
          const Icon(Icons.add, size: 14, color: Colors.grey),

          _buildMiniScore('ف2', p2),
          const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),

          _buildMiniScore('المعدل', avg),
          const Icon(Icons.add, size: 14, color: Colors.grey),

          // هنا إضافة الاختبار النهائي
          _buildMiniScore('النهائي', fin),

          // فاصل عمودي
          Container(height: 25, width: 1, color: Colors.grey.shade400),

          // المحصلة النهائية الكبرى
          Column(
            children: [
              const Text(
                'المحصلة',
                style: TextStyle(fontSize: 10, color: Colors.black87),
              ),
              Text(
                '${formatNumberForDisplay(total)}/${formatNumberForDisplay(max)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: kPrimaryColor,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniScore(String label, double val) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.black54),
        ),
        Text(
          formatNumberForDisplay(val),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // --- محتوى الفترة ---
  Widget _buildPeriodContent(String suffix) {
    bool isPeriod2 = suffix == '_p2';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // المهام (تظهر في الفترتين دائماً)
          ..._config.items.map((col) => _buildItemCard(col, suffix)),

          const SizedBox(height: 10),

          // الاختبارات (سنفلترها داخل الدالة نفسها)
          if (_config.exams.isNotEmpty) _buildExamsSection(suffix),

          const SizedBox(height: 50),
        ],
      ),
    );
  }

  // كرت الاختبار النهائي (الذي يظهر في الفترة 2 فقط)
  Widget _buildFinalExamCard() {
    return Card(
      elevation: 4,
      color: const Color(0xFFE8EAF6), // لون مميز (أزرق فاتح جداً)
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFF3F51B5), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(
              Icons.assignment_turned_in,
              size: 30,
              color: Color(0xFF3F51B5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'الاختبار النهائي',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF3F51B5),
                    ),
                  ),
                  Text(
                    'نهاية الفصل الدراسي',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 90,
              child: ScoreInputField(
                label: 'الدرجة',
                initialValue: (_studentData['final_exam_global'] ?? '')
                    .toString(),
                max: _finalExamMaxScore,
                onChanged: (v) {
                  setState(() {
                    _studentData['final_exam_global'] = v;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(GradeColumn col, String suffix) {
    if (col.type == GradeType.checkbox) return _buildCheckboxCard(col, suffix);
    if (col.type == GradeType.numericList)
      return _buildNumericListCard(col, suffix);
    return _buildNumericCard(col, suffix);
  }

  Widget _buildCheckboxCard(GradeColumn col, String suffix) {
    final key = '${col.id}$suffix';
    int currentChecked =
        int.tryParse(_studentData[key]?.toString().toEnglishNum() ?? '0') ?? 0;
    double valPerBox = col.subCount > 0 ? col.maxScore / col.subCount : 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  col.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${formatNumberForDisplay(_getColumnVal(col, suffix))}/${col.maxScore}',
                  style: TextStyle(
                    color: kPrimaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(col.subCount, (index) {
                bool isChecked = index < currentChecked;
                return GestureDetector(
                  onTap: () {
                    setState(
                      () => _studentData[key] =
                          isChecked && index == currentChecked - 1
                          ? currentChecked - 1
                          : index + 1,
                    );
                  },
                  child: Container(
                    width: 35,
                    height: 35,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isChecked ? kPrimaryColor : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${index + 1}'.toAppNum(),
                      style: TextStyle(
                        color: isChecked ? Colors.white : Colors.black54,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumericListCard(GradeColumn col, String suffix) {
    final key = '${col.id}$suffix';
    List<dynamic> values = _studentData[key] is List
        ? List.from(_studentData[key])
        : List.filled(col.subCount, "");
    if (values.length != col.subCount) values = List.filled(col.subCount, "");

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  col.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${formatNumberForDisplay(_getColumnVal(col, suffix))}/${col.maxScore}',
                  style: TextStyle(
                    color: kPrimaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(col.subCount, (index) {
                return SizedBox(
                  width: 55,
                  height: 40,
                  child: ScoreInputField(
                    label: '${index + 1}',
                    initialValue: values[index].toString(),
                    max: col.maxScore, // 👈 نفس الحد الأعلى
                    onChanged: (v) {
                      values[index] = v;
                      _studentData[key] = values;
                      setState(() {});
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumericCard(GradeColumn col, String suffix) {
    final key = '${col.id}$suffix';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(col.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(
              width: 90,
              child: ScoreInputField(
                label: 'الدرجة',
                initialValue: (_studentData[key] ?? '').toString(),
                max: col.maxScore,
                onChanged: (v) => setState(() => _studentData[key] = v),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- قسم الاختبارات القصيرة (معدل) ---
  Widget _buildExamsSection(String suffix) {
    return Card(
      color: const Color(0xFFFFF8E1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الاختبارات',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const Divider(),
            ..._config.exams.map((col) {
              // >>> التعديل هنا: الإخفاء <<<
              // إذا كنا في الفترة الأولى (_p1) والعمود هو اختبار نهائي -> لا نعرضه
              if (suffix == '_p1' && _isFinalExam(col)) {
                return const SizedBox.shrink(); // يخفي العنصر تماماً
              }

              // بقية الكود كما هو...
              if (col.type == GradeType.averagePair) {
                final key = '${col.id}$suffix';
                List<dynamic> values = ["", ""];
                if (_studentData[key] is List &&
                    (_studentData[key] as List).length >= 2) {
                  values = List.from(_studentData[key]);
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          col.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Expanded(
                        child: ScoreInputField(
                          label: '1',
                          initialValue: values[0].toString(),
                          max: col.maxScore,
                          onChanged: (v) {
                            values[0] = v;
                            setState(() {
                              _studentData[key] = values;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ScoreInputField(
                          label: '2',
                          initialValue: values[1].toString(),
                          max: col.maxScore,
                          onChanged: (v) {
                            values[1] = v;
                            setState(() {
                              _studentData[key] = values;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                return _buildNumericCard(col, suffix);
              }
            }),
          ],
        ),
      ),
    );
  }
}
