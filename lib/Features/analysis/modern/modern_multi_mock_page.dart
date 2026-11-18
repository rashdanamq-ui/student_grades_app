import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_grades_app/core/settings/app_settings.dart';

// استيراد الموديلات والخدمات
import '../../../models/student.dart';
import '../../../models/mock_student.dart';
import '../../../core/grading_levels/level_settings_service.dart';
import '../../../core/utils/number_utils.dart';
import '../models/analysis_view_models.dart';
import '../services/analysis_calculator.dart';
import '../widgets/analysis_print_dialog.dart';
import '../widgets/level_settings_dialog.dart';

// تحليل مهارة شامل
// تمديد لحفظ البيانات المؤقتة (الدرجة + اسم الفصل الأصلي)

// كلاس مساعد لتخزين بيانات الفصل المحملة
class _LoadedMockData {
  final String title;
  final List<String> columnTitles;
  final List<double> columnMaxScores;
  final List<MockStudent> students;

  _LoadedMockData({
    required this.title,
    required this.columnTitles,
    required this.columnMaxScores,
    required this.students,
  });
}

class ModernMultiMockPage extends StatefulWidget {
  final List<String> classIds;
  final List<String> classTitles;

  const ModernMultiMockPage({
    super.key,
    required this.classIds,
    required this.classTitles,
  });

  @override
  State<ModernMultiMockPage> createState() => _ModernMultiMockPageState();
}

class _ModernMultiMockPageState extends State<ModernMultiMockPage> {
  // === ثوابت ===
  static const String _sumOption = 'المجموع الكلي';

  // === البيانات ===
  final Map<String, _LoadedMockData> _classDataMap = {};
  List<Student> _validStudentsForDisplay = [];

  // === إعدادات التحليل ===
  List<LevelConfigV2> _activeLevels = [];
  AnalysisStatsV2? _stats;

  // === حالة الواجهة ===
  bool _isLoading = true;
  String _selectedSkillTitle = ''; // عنوان العمود المختار
  List<String> _availableSkills = []; // كل العناوين الموجودة في كل الفصول

  // === حالة الخطأ ===
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ---------------------------------------------------------
  // 1️⃣ منطق الترتيب (جديد)
  // ---------------------------------------------------------
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

  // دالة ترتيب محلية للتعامل مع نوع Student
  List<Student> _sortLocalList(List<Student> list) {
    final sorted = List<Student>.from(list);
    switch (_currentSortMode) {
      case StudentSortMode.byScore:
        sorted.sort((a, b) => (b.tempScore ?? 0).compareTo(a.tempScore ?? 0));
        break;
      case StudentSortMode.byClass:
        // هنا يمكنك استخدام a.originalClassTitle إذا قمت بحفظ اسم الفصل فيها
        // أو استخدام الاسم كبديل مؤقت
        sorted.sort((a, b) => a.name.compareTo(b.name));
        break;
      case StudentSortMode.byName:
        sorted.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
    return sorted;
  }

  // 1. تحميل البيانات من الذاكرة
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    // أ) تحميل المستويات
    final levelSettings = await LevelSettingsService.load();
    _activeLevels = levelSettings.levels
      ..sort((a, b) => b.minPercent.compareTo(a.minPercent));

    Set<String> allTitlesFound = {};

    // ب) تحميل بيانات كل اختبار محاكي
    for (int i = 0; i < widget.classIds.length; i++) {
      String id = widget.classIds[i];
      String title = widget.classTitles[i];

      // تحميل الميتاداتا (العناوين والدرجات)
      final metaKey = 'mock_exam_${id}_v1_meta';
      final metaStr = prefs.getString(metaKey);

      List<String> colTitles = [];
      List<double> colMax = [];

      if (metaStr != null) {
        try {
          final meta = jsonDecode(metaStr);
          if (meta['titles'] != null) {
            colTitles = List<String>.from(
              meta['titles'].map((e) => e.toString().trim()),
            );
          }
          if (meta['max_scores'] != null) {
            colMax = List<double>.from(
              meta['max_scores'].map(
                (e) => double.tryParse(e.toString()) ?? 20.0,
              ),
            );
          }
        } catch (_) {}
      }

      // تعبئة العناوين الفارغة بأسماء افتراضية
      int count = max(colTitles.length, 8);
      if (colTitles.length < count) {
        for (int k = colTitles.length; k < count; k++) colTitles.add('');
      }
      if (colMax.length < count) {
        for (int k = colMax.length; k < count; k++) colMax.add(20.0);
      }

      // إضافة العناوين غير الفارغة للقائمة العامة
      for (var t in colTitles) {
        if (t.isNotEmpty) allTitlesFound.add(t);
      }

      // تحميل الطلاب
      List<MockStudent> students = [];
      final storageKey = 'mock_exam_${id}_v1';
      final str = prefs.getString(storageKey);
      if (str != null) {
        final List decoded = jsonDecode(str);
        students = decoded
            .map((e) => MockStudent.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }

      // حفظ البيانات
      _classDataMap[id] = _LoadedMockData(
        title: title,
        columnTitles: colTitles,
        columnMaxScores: colMax,
        students: students,
      );
    }

    // ترتيب المهارات
    final sortedSkills = allTitlesFound.toList()..sort();

    // إضافة خيار المجموع الكلي إذا كان هناك مهارات
    if (sortedSkills.isNotEmpty) {
      _availableSkills = [_sumOption, ...sortedSkills];
    } else {
      _availableSkills = [];
    }

    // اختيار أول مهارة تلقائياً (المجموع الكلي سيكون الأول)
    if (_availableSkills.isNotEmpty) {
      _selectedSkillTitle = _availableSkills.first;
      _validateAndCalculate();
    } else {
      _errorMessage =
          "لم يتم العثور على مهارات/عناوين أعمدة في الفصول المختارة.";
    }

    setState(() => _isLoading = false);
  }

  // 2. المحرك: المطابقة، التحقق، والحساب
  void _validateAndCalculate() {
    _errorMessage = null;
    _validStudentsForDisplay = [];
    _stats = null;

    if (_selectedSkillTitle.isEmpty) return;

    double? referenceMaxScore;
    List<Student> aggregatedStudents = [];
    List<double> scoresList = [];

    // --- حالة خاصة: المجموع الكلي ---
    final isTotalSumMode = _selectedSkillTitle == _sumOption;

    // --- الخطوة 1: الفحص وجمع البيانات ---
    for (int i = 0; i < widget.classIds.length; i++) {
      String id = widget.classIds[i];
      _LoadedMockData data = _classDataMap[id]!;

      // حساب الدرجة العظمى لهذا الاختبار
      double currentMax = 0.0;
      if (isTotalSumMode) {
        // جمع كل الدرجات العظمى للأعمدة المسماة فقط
        for (int c = 0; c < data.columnTitles.length; c++) {
          if (data.columnTitles[c].isNotEmpty &&
              c < data.columnMaxScores.length) {
            currentMax += data.columnMaxScores[c];
          }
        }
      } else {
        // البحث عن العمود
        int colIndex = data.columnTitles.indexOf(_selectedSkillTitle);
        if (colIndex == -1) {
          setState(() {
            _errorMessage =
                'المهارة "$_selectedSkillTitle" غير موجودة في (${data.title}).\nيرجى التأكد من تطابق الأسماء.';
          });
          return;
        }
        currentMax = data.columnMaxScores.length > colIndex
            ? data.columnMaxScores[colIndex]
            : 20.0;
      }

      // التحقق من توافق الدرجات العظمى
      if (referenceMaxScore == null) {
        referenceMaxScore = currentMax;
      } else if ((referenceMaxScore - currentMax).abs() > 0.1) {
        // سماحية بسيطة للأرقام العشرية
        setState(() {
          if (isTotalSumMode) {
            _errorMessage =
                'لا يمكن حساب المجموع الكلي لاختلاف مجموع الدرجات العظمى.\n\n'
                'في (${data.title}): $currentMax\n'
                'في الفصول الأخرى: $referenceMaxScore';
          } else {
            _errorMessage =
                'لا يمكن المقارنة لاختلاف الدرجة العظمى للمهارة "$_selectedSkillTitle".\n\n'
                'في (${data.title}): $currentMax\n'
                'في الفصول الأخرى: $referenceMaxScore';
          }
        });
        return;
      }

      // ج) استخراج الطلاب ودرجاتهم
      for (var ms in data.students) {
        double score = 0.0;

        if (isTotalSumMode) {
          // جمع درجات الطالب لكل الأعمدة التي لها عناوين
          for (int c = 0; c < ms.exams.length; c++) {
            // نجمع فقط إذا كان العمود له عنوان في هذا الاختبار (تجنب الأعمدة الفارغة)
            if (c < data.columnTitles.length &&
                data.columnTitles[c].isNotEmpty) {
              score += ms.exams[c] ?? 0.0;
            }
          }
        } else {
          // درجة عمود محدد
          int colIndex = data.columnTitles.indexOf(_selectedSkillTitle);
          if (ms.exams.length > colIndex) {
            score = ms.exams[colIndex] ?? 0.0;
          }
        }

        final displayS = Student(name: ms.name);
        displayS.tempScore = score;
        displayS.className = data.title; // إضافة اسم الفصل للعرض

        aggregatedStudents.add(displayS);
        scoresList.add(score);
      }
    }

    if (referenceMaxScore == null || referenceMaxScore == 0)
      referenceMaxScore = 100;

    // --- الخطوة 2: الحساب ---
    scoresList.sort();

    final Map<String, int> counts = {for (var l in _activeLevels) l.label: 0};
    for (var s in scoresList) {
      final lvl = AnalysisCalculator.getLevelForScore(
        score: s,
        maxScore: referenceMaxScore,
        useSum: true,
        selectedTag: 'Mock',
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
                'تحليل مهارة مجمع (محاكي)',
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
                        initialClassTitle: _selectedSkillTitle,
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
                        const SizedBox(height: 16),

                        if (_errorMessage != null)
                          _buildErrorState()
                        else if (_stats != null) ...[
                          /*Text(
                        'مقارنة المهارة عبر ${widget.classIds.length} فصول',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 5),*/
                          _buildStatsCards(),
                          const SizedBox(height: 1),
                          _buildGridTablesLayout(),
                          const SizedBox(height: 5),
                          _buildBottomChartsOnly(),
                        ],

                        const SizedBox(height: 2),
                        // 2. استخدام الترحيل (Translation) لرفع الرسوم للأعلى
                        Transform.translate(
                          offset: const Offset(
                            0,
                            -80,
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

  Widget _buildFilterBar() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      // تقليل الحشوة الرأسية لتصغير حجم الصندوق (vertical: 8)
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6F3),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // السطر العلوي: نستخدم Stack لضمان التوسط الدقيق
          SizedBox(
            height: 25, // ارتفاع محدد للسطر العلوي
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. التعليمات: تظهر في منتصف الشريط تماماً
                const Text(
                  'اختر المهارة لمقارنتها بين الفصول',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF2E7D6F),
                  ),
                ),

                // 2. معلومات الفصول: تظهر من جهة اليمين
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'مقارنة المهارة عبر : ${widget.classIds.length} فصول',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // مسافة صغيرة جداً بين النصوص والأزرار
          const SizedBox(height: 5),

          _availableSkills.isEmpty
              ? const Text(
                  "لا توجد مهارات مشتركة",
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _availableSkills.map((title) {
                      final isSelected = _selectedSkillTitle == title;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(
                            title,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF2E7D6F),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF1FAF8E),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: const Color(0xFF1FAF8E).withOpacity(0.3),
                            ),
                          ),
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _selectedSkillTitle = title;
                                _validateAndCalculate();
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
        ],
      ),
    );
  }
  // --- (الويدجتات المعاد استخدامها - نفس التصميم) ---

  Widget _buildStatsCards() {
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
          // ✅ 2. الكرت الجديد: مجموع درجات المهارة
          _StatCardLarge(
            icon: Icons.functions,
            title:
                'مجموع ($_selectedSkillTitle)', // يظهر اسم المهارة (مثلاً: مجموع (إملاء))
            value: formatNumberForDisplay(_stats!.sum),
            color: const Color(0xFF9C27B0), // لون بنفسجي
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
      showClassName: true, // ✅ إظهار اسم الفصل
    );
  }

  // ✅ الدالة المفقودة لجلب الطلاب لكل مستوى
  List<Student> _getStudentsForLevel(String levelLabel) {
    // 1. تصفية القائمة _validStudentsForDisplay
    final filteredList = _validStudentsForDisplay.where((s) {
      final lvl = AnalysisCalculator.getLevelForScore(
        score: s.tempScore ?? 0,
        maxScore: _stats?.maxScore ?? 100,
        useSum: true,
        selectedTag: 'Comprehensive', // أو حسب المتغير لديك
        activeLevels: _activeLevels,
      );
      return lvl == levelLabel;
    }).toList();

    // 2. تطبيق الترتيب
    return _sortLocalList(filteredList);
  }

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
              range.toAppNum(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              count.toAppNum(),
              textAlign: TextAlign.center,
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
                      children: List.generate(
                        6,
                        (index) => SizedBox(
                          height: 20,
                          child: Text(
                            '${(axisMax * (1 - index / 5)).toInt()}',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            6,
                            (index) => Container(
                              height: 20,
                              alignment: Alignment.center,
                              child: Divider(
                                color: Colors.grey[200],
                                thickness: 1,
                              ),
                            ),
                          ),
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
                                      fontSize: 12,
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
                                      fontSize: 10,
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
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'الإتقان',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
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
      width: 150,
      height: 140,
      child: Card(
        elevation: 1.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
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
                  fontSize: 14,
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
                            textAlign: TextAlign.center,
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
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
                                          style: const TextStyle(fontSize: 11),
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
                                              fontSize: 10,
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
