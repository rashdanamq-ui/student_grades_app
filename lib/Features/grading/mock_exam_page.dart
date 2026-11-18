// lib/mock_exam_page.dart

import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'package:file_picker/file_picker.dart';
import 'package:student_grades_app/Features/analysis/mock_exam_analysis_v2 _page.dart'; // الصفحة الجديدة (V2) للاختبارات والمهارات
import '../../services/backup_service.dart';
import '../home/home_page.dart';
import '../security/security/security_settings_page.dart';
import '../../core/widgets/main_bottom_bar.dart';
import 'dart:math';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../core/settings/app_settings.dart';
import '../../core/utils/number_utils.dart';
import 'package:student_grades_app/Features/analysis/mock_exam_analysis_page.dart';
import '../../core/widgets/app_dialogs.dart';

import '../../core/settings/app_settings.dart'; // للوصول لزر التحويل
import '../analysis/modern/modern_mock_skill_page.dart'; // الصفحة الحديثة التي أنشأناها

import 'package:syncfusion_flutter_pdf/pdf.dart';
// ignore: depend_on_referenced_packages

// ignore: depend_on_referenced_packages

// ===== الموديلات =====
class MockStudent {
  String name;
  List<double?> exams;
  bool isSelected;

  MockStudent({
    required this.name,
    List<double?>? exams,
    this.isSelected = false,
  }) : exams = (exams ?? List<double?>.filled(8, null)).take(8).toList() {
    if (this.exams.length < 8) {
      this.exams.addAll(List<double?>.filled(8 - this.exams.length, null));
    }
  }
  Map<String, dynamic> toJson() => {
    'name': name,
    'exams': exams,
    'isSelected': isSelected,
  };
  factory MockStudent.fromJson(Map<String, dynamic> m) {
    final name = m['name']?.toString() ?? '';
    final rawExams = (m['exams'] as List?) ?? [];
    final exms = <double?>[];
    for (var i = 0; i < 8; i++) {
      exms.add(
        (i < rawExams.length && rawExams[i] != null)
            ? double.tryParse(rawExams[i].toString())
            : null,
      );
    }
    return MockStudent(
      name: name,
      exams: exms,
      isSelected: m['isSelected'] as bool? ?? false,
    );
  }
}

class EditingCell {
  final int studentIndex;
  final int examIndex;
  const EditingCell({required this.studentIndex, required this.examIndex});
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditingCell &&
          runtimeType == other.runtimeType &&
          studentIndex == other.studentIndex &&
          examIndex == other.examIndex;
  @override
  int get hashCode => studentIndex.hashCode ^ examIndex.hashCode;
}

class MockExamPage extends StatefulWidget {
  final String classId;
  final String classTitle;

  const MockExamPage({
    super.key,
    required this.classId,
    required this.classTitle,
  });

  @override
  State<MockExamPage> createState() => _MockExamPageState();
}

class _MockExamPageState extends State<MockExamPage> {
  late final String storageKey;
  late final String metaKey;

  bool showSumInsteadOfAverage = false;

  // ... المتغيرات السابقة ...
  int _examCount = 8;
  List<String> _examTitles = List.filled(8, ''); // الاسم الظاهر (مثلاً: إملاء)
  List<String> _examTags = List.filled(8, 'عام'); // التاق (مثلاً: اختبار)
  List<double> _examMax = List.filled(8, 20.0); // الدرجة
  String _analysisTag = ""; // وصف الفصل العام
  String convertArabicToEnglish(String input) {
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩', '٫', '،'];
    const english = [
      '0',
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      '.',
      '.',
    ];

    for (int i = 0; i < arabic.length; i++) {
      input = input.replaceAll(arabic[i], english[i]);
    }

    return input;
  }

  int _bottomIndex = 0;
  List<MockStudent> students = [];
  final TextEditingController _newStudentController = TextEditingController();
  final TextEditingController _bulkNamesController = TextEditingController();

  EditingCell? _editingCell;
  final FocusNode _pageFocusNode = FocusNode();
  final TextEditingController _cellEditController = TextEditingController();
  final FocusNode _cellFocusNode = FocusNode();

  final double _headerHeight = 60.0;
  final double _rowHeight = 37;
  final double _indexColWidth = 25;
  final double _nameColWidth = 230;
  final double _examColWidth = 45;
  // ================== إعدادات الألوان (تحكم كامل) ==================

  // 1. ألوان خلفية الصفوف
  // هذا هو اللون الغامق الذي طلبته
  final Color _rowEvenColor = const Color(0xFFFFFFFF).withOpacity(0.9);

  // لون الصف الثاني: يمكنك جعله نفسه، أو درجة أفتح قليلاً للتمييز
  // وضعت لك هنا درجة أفتح قليلاً (كحلي رمادي)، يمكنك تغييره لأي كود تريده
  final Color _rowOddColor = const Color(0xFFE3E3E3).withOpacity(0.9);

  // 2. لون النصوص (الأسماء والدرجات)
  // *مهم*: جعلته أبيض (Colors.white) لأن خلفية الصفوف غامقة، وإلا لن يظهر النص
  final Color _textColor = const Color(0xFF201F1F).withOpacity(0.9);

  // 3. بقية الألوان
  final Color _headerBgColor = const Color(0xFF0F3460); // لون العنوان
  final Color _headerTextColor = Colors.white;
  final Color _borderColor = const Color(
    0xFF4B4B69,
  ); // لون الخطوط الفاصلة (فاتح قليلاً ليظهر)
  final Color _selectedRowColor = const Color(
    0xFF9CD0E6,
  ).withOpacity(0.9); // لون التحديد (أحمر شفاف مثلاً)

  // لون الخلية أثناء الكتابة (عادة تكون فاتحة ليسهل القراءة)
  final Color _editingCellColor = const Color(0xFFFFF9C4);

  // ===============================================================

  @override
  void initState() {
    super.initState();
    storageKey = 'mock_exam_${widget.classId}_v1';
    metaKey = '${storageKey}_meta';
    _loadLocal();
    _loadGlobalTags(); // ✅ تحميل التاقات العالمية
  }

  // --- Global Tags Logic ---
  static const String _globalTagsKey = 'mock_exam_global_tags_v1';
  final Set<String> _availableTags = {
    'عام',
    'واجبات',
    'مشاركة',
    'عملي',
    'تحريري',
  }; // القائمة الافتراضية

  Future<void> _loadGlobalTags() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTags = prefs.getStringList(_globalTagsKey);
    if (savedTags != null) {
      setState(() {
        _availableTags.addAll(savedTags);
      });
    }
  }

  Future<void> _saveGlobalTag(String newTag) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _availableTags.add(newTag);
    });
    // نحفظ فقط التاقات التي ليست من ضمن الافتراضية "الصلبة" إذا أردت، أو نحفظ الكل.
    // للأمان سنحفظ كل ما هو إضافي عن القائمة الأساسية، لكن للسهولة سنحفظ القائمة الكاملة المحولة.
    await prefs.setStringList(_globalTagsKey, _availableTags.toList());
  }

  @override
  void dispose() {
    _newStudentController.dispose();
    _bulkNamesController.dispose();
    _pageFocusNode.dispose();
    _cellEditController.dispose();
    _cellFocusNode.dispose();
    super.dispose();
  }

  // =================== دالة استيراد الأسماء الشاملة (فصول + اختبارات) ===================
  Future<void> _showImportDialog() async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, String>> availableSources = [];

    // 1. الفصول الأساسية
    final baseClassesStr = prefs.getString('home_base_classes_cfg_v1');
    if (baseClassesStr != null) {
      try {
        Map<String, dynamic> baseMap = jsonDecode(baseClassesStr);
        baseMap.forEach((key, value) {
          if (value['visible'] == true) {
            availableSources.add({
              'id': key,
              'name': value['title'] ?? 'فصل أساسي',
              'type': 'class',
            });
          }
        });
      } catch (e) {
        debugPrint('$e');
      }
    } else {
      availableSources.addAll([
        {'id': 'c5', 'name': 'رابع 5', 'type': 'class'},
        {'id': 'c6', 'name': 'رابع 6', 'type': 'class'},
        {'id': 'c7', 'name': 'رابع 7', 'type': 'class'},
      ]);
    }

    // 2. الفصول الإضافية
    final extraClassesStr = prefs.getString('home_extra_classes_v2');
    if (extraClassesStr != null) {
      try {
        List<dynamic> extraList = jsonDecode(extraClassesStr);
        for (var item in extraList) {
          availableSources.add({
            'id': item['id'],
            'name': item['title'] ?? 'فصل إضافي',
            'type': 'class',
          });
        }
      } catch (e) {
        debugPrint('$e');
      }
    }

    // 3. الاختبارات المحاكية
    final mockClassesStr = prefs.getString('home_mock_classes_v1');
    if (mockClassesStr != null) {
      try {
        List<dynamic> mockList = jsonDecode(mockClassesStr);
        for (var item in mockList) {
          if (item['id'] != widget.classId) {
            availableSources.add({
              'id': item['id'],
              'name': '📝 ${item['displayTitle'] ?? 'اختبار'}',
              'type': 'mock',
            });
          }
        }
      } catch (e) {
        debugPrint('$e');
      }
    }

    if (availableSources.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد مصادر للنسخ منها.')),
        );
      }
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('نسخ الأسماء من:'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: availableSources.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final src = availableSources[index];
              final isMock = src['type'] == 'mock';
              return ListTile(
                leading: Icon(
                  isMock ? Icons.assignment : Icons.class_,
                  color: isMock ? Colors.orange : Colors.teal,
                ),
                title: Text(src['name']!),
                subtitle: Text(isMock ? 'اختبار محاكي' : 'فصل دراسي'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () =>
                    _copyNamesFromSource(src['id']!, src['name'], src['type']!),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  // ✅ أضف هذه الدالة بالكامل
  Future<void> _exportNamesToTxt() async {
    try {
      // 1. تجهيز المحتوى (أسماء الطلاب)
      final StringBuffer buffer = StringBuffer();
      for (var student in students) {
        buffer.writeln(student.name);
      }
      final String content = buffer.toString();

      // 2. إظهار نافذة "حفظ باسم" باستخدام file_picker
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'الرجاء تحديد مكان حفظ الملف:',
        fileName: 'اسماء_طلاب_${widget.classTitle.replaceAll(" ", "_")}.txt',
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      // 3. التحقق من اختيار المستخدم لمسار والحفظ
      if (outputFile != null) {
        if (!outputFile.endsWith('.txt')) {
          outputFile += '.txt';
        }

        final file = File(outputFile);
        await file.writeAsString(content, encoding: utf8);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حفظ ملف الأسماء بنجاح ✅'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // المستخدم ألغى عملية الحفظ
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تم إلغاء عملية الحفظ')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _copyNamesFromSource(
    String sourceId,
    String? sourceTitle,
    String type,
  ) async {
    Navigator.pop(context);
    final prefs = await SharedPreferences.getInstance();
    String? sourceDataJson;

    if (type == 'mock') {
      sourceDataJson = prefs.getString('mock_exam_${sourceId}_v1');
    } else {
      sourceDataJson = prefs.getString('class_students_$sourceId');
    }

    if (sourceDataJson != null) {
      List<dynamic> sourceList = jsonDecode(sourceDataJson);
      int addedCount = 0;
      for (var item in sourceList) {
        String name = item['name'];
        if (!students.any((s) => s.name == name)) {
          students.add(MockStudent(name: name));
          addedCount++;
        }
      }
      if (addedCount > 0) {
        await _saveLocal();
        setState(() {});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم نسخ $addedCount اسم من "$sourceTitle" ✅'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('الأسماء موجودة بالفعل!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('المصدر "$sourceTitle" فارغ.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> importFromPDF() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result == null) {
      print("❌ لم يتم اختيار ملف");
      return;
    }

    final bytes = result.files.single.bytes;

    if (bytes == null) {
      print("❌ فشل قراءة الملف");
      return;
    }
    PdfDocument document = PdfDocument(inputBytes: bytes);

    String text = "";

    for (int i = 0; i < document.pages.count; i++) {
      text += PdfTextExtractor(document).extractText(startPageIndex: i);
    }

    document.dispose();

    print("===== PDF TEXT =====");
    print(text);
    print("====================");

    parseSmartPdf(text);
  }

  void parseSmartPdf(String text) {
    List<String> lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    students.clear();

    if (text.contains("تقرير") && text.contains("المحصلة")) {
      print("⚠️ هذا PDF معقد (أعمدة مقلوبة)");

      parseComplexPdf(text);
      return;
    }
    // =========================
    // 🔥 حذف كل شيء قبل أول رقم طالب
    // =========================
    int startIndex = 0;

    for (int i = 0; i < lines.length; i++) {
      if (int.tryParse(convertArabicToEnglish(lines[i])) != null) {
        startIndex = i;
        break;
      }
    }

    lines = lines.sublist(startIndex);

    int i = 0;

    while (i < lines.length) {
      // =========================
      // 🧠 تحويل الأرقام العربية
      // =========================
      int? studentNumber = int.tryParse(convertArabicToEnglish(lines[i]));

      if (studentNumber == null) {
        i++;
        continue;
      }

      i++;

      // =========================
      // 👤 قراءة الاسم
      // =========================
      String name = "";

      while (i < lines.length &&
          double.tryParse(convertArabicToEnglish(lines[i])) == null) {
        name += (name.isEmpty ? "" : " ") + lines[i];
        i++;
      }

      // =========================
      // 📊 قراءة الدرجات
      // =========================
      List<double> grades = [];

      while (i < lines.length) {
        double? num = double.tryParse(convertArabicToEnglish(lines[i]));

        if (num != null) {
          grades.add(num);
          i++;
        } else {
          break;
        }
      }

      while (grades.length < 8) {
        grades.add(0);
      }

      students.add(MockStudent(name: name, exams: grades));
    }

    print("عدد الطلاب النهائي: ${students.length}");

    setState(() {
      _examCount = 8;
    });
  }

  void parseComplexPdf(String text) {
    List<String> lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    students.clear();

    List<String> buffer = [];

    for (int i = 0; i < lines.length; i++) {
      String line = convertArabicToEnglish(lines[i]);

      // إذا وصلنا لرقم طالب
      if (int.tryParse(line) != null) {
        if (buffer.isNotEmpty) {
          // استخراج الاسم
          List<String> nameParts = buffer.where((e) {
            return double.tryParse(convertArabicToEnglish(e)) == null;
          }).toList();

          String name = nameParts.join(" ");

          // استخراج الدرجات
          List<double> grades = buffer
              .map((e) {
                return double.tryParse(convertArabicToEnglish(e));
              })
              .whereType<double>()
              .toList();

          while (grades.length < 8) {
            grades.add(0);
          }

          students.add(MockStudent(name: name, exams: grades));
        }

        buffer.clear();
      } else {
        buffer.add(lines[i]);
      }
    }

    print("عدد الطلاب النهائي: ${students.length}");

    setState(() {
      _examCount = 8;
    });
  }

  void convertPdfToCsv(String text) {
    List<String> lines = text.split('\n');

    List<List<String>> table = [];

    for (var line in lines) {
      var parts = line.trim().split(RegExp(r'\s+'));

      if (parts.length >= 4) {
        String name = parts.sublist(0, parts.length - 3).join(" ");

        String exam1 = parts[parts.length - 3];
        String exam2 = parts[parts.length - 2];
        String exam3 = parts[parts.length - 1];

        table.add([name, exam1, exam2, exam3]);
      }
    }

    importFromCsvTable(table);
  }

  void importFromCsvTable(List<List<String>> table) {
    students.clear();

    for (var row in table) {
      students.add(
        MockStudent(
          name: row[0],
          exams: [
            double.tryParse(row[1]) ?? 0,
            double.tryParse(row[2]) ?? 0,
            double.tryParse(row[3]) ?? 0,
          ],
        ),
      );
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // 🔒 تأمين القوائم (منع StateError نهائيًا)
    _ensureListLength(_examTitles, '');
    _ensureListLength(_examTags, 'عام');
    _ensureListLength(_examMax, 20.0);

    final hasSelected = students.any((s) => s.isSelected);

    // ✅✅ تم حذف RawKeyboardListener من هنا ✅✅
    return ValueListenableBuilder<bool>(
      valueListenable: AppSettings.useArabicNumbers,
      builder: (context, isArabic, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              title: Text(widget.classTitle.toAppNum()),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              titleTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              actions: [
                ValueListenableBuilder<bool>(
                  valueListenable: AppSettings.showQuickGradingButtons,
                  builder: (context, show, child) {
                    if (!show) return const SizedBox();
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: _fillRandomScores,
                          icon: const Icon(
                            Icons.casino_outlined,
                            color: Colors.white,
                          ),
                          tooltip: 'توليد عشوائي',
                        ),
                        IconButton(
                          onPressed: _fillAllStudentsFullMarks,
                          icon: const Icon(Icons.done_all, color: Colors.white),
                          tooltip: 'رصد كامل',
                        ),
                      ],
                    );
                  },
                ),

                IconButton(
                  icon: Icon(
                    showSumInsteadOfAverage ? Icons.functions : Icons.calculate,
                  ),
                  tooltip: showSumInsteadOfAverage
                      ? 'عرض المتوسط'
                      : 'عرض المجموع',
                  onPressed: () {
                    setState(() {
                      showSumInsteadOfAverage = !showSumInsteadOfAverage;
                    });
                  },
                ),

                IconButton(
                  onPressed: _showImportDialog,
                  icon: const Icon(Icons.copy_all),
                  tooltip: 'نسخ من صف آخر',
                ),
                IconButton(
                  icon: Icon(Icons.picture_as_pdf),
                  tooltip: "استيراد من PDF",
                  onPressed: importFromPDF,
                ),

                // ✅✅✅ تم التعديل هنا: إضافة ValueListenableBuilder ✅✅✅
                ValueListenableBuilder<bool>(
                  valueListenable: AppSettings.useModernAnalysis,
                  builder: (context, isModern, child) {
                    return PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (val) {
                        if (val == 'add') _showAddStudentDialog();
                        if (val == 'bulk') _showBulkAddNamesDialog();
                        if (val == 'sort') _sortStudentsAlphabetically();
                        if (val == 'settings') _showEditExamsMaxDialog();
                        if (val == 'pdf') _exportClassPdf();
                        if (val == 'csv') _exportClassCsv();
                        if (val == 'import_csv') _importFromCsv();
                        if (val == 'excel') _exportClassExcel();
                        if (val == 'del_all') _deleteAllStudentsDialog();
                        if (val == 'analyze') {
                          // 1. قراءة الإعدادات
                          bool isModern = AppSettings.useModernAnalysis.value;

                          // 2. طباعة للتأكد (ستظهر في الكونسول بالأسفل)
                          print(
                            "📢 زر التحليل ضُغط! الوضع الحديث مفعل؟ $isModern",
                          );

                          if (isModern) {
                            // 🆕 فتح الصفحة الحديثة
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ModernMockSkillPage(
                                  // 👈 تأكد أن هذا الكلاس هو المستخدم
                                  classId: widget.classId,
                                  classTitle: widget.classTitle,
                                ),
                              ),
                            );
                          } else {
                            // 🏛️ فتح الصفحة القديمة
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MockExamAnalysisV2Page(
                                  classId: widget.classId,
                                  classTitle: widget.classTitle,
                                ),
                              ),
                            );
                          }
                        }

                        // ... بقية الأزرار (add, bulk, etc)
                        if (val == 'add') _showAddStudentDialog();
                        // ...
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'add',
                          child: Row(
                            children: [
                              Icon(Icons.person_add, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('إضافة طالب'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'bulk',
                          child: Row(
                            children: [
                              Icon(Icons.playlist_add, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('إضافة متعددة'),
                            ],
                          ),
                        ),

                        const PopupMenuItem(
                          value: 'csv',
                          child: Row(
                            children: [
                              Icon(Icons.table_chart, color: Colors.green),
                              SizedBox(width: 8),
                              Text('CSV (Excel)'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'import_csv',
                          child: Row(
                            children: [
                              Icon(Icons.upload_file, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('استيراد من CSV'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'sort',
                          child: Row(
                            children: [
                              Icon(Icons.sort_by_alpha, color: Colors.teal),
                              SizedBox(width: 8),
                              Text('ترتيب هجائي'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'settings',
                          child: Row(
                            children: [
                              Icon(Icons.tune, color: Colors.grey),
                              SizedBox(width: 8),
                              Text('إعداد الدرجات'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'analyze',
                          child: Row(
                            children: [
                              Icon(Icons.analytics, color: Colors.purple),
                              SizedBox(width: 8),
                              Text('تحليل الدرجات'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        const PopupMenuItem(
                          value: 'pdf',
                          child: Row(
                            children: [
                              Icon(Icons.picture_as_pdf, color: Colors.red),
                              SizedBox(width: 8),
                              Text('PDF'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'excel',
                          child: Row(
                            children: [
                              Icon(Icons.table_view, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Excel'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'txt',
                          child: Row(
                            children: [
                              Icon(Icons.text_snippet, color: Colors.blueGrey),
                              SizedBox(width: 8),
                              Text('سحب الأسماء (TXT)'),
                            ],
                          ),
                        ),
                        if (students.isNotEmpty)
                          const PopupMenuItem(
                            value: 'del_all',
                            child: Row(
                              children: [
                                Icon(Icons.delete_forever, color: Colors.red),
                                SizedBox(width: 8),
                                Text('حذف الجميع'),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),

                // ✅✅✅ انتهى التعديل ✅✅✅
                if (hasSelected)
                  IconButton(
                    onPressed: _deleteSelectedStudents,
                    icon: const Icon(Icons.delete, color: Colors.white),
                    tooltip: 'حذف المحدد',
                  ),
              ],
            ),
            body: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF30c9cd), Color(0xFF330d69)],
                    ),
                  ),
                ),
                Column(
                  children: [
                    SizedBox(
                      height:
                          kToolbarHeight +
                          MediaQuery.of(context).padding.top +
                          10,
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final availableHeight = constraints.maxHeight;
                          bool isLandscape = constraints.maxWidth > 800;
                          if (isLandscape) {
                            final mid = (students.length / 2).ceil();
                            final rightList = students.take(mid).toList();
                            final leftList = students.skip(mid).toList();
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildFloatingCard(
                                    child: _buildPanel(
                                      rightList,
                                      0,
                                      availableHeight,
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      topRight: Radius.circular(30),
                                    ),
                                    margin: const EdgeInsets.only(
                                      left: 5,
                                      right: 20,
                                    ),
                                  ),
                                ),
                                Container(width: 0),
                                Expanded(
                                  child: _buildFloatingCard(
                                    child: _buildPanel(
                                      leftList,
                                      mid,
                                      availableHeight,
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(30),
                                    ),
                                    margin: const EdgeInsets.only(
                                      left: 20,
                                      right: 20,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return _buildFloatingCard(
                              child: _buildPanel(students, 0, availableHeight),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(30),
                                topRight: Radius.circular(30),
                              ),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
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

  Widget _buildFloatingCard({
    required Widget child,
    required BorderRadius borderRadius,
    required EdgeInsets margin,
  }) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        // جعلنا الخلفية الأساسية شفافة لكي تظهر ألوان الصفوف فقط
        color: Colors.transparent,
        borderRadius: borderRadius,
        // يمكنك حذف الظل (BoxShadow) إذا أردت مظهراً مسطحاً تماماً
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 30,
            offset: Offset(0, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: child, // هنا سيتم عرض الصفوف بألوانها التي حددتها بالأعلى
      ),
    );
  }

  // لاحظ: أضفنا معامل جديد (height)
  Widget _buildPanel(
    List<MockStudent> panelStudents,
    int startIndex,
    double height,
  ) {
    // العرض الكلي
    final double totalWidth =
        _indexColWidth +
        _nameColWidth +
        (_examColWidth * _examCount) +
        _examColWidth;

    // ارتفاع منطقة القائمة المتاحة (الشاشة ناقص العنوان)
    final double listAvailableHeight = height - _headerHeight;

    // ============================================================
    //  الخدعة هنا: حساب مساحة فارغة في الأسفل
    //  المعادلة: ارتفاع القائمة - ارتفاع صف واحد
    //  هذا سيسمح لك برفع القائمة حتى يبقى صف واحد فقط في الأعلى
    // ============================================================
    double bottomPadding = listAvailableHeight - _rowHeight;
    if (bottomPadding < 0) {
      bottomPadding = 0; // حماية من الأخطاء لو الشاشة صغيرة جداً
    }

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. رأس الجدول (ثابت)
            Container(
              height: _headerHeight,
              width: totalWidth,
              color: _headerBgColor,
              child: Row(
                children: [
                  _buildHeaderCell('ت', _indexColWidth),
                  _buildHeaderCell('الاسم', _nameColWidth),
                  for (int i = 0; i < _examCount; i++)
                    Tooltip(
                      message: 'التاق: ${_examTags[i]}\nالدرجة: ${_examMax[i]}',
                      child: _buildHeaderCell(
                        _examTitles[i].isNotEmpty
                            ? _examTitles[i]
                            : '(${i + 1})',
                        _examColWidth,
                      ),
                    ),
                  _buildHeaderCell(
                    showSumInsteadOfAverage ? 'المجموع' : 'المتوسط',
                    _examColWidth,
                    isHighlight: true,
                  ),
                ],
              ),
            ),

            // 2. جسم الجدول (القائمة)
            SizedBox(
              height: listAvailableHeight > 0 ? listAvailableHeight : 100,
              width: totalWidth,
              child: panelStudents.isEmpty
                  ? Center(
                      child: Text(
                        'لا يوجد طلاب',
                        style: TextStyle(color: _textColor),
                      ),
                    )
                  : ListView.builder(
                      // 👇👇 هنا التعديل: إضافة الحشوة السفلية 👇👇
                      padding: EdgeInsets.only(bottom: bottomPadding),
                      physics:
                          const AlwaysScrollableScrollPhysics(), // ضمان التمرير حتى لو القائمة قصيرة
                      itemCount: panelStudents.length,
                      itemBuilder: (context, i) {
                        final studentIndex = startIndex + i;
                        final s = panelStudents[i];

                        Color rowColor = (i % 2 == 0)
                            ? _rowEvenColor
                            : _rowOddColor;
                        if (s.isSelected) rowColor = _selectedRowColor;

                        return Container(
                          height: _rowHeight,
                          color: rowColor,
                          child: Row(
                            children: _buildStudentRowCells(studentIndex, s),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStudentRowCells(int studentIndex, MockStudent s) {
    List<Widget> cells = [];
    cells.add(
      InkWell(
        onTap: () => setState(() => s.isSelected = !s.isSelected),
        child: Container(
          width: _indexColWidth,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: _borderColor)),
          ),
          child: Text(
            '${studentIndex + 1}'.toAppNum(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
    cells.add(
      Container(
        width: _nameColWidth,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: _borderColor)),
        ),
        child: Text(
          s.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: _textColor,
          ),
        ),
      ),
    ); // تغير حجم الاسم

    // حلقة تكرار مرنة
    for (int i = 0; i < _examCount; i++) {
      final isEditing =
          _editingCell?.studentIndex == studentIndex &&
          _editingCell?.examIndex == i;
      // التأكد من عدم حدوث خطأ Index
      double? val;
      if (i < s.exams.length) val = s.exams[i];

      cells.add(_buildDataCell(studentIndex, i, val, isEditing));
    }

    final result = _calcResult(s);
    cells.add(
      Container(
        width: _examColWidth,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.05),
          border: Border(right: BorderSide(color: _borderColor)),
        ),
        child: Text(
          result > 0 ? formatNumberForDisplay(result) : '-',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: _textColor,
          ),
        ),
      ),
    );

    return cells;
  }

  Widget _buildHeaderCell(
    String text,
    double width, {
    bool isHighlight = false,
  }) {
    return Container(
      width: width,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isHighlight ? Colors.white.withOpacity(0.1) : null,
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.2))),
      ),
      child: Text(
        text.toAppNum(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: _headerTextColor,
        ),
      ),
    );
  }

  Widget _buildDataCell(
    int studentIndex,
    int examIndex,
    double? value,
    bool isEditing,
  ) {
    return GestureDetector(
      // ✅✅✅ هذا السطر هو الحل: يجعل الخلية قابلة للضغط في أي مكان (حتى الفراغ)
      behavior: HitTestBehavior.opaque,
      onTap: () => _startEditing(studentIndex, examIndex),
      child: Container(
        width: _examColWidth,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isEditing ? _editingCellColor : null,
          border: Border(right: BorderSide(color: _borderColor)),
        ),
        child: isEditing
            ? _buildEditingField(studentIndex, examIndex, value)
            : Text(
                value != null ? formatNumberForDisplay(value) : '-',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _textColor,
                ),
              ),
      ),
    );
  }

  Widget _buildEditingField(int studentIndex, int examIndex, double? value) {
    return Focus(
      canRequestFocus: false,
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          final key = event.logicalKey;
          bool isNavKey =
              key == LogicalKeyboardKey.arrowUp ||
              key == LogicalKeyboardKey.arrowDown ||
              key == LogicalKeyboardKey.arrowLeft ||
              key == LogicalKeyboardKey.arrowRight ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.tab;

          if (isNavKey) {
            int sIndex = studentIndex;
            int eIndex = examIndex;

            if (key == LogicalKeyboardKey.arrowDown ||
                key == LogicalKeyboardKey.enter) {
              if (sIndex < students.length - 1) {
                sIndex++;
              } else {
                sIndex = 0;
                if (eIndex < _examCount - 1) {
                  eIndex++;
                } else {
                  eIndex = 0;
                }
              }
            } else if (key == LogicalKeyboardKey.arrowUp) {
              if (sIndex > 0) {
                sIndex--;
              } else {
                sIndex = students.length - 1;
                if (eIndex > 0) {
                  eIndex--;
                } else {
                  eIndex = _examCount - 1;
                }
              }
            } else if (key == LogicalKeyboardKey.arrowRight) {
              if (eIndex > 0) {
                eIndex--;
              } else {
                eIndex = _examCount - 1;
                if (sIndex > 0) {
                  sIndex--;
                } else {
                  sIndex = students.length - 1;
                }
              }
            } else if (key == LogicalKeyboardKey.arrowLeft ||
                key == LogicalKeyboardKey.tab) {
              if (eIndex < _examCount - 1) {
                eIndex++;
              } else {
                eIndex = 0;
                if (sIndex < students.length - 1) {
                  sIndex++;
                } else {
                  sIndex = 0;
                }
              }
            }

            _stopEditing(save: true);
            // تقليل الوقت لأقل قدر ممكن لاستجابة سريعة
            Future.delayed(const Duration(milliseconds: 10), () {
              if (mounted) _startEditing(sIndex, eIndex);
            });
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: TextFormField(
        // ✅✅✅ هذا هو الحل السحري: مفتاح فريد لكل خلية
        key: ValueKey('input_${studentIndex}_$examIndex'),

        focusNode: _cellFocusNode,
        controller: _cellEditController,
        autofocus: true, // سيعمل الآن إجبارياً بسبب الـ Key
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        onTapOutside: (_) => _stopEditing(save: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9\u0660-\u0669.]')),
        ],
      ),
    );
  }

  void _startEditing(int studentIndex, int examIndex) {
    // إزالة التركيز القديم فوراً
    _cellFocusNode.unfocus();

    if (_editingCell != null &&
        (_editingCell!.studentIndex != studentIndex ||
            _editingCell!.examIndex != examIndex)) {
      _stopEditing(save: true);
    }

    setState(() {
      _editingCell = EditingCell(
        studentIndex: studentIndex,
        examIndex: examIndex,
      );
      final value = (examIndex < students[studentIndex].exams.length)
          ? students[studentIndex].exams[examIndex]
          : null;
      _cellEditController.text = _formatScore(value) ?? '';
    });

    // نستخدم addPostFrameCallback بدلاً من التاخير الزمني لأنه أدق
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).requestFocus(_cellFocusNode);
        if (_cellEditController.text.isNotEmpty) {
          _cellEditController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _cellEditController.text.length,
          );
        }
      }
    });
  }

  void _stopEditing({bool save = false}) {
    if (_editingCell == null) return;

    if (save) {
      // تحويل النص إلى رقم
      final text = _cellEditController.text.trim().toEnglishNum();
      double? value = text.isEmpty ? null : double.tryParse(text);

      // ================== منطق الفحص (يعمل بعد الانتهاء من الكتابة) ==================
      if (value != null) {
        // معرفة الحد الأقصى للعمود الحالي
        final currentMax = _examMax[_editingCell!.examIndex];

        // إذا كانت الدرجة المكتوبة أكبر من الحد المسموح
        if (value > currentMax) {
          value = null; // اجعل الخلية فارغة

          // رسالة تنبيه سريعة
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'خطأ: الدرجة $text أكبر من الحد المسموح ($currentMax)',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
      // =========================================================================

      setState(() {
        students[_editingCell!.studentIndex].exams[_editingCell!.examIndex] =
            value;
      });
      _saveLocal();
    }

    setState(() {
      _editingCell = null;
    });
  }

  String _formatScore(double? v) {
    if (v == null) return '';
    if (v == v.roundToDouble()) {
      return v.toStringAsFixed(0).toAppNum();
    }
    return v.toStringAsFixed(1).toAppNum();
  }

  double _calcResult(MockStudent s) {
    double sum = 0.0;
    int count = 0;

    for (int i = 0; i < _examCount; i++) {
      if (i >= s.exams.length) break;

      final score = s.exams[i];
      if (score == null) continue;

      if (showSumInsteadOfAverage) {
        sum += score;
      } else {
        final max = (_examMax[i] <= 0) ? 20.0 : _examMax[i];
        sum += (score / max) * 20.0;
        count++;
      }
    }

    if (showSumInsteadOfAverage) {
      return sum;
    }

    return count == 0 ? 0.0 : sum / _examCount;
  }

  double _calcAverage(MockStudent s) {
    // نعيد دائمًا المتوسط (حتى لو وضع العرض = مجموع)
    final oldFlag = showSumInsteadOfAverage;
    showSumInsteadOfAverage = false;

    final result = _calcResult(s);

    showSumInsteadOfAverage = oldFlag;
    return result;
  }

  double _calcSum(MockStudent s) {
    double sum = 0.0;

    for (int i = 0; i < _examCount; i++) {
      if (i >= s.exams.length) break;

      final score = s.exams[i];
      if (score != null) {
        sum += score;
      }
    }

    return sum;
  }

  void _sortStudentsAlphabetically() {
    setState(() {
      students.sort((a, b) => a.name.compareTo(b.name));
    });
    _saveLocal();
  }

  void _deleteSelectedStudents() {
    setState(() {
      students.removeWhere((s) => s.isSelected);
    });
    _saveLocal();
  }

  Future<void> _deleteAllStudentsDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تأكيد'),
          content: const Text('هل تريد حذف جميع الأسماء؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('نعم'),
            ),
          ],
        ),
      ),
    );
    if (confirm == true) {
      setState(() {
        students.clear();
      });
      await _saveLocal();
    }
  }

  Future<void> _showBulkAddNamesDialog() async {
    await showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إضافة عدة أسماء'),
          content: SizedBox(
            width: 320,
            child: TextField(
              controller: _bulkNamesController,
              maxLines: 10,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'اكتب أو الصق الأسماء هنا',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _bulkNamesController.clear();
                Navigator.pop(context);
              },
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                final text = _bulkNamesController.text.trim();
                if (text.isEmpty) {
                  Navigator.pop(context);
                  return;
                }
                final lines = text.split(RegExp(r'[\r\n]+'));
                final existingNames = students.map((s) => s.name).toSet();
                setState(() {
                  for (var line in lines) {
                    final name = line.trim();
                    if (name.isEmpty || existingNames.contains(name)) continue;
                    students.add(MockStudent(name: name));
                    existingNames.add(name);
                  }
                });
                _bulkNamesController.clear();
                _saveLocal();
                Navigator.pop(context);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  void _addNewStudent() {
    final newName = _newStudentController.text.trim();
    if (newName.isEmpty) return;
    setState(() {
      students.add(MockStudent(name: newName));
    });
    _newStudentController.clear();
    _saveLocal();
  }

  Future<void> _showAddStudentDialog() async {
    await showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إضافة طالب'),
          content: TextField(
            controller: _newStudentController,
            onSubmitted: (_) => _addNewStudent(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _newStudentController.clear();
                Navigator.pop(context);
              },
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                _addNewStudent();
                Navigator.pop(context);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();

    final metaStr = prefs.getString(metaKey);
    if (metaStr != null && metaStr.isNotEmpty) {
      try {
        final Map<String, dynamic> metaMap = jsonDecode(metaStr);

        _examCount = metaMap['count'] ?? 8;
        _analysisTag = metaMap['tag'] ?? "";

        if (metaMap['max_scores'] != null) {
          _examMax = List<double>.from(
            metaMap['max_scores'].map(
              (x) => double.tryParse(x.toString()) ?? 20.0,
            ),
          );
        } else {
          _examMax = List.filled(_examCount, 20.0);
        }

        if (metaMap['titles'] != null) {
          _examTitles = List<String>.from(metaMap['titles']);
        } else {
          _examTitles = List.filled(_examCount, '');
        }

        if (metaMap['col_tags'] != null) {
          _examTags = List<String>.from(metaMap['col_tags']);
        } else {
          _examTags = List.filled(_examCount, 'عام');
        }

        _ensureListLength(_examMax, 20.0);
        _ensureListLength(_examTitles, '');
        _ensureListLength(_examTags, 'عام');
      } catch (_) {
        _initDefaults();
      }
    } else {
      _initDefaults();
    }

    final str = prefs.getString(storageKey);
    if (str != null && str.isNotEmpty) {
      try {
        final List decoded = jsonDecode(str);
        students = decoded
            .map((e) => MockStudent.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        for (var s in students) {
          if (s.exams.length < _examCount) {
            s.exams.addAll(List.filled(_examCount - s.exams.length, null));
          } else if (s.exams.length > _examCount) {
            s.exams = s.exams.take(_examCount).toList();
          }
        }
      } catch (_) {}
    }
    setState(() {});
  }

  void _ensureListLength<T>(List<T> list, T defaultValue) {
    if (list.length < _examCount) {
      list.addAll(List.filled(_examCount - list.length, defaultValue));
    } else if (list.length > _examCount) {
      list.length = _examCount;
    }
  }

  void _initDefaults() {
    _examCount = 8;
    _examMax = List.filled(8, 20.0);
    _examTitles = List.filled(8, '');
    _examTags = List.filled(8, 'عام');
    _analysisTag = "";
  }

  Future<void> _saveMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> metaMap = {
      'count': _examCount,
      'max_scores': _examMax,
      'titles': _examTitles,
      'col_tags': _examTags,
      'tag': _analysisTag,
    };
    await prefs.setString(metaKey, jsonEncode(metaMap));
  }

  // قائمة التصنيفات الافتراضية

  Future<void> _importFromCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null) return;

    final file = File(result.files.single.path!);
    final content = await file.readAsString(encoding: utf8);

    final lines = content.split(RegExp(r'\r?\n'));
    if (lines.length <= 1) return;

    setState(() {
      students.clear();

      for (int i = 1; i < lines.length; i++) {
        final row = lines[i].trim();
        if (row.isEmpty) continue;

        final cols = row.split(';').map((e) => e.trim()).toList();

        // 🔎 هل أول عمود رقم (تسلسل)؟
        int startIndex = 0;
        if (cols.isNotEmpty && RegExp(r'^\d+$').hasMatch(cols[0])) {
          startIndex = 1; // تجاهل عمود التسلسل
        }
        final name = cols.length > startIndex ? cols[startIndex] : '';
        final className = cols.length > startIndex + 1
            ? cols[startIndex + 1]
            : '';

        final exams = <double?>[];
        for (
          int c = startIndex + 2; // 👈 بعد الاسم + الفصل
          c < cols.length && exams.length < _examCount;
          c++
        ) {
          final v = double.tryParse(cols[c].toEnglishNum());
          exams.add(v);
        }

        while (exams.length < _examCount) {
          exams.add(null);
        }
        students.add(MockStudent(name: name, exams: exams));
      }
    });

    await _saveLocal();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم استيراد الدرجات من CSV بنجاح ✅')),
      );
    }
  }

  // كلاس مساعد لإدارة حالة الأعمدة أثناء التعديل
  Future<void> _showEditExamsMaxDialog() async {
    // 1. تجهيز المتحكمات
    // نقوم بدمج التاقات الموجودة حالياً مع القائمة الافتراضية

    // استخدام Set لضمان عدم التكرار
    final Set<String> currentTags = {
      ..._availableTags,
      ..._examTags.where((t) => t.trim().isNotEmpty),
    };
    List<String> dialogTags = currentTags.toList();

    // نستخدم قائمة من الكائنات لتتبع الحالة + الفهرس الأصلي (لحفظ الدرجات)
    List<_ColumnConfig> columns = List.generate(_examCount, (i) {
      return _ColumnConfig(
        tag: TextEditingController(
          text: _examTags[i].isEmpty ? 'عام' : _examTags[i],
        ),
        title: TextEditingController(text: _examTitles[i]),
        score: TextEditingController(text: _formatScore(_examMax[i])),
        originalIndex: i, // ✅ نحفظ الفهرس الأصلي لنربط الدرجات لاحقاً
      );
    });

    final mainTagController = TextEditingController(text: _analysisTag);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // دالة لإضافة تصنيف جديد داخل الديالوج
            void addNewTag() {
              TextEditingController newTagCtrl = TextEditingController();
              showDialog(
                context: context,
                builder: (c) => Directionality(
                  textDirection: TextDirection.rtl,
                  child: AlertDialog(
                    title: const Text('إضافة تصنيف جديد'),
                    content: TextField(
                      controller: newTagCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم التصنيف',
                        hintText: 'مثال: نشاط عملي',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('إلغاء'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (newTagCtrl.text.trim().isNotEmpty) {
                            final tag = newTagCtrl.text.trim();
                            // ✅ حفظ في القائمة العالمية
                            await _saveGlobalTag(tag);

                            setDialogState(() {
                              dialogTags = {
                                ...dialogTags,
                                tag,
                              }.toList(); // تحديث القائمة في الديالوج
                            });
                          }
                          Navigator.pop(c);
                        },
                        child: const Text('إضافة'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('إعداد الأعمدة'),
                    TextButton.icon(
                      onPressed: addNewTag,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('تصنيف جديد'),
                      style: TextButton.styleFrom(foregroundColor: Colors.teal),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // التاق العام للفصل
                      TextField(
                        controller: mainTagController,
                        decoration: const InputDecoration(
                          labelText: 'عنوان المجموعة (للتحليل)',
                          hintText: 'مثال: الفترة الأولى',
                          prefixIcon: Icon(Icons.folder_open),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Divider(height: 1, thickness: 1),
                      const SizedBox(height: 10),

                      // العناوين
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                'التصنيف',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            SizedBox(width: 5),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'اسم العمود',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            SizedBox(width: 5),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'الدرجة',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            SizedBox(width: 30), // مكان أيقونة الحذف
                          ],
                        ),
                      ),

                      Expanded(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: columns.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final col = columns[i];
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. قائمة منسدلة للتصنيف (Tags)
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<String>(
                                    value: dialogTags.contains(col.tag.text)
                                        ? col.tag.text
                                        : null,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    items: dialogTags
                                        .map(
                                          (t) => DropdownMenuItem(
                                            value: t,
                                            child: Text(
                                              t,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        col.tag.text = val;
                                      }
                                    },
                                    hint: const Text(
                                      'اختر',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),

                                // 2. الاسم الظاهر (Title)
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: col.title,
                                    decoration: InputDecoration(
                                      hintText: 'عنوان',
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 12,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),

                                // 3. الدرجة (Max)
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: col.score,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                      hintText: '20',
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 12,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9\u0660-\u0669.]'),
                                      ),
                                    ],
                                  ),
                                ),

                                // ✅ 4. زر حذف العمود
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    // منع حذف آخر عمود متبقي لتجنب المشاكل
                                    if (columns.length <= 1) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'يجب أن يبقى عمود واحد على الأقل',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    setDialogState(() {
                                      columns.removeAt(i);
                                    });
                                  },
                                ),
                              ],
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 10),
                      // زر إضافة عمود
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            columns.add(
                              _ColumnConfig(
                                tag: TextEditingController(text: 'عام'),
                                title: TextEditingController(text: ''),
                                score: TextEditingController(text: '20'),
                                originalIndex: null, // جديد ليس له فهرس سابق
                              ),
                            );
                          });
                        },
                        icon: const Icon(Icons.add_circle),
                        label: const Text('إضافة عمود جديد'),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      // الحفظ ومعالجة البيانات

                      // 1. تحديث الإعدادات العامة
                      final newCount = columns.length;
                      final newTags = columns.map((c) => c.tag.text).toList();
                      final newTitles = columns
                          .map((c) => c.title.text.trim())
                          .toList();
                      final newMax = columns.map((c) {
                        final v = double.tryParse(
                          c.score.text.trim().toEnglishNum(),
                        );
                        return (v == null || v <= 0) ? 20.0 : v;
                      }).toList();

                      setState(() {
                        _analysisTag = mainTagController.text.trim();
                        _examCount = newCount;
                        _examTags = newTags;
                        _examTitles = newTitles;
                        _examMax = newMax;

                        // ✅ 2. تحديث درجات الطلاب بذكاء (نقل الدرجات للأماكن الصحيحة)
                        for (var s in students) {
                          List<double?> newExams = [];
                          for (var col in columns) {
                            if (col.originalIndex != null &&
                                col.originalIndex! < s.exams.length) {
                              // إذا كان العمود موجوداً سابقاً، ننقل درجته
                              newExams.add(s.exams[col.originalIndex!]);
                            } else {
                              // عمود جديد = null
                              newExams.add(null);
                            }
                          }
                          s.exams = newExams;
                        }
                      });

                      await _saveMeta();
                      await _saveLocal();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم حفظ الإعدادات وتحديث الأعمدة ✅'),
                          ),
                        );
                      }
                      Navigator.pop(ctx);
                    },
                    child: const Text('حفظ التعديلات'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveLocal({bool showSnack = false}) async {
    final prefs = await SharedPreferences.getInstance();
    // تحويل قائمة الطلاب إلى JSON
    final jsonList = students.map((s) => s.toJson()).toList();
    final str = jsonEncode(jsonList);
    // الحفظ في الذاكرة
    await prefs.setString(storageKey, str);

    if (mounted && showSnack) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم الحفظ')));
    }
  }

  Future<void> _fillAllStudentsFullMarks() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('رصد كامل للجميع'),
          content: const Text(
            'سيتم منح الجميع الدرجة الكاملة في جميع الاختبارات.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('نعم'),
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;
    setState(() {
      for (var student in students) {
        student.exams = List.from(_examMax);
      }
    });
    await _saveLocal();
  }

  Future<void> _fillRandomScores() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('⚠️ توليد عشوائي'),
          content: const Text(
            'سيتم مسح البيانات الحالية وتوليد درجات عشوائية بناءً على الدرجات العظمى المحددة لكل عمود.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('توليد'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    final rnd = Random();

    setState(() {
      for (var student in students) {
        // تحديد "مستوى" للطالب (ضعيف، متوسط، ممتاز) لكي تكون الدرجات واقعية
        int studentLevel = rnd.nextInt(10); // 0..9

        // إنشاء قائمة درجات جديدة بناءً على عدد الأعمدة الحالي (_examCount)
        student.exams = List.generate(_examCount, (index) {
          // احتمال بسيط أن يكون غائباً (null)
          if (rnd.nextInt(20) == 0) return null;

          // جلب الدرجة العظمى لهذا العمود تحديداً
          double currentMax = (index < _examMax.length)
              ? _examMax[index]
              : 20.0;
          if (currentMax <= 0) currentMax = 20.0;

          double minPercent;
          double maxPercent;

          if (studentLevel < 2) {
            // طالب ضعيف (درجات بين 20% و 60%)
            minPercent = 0.20;
            maxPercent = 0.60;
          } else if (studentLevel < 7) {
            // طالب متوسط (درجات بين 50% و 85%)
            minPercent = 0.50;
            maxPercent = 0.85;
          } else {
            // طالب ممتاز (درجات بين 85% و 100%)
            minPercent = 0.85;
            maxPercent = 1.0;
          }

          // حساب الدرجة العشوائية
          double factor =
              minPercent + (rnd.nextDouble() * (maxPercent - minPercent));
          double rawScore = currentMax * factor;

          // التقريب لأقرب 0.5
          return (rawScore * 2).round() / 2.0;
        });
      }
    });

    await _saveLocal(showSnack: true);
  }

  Future<void> _exportClassPdf() async {
    final orientation = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('تخطيط الصفحة'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'portrait'),
            child: const Text('عمودي'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'landscape'),
            child: const Text('أفقي'),
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
    final amiriRegular = pw.Font.ttf(regularFontData);
    final amiriBold = pw.Font.ttf(boldFontData);
    final all = List<MockStudent>.from(students);
    if (all.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('لا يوجد طلاب للطباعة')));
      }
      return;
    }
    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: amiriRegular, bold: amiriBold),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              widget.classTitle.toAppNum(),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
            ),
          ),
          pw.SizedBox(height: 8),
          _buildPdfTable(amiriRegular, all),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  pw.Widget _buildPdfTable(pw.Font ttf, List<MockStudent> list) {
    // 1. بناء العناوين
    final headers = <String>[];

    // عمود (المتوسط / المجموع) حسب الزر
    headers.add(showSumInsteadOfAverage ? 'المجموع' : 'المتوسط');

    // أعمدة الاختبارات (معكوسة للعرض RTL)
    for (int i = _examCount - 1; i >= 0; i--) {
      headers.add(
        _examTitles[i].isNotEmpty ? _examTitles[i] : 'اختبار ${i + 1}',
      );
    }

    // الاسم والتسلسل
    headers.add('الاسم');
    headers.add('ت');

    // 2. الصفوف
    final rows = <pw.TableRow>[];

    // صف العناوين
    rows.add(
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: pdf.PdfColors.grey300),
        children: headers
            .map(
              (h) => pw.Container(
                padding: const pw.EdgeInsets.all(2),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  h.toAppNum(),
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );

    // صفوف الطلاب
    for (int i = 0; i < list.length; i++) {
      final s = list[i];
      final idx = i + 1;

      // ✅ الحساب الموحد (مجموع / متوسط حسب الزر)
      final double result = _calcResult(s);

      final rowColor = i.isOdd
          ? pdf.PdfColor.fromHex("#f5f0eb")
          : pdf.PdfColors.white;

      final cells = <pw.Widget>[];

      // 1. خلية (المتوسط / المجموع)
      cells.add(
        pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.all(2),
          child: pw.Text(
            result > 0 ? formatNumberForPdf(result) : '',
            style: pw.TextStyle(fontSize: 8),
          ),
        ),
      );

      // 2. خلايا الاختبارات
      for (int x = _examCount - 1; x >= 0; x--) {
        final double? val = (x < s.exams.length) ? s.exams[x] : null;
        cells.add(
          pw.Container(
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.all(2),
            child: pw.Text(
              val != null ? formatNumberForPdf(val) : '',
              style: pw.TextStyle(fontSize: 8),
            ),
          ),
        );
      }

      // 3. الاسم
      cells.add(
        pw.Container(
          alignment: pw.Alignment.centerRight,
          padding: const pw.EdgeInsets.only(right: 4, left: 2),
          child: pw.Text(
            s.name,
            textDirection: pw.TextDirection.rtl,
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            style: pw.TextStyle(fontSize: 9),
          ),
        ),
      );

      // 4. التسلسل
      cells.add(
        pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.all(2),
          child: pw.Text(
            idx.toString().toAppNum(),
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ),
      );

      rows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: rowColor),
          children: cells,
        ),
      );
    }

    // 3. عرض الأعمدة
    final Map<int, pw.TableColumnWidth> colWidths = {};
    final int totalCols = headers.length;

    // عمود المتوسط/المجموع
    colWidths[0] = const pw.FlexColumnWidth(1.2);

    // أعمدة الاختبارات
    for (int i = 1; i <= _examCount; i++) {
      colWidths[i] = const pw.FlexColumnWidth(1);
    }

    // الاسم
    colWidths[totalCols - 2] = const pw.FlexColumnWidth(4);

    // التسلسل
    colWidths[totalCols - 1] = const pw.FixedColumnWidth(25);

    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: colWidths,
      children: rows,
    );
  }

  Future<void> _exportClassCsv() async {
    try {
      final buffer = StringBuffer();
      const sep = ';'; // ✅ الفاصل الصحيح لـ Excel العربي

      // ===== 1. العناوين =====
      buffer.write('تسلسل$sepالاسم');
      for (int i = 0; i < _examCount; i++) {
        final title = (i < _examTitles.length && _examTitles[i].isNotEmpty)
            ? _examTitles[i]
            : 'اختبار ${i + 1}';
        buffer.write('$sep$title');
      }
      buffer.writeln('$sepالمتوسط');

      // ===== 2. بيانات الطلاب =====
      for (int i = 0; i < students.length; i++) {
        final s = students[i];
        buffer.write('${i + 1}$sep${s.name}');

        for (int x = 0; x < _examCount; x++) {
          final val = (x < s.exams.length && s.exams[x] != null)
              ? s.exams[x]
              : '';
          buffer.write('$sep$val');
        }

        buffer.writeln('$sep${_calcAverage(s).toStringAsFixed(1)}');
      }

      // ===== 3. حفظ الملف =====
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ ملف الدرجات',
        fileName: 'درجات_${widget.classTitle.replaceAll(" ", "_")}.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (outputFile == null) return;

      if (!outputFile.endsWith('.csv')) {
        outputFile += '.csv';
      }

      final file = File(outputFile);

      // BOM لضمان العربية
      final bytes = utf8.encode('\uFEFF${buffer.toString()}');
      await file.writeAsBytes(bytes, flush: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تصدير الملف بنجاح (CSV) ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء التصدير: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportClassExcel() async {
    debugPrint('=== EXPORT EXCEL START ===');

    // 🔒 تأمين القوائم قبل أي استخدام
    _ensureListLength(_examTitles, '');
    _ensureListLength(_examTags, 'عام');
    _ensureListLength(_examMax, 20.0);

    // إظهار مؤشر التحميل
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. إنشاء ملف الإكسل (الطريقة الصحيحة مع مكتبة excel)
      final excel = excel_lib.Excel.createExcel();

      // 2. اسم الشيت
      const String sheetName = 'الدرجات';

      // 3. إنشاء الشيت بشكل آمن (ولا نستخدم الافتراضي)
      final sheet = excel[sheetName];
      sheet.isRTL = true;

      // 4. كتابة العناوين (Headers)
      final List<excel_lib.CellValue> headers = [
        excel_lib.TextCellValue('تسلسل'),
        excel_lib.TextCellValue('الاسم'),
      ];

      for (int i = 0; i < _examCount; i++) {
        final String title =
            (i < _examTitles.length && _examTitles[i].isNotEmpty)
            ? _examTitles[i]
            : 'اختبار ${i + 1}';

        final double max = (i < _examMax.length) ? _examMax[i] : 0.0;

        final String maxStr = max.toStringAsFixed(max % 1 == 0 ? 0 : 1);

        headers.add(excel_lib.TextCellValue('$title (من $maxStr)'));
      }

      headers.add(excel_lib.TextCellValue('المتوسط (من 20)'));
      sheet.appendRow(headers);

      // 4. كتابة بيانات الطلاب
      int index = 1;
      for (final s in students) {
        final double avg = _calcAverage(s);

        List<excel_lib.CellValue> row = [
          excel_lib.IntCellValue(index),
          excel_lib.TextCellValue(s.name),
        ];

        for (int i = 0; i < _examCount; i++) {
          if (i < s.exams.length && s.exams[i] != null) {
            row.add(excel_lib.DoubleCellValue(s.exams[i]!));
          } else {
            row.add(excel_lib.TextCellValue(''));
          }
        }

        if (avg > 0) {
          row.add(excel_lib.DoubleCellValue(avg));
        } else {
          row.add(excel_lib.TextCellValue(''));
        }

        sheet.appendRow(row);
        index++;
      }

      // 5. حفظ الملف
      final fileBytes = excel.save();
      if (mounted) Navigator.pop(context);

      if (fileBytes == null) {
        throw Exception('فشل إنشاء ملف Excel');
      }

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ ملف الإكسل',
        fileName: 'درجات_${widget.classTitle.replaceAll(" ", "_")}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (outputFile != null) {
        if (!outputFile.endsWith('.xlsx')) {
          outputFile += '.xlsx';
        }

        final file = File(outputFile);
        await file.writeAsBytes(fileBytes, flush: true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حفظ ملف الإكسل بنجاح ✅'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء التصدير: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _ColumnConfig {
  TextEditingController tag;
  TextEditingController title;
  TextEditingController score;
  int? originalIndex;

  _ColumnConfig({
    required this.tag,
    required this.title,
    required this.score,
    required this.originalIndex,
  });
}
