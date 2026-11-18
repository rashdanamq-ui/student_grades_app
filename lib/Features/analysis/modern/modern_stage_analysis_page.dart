import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_grades_app/core/settings/app_settings.dart';
import 'package:student_grades_app/models/mock_student.dart';

// استيراد الموديلات والخدمات
import '../../../models/student.dart';
import '../../../core/config/class_grading_config.dart';
import '../../../core/grading_levels/level_settings_service.dart';
import '../../../core/utils/number_utils.dart';
import '../models/analysis_view_models.dart';
import '../services/analysis_calculator.dart';
import '../widgets/analysis_print_dialog.dart';
import '../widgets/level_settings_dialog.dart';

// صفحة مرحلة
// تمديد لحفظ البيانات المؤقتة

class ModernStageAnalysisPage extends StatefulWidget {
  final List<String> classIds;
  final List<String> classTitles;

  const ModernStageAnalysisPage({
    super.key,
    required this.classIds,
    required this.classTitles,
  });

  @override
  State<ModernStageAnalysisPage> createState() =>
      _ModernStageAnalysisPageState();
}

class _ModernStageAnalysisPageState extends State<ModernStageAnalysisPage> {
  // === البيانات ===
  final Map<String, ClassGradingConfig> _loadedConfigs =
      {}; // الاحتفاظ بالإعدادات
  final Map<String, List<Student>> _loadedStudents = {}; // الاحتفاظ بالطلاب
  final Map<String, Map<String, dynamic>> _loadedScores =
      {}; // الاحتفاظ بالدرجات

  List<Student> _validStudentsForDisplay = []; // القائمة النهائية للعرض

  // === إعدادات التحليل ===
  List<LevelConfigV2> _activeLevels = [];
  AnalysisStatsV2? _stats;

  // === حالة الواجهة ===
  bool _isLoading = true;
  String _selectedTag = 'Comprehensive';
  List<String> _availableTags = [];

  // === حالة الخطأ ===
  String? _errorMessage; // لعرض رسالة في وسط الشاشة عند عدم التطابق

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ---------------------------------------------------------------------------
  StudentSortMode _currentSortMode = StudentSortMode.byScore;

  void _cycleSortMode() {
    setState(() {
      if (_currentSortMode == StudentSortMode.byScore) {
        _currentSortMode = StudentSortMode.byClass;
      } else if (_currentSortMode == StudentSortMode.byClass) {
        _currentSortMode = StudentSortMode.byName;
      } else {
        _currentSortMode = StudentSortMode.byScore;
      }
    });
  }

  Widget _buildSortIcon() {
    IconData icon = Icons.sort;
    String tooltip = '';
    Color color = const Color(0xFF2E7D6F);

    switch (_currentSortMode) {
      case StudentSortMode.byScore:
        icon = Icons.format_list_numbered_rtl;
        tooltip = 'الترتيب: حسب الدرجة';
        break;
      case StudentSortMode.byClass:
        icon = Icons.grid_view;
        tooltip = 'الترتيب: حسب الصف';
        break;
      case StudentSortMode.byName:
        icon = Icons.sort_by_alpha;
        tooltip = 'الترتيب: حسب الاسم';
        break;
    }

    return IconButton(
      icon: Icon(icon, color: color),
      tooltip: tooltip,
      onPressed: _cycleSortMode,
    );
  }

  // دالة ترتيب محلية للنوع Student
  List<Student> _sortLocalList(List<Student> list) {
    final sorted = List<Student>.from(list);
    switch (_currentSortMode) {
      case StudentSortMode.byScore:
        sorted.sort((a, b) => (b.tempScore ?? 0).compareTo(a.tempScore ?? 0));
        break;
      case StudentSortMode.byClass:
        // هنا يمكن الترتيب حسب اسم الفصل إذا كنت تخزنه، أو حسب الاسم كبديل
        sorted.sort((a, b) => a.name.compareTo(b.name));
        break;
      case StudentSortMode.byName:
        sorted.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
    return sorted;
  }

  // 1. تحميل البيانات الأولية (مرة واحدة)
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    // أ) تحميل المستويات
    final levelSettings = await LevelSettingsService.load();
    _activeLevels = levelSettings.levels
      ..sort((a, b) => b.minPercent.compareTo(a.minPercent));

    Set<String> collectedTags = {};

    // ب) تحميل بيانات كل فصل وحفظها في الذاكرة
    for (int i = 0; i < widget.classIds.length; i++) {
      String id = widget.classIds[i];
      String title = widget.classTitles[i];

      // 1. Config
      ClassGradingConfig config = await ClassGradingConfig.load(id);
      _loadedConfigs[id] = config;

      // جمع التاقات للعرض في الشريط
      for (var item in config.items) collectedTags.add(item.tag);
      for (var item in config.exams) collectedTags.add(item.tag);

      // 2. Students
      final studentsJson = prefs.getString('class_students_$id');
      if (studentsJson != null) {
        final List list = jsonDecode(studentsJson);
        List<Student> classStudents = list
            .map((e) => Student.fromJson(e))
            .toList();

        // ربط الطالب باسم فصله
        for (var s in classStudents) {
          s.className = title;
          // تحميل درجاته
          final sKey = 'student_detail_${s.name}_$id';
          final sStr = prefs.getString(sKey);
          if (sStr != null) {
            // نخزن الدرجات بمفتاح فريد (اسم الطالب + الايدي) لتجنب التشابه
            _loadedScores['${s.name}_$id'] = jsonDecode(sStr);
          }
        }
        _loadedStudents[id] = classStudents;
      }
    }

    _availableTags = [
      'Comprehensive',
      ...collectedTags.where((t) => t.trim().isNotEmpty),
    ];

    // ج) إجراء التحقق والحساب الأولي
    _validateAndCalculate();

    setState(() => _isLoading = false);
  }

  // 2. المحرك: التحقق الصارم ثم الحساب
  void _validateAndCalculate() {
    _errorMessage = null;
    _validStudentsForDisplay = [];
    _stats = null;

    double? referenceMaxScore; // الدرجة المرجعية للمقارنة

    // --- الخطوة 1: التحقق من الفصول (Validation) ---
    for (int i = 0; i < widget.classIds.length; i++) {
      String id = widget.classIds[i];
      String title = widget.classTitles[i];
      ClassGradingConfig config = _loadedConfigs[id]!;

      double classMaxForTag = 0.0;
      bool tagFound = false;

      // حساب الدرجة العظمى للتاق في هذا الفصل
      if (_selectedTag == 'Comprehensive') {
        classMaxForTag = config.getTotalMaxScore();
        tagFound = true; // المجموع دائما موجود
      } else {
        final allCols = [...config.items, ...config.exams];
        for (var col in allCols) {
          if (col.tag == _selectedTag) {
            classMaxForTag += col.maxScore;
            tagFound = true;
          }
        }
      }

      // أ) التحقق من وجود التاق
      if (!tagFound) {
        setState(() {
          _errorMessage =
              'لا يمكن المقارنة لعدم وجود "$_selectedTag" في فصل ($title)';
        });
        return;
      }

      // ب) التحقق من تطابق الدرجة
      if (referenceMaxScore == null) {
        referenceMaxScore = classMaxForTag; // نعتمد درجة أول فصل كمرجع
      } else {
        if (classMaxForTag != referenceMaxScore) {
          setState(() {
            _errorMessage =
                'الدرجة غير قابلة للقياس لاختلاف الدرجة العظمى في "$_selectedTag".\n\n'
                '($title: $classMaxForTag) \n'
                'بينما الفصول الأخرى: $referenceMaxScore';
          });
          return;
        }
      }
    }

    // إذا وصلنا هنا، يعني أن جميع الفصول تحتوي التاق ولها نفس الدرجة العظمى
    if (referenceMaxScore == null || referenceMaxScore == 0)
      referenceMaxScore = 100; // احتياط

    // --- الخطوة 2: تجميع الدرجات (Calculation) ---
    List<Student> aggregatedStudents = [];
    List<double> scoresList = [];

    for (int i = 0; i < widget.classIds.length; i++) {
      String id = widget.classIds[i];
      ClassGradingConfig config = _loadedConfigs[id]!;
      List<Student>? students = _loadedStudents[id];

      if (students == null) continue;

      for (var s in students) {
        Map<String, dynamic> scores = _loadedScores['${s.name}_$id'] ?? {};
        double studentTotal = 0.0;

        final allCols = [...config.items, ...config.exams];

        if (_selectedTag == 'Comprehensive') {
          // جمع كل شيء
          for (var col in allCols) {
            studentTotal += _extractScore(col, scores);
          }
        } else {
          // جمع الأعمدة التابعة للتاق فقط
          for (var col in allCols) {
            if (col.tag == _selectedTag) {
              studentTotal += _extractScore(col, scores);
            }
          }
        }

        s.tempScore = studentTotal;
        scoresList.add(studentTotal);
        aggregatedStudents.add(s);
      }
    }

    scoresList.sort();

    // حساب التوزيع (المستويات)
    final Map<String, int> counts = {for (var l in _activeLevels) l.label: 0};
    for (var s in scoresList) {
      final lvl = AnalysisCalculator.getLevelForScore(
        score: s,
        maxScore: referenceMaxScore,
        useSum: true,
        selectedTag: _selectedTag,
        activeLevels: _activeLevels,
      );
      counts[lvl] = (counts[lvl] ?? 0) + 1;
    }

    double sum = scoresList.fold(0, (a, b) => a + b);

    _validStudentsForDisplay = aggregatedStudents;

    _stats = AnalysisStatsV2(
      maxScore: referenceMaxScore,
      totalStudents: _validStudentsForDisplay.length,
      activeStudents: scoresList.length,
      highest: scoresList.isEmpty ? 0 : scoresList.last,
      lowest: scoresList.isEmpty ? 0 : scoresList.first,
      average: scoresList.isEmpty ? 0 : sum / scoresList.length,
      sum: sum,
      achievementPercent:
          (sum / (_validStudentsForDisplay.length * referenceMaxScore)) * 100,
      levelCounts: counts,
      levelLabels: _activeLevels.map((e) => e.label).toList(),
    );
  }

  // ✅ دالة محسنة لاستخراج الدرجة الحقيقية في تحليل المرحلة
  double _extractScore(GradeColumn col, Map<String, dynamic> scores) {
    final val = scores[col.id];
    if (val == null) return 0.0;

    // 1. إذا كان العمود "رقمي عادي"
    if (col.type == GradeType.numeric) {
      return double.tryParse(val.toString().toEnglishNum()) ?? 0.0;
    }
    // 2. إذا كان العمود "مربعات اختيار" (صح/خطأ)
    else if (col.type == GradeType.checkbox) {
      int checkedCount = int.tryParse(val.toString().toEnglishNum()) ?? 0;
      if (col.subCount == 0) return 0.0;
      // المعادلة: عدد الصحوح * (الدرجة الكلية للعمود / عدد المربعات)
      return checkedCount * (col.maxScore / col.subCount);
    }
    // 3. إذا كان العمود "قائمة أرقام" (مثل القراءة، الإملاء، اختبارات الفترة)
    else if (col.type == GradeType.numericList) {
      if (val is List && val.isNotEmpty) {
        double sum = 0.0;
        int validEntries = 0;
        for (var v in val) {
          // تحويل القيمة مع دعم الأرقام العربية
          double? d = double.tryParse(v.toString().toEnglishNum());
          if (d != null) {
            sum += d;
            validEntries++;
          }
        }
        // ✅ التعديل الجذري: نرجع المتوسط (مثلاً 20 تقسيم 5 مربعات يعطي 4)
        return validEntries > 0 ? sum / validEntries : 0.0;
      }
      return 0.0;
    }
    // 4. إذا كان العمود "متوسط اختبارين"
    else if (col.type == GradeType.averagePair) {
      if (val is List && val.length >= 2) {
        double v1 = double.tryParse(val[0].toString().toEnglishNum()) ?? 0.0;
        double v2 = double.tryParse(val[1].toString().toEnglishNum()) ?? 0.0;
        return (v1 + v2) / 2.0;
      }
      return 0.0;
    }

    return double.tryParse(val.toString().toEnglishNum()) ?? 0.0;
  }

  // ✅ الدالة المحدثة: ترتيب حسب الدرجة (تنازلي) ثم الاسم (أبجدي)
  List<Student> _getStudentsForLevel(String levelLabel) {
    // 1. التصفية من القائمة النهائية _validStudentsForDisplay
    final filteredList = _validStudentsForDisplay.where((s) {
      final lvl = AnalysisCalculator.getLevelForScore(
        score: s.tempScore ?? 0,
        maxScore: _stats?.maxScore ?? 100,
        useSum: true,
        selectedTag: _selectedTag,
        activeLevels: _activeLevels,
      );
      return lvl == levelLabel;
    }).toList();

    // 2. الترتيب
    return _sortLocalList(filteredList);
  }

  @override
  Widget build(BuildContext context) {
    // نستخدم ValueListenableBuilder في البداية للاستماع لتغير لغة الأرقام
    return ValueListenableBuilder<bool>(
      valueListenable: AppSettings.useArabicNumbers,
      builder: (context, isArabic, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: const Color(0xFFF6F7F8),
            appBar: AppBar(
              centerTitle: true,
              title: const Text(
                'تحليل مجمع (مرحلة)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D6F),
                ),
              ),
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Color(0xFF2E7D6F)),
              actions: [
                _buildSortIcon(),

                IconButton(
                  icon: const Icon(Icons.print),
                  onPressed: () {
                    if (_stats == null) return;
                    showDialog(
                      context: context,
                      builder: (_) => AnalysisPrintDialog(
                        initialClassTitle: _selectedTag == 'Comprehensive'
                            ? 'المرحلة'
                            : _selectedTag,
                        stats: _stats!,
                        activeLevels: _activeLevels,
                        students: _validStudentsForDisplay,
                        getStudentsForLevel: (label) =>
                            _getStudentsForLevel(label),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: () async {
                    final changed = await showDialog<bool>(
                      context: context,
                      builder: (_) => LevelSettingsDialog(
                        maxScore: _stats?.maxScore ?? 100,
                      ),
                    );
                    if (changed == true) {
                      final levelSettings = await LevelSettingsService.load();
                      setState(() {
                        _activeLevels = levelSettings.levels
                          ..sort(
                            (a, b) => b.minPercent.compareTo(a.minPercent),
                          );
                        _validateAndCalculate();
                      });
                    }
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
                        _buildFilterBar(),
                        const SizedBox(height: 10),

                        // === منطقة العرض الرئيسية ===
                        if (_errorMessage != null)
                          _buildErrorState()
                        else if (_stats != null) ...[
                          /*Text(
                        'تم دمج ${widget.classIds.length} فصول: ${widget.classTitles.join("، ")}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 5),*/
                          _buildStatsCards(),
                          const SizedBox(height: 0),
                          _buildGridTablesLayout(),
                          const SizedBox(height: 0),
                          _buildBottomChartsOnly(),
                        ],

                        const SizedBox(height: 0),
                        // 2. استخدام الترحيل (Translation) لرفع الرسوم للأعلى
                        Transform.translate(
                          offset: const Offset(
                            0,
                            -90,
                          ), // 👈 الرقم بالسالب يرفع العناصر للأعلى. جرب -40 أو -50 حسب حاجتك
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  // واجهة عرض الخطأ
  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 40),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- (نفس الويدجتات المستخدمة سابقاً) ---
  // يمكن نسخها من ملف modern_class_analysis_page.dart لتجنب التكرار في الرسالة
  // سأضع الأساسيات هنا فقط
  Widget _buildFilterBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6F3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start, // جعل العناصر تبدأ من اليمين (في وضع RTL)
        children: [
          const Text(
            'اختر البيانات المراد تحليلها (موحد للجميع)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF2E7D6F),
            ),
          ),

          const SizedBox(height: 0),

          // ✅ تم تغليف النص بـ Align ليكون جهة اليمين ✅
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'تم دمج ${widget.classIds.length} فصول: ${widget.classTitles.join("، ")}',
              style: TextStyle(
                color: const Color(0xFF2E7D6F).withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 0),

          // لجعل الأزرار (Chips) تبقى في المنتصف، سنغلف الـ Wrap بـ Center
          Center(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _availableTags.map((tag) {
                final isSelected = _selectedTag == tag;
                String label = tag == 'Comprehensive' ? 'المجموع الكلي' : tag;
                return ChoiceChip(
                  label: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF2E7D6F),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF1FAF8E),
                  backgroundColor: Colors.white,
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _selectedTag = tag;
                        _validateAndCalculate();
                      });
                    }
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ... (بقية الويدجتات: _buildStatsCards, _buildGridTablesLayout, _buildBottomChartsOnly)
  // هي نفسها الموجودة في modern_class_analysis_page.dart
  // قم بنسخها هنا، مع التأكد من تفعيل showClassName: true في _LevelStudentsCard

  Widget _buildStatsCards() {
    // تحديد عنوان الكرت بناءً على التاق المختار
    String sumTitle = _selectedTag == 'Comprehensive'
        ? 'مجموع الدرجات'
        : 'مجموع ($_selectedTag)';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        children: [
          _StatCardLarge(
            icon: Icons.groups,
            title: 'إجمالي الطلاب',
            value: '${_stats!.totalStudents}'.toAppNum(),
            color: const Color(0xFF2EAD8B),
          ),
          _StatCardLarge(
            icon: Icons.emoji_events,
            title: 'أعلى درجة',
            value: formatNumberForDisplay(_stats!.highest),
            color: const Color(0xFFFFA726),
          ),
          _StatCardLarge(
            icon: Icons.arrow_downward,
            title: 'أقل درجة',
            value: formatNumberForDisplay(_stats!.lowest),
            color: const Color(0xFFEF5350),
          ),
          _StatCardLarge(
            icon: Icons.bar_chart,
            title: 'المتوسط',
            value: formatNumberForDisplay(_stats!.average),
            color: const Color(0xFF42A5F5),
          ),

          _StatCardLarge(
            icon: Icons.check_circle,
            title: 'نسبة الإتقان',
            value: '${formatNumberForDisplay(_stats!.achievementPercent)}%',
            color: const Color(0xFF66BB6A),
          ),

          // ✅ 2. الكرت الجديد: مجموع الدرجات المحصلة (حسب التاق)
          _StatCardLarge(
            icon: Icons.functions, // أيقونة المجموع (سيجما)
            title: sumTitle,
            // إزالة .0 إذا كان الرقم صحيحاً
            value: formatNumberForDisplay(_stats!.sum),
            color: const Color(0xFF9C27B0), // لون بنفسجي مميز
          ),

          _StatCardLarge(
            icon: Icons.straighten,
            title: 'الدرجة العظمى',
            value: formatNumberForDisplay(_stats!.maxScore),
            color: const Color(0xFF7E57C2),
          ),
        ],
      ),
    );
  }

  Widget _buildGridTablesLayout() {
    const double topRowHeight = 280;
    const double bottomRowHeight = 380;
    const double smallTableHeight =
        300; // 👈 الارتفاع الجديد المصغر للمقبول والضعيف
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildLevelCardSafe(
                0,
                topRowHeight,
                const Color(0xFF00C853),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildLevelCardSafe(
                1,
                topRowHeight,
                const Color(0xFF2979FF),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildLevelCardSafe(
                2,
                topRowHeight,
                const Color(0xFF7E57C2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start, // المحاذاة من الأعلى
          children: [
            // جدول مقبول - تم تصغير الارتفاع
            Expanded(
              child: _buildLevelCardSafe(
                3,
                smallTableHeight,
                const Color(0xFFFFA726),
              ),
            ),

            const SizedBox(width: 16),

            // جدول ضعيف - تم تصغير الارتفاع
            Expanded(
              child: _buildLevelCardSafe(
                4,
                smallTableHeight,
                const Color(0xFFEF5350),
              ),
            ),

            const SizedBox(width: 16),

            // جدول النطاق - يبقى طويلاً لاستيعاب البيانات
            Expanded(
              child: _buildLevelsSummaryTableContent(height: bottomRowHeight),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLevelCardSafe(int index, double height, Color color) {
    if (index >= _activeLevels.length) return SizedBox(height: height);
    final lvl = _activeLevels[index];
    final studentsInLevel = _getStudentsForLevel(lvl.label);

    return _LevelStudentsCard(
      title: lvl.label,
      color: color,
      height: height,
      students: studentsInLevel,
      showClassName: true, // ✅ إظهار اسم الفصل هنا
    );
  }

  // ويدجت جدول النطاق
  Widget _buildLevelsSummaryTableContent({required double height}) {
    return SizedBox(
      height: height,
      child: Card(
        elevation: 1.5,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: const [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'المستوى',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'النطاق',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'العدد',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(thickness: 1, height: 1),
              const SizedBox(height: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(_activeLevels.length, (i) {
                    final lvl = _activeLevels[i];
                    final max = _stats!.maxScore;
                    final minP = lvl.minPercent;
                    final maxP = i == 0
                        ? 100.0
                        : _activeLevels[i - 1].minPercent - 0.01;

                    final rangeStart = (max * (minP / 100)).toStringAsFixed(0);
                    final rangeEnd = (max * (maxP / 100)).toStringAsFixed(0);
                    final count = _stats!.levelCounts[lvl.label] ?? 0;

                    final colors = [
                      const Color(0xFF2EAD8B),
                      const Color(0xFF2979FF),
                      const Color(0xFF7E57C2),
                      const Color(0xFFFFA726),
                      const Color(0xFFEF5350),
                    ];
                    final color = i < colors.length ? colors[i] : Colors.grey;

                    return _buildNitaqRow(
                      lvl.label,
                      '$rangeEnd - $rangeStart',
                      '$count',
                      color,
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNitaqRow(String title, String range, String count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              range.toAppNum(), // النطاق
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              count.toAppNum(),
              textAlign: TextAlign.center, //العددالنطاق
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomChartsOnly() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start, // محاذاة العناصر من الأعلى
      children: [
        // 1. الدائرة (تم تغليفها بـ Transform لرفعها)
        Expanded(
          flex: 2,
          child: Transform.translate(
            offset: const Offset(
              0,
              -50,
            ), // 👈 الرقم بالسالب يرفع الدائرة للأعلى. جرب -30 أو -50 حسب المساحة
            child: _buildAchievementDonut(),
          ),
        ),

        const SizedBox(width: 20),

        // 2. الأعمدة (تبقى في مكانها الطبيعي)
        Expanded(flex: 3, child: _buildDetailedVerticalBarChart()),
      ],
    );
  }

  Widget _buildDetailedVerticalBarChart() {
    final colors = [
      const Color(0xFF2EAD8B),
      const Color(0xFF5C6BC0),
      const Color(0xFF7E57C2),
      const Color(0xFFFFA726),
      const Color(0xFFEF5350),
    ];

    final List<Map<String, dynamic>> chartData = [];
    final reversedLevels = _activeLevels.reversed.toList();
    final reversedColors = colors.reversed.toList();

    for (int i = 0; i < reversedLevels.length; i++) {
      final lvl = reversedLevels[i];
      final count = _stats!.levelCounts[lvl.label] ?? 0;
      chartData.add({
        'label': lvl.label,
        'value': count,
        'color': i < reversedColors.length ? reversedColors[i] : Colors.grey,
      });
    }

    int maxVal = 0;
    for (var d in chartData)
      if ((d['value'] as int) > maxVal) maxVal = d['value'] as int;
    if (maxVal == 0) maxVal = 10;
    int axisMax = (maxVal * 1.2).ceil();
    int step = (axisMax / 5).ceil();
    if (step == 0) step = 1;

    return Card(
      elevation: 1.5,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SizedBox(
          height: 300,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double height = constraints.maxHeight;
              final double chartHeight = height - 30;
              final double yAxisWidth = 30;

              return Row(
                children: [
                  SizedBox(
                    width: yAxisWidth,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) {
                        return SizedBox(
                          height: 20,
                          child: Text(
                            '${(axisMax * (1 - index / 5)).toInt()}',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 10,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (index) {
                            return Container(
                              height: 20,
                              alignment: Alignment.center,
                              child: Divider(
                                color: Colors.grey[200],
                                thickness: 1,
                              ),
                            );
                          }),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: chartData.map((item) {
                              final int val = item['value'] as int;
                              final double percentage = val / axisMax;
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    '$val'.toAppNum(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize:
                                          20, // اعداد الاعمدة التي في الاعلى
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Container(
                                    width: 35,
                                    height: (chartHeight - 20) * percentage,
                                    decoration: BoxDecoration(
                                      color: item['color'] as Color,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(6),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item['label'] as String,
                                    style: const TextStyle(
                                      fontSize: 12, // خط المستوى للاعمدة
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementDonut() {
    final segments = <_DonutSegment>[];
    final colors = [
      const Color(0xFF2EAD8B), // ممتاز
      const Color(0xFF2979FF), // جيد جدا
      const Color(0xFF7E57C2), // جيد
      const Color(0xFFFFA726), // مقبول
      const Color(0xFFEF5350), // ضعيف
    ];

    double totalCount = _stats?.totalStudents.toDouble() ?? 1;
    if (totalCount == 0) totalCount = 1;

    // حساب نسب الطلاب (مجموعهم يجب أن يكون 100%)
    for (int i = 0; i < _activeLevels.length; i++) {
      final lvl = _activeLevels[i];
      final count = _stats?.levelCounts[lvl.label] ?? 0;
      if (count > 0) {
        segments.add(
          _DonutSegment(
            lvl.label,
            (count / totalCount) * 100, // نسبة الطلاب في هذا المستوى
            i < colors.length ? colors[i] : Colors.grey,
          ),
        );
      }
    }

    // نسبة الإتقان الكلية (التي ستحدد طول القوس الملون)
    double achievement = _stats?.achievementPercent ?? 0;

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'مستوى الإتقان لدى الطلاب',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(260, 260),
                    // ✅ نمرر نسبة الإتقان هنا
                    painter: _DonutPainter(segments, achievement),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${formatNumberForDisplay(achievement)}%', // ✅ يستخدم دالتك التي تبدل النقطة بفاصلة
                        style: const TextStyle(
                          fontSize: 40, //الدرجة الوسطى للاتقان في الدائرة
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'الإتقان',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // المفتاح (Legend)
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: segments
                  .map(
                    (e) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: e.color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // نعرض النسبة الخاصة بعدد الطلاب في هذا المستوى
                        Text(
                          '${e.label} (${e.percent.toStringAsFixed(0)}%)'
                              .toAppNum(),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCardLarge extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatCardLarge({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 140,
      child: Card(
        elevation: 1.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              Text(
                title, // الكروت العلياء للاتقان درجة القياس عدد الطلاب
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelStudentsCard extends StatelessWidget {
  final String title;
  final Color color;
  final double height;
  final List<Student> students;
  final bool showClassName;

  const _LevelStudentsCard({
    required this.title,
    required this.color,
    required this.height,
    required this.students,
    this.showClassName = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Card(
        elevation: 1.5,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              color: color,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14, // المستوى الداخلي للجداول
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          flex: 1,
                          child: Text(
                            '#',
                            textAlign: TextAlign.center, // الاسم الفصل المجموع
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ),
                        const Expanded(
                          flex: 3,
                          child: Text(
                            'الاسم',
                            textAlign: TextAlign.right,
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ),
                        if (showClassName)
                          const Expanded(
                            flex: 2,
                            child: Text(
                              'الفصل',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        const Expanded(
                          flex: 1,
                          child: Text(
                            'الدرجة',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Expanded(
                      child: students.isEmpty
                          ? Center(
                              child: Text(
                                'لا يوجد طلاب',
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                            )
                          : ListView.separated(
                              padding: EdgeInsets.zero,
                              itemCount: students.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                indent: 10,
                                endIndent: 10,
                              ),
                              itemBuilder: (context, index) {
                                final s = students[index];
                                return Padding(
                                  //داخل الجدول للمستوى اسم الطالب والفصل ودرجته
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 5,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          '${index + 1}'.toAppNum(),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          s.name,
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(fontSize: 14),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (showClassName)
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            s.className,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          formatNumberForDisplay(
                                            s.tempScore ?? 0.0,
                                          ), // ✅ هذا يظهر فاصلة عربية
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: color,
                                            fontWeight: FontWeight.bold,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutSegment {
  final String label;
  final double percent;
  final Color color;
  _DonutSegment(this.label, this.percent, this.color);
}

class _DonutPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final double achievementPercent;

  _DonutPainter(this.segments, this.achievementPercent);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 22;
    const double strokeWidth = 22;

    // 1. رسم الخلفية الرمادية (الدائرة كاملة)
    final bgPaint = Paint()
      ..color = const Color(0xFFEEEEEE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth - 6
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    double totalAvailableAngle = (achievementPercent / 100) * 2 * pi;
    double startAngle = -pi / 2;

    // 2. رسم الأقواس الملونة وكتابة النسب
    for (final segment in segments) {
      // إذا كانت نسبة المستوى صفر، لا نرسمه
      if (segment.percent <= 0) continue;

      double sweepAngle = (segment.percent / 100) * totalAvailableAngle;

      // القوس الخارجي (الإطار)
      final outerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 2
        ..strokeCap = StrokeCap.butt
        ..color = segment.color.withOpacity(0.85);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        outerPaint,
      );

      // القوس الداخلي (اللون الصلب)
      final innerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth - 6
        ..strokeCap = StrokeCap.round
        ..color = segment.color;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        innerPaint,
      );

      // ✅✅✅ رسم النسبة المئوية للمستوى (خارج الدائرة) ✅✅✅
      // نحسب زاوية المنتصف لهذا القوس
      final labelAngle = startAngle + sweepAngle / 2;

      // نحدد المسافة للخارج (radius + 35)
      final labelOffset = Offset(
        center.dx + (radius + 35) * cos(labelAngle),
        center.dy + (radius + 35) * sin(labelAngle),
      );

      // نسبة هذا المستوى من إجمالي الطلاب (وليس من الإتقان)
      // المعادلة: (نسبة الإتقان الكلية * نسبة هذا المستوى من الإتقان) / 100
      // ولكن للتبسيط ومطابقة الجدول، سنعرض النسبة المحسوبة مسبقاً في segment.percent
      // لأن segment.percent هي حصة هذا المستوى من إجمالي الطلاب (كما حسبناها في build)

      String labelText = '${segment.percent.toStringAsFixed(0)}%'.toAppNum();

      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: segment.color, // نفس لون المستوى
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      // رسم النص في المنتصف
      textPainter.paint(
        canvas,
        labelOffset - Offset(textPainter.width / 2, textPainter.height / 2),
      );

      startAngle += sweepAngle;
    }

    // 3. الظل الداخلي
    final innerShadowPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.transparent, Colors.black.withOpacity(0.1)],
        stops: const [5.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, innerShadowPaint);

    // ✅✅✅ 4. رسم نسبة "غير المتقن" (الجزء الرمادي) ✅✅✅
    double remainingPercent = 100.0 - achievementPercent;
    if (remainingPercent > 1) {
      // فقط إذا كانت النسبة تستحق الذكر
      // زاوية منتصف الجزء الرمادي
      // الجزء الرمادي يبدأ من حيث انتهت الألوان (startAngle) ويمتد لنهاية الدائرة
      // نهايته هي -pi/2 (أو 3pi/2). لنحسب منتصف المسافة المتبقية.

      double endAngle = 1.5 * pi; // 270 درجة (أعلى الدائرة مجدداً)
      double midGrayAngle = startAngle + (endAngle - startAngle) / 2;

      // إذا تجاوزت الدائرة، نضبط الزاوية
      if (midGrayAngle > 2 * pi) midGrayAngle -= 2 * pi;

      final grayLabelOffset = Offset(
        center.dx + (radius + 35) * cos(midGrayAngle),
        center.dy + (radius + 35) * sin(midGrayAngle),
      );

      final grayPainter = TextPainter(
        text: TextSpan(
          text: '${remainingPercent.toStringAsFixed(0)}%'.toAppNum(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey, // لون رمادي
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      grayPainter.paint(
        canvas,
        grayLabelOffset - Offset(grayPainter.width / 2, grayPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
