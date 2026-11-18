// lib/generic_class_page.dart

import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// استيرادات المشروع (تأكد من صحة المسارات)
import '../../models/student.dart';
import '../../services/export_service.dart';
import '../../services/csv_export_service.dart';
import '../../core/config/class_grading_config.dart';
import '../students/student_detail_page.dart';
import '../../core/utils/number_utils.dart';
import '../home/home_page.dart';
import '../../core/settings/app_settings.dart';
import '../../core/widgets/main_bottom_bar.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../services/backup_service.dart';
import '../security/security/security_settings_page.dart';
import '../behavior/behavior_tracking_page.dart';
import '../behavior/student_styles_page.dart';
import '../behavior/student_academic_delay_page.dart';

class GenericClassPage extends StatefulWidget {
  final String classId;
  final String classTitle;

  const GenericClassPage({
    super.key,
    required this.classId,
    required this.classTitle,
  });

  @override
  State<GenericClassPage> createState() => _GenericClassPageState();
}

class _GenericClassPageState extends State<GenericClassPage> {
  ClassGradingConfig _config = ClassGradingConfig();
  List<Student> _students = [];
  final Map<String, Map<String, dynamic>> _allStudentScores = {};
  bool _isLoading = true;
  final TextEditingController _bulkNamesController = TextEditingController();
  int _bottomIndex = 0;

  // إعدادات التحكم في القياسات والأبعاد
  final double _headerHeight = 60.0;
  final double _rowHeight = 35.0; // زيادة الارتفاع قليلاً
  final double _indexColWidth = 45.0;
  final double _nameColRatio = 0.28;

  // ألوان الجدول العصري
  final Color _headerBgColor = const Color(0xFF2C3E50);
  final Color _headerTextColor = Colors.white;
  final Color _rowEvenColor = const Color(0xFFFFFFFF);
  final Color _rowOddColor = const Color.fromARGB(30, 39, 180, 232);
  final Color _borderColor = const Color(0xFFE0E0E0);
  final Color _selectedRowColor = const Color(0xFFFFF3E0);
  final Color _textColor = const Color(0xFF1A1A2E);

  // === متغير الفترة المختارة (الإضافة الجديدة) ===
  // 1: الفترة الأولى، 2: الفترة الثانية، 0: المحصلة النهائية
  int _selectedPeriod = 1;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _bulkNamesController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    _config = await ClassGradingConfig.load(widget.classId);
    final prefs = await SharedPreferences.getInstance();

    final studentsJson = prefs.getString('class_students_${widget.classId}');
    if (studentsJson != null) {
      final List list = jsonDecode(studentsJson);
      _students = list.map((e) => Student.fromJson(e)).toList();
    }

    _allStudentScores.clear();
    for (var s in _students) {
      final sKey = 'student_detail_${s.name}_${widget.classId}';
      final sStr = prefs.getString(sKey);
      if (sStr != null) _allStudentScores[s.name] = jsonDecode(sStr);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // --- دوال مساعدة للفترات ---
  String _getSuffix() {
    if (_selectedPeriod == 1) return '_p1';
    if (_selectedPeriod == 2) return '_p2';
    return ''; // للمحصلة
  }

  double _parseScoreValue(GradeColumn col, dynamic val) {
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
        if (count > 0) return (sum / count);
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

  bool _isFinalExam(GradeColumn col) {
    return col.tag == 'اختبار نهائي' || col.name.contains('نهائي');
  }

  // جلب الدرجة (مع مراعاة الفترة المختارة)
  String _getCalculatedScore(Student s, GradeColumn col) {
    // 1. إذا كان العمود "اختبار نهائي" ونحن في فترة 1 أو 2 -> ارجع شرطة
    if (_selectedPeriod != 0 && _isFinalExam(col)) {
      return '-';
    }

    final data = _allStudentScores[s.name];
    if (data == null) return '-';

    if (_selectedPeriod == 0) {
      // === المحصلة النهائية ===
      if (_isFinalExam(col)) {
        // النهائي يقرأ من الفترة الثانية فقط (حسب اتفاقنا في صفحة الطالب)
        final val = data['${col.id}_p2']; // النهائي مخزن هنا
        if (val == null) return '-';
        return formatNumberForDisplay(_parseScoreValue(col, val));
      } else {
        // بقية الأعمدة: متوسط الفترتين
        final val1 = data['${col.id}_p1'];
        final val2 = data['${col.id}_p2'];
        double score1 = val1 != null ? _parseScoreValue(col, val1) : 0.0;
        double score2 = val2 != null ? _parseScoreValue(col, val2) : 0.0;
        return formatNumberForDisplay((score1 + score2) / 2);
      }
    } else {
      // === فترة محددة (1 أو 2) ===
      final suffix = _getSuffix();
      final val = data['${col.id}$suffix'];
      if (val == null) return '-';
      double score = _parseScoreValue(col, val);
      return formatNumberForDisplay(score);
    }
  }

  // مجموع المهام
  double _getPerformanceTotal(Student s) {
    final data = _allStudentScores[s.name];
    if (data == null) return 0.0;

    double total = 0.0;

    if (_selectedPeriod == 0) {
      for (var col in _config.items) {
        // المهام فقط
        double v1 = data['${col.id}_p1'] != null
            ? _parseScoreValue(col, data['${col.id}_p1'])
            : 0.0;
        double v2 = data['${col.id}_p2'] != null
            ? _parseScoreValue(col, data['${col.id}_p2'])
            : 0.0;
        total += (v1 + v2) / 2;
      }
    } else {
      String suffix = _getSuffix();
      for (var col in _config.items) {
        final val = data['${col.id}$suffix'];
        if (val != null) total += _parseScoreValue(col, val);
      }
    }
    return total;
  }

  // المجموع الكلي (للفترة أو المحصلة)
  // حساب مجموع صف الطالب (العمود الأخير)
  double _getPeriodTotalScore(Student s) {
    final data = _allStudentScores[s.name];
    if (data == null) return 0.0;

    double total = 0.0;
    String suffix = _getSuffix();

    // إذا اخترنا فترة محددة (1 أو 2)
    if (_selectedPeriod != 0) {
      for (var col in [..._config.items, ..._config.exams]) {
        // استثناء الاختبار النهائي من مجموع الفترة
        if (_isFinalExam(col)) continue;

        final val = data['${col.id}$suffix'];
        if (val != null) total += _parseScoreValue(col, val);
      }
      return total;
    }

    return 0.0; // حالة المحصلة تحسب في دالة أخرى
  }

  // --- واجهة المستخدم ---
  @override
  Widget build(BuildContext context) {
    List<GradeColumn> allColumns = [..._config.items, ..._config.exams];
    final hasSelected = _students.any((s) => s.isSelected);

    return ValueListenableBuilder<bool>(
      valueListenable: AppSettings.useArabicNumbers,
      builder: (context, isArabic, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            extendBodyBehindAppBar: true,
            extendBody: true,
            appBar: AppBar(
              title: Column(
                children: [
                  Text(widget.classTitle.toAppNum()),
                  // عرض الفترة المختارة
                  Text(
                    _selectedPeriod == 0
                        ? 'المحصلة النهائية'
                        : 'الفترة ${_selectedPeriod.toString().toAppNum()}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              titleTextStyle: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              actions: [
                // فلتر الفترة (Dropdown)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      dropdownColor: const Color(0xFF2C3E50),
                      value: _selectedPeriod,
                      icon: const Icon(Icons.filter_list, color: Colors.white),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 1,
                          child: Text('الفترة الأولى'),
                        ),
                        DropdownMenuItem(
                          value: 2,
                          child: Text('الفترة الثانية'),
                        ),
                        DropdownMenuItem(
                          value: 0,
                          child: Text('المحصلة النهائية'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedPeriod = val);
                      },
                    ),
                  ),
                ),

                // بقية الأزرار كما هي في الكود الأصلي
                Tooltip(
                  message: 'سلوك',
                  child: IconButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BehaviorTrackingPage(
                          classId: widget.classId,
                          classTitle: widget.classTitle,
                          studentNames: _students.map((e) => e.name).toList(),
                        ),
                      ),
                    ),
                    icon: const Icon(
                      Icons.sentiment_satisfied_alt,
                      color: Colors.amberAccent,
                    ),
                  ),
                ),
                Tooltip(
                  message: 'أنماط التعلم',
                  child: IconButton(
                    icon: const Icon(Icons.psychology_outlined),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StudentStylesPage(
                            classId: widget.classId,
                            classTitle: widget.classTitle,
                            studentNames: _students.map((e) => e.name).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Tooltip(
                  message: 'المتأخرين دراسياً',
                  child: IconButton(
                    icon: const Icon(Icons.warning_amber_rounded),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StudentAcademicDelayPage(
                            classId: widget.classId,
                            classTitle: widget.classTitle,
                            studentNames: _students.map((e) => e.name).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.upload_file),
                  tooltip: 'استيراد من CSV',
                  onPressed: _importFromCsvGeneric,
                ),
                IconButton(
                  onPressed: _showImportDialog,
                  icon: const Icon(Icons.copy_all),
                  tooltip: 'نسخ من صف آخر',
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (val) {
                    if (val == 'add') _addStudent();
                    if (val == 'bulk') _showBulkAddNamesDialog();
                    if (val == 'sort') _sortStudentsAlphabetically();
                    if (val == 'settings') _showGradingSettings();
                    // لاحظ: الرصد العشوائي سيحتاج تحديث ليدعم الفترات، حالياً هو يرصد للعمود الأساسي
                    // يمكنك تركه كما هو إذا لم تستخدمه، أو تحديثه لاحقاً
                    if (val == 'random') _showRandomOptionsDialog();
                    if (val == 'full') _fillQuickGrades(isRandom: false);
                    if (val == 'txt') _exportNamesToTxt();
                    if (val == 'csv') _exportClassCsv();

                    // التصدير يعتمد على الفترة
                    if (val == 'pdf') {
                      ExportService.generatePdf(
                        context: context,
                        // العنوان يتغير حسب الفترة
                        classTitle:
                            '${widget.classTitle} - ${_selectedPeriod == 0 ? "المحصلة النهائية" : "الفترة ${_selectedPeriod.toString().toAppNum()}"}',
                        students: _students,
                        config: _config,
                        allScores: _allStudentScores,
                        // ✅ هذا هو المفتاح: إرسال رقم الفترة للخدمة
                        activePeriod: _selectedPeriod,
                      );
                    }
                    if (val == 'excel') {
                      ExportService.generateExcel(
                        context: context,
                        classTitle: widget.classTitle,
                        students: _students,
                        config: _config,
                        allScores: _allStudentScores,
                        activePeriod: _selectedPeriod, // ✅ نفس الشيء للإكسل
                      );
                    }
                    if (val == 'del_all') _deleteAllStudentsDialog();
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
                          Icon(Icons.settings, color: Colors.grey),
                          SizedBox(width: 8),
                          Text('إعداد الدرجات'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'full',
                      child: Row(
                        children: [
                          Icon(Icons.done_all, color: Colors.green),
                          SizedBox(width: 8),
                          Text('رصد كامل'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'random',
                      child: Row(
                        children: [
                          Icon(Icons.casino, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('رصد عشوائي'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'csv',
                      child: Row(
                        children: [
                          Icon(Icons.table_chart, color: Colors.green),
                          SizedBox(width: 8),
                          Text('CSV'),
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
                    if (_students.isNotEmpty)
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
                ),
              ],
            ),
            body: Stack(
              children: [
                // الخلفية
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF30c9cd), Color(0xFF330d69)],
                    ),
                  ),
                ),

                // المحتوى
                if (_isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  )
                else
                  SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: kToolbarHeight + 24,
                        bottom: 100,
                      ),
                      child: SafeArea(
                        top: false,
                        bottom: false,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            bool isLandscape = constraints.maxWidth > 800;
                            if (isLandscape) {
                              final mid = (_students.length / 2).ceil();
                              final rightList = _students.take(mid).toList();
                              final leftList = _students.skip(mid).toList();
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildFloatingCard(
                                      child: _buildPanel(
                                        rightList,
                                        0,
                                        allColumns,
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(30),
                                      ),
                                      margin: const EdgeInsets.only(
                                        left: 1,
                                        right: 10,
                                      ),
                                    ),
                                  ),
                                  Container(width: 10),
                                  Expanded(
                                    child: _buildFloatingCard(
                                      child: _buildPanel(
                                        leftList,
                                        mid,
                                        allColumns,
                                      ),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(30),
                                      ),
                                      margin: const EdgeInsets.only(
                                        left: 10,
                                        right: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            } else {
                              return _buildFloatingCard(
                                child: _buildPanel(_students, 0, allColumns),
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
                    ),
                  ),

                if (hasSelected)
                  Positioned(
                    bottom: 80,
                    left: 20,
                    child: FloatingActionButton(
                      backgroundColor: Colors.red,
                      onPressed: _deleteSelectedStudents,
                      child: const Icon(Icons.delete),
                    ),
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

  // --- بناء البطاقة العائمة ---
  Widget _buildFloatingCard({
    required Widget child,
    required BorderRadius borderRadius,
    required EdgeInsets margin,
  }) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: borderRadius,
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: borderRadius, child: child),
    );
  }

  // --- تصميم الجدول ---
  Widget _buildPanel(
    List<Student> panelStudents,
    int startIndex,
    List<GradeColumn> allColumns,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        double nameW = w * _nameColRatio;
        if (nameW < 130) nameW = 130;
        final double remainW = w - _indexColWidth - nameW;
        int totalDataCols = _config.items.length + _config.exams.length + 2;
        double colW = remainW / (totalDataCols > 0 ? totalDataCols : 1);
        if (colW < 45) colW = 45;

        List<Widget> headerCells = [];
        headerCells.add(_buildHeaderCell('ت', _indexColWidth));
        headerCells.add(_buildHeaderCell('الاسم', nameW));
        for (var col in _config.items) {
          headerCells.add(_buildHeaderCell(col.name, colW, isVertical: true));
        }
        headerCells.add(
          _buildHeaderCell(
            'م.المهام',
            colW,
            isVertical: true,
            isHighlight: true,
          ),
        );
        for (var col in _config.exams) {
          headerCells.add(_buildHeaderCell(col.name, colW, isVertical: true));
        }

        // عنوان المجموع حسب الفترة
        String totalTitle = _selectedPeriod == 0 ? 'النهائي' : 'المجموع';
        headerCells.add(
          _buildHeaderCell(
            totalTitle,
            colW,
            isVertical: true,
            isHighlight: true,
          ),
        );

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // الهيدر
              Container(
                height: _headerHeight,
                decoration: BoxDecoration(
                  color: _headerBgColor,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: Row(children: headerCells),
              ),

              // الصفوف
              if (panelStudents.isEmpty)
                const SizedBox(
                  height: 100,
                  child: Center(child: Text('لا يوجد طلاب')),
                )
              else
                Column(
                  children: List.generate(panelStudents.length, (i) {
                    final s = panelStudents[i];
                    final displayIndex = startIndex + i + 1;
                    Color rowColor = (i % 2 == 0)
                        ? _rowEvenColor
                        : _rowOddColor;
                    if (s.isSelected) rowColor = _selectedRowColor;

                    return Container(
                      height: _rowHeight,
                      color: rowColor,
                      child: Row(
                        children: _buildStudentRowCells(
                          displayIndex,
                          s,
                          _indexColWidth,
                          nameW,
                          colW,
                        ),
                      ),
                    );
                  }),
                ),
            ],
          ),
        );
      },
    );
  }

  // --- خلايا الصف ---
  List<Widget> _buildStudentRowCells(
    int index,
    Student s,
    double idxW,
    double nameW,
    double colW,
  ) {
    List<Widget> cells = [];
    cells.add(
      InkWell(
        onTap: () => setState(() => s.isSelected = !s.isSelected),
        child: Container(
          width: idxW,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: _borderColor)),
          ),
          child: Text(
            '$index'.toAppNum(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
    cells.add(
      InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentDetailPage(
                name: s.name,
                classId: widget.classId,
                allNames: _students.map((e) => e.name).toList(),
                initialIndex: _students.indexOf(s),
              ),
            ),
          );
          _loadAllData();
        },
        child: Container(
          width: nameW,
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
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: _textColor,
            ),
          ),
        ),
      ),
    );

    // عرض الدرجات (معدلة حسب الفترة)
    for (var col in _config.items) {
      cells.add(_buildDataCell(_getCalculatedScore(s, col), colW));
    }

    cells.add(
      _buildDataCell(
        formatNumberForDisplay(_getPerformanceTotal(s)),
        colW,
        isBold: true,
        bgColor: Colors.purple.withOpacity(0.05),
      ),
    );

    for (var col in _config.exams) {
      cells.add(_buildDataCell(_getCalculatedScore(s, col), colW));
    }

    cells.add(
      _buildDataCell(
        formatNumberForDisplay(_getGrandTotalScore(s)),
        colW,
        isBold: true,
        bgColor: Colors.blue.withOpacity(0.05),
      ),
    );

    return cells;
  }

  double _getGrandTotalScore(Student s) {
    // 1. إذا كنا في فترة عادية، نرجع مجموع أعمالها فقط
    if (_selectedPeriod != 0) {
      return _getPeriodTotalScore(s);
    }

    // 2. إذا كنا في المحصلة النهائية
    final data = _allStudentScores[s.name];
    if (data == null) return 0.0;

    // أ. حساب مجموع ف1 (بدون نهائي)
    double p1 = 0;
    for (var col in [..._config.items, ..._config.exams]) {
      if (!_isFinalExam(col) && data['${col.id}_p1'] != null) {
        p1 += _parseScoreValue(col, data['${col.id}_p1']);
      }
    }

    // ب. حساب مجموع ف2 (بدون نهائي)
    double p2 = 0;
    for (var col in [..._config.items, ..._config.exams]) {
      if (!_isFinalExam(col) && data['${col.id}_p2'] != null) {
        p2 += _parseScoreValue(col, data['${col.id}_p2']);
      }
    }

    // ج. درجة الاختبار النهائي (المخزن في p2 أو final_exam_global حسب كود الطالب)
    // في كود الطالب الأخير، اتفقنا أنه يخزن في _p2 أو مفتاح خاص.
    // لتوحيد العمل، سأبحث عنه في كل الأماكن المحتملة
    double finalExam = 0.0;

    // محاولة 1: البحث عنه كعمود عادي في الفترة 2
    for (var col in _config.exams) {
      if (_isFinalExam(col)) {
        if (data['${col.id}_p2'] != null) {
          finalExam += _parseScoreValue(col, data['${col.id}_p2']);
        }
      }
    }

    // محاولة 2: إذا كنت تستخدم المفتاح القديم (احتياط)
    if (finalExam == 0) {
      finalExam =
          double.tryParse(data['final_exam_global']?.toString() ?? '0') ?? 0.0;
    }

    // المعادلة: (ف1 + ف2) / 2 + النهائي
    return ((p1 + p2) / 2) + finalExam;
  }

  Widget _buildHeaderCell(
    String text,
    double width, {
    bool isVertical = false,
    bool isHighlight = false,
  }) {
    return Container(
      width: width,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isHighlight ? Colors.white.withOpacity(0.1) : null,
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.2))),
      ),
      child: isVertical
          ? RotatedBox(
              quarterTurns: 3,
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _headerTextColor,
                ),
              ),
            )
          : Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _headerTextColor,
              ),
            ),
    );
  }

  Widget _buildDataCell(
    String text,
    double width, {
    bool isBold = false,
    Color? bgColor,
  }) {
    return Container(
      width: width,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(right: BorderSide(color: _borderColor)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          color: _textColor,
        ),
      ),
    );
  }

  // --- الدوال الإدارية (نسخ، حذف، استيراد) ---

  void _addStudent() {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة طالب'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'الاسم الثلاثي'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                _students.add(Student(name: controller.text));
                await _saveStudentsList();
                Navigator.pop(ctx);
                _loadAllData();
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBulkAddNamesDialog() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة عدة أسماء'),
        content: SizedBox(
          width: 300,
          child: TextField(
            controller: _bulkNamesController,
            maxLines: 10,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'ألصق الأسماء هنا',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = _bulkNamesController.text.trim();
              if (text.isNotEmpty) {
                final lines = text.split('\n');
                for (var line in lines) {
                  final name = line.trim();
                  if (name.isNotEmpty &&
                      !_students.any((s) => s.name == name)) {
                    _students.add(Student(name: name));
                  }
                }
                await _saveStudentsList();
                _loadAllData();
              }
              _bulkNamesController.clear();
              Navigator.pop(context);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAllStudentsDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('حذف جميع الطلاب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      _students.clear();
      _allStudentScores.clear();
      await _saveStudentsList();
      setState(() {});
    }
  }

  void _sortStudentsAlphabetically() {
    setState(() {
      _students.sort((a, b) => a.name.compareTo(b.name));
    });
    _saveStudentsList();
  }

  void _deleteSelectedStudents() {
    setState(() {
      _students.removeWhere((s) => s.isSelected);
    });
    _saveStudentsList();
  }

  Future<void> _saveStudentsList() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_students.map((e) => e.toJson()).toList());
    await prefs.setString('class_students_${widget.classId}', data);
  }

  void _showGradingSettings() {
    showDialog(
      context: context,
      builder: (context) => _GradingSettingsDialog(
        initialConfig: _config,
        onSave: (newConfig) async {
          await newConfig.save(widget.classId);
          _loadAllData();
        },
      ),
    );
  }

  // خيارات الرصد العشوائي
  void _showRandomOptionsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('خيارات الرصد العشوائي'),
        content: const Text(
            'هل تفضل أن تكون الدرجات العشوائية بأرقام صحيحة أم بأرقام تحتوي على أنصاف (كسور عشرية)؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _fillQuickGrades(isRandom: true, allowDecimals: true);
            },
            child: const Text('بكسور (أنصاف)'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _fillQuickGrades(isRandom: true, allowDecimals: false);
            },
            child: const Text('أرقام صحيحة'),
          ),
        ],
      ),
    );
  }

  // دالة الرصد العشوائي / الكامل (محدثة لدعم النهائي وأنماط العشوائية المتقدمة)
  Future<void> _fillQuickGrades({required bool isRandom, bool allowDecimals = true}) async {
    // لا يمكن الرصد في وضع المحصلة النهائية لأنه عرض فقط
    if (_selectedPeriod == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجا اختيار فترة محددة (1 أو 2) للرصد')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final rnd = Random();
    List<GradeColumn> allCols = [..._config.items, ..._config.exams];
    String suffix = _getSuffix(); // _p1 أو _p2

    for (var s in _students) {
      final sKey = 'student_detail_${s.name}_${widget.classId}';

      // تحميل البيانات القديمة للحفاظ على بيانات الفترة الأخرى
      Map<String, dynamic> studentData = {};
      final str = prefs.getString(sKey);
      if (str != null) studentData = jsonDecode(str);

      // تحديد مستوى الطالب (للعشوائي) بشكل يعطي تفاوتاً أكبر
      double basePercent = 1.0;
      if (isRandom) {
        // نختار نسبة عشوائية للطالب تتراوح تقريباً بين 50% إلى 100% لخلق تفاوت ملحوظ
        basePercent = 0.50 + (rnd.nextDouble() * 0.50);
      }

      // المرور على الأعمدة
      for (var col in allCols) {
        // 1. التعامل مع الاختبار النهائي
        if (_isFinalExam(col)) {
          // النهائي يرصد فقط إذا كنا في الفترة الثانية
          if (_selectedPeriod == 2) {
            String finalKey = '${col.id}_p2'; // النهائي يخزن دائماً في p2
            if (!isRandom) {
              studentData[finalKey] = col.maxScore; // رصد كامل
            } else {
              // رصد عشوائي للنهائي مع تذبذب إضافي قليل
              double examPercent = basePercent + (rnd.nextDouble() * 0.2 - 0.1);
              double score = col.maxScore * examPercent.clamp(0.0, 1.0);
              studentData[finalKey] = allowDecimals 
                  ? (score * 2).round() / 2.0 
                  : score.roundToDouble();
            }
          }
          continue; // انتهينا من النهائي، ننتقل للعمود التالي
        }

        // 2. التعامل مع بقية الأعمدة (فترة عادية)
        String key = '${col.id}$suffix';

        if (!isRandom) {
          // --- رصد كامل ---
          if (col.type == GradeType.numeric)
            studentData[key] = col.maxScore;
          else if (col.type == GradeType.checkbox)
            studentData[key] = col.subCount;
          else if (col.type == GradeType.numericList)
            studentData[key] = List.filled(col.subCount, col.maxScore);
          else if (col.type == GradeType.averagePair)
            studentData[key] = [col.maxScore, col.maxScore];
        } else {
          // --- رصد عشوائي ---
          if (col.type == GradeType.numeric) {
            double itemPercent = basePercent + (rnd.nextDouble() * 0.2 - 0.1);
            double score = col.maxScore * itemPercent.clamp(0.0, 1.0);
            studentData[key] = allowDecimals 
                ? (score * 2).round() / 2.0 
                : score.roundToDouble();
          } else if (col.type == GradeType.checkbox) {
            double score = col.subCount * basePercent;
            studentData[key] = score.round();
          } else if (col.type == GradeType.numericList) {
            List<double> scores = [];
            for (int i = 0; i < col.subCount; i++) {
              double itemPercent = basePercent + (rnd.nextDouble() * 0.3 - 0.15);
              double score = col.maxScore * itemPercent.clamp(0.0, 1.0);
              scores.add(allowDecimals 
                  ? (score * 2).round() / 2.0 
                  : score.roundToDouble());
            }
            studentData[key] = scores;
          } else if (col.type == GradeType.averagePair) {
            double p1 = (basePercent + (rnd.nextDouble() * 0.2 - 0.1)).clamp(0.0, 1.0);
            double p2 = (basePercent + (rnd.nextDouble() * 0.2 - 0.1)).clamp(0.0, 1.0);
            double v1 = allowDecimals 
                ? (col.maxScore * p1 * 2).round() / 2.0 
                : (col.maxScore * p1).roundToDouble();
            double v2 = allowDecimals 
                ? (col.maxScore * p2 * 2).round() / 2.0 
                : (col.maxScore * p2).roundToDouble();
            studentData[key] = [v1, v2];
          }
        }
      }

      // حفظ البيانات
      await prefs.setString(sKey, jsonEncode(studentData));
    }

    _loadAllData();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'تم الرصد ${isRandom ? "العشوائي" : "الكامل"} للفترة $_selectedPeriod بنجاح',
        ),
      ),
    );
  }

  // --- استيراد وتصدير (تحتاج تحديث لاحقاً) ---
  Future<void> _exportNamesToTxt() async {
    try {
      // 1. تجهيز المحتوى (نفس السابق)
      final StringBuffer buffer = StringBuffer();
      for (int i = 0; i < _students.length; i++) {
        buffer.writeln(_students[i].name);
      }
      final String content = buffer.toString();

      // 2. إظهار نافذة "حفظ باسم" باستخدام file_picker
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'الرجاء تحديد مكان حفظ الملف:',
        fileName: 'names_${widget.classTitle.replaceAll(" ", "_")}.txt',
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      // 3. التحقق من اختيار المستخدم لمسار والحفظ
      if (outputFile != null) {
        // قد لا يضيف file_picker الامتداد تلقائياً، لذلك نتأكد منه
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

  Future<void> _exportClassCsv() async {
    final headers = <String>['تسلسل', 'الاسم'];

    final allCols = [..._config.items, ..._config.exams];
    for (final col in allCols) {
      if (col.type == GradeType.numericList) {
        for (int i = 0; i < col.subCount; i++) {
          headers.add('${col.name} ${i + 1}');
        }
      } else if (col.type == GradeType.averagePair) {
        headers.add('${col.name} 1');
        headers.add('${col.name} 2');
      } else {
        headers.add(col.name);
      }
    }

    headers.add('مجموع المهام');
    headers.add('المجموع الكلي');

    final rows = <List<dynamic>>[];

    for (int i = 0; i < _students.length; i++) {
      final s = _students[i];
      final row = <dynamic>[i + 1, s.name];

      final data = _allStudentScores[s.name] ?? {};

      for (final col in allCols) {
        final val = data[col.id];

        if (col.type == GradeType.numericList) {
          // ... (كود القوائم يبقى كما هو) ...
          if (val is List) {
            for (int i = 0; i < col.subCount; i++) {
              row.add(i < val.length ? val[i] : '');
            }
          } else {
            for (int i = 0; i < col.subCount; i++) {
              row.add('');
            }
          }
        } else if (col.type == GradeType.averagePair) {
          // ... (كود المتوسط يبقى كما هو) ...
          if (val is List && val.length >= 2) {
            row.add(val[0]);
            row.add(val[1]);
          } else {
            row.add('');
            row.add('');
          }
        } else {
          // ✅ التعديل هنا:
          // استخدام الدالة لحساب الدرجة (خاصة للصح والخطأ)
          row.add(calculateCellForCsv(col, val));
        }
      }

      row.add(
        ExportService.calculatePerformanceTotal(
          student: s,
          config: _config,
          allScores: _allStudentScores,
          activePeriod: _selectedPeriod, // ✅ أضفنا الفترة المختارة
        ),
      );

      // حساب المجموع الكلي
      row.add(
        ExportService.calculateTotalScore(
          student: s,
          config: _config,
          allScores: _allStudentScores,
          activePeriod: _selectedPeriod, // ✅ أضفنا الفترة المختارة
        ),
      );

      rows.add(row);
    }

    await exportClassCsvGeneric(
      fileName: 'درجات_${widget.classTitle}',
      headers: headers,
      rows: rows,
    );
  }

  Future<void> _importFromCsvGeneric() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null) return;

    final file = File(result.files.single.path!);
    final content = await file.readAsString(encoding: utf8);

    final lines = content.split(RegExp(r'\r?\n'));
    if (lines.length < 2) return;

    // الأعمدة المعرفة في النظام
    final allCols = [..._config.items, ..._config.exams];

    final prefs = await SharedPreferences.getInstance();

    for (int i = 1; i < lines.length; i++) {
      final row = lines[i].trim();
      if (row.isEmpty) continue;

      final cols = row.split(';').map((e) => e.trim()).toList();
      if (cols.length < 2) continue;

      int colIndex = 0;

      // تجاهل التسلسل إذا كان رقم
      if (RegExp(r'^\d+$').hasMatch(cols[0])) {
        colIndex = 1;
      }

      final name = cols[colIndex];
      colIndex++;

      if (!_students.any((s) => s.name == name)) continue;

      final Map<String, dynamic> studentData = {};

      for (final col in allCols) {
        if (colIndex >= cols.length) break;

        if (col.type == GradeType.numeric) {
          studentData[col.id] =
              double.tryParse(cols[colIndex].toEnglishNum()) ?? 0.0;
          colIndex++;
        }
        // ✅✅✅ بداية التعديل لقسم المربعات ✅✅✅
        else if (col.type == GradeType.checkbox) {
          double importedScore =
              double.tryParse(cols[colIndex].toEnglishNum()) ?? 0.0;
          int count = 0;

          if (col.subCount > 0 && col.maxScore > 0) {
            // حساب قيمة المربع الواحد
            double scorePerBox = col.maxScore / col.subCount;
            // عكس العملية: الدرجة تقسيم قيمة المربع = العدد
            count = (importedScore / scorePerBox).round();

            // التأكد من عدم تجاوز الحد الأقصى للمربعات
            if (count > col.subCount) count = col.subCount;
          }

          studentData[col.id] = count; // حفظ العدد بدلاً من الدرجة
          colIndex++;
        }
        // ✅✅✅ نهاية التعديل ✅✅✅
        else if (col.type == GradeType.numericList) {
          List<double> values = [];
          for (int c = 0; c < col.subCount && colIndex < cols.length; c++) {
            final v = double.tryParse(cols[colIndex].toEnglishNum());
            values.add(v ?? 0.0);
            colIndex++;
          }
          studentData[col.id] = values;
        } else if (col.type == GradeType.averagePair) {
          double v1 = colIndex < cols.length
              ? double.tryParse(cols[colIndex].toEnglishNum()) ?? 0.0
              : 0.0;
          double v2 = colIndex + 1 < cols.length
              ? double.tryParse(cols[colIndex + 1].toEnglishNum()) ?? 0.0
              : 0.0;
          studentData[col.id] = [v1, v2];
          colIndex += 2;
        }
      }

      final key = 'student_detail_${name}_${widget.classId}';
      await prefs.setString(key, jsonEncode(studentData));
    }

    _loadAllData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم استيراد الدرجات من CSV بنجاح ✅'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showImportDialog() async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, String>> availableSources = [];

    // الفصول الأساسية
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

    // الفصول الإضافية
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

    // الاختبارات المحاكية
    final mockClassesStr = prefs.getString('home_mock_classes_v1');
    if (mockClassesStr != null) {
      try {
        List<dynamic> mockList = jsonDecode(mockClassesStr);
        for (var item in mockList) {
          availableSources.add({
            'id': item['id'],
            'name': '📝 ${item['displayTitle']}',
            'type': 'mock',
          });
        }
      } catch (e) {
        debugPrint('$e');
      }
    }

    availableSources.removeWhere((element) => element['id'] == widget.classId);

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize:
                  MainAxisSize.min, // ليأخذ الـ Dialog حجم المحتوى فقط
              children: [
                for (int i = 0; i < availableSources.length; i++) ...[
                  // بناء العنصر (ListTile)
                  ListTile(
                    leading: Icon(
                      availableSources[i]['type'] == 'mock'
                          ? Icons.assignment
                          : Icons.class_,
                      color: availableSources[i]['type'] == 'mock'
                          ? Colors.orange
                          : Colors.blue,
                    ),
                    title: Text(availableSources[i]['name']!),
                    subtitle: Text(
                      availableSources[i]['type'] == 'mock'
                          ? 'اختبار محاكي'
                          : 'فصل دراسي',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => _copyNamesFromSource(
                      availableSources[i]['id']!,
                      availableSources[i]['name']!,
                      availableSources[i]['type']!,
                    ),
                  ),
                  // ✅ إضافة الفاصل يدوياً (Separator) باستثناء العنصر الأخير
                  if (i < availableSources.length - 1) const Divider(height: 1),
                ],
              ],
            ),
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
        if (!_students.any((s) => s.name == name)) {
          _students.add(Student(name: name));
          addedCount++;
        }
      }
      if (addedCount > 0) {
        await _saveStudentsList();
        _loadAllData();
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
}

// نافذة الإعدادات (ضرورية كي لا يحدث خطأ في الكود)
class _GradingSettingsDialog extends StatefulWidget {
  final ClassGradingConfig initialConfig;
  final Function(ClassGradingConfig) onSave;
  const _GradingSettingsDialog({
    required this.initialConfig,
    required this.onSave,
  });
  @override
  State<_GradingSettingsDialog> createState() => _GradingSettingsDialogState();
}

class _GradingSettingsDialogState extends State<_GradingSettingsDialog> {
  late ClassGradingConfig _tempConfig;
  List<String> _availableTags = List.from(GlobalGradingTags.defaultTags);
  @override
  void initState() {
    super.initState();
    _tempConfig = ClassGradingConfig();
    _tempConfig.items = List.from(widget.initialConfig.items);
    _tempConfig.exams = List.from(widget.initialConfig.exams);
    _loadTags();
  }

  Future<void> _loadTags() async {
    final tags = await GlobalGradingTags.loadTags();
    if (mounted) setState(() => _availableTags = List.from(tags));
  }

  void _openItemDialog({
    required bool isExam,
    int? index,
    GradeColumn? existingItem,
  }) {
    final TextEditingController nameCtrl = TextEditingController(
      text: existingItem?.name ?? '',
    );
    final TextEditingController scoreCtrl = TextEditingController(
      text: existingItem?.maxScore.toString() ?? '',
    );
    final TextEditingController countCtrl = TextEditingController(
      text: existingItem?.subCount.toString() ?? '5',
    );
    GradeType type =
        existingItem?.type ?? (isExam ? GradeType.numeric : GradeType.checkbox);
    bool isPerformance = existingItem?.isPerformanceTask ?? false;
    String selectedTag =
        existingItem?.tag ??
        (_availableTags.isNotEmpty ? _availableTags.first : 'عام');
    if (existingItem != null && !_availableTags.contains(existingItem.tag)) {
      setState(() {
        _availableTags.add(existingItem.tag);
      });
      selectedTag = existingItem.tag;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateLocal) => AlertDialog(
          title: Text(
            index == null
                ? (isExam ? 'إضافة' : 'إضافة')
                : (isExam ? 'تعديل' : 'تعديل'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'تصنيف العمود:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _availableTags.contains(selectedTag)
                            ? selectedTag
                            : null,
                        isExpanded: true,
                        items: _availableTags
                            .toSet()
                            .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setStateLocal(() => selectedTag = v);
                        },
                      ),
                    ),
                    // زر إضافة تاق جديد
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.blue),
                      tooltip: 'إضافة تصنيف جديد',
                      onPressed: () async {
                        String? newTag = await _addNewTagDialog(context);
                        if (newTag != null && newTag.trim().isNotEmpty) {
                          final currentTags =
                              await GlobalGradingTags.loadTags();
                          final updatedTags = {
                            ...currentTags,
                            newTag.trim(),
                          }.toList();
                          await GlobalGradingTags.saveTags(updatedTags);
                          setState(() {
                            _availableTags = List.from(updatedTags);
                          });
                          setStateLocal(() {
                            selectedTag = newTag.trim();
                          });
                        }
                      },
                    ),
                    // ✅ زر تنظيف التاقات (الجديد)
                    IconButton(
                      icon: const Icon(
                        Icons.delete_sweep,
                        color: Colors.orange,
                      ),
                      tooltip: 'استعادة التصنيفات الافتراضية',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('تنظيف القائمة'),
                            content: const Text(
                              'هل تريد حذف التصنيفات المضافة يدوياً والعودة للقائمة الأساسية فقط؟\n(لن تتأثر الأعمدة الموجودة حالياً)',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('إلغاء'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('نعم، نظف القائمة'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await GlobalGradingTags.saveTags(
                            GlobalGradingTags.defaultTags,
                          );
                          setState(() {
                            _availableTags = List.from(
                              GlobalGradingTags.defaultTags,
                            );
                          });
                          // إذا كان التاق المختار حالياً غير موجود في القائمة الجديدة، نضيفه مؤقتاً لكي لا يختفي
                          if (!_availableTags.contains(selectedTag)) {
                            setState(() {
                              _availableTags.add(selectedTag);
                            });
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم تنظيف القائمة بنجاح'),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'اسم العمود'),
                ),
                TextField(
                  controller: scoreCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9\.]')),
                    ArabicToEnglishNumberFormatter(),
                  ],
                  decoration: const InputDecoration(labelText: 'الدرجة القصوى'),
                ),
                DropdownButtonFormField<GradeType>(
                  initialValue: type,
                  items: isExam
                      ? const [
                          DropdownMenuItem(
                            value: GradeType.numeric,
                            child: Text('رقمي'),
                          ),
                          DropdownMenuItem(
                            value: GradeType.averagePair,
                            child: Text('متوسط اختبارين'),
                          ),
                        ]
                      : const [
                          DropdownMenuItem(
                            value: GradeType.checkbox,
                            child: Text('صح/خطأ'),
                          ),
                          DropdownMenuItem(
                            value: GradeType.numericList,
                            child: Text('مربعات إدخال'),
                          ),
                          DropdownMenuItem(
                            value: GradeType.numeric,
                            child: Text('رقمي مباشر'),
                          ),
                        ],
                  onChanged: (v) => setStateLocal(() => type = v!),
                ),
                if (type == GradeType.checkbox || type == GradeType.numericList)
                  TextField(
                    controller: countCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'عدد الخانات'),
                  ),
                CheckboxListTile(
                  title: const Text('ضمن المهام الأدائية؟'),
                  value: isPerformance,
                  onChanged: (val) =>
                      setStateLocal(() => isPerformance = val ?? false),
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
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  setState(() {
                    final newItem = GradeColumn(
                      id:
                          existingItem?.id ??
                          DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameCtrl.text,
                      tag: selectedTag,
                      type: type,
                      maxScore: double.tryParse(scoreCtrl.text) ?? 10,
                      subCount: int.tryParse(countCtrl.text) ?? 5,
                      isPerformanceTask: isPerformance,
                    );
                    if (isExam) {
                      if (index != null) {
                        _tempConfig.exams[index] = newItem;
                      } else {
                        _tempConfig.exams.add(newItem);
                      }
                    } else {
                      if (index != null) {
                        _tempConfig.items[index] = newItem;
                      } else {
                        _tempConfig.items.add(newItem);
                      }
                    }
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _addNewTagDialog(BuildContext context) async {
    TextEditingController txt = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تصنيف جديد'),
        content: TextField(controller: txt),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, txt.text.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _deleteItem(bool isExam, int index) {
    setState(() {
      if (isExam) {
        _tempConfig.exams.removeAt(index);
      } else {
        _tempConfig.items.removeAt(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 600,
        child: Column(
          children: [
            const Text(
              'إعدادات الدرجات',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildSectionHeader(
                      'المهام',
                      () => _openItemDialog(isExam: false),
                    ),
                    ..._tempConfig.items.asMap().entries.map(
                      (e) => ListTile(
                        title: Text(e.value.name),
                        subtitle: Text('${e.value.maxScore} درجة'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _openItemDialog(
                                isExam: false,
                                index: e.key,
                                existingItem: e.value,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteItem(false, e.key),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(),
                    _buildSectionHeader(
                      'الاختبارات',
                      () => _openItemDialog(isExam: true),
                    ),
                    ..._tempConfig.exams.asMap().entries.map(
                      (e) => ListTile(
                        title: Text(e.value.name),
                        subtitle: Text('${e.value.maxScore} درجة'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _openItemDialog(
                                isExam: true,
                                index: e.key,
                                existingItem: e.value,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteItem(true, e.key),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                widget.onSave(_tempConfig);
                Navigator.pop(context);
              },
              child: const Text('حفظ الإعدادات'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onAdd) {
    return Container(
      color: Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.blue),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class ArabicToEnglishNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    String newText = newValue.text
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9');
    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
