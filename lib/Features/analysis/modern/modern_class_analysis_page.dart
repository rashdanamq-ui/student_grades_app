// lib/features/analysis/modern/modern_class_analysis_page.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_grades_app/Features/analysis/modern/PeriodComparison_class_Page.dart';
import '../../../core/settings/app_settings.dart';
import '../../../models/student.dart'; // تأكد من المسار
import '../../../models/mock_student.dart'; // لاستخدام StudentSortMode ودالة الترتيب
import '../../../core/config/class_grading_config.dart';
import '../../../core/grading_levels/level_settings_service.dart';
import '../../../core/utils/number_utils.dart';
import '../models/analysis_view_models.dart';
import '../services/analysis_calculator.dart';
import '../widgets/analysis_print_dialog.dart';
import '../widgets/level_settings_dialog.dart';

// صفحة المقارنة (سننشئها لاحقاً، حالياً مجرد placeholder لتجنب الخطأ)
// import 'period_comparison_page.dart';

class ModernClassAnalysisPage extends StatefulWidget {
  final String classId;
  final String classTitle;

  const ModernClassAnalysisPage({
    super.key,
    required this.classId,
    required this.classTitle,
  });

  @override
  State<ModernClassAnalysisPage> createState() =>
      _ModernClassAnalysisPageState();
}

class _ModernClassAnalysisPageState extends State<ModernClassAnalysisPage> {
  // === البيانات ===
  ClassGradingConfig _config = ClassGradingConfig();
  List<Student> _students = [];
  final Map<String, Map<String, dynamic>> _allScores = {};

  // === إعدادات التحليل ===
  List<LevelConfigV2> _activeLevels = [];
  AnalysisStatsV2? _stats;

  // === حالة الواجهة ===
  bool _isLoading = true;
  String _selectedTag = 'Comprehensive';
  List<String> _availableTags = [];

  // === 1. متغير الفترة (جديد) ===
  // 1: الفترة الأولى، 2: الفترة الثانية، 0: المحصلة النهائية
  int _selectedPeriod = 1;

  // === متغيرات الترتيب ===
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    final levelSettings = await LevelSettingsService.load();
    _activeLevels = levelSettings.levels
      ..sort((a, b) => b.minPercent.compareTo(a.minPercent));

    _config = await ClassGradingConfig.load(widget.classId);

    final Set<String> tags = {};
    for (var item in _config.items) tags.add(item.tag);
    for (var item in _config.exams) tags.add(item.tag);
    _availableTags = [
      'Comprehensive',
      'PeriodTotal', // ✅ تاق المجموع الكلي لاختبار الفترة + المهام
      'PerformanceTasks', // ✅ تاق المهام الأدائية
      ...tags.where((t) => t.trim().isNotEmpty),
    ];

    final studentsJson = prefs.getString('class_students_${widget.classId}');
    if (studentsJson != null) {
      final List list = jsonDecode(studentsJson);
      _students = list.map((e) => Student.fromJson(e)).toList();
    }

    _allScores.clear();
    for (var s in _students) {
      s.className = widget.classTitle;
      final sKey = 'student_detail_${s.name}_${widget.classId}';
      final sStr = prefs.getString(sKey);
      if (sStr != null) _allScores[s.name] = jsonDecode(sStr);
    }

    _calculateStats();
    setState(() => _isLoading = false);
  }

  // === 2. دالة الحسابات (المحرك الرئيسي) ===
  void _calculateStats() {
    double calculatedMax = 0.0;

    // --- 1. حساب الدرجة العظمى ---
    if (_selectedTag == 'Comprehensive') {
      if (_selectedPeriod == 0) {
        // المحصلة: (معدل الأعمال + النهائي)
        double workMax = 0;
        double finalMax = 0;
        for (var item in [..._config.items, ..._config.exams]) {
          if (_isFinalExam(item))
            finalMax += item.maxScore;
          else
            workMax += item.maxScore;
        }
        calculatedMax = workMax + finalMax;
      } else {
        // فترة عادية
        for (var item in [..._config.items, ..._config.exams]) {
          if (_selectedPeriod == 1 && _isFinalExam(item)) continue;
          calculatedMax += item.maxScore;
        }
      }
    } else if (_selectedTag == 'PeriodTotal') {
      // ✅ المجموع الكلي (المهام + الاختبار) للفترة المحددة
      for (var item in [..._config.items, ..._config.exams]) {
        if (!_isFinalExam(item)) {
          calculatedMax += item.maxScore;
        }
      }
    } else if (_selectedTag == 'PerformanceTasks') {
      // ✅ المهام الأدائية للفترة المحددة استناداً لخيار "المهام الأدائية" (isPerformanceTask)
      for (var item in [..._config.items, ..._config.exams]) {
        if (item.isPerformanceTask) {
          calculatedMax += item.maxScore;
        }
      }
    } else {
      // تاق محدد ...
      for (var item in [..._config.items, ..._config.exams]) {
        if (item.tag == _selectedTag) {
          if (_selectedPeriod == 0) {
            if (_isFinalExam(item))
              calculatedMax += item.maxScore;
            else
              calculatedMax += item.maxScore;
          } else {
            if (_selectedPeriod == 1 && _isFinalExam(item)) continue;
            calculatedMax += item.maxScore;
          }
        }
      }
    }

    if (calculatedMax == 0) calculatedMax = 100;

    // --- 2. حساب درجات الطلاب ---
    String suffix = _selectedPeriod == 1
        ? '_p1'
        : (_selectedPeriod == 2 ? '_p2' : '');

    for (var s in _students) {
      double total = 0.0;
      final scores = _allScores[s.name];

      if (scores != null) {
        // ✅ 0. حالة المجموع الكلي للفترة (PeriodTotal)
        if (_selectedTag == 'PeriodTotal') {
          for (var col in [..._config.items, ..._config.exams]) {
            if (!_isFinalExam(col)) {
              if (_selectedPeriod == 1 || _selectedPeriod == 2) {
                total += _getRealScoreForColumn(
                  col,
                  scores['${col.id}$suffix'],
                );
              }
            }
          }
        }
        // ✅ 1. حالة المهام الأدائية فقط (PerformanceTasks)
        else if (_selectedTag == 'PerformanceTasks') {
          for (var col in [..._config.items, ..._config.exams]) {
            if (col.isPerformanceTask) {
              if (_selectedPeriod == 1 || _selectedPeriod == 2) {
                total += _getRealScoreForColumn(
                  col,
                  scores['${col.id}$suffix'],
                );
              } else {
                // في حال اختار "شامل" مع المهام الأدائية فقط
                double v1 = _getRealScoreForColumn(col, scores['${col.id}_p1']);
                double v2 = _getRealScoreForColumn(col, scores['${col.id}_p2']);
                total += (v1 + v2) / 2;
              }
            }
          }
        }
        // ✅ 2. حالة المحصلة النهائية (شامل أو تاق)
        else if (_selectedPeriod == 0) {
          // ... (نفس الكود السابق للمحصلة) ...
          if (_selectedTag == 'Comprehensive') {
            double p1 = 0;
            double p2 = 0;
            double fin = 0;
            for (var col in [..._config.items, ..._config.exams]) {
              if (_isFinalExam(col)) {
                fin += _getRealScoreForColumn(col, scores['${col.id}_p2']);
              } else {
                p1 += _getRealScoreForColumn(col, scores['${col.id}_p1']);
                p2 += _getRealScoreForColumn(col, scores['${col.id}_p2']);
              }
            }
            total = ((p1 + p2) / 2) + fin;
          } else {
            // تاق محدد
            for (var col in [..._config.items, ..._config.exams]) {
              if (col.tag == _selectedTag) {
                if (_isFinalExam(col)) {
                  total += _getRealScoreForColumn(col, scores['${col.id}_p2']);
                } else {
                  double v1 = _getRealScoreForColumn(
                    col,
                    scores['${col.id}_p1'],
                  );
                  double v2 = _getRealScoreForColumn(
                    col,
                    scores['${col.id}_p2'],
                  );
                  total += (v1 + v2) / 2;
                }
              }
            }
          }
        }
        // ✅ 3. حالة فترة محددة
        else {
          for (var col in [..._config.items, ..._config.exams]) {
            bool include =
                (_selectedTag == 'Comprehensive') || (col.tag == _selectedTag);
            if (_selectedPeriod == 1 && _isFinalExam(col)) include = false;
            if (include) {
              final val = scores['${col.id}$suffix'];
              total += _getRealScoreForColumn(col, val);
            }
          }
        }
      }
      s.tempScore = total;
    }

    // ... (بقية الدالة)

    final scoresList = _students.map((s) => s.tempScore ?? 0.0).toList();
    scoresList.sort();

    final Map<String, int> counts = {for (var l in _activeLevels) l.label: 0};
    for (var s in scoresList) {
      final lvl = AnalysisCalculator.getLevelForScore(
        score: s,
        maxScore: calculatedMax,
        useSum: true,
        selectedTag: _selectedTag,
        activeLevels: _activeLevels,
      );
      counts[lvl] = (counts[lvl] ?? 0) + 1;
    }

    double sum = scoresList.fold(0, (a, b) => a + b);

    _stats = AnalysisStatsV2(
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

  // دالة مساعدة للتحقق من النهائي
  bool _isFinalExam(GradeColumn col) {
    return col.tag == 'اختبار نهائي' || col.name.contains('نهائي');
  }

  bool _isFinalExamTag(String tag) {
    return tag == 'اختبار نهائي' || tag.contains('نهائي');
  }

  double _getRealScoreForColumn(GradeColumn col, dynamic val) {
    if (val == null) return 0.0;
    if (col.type == GradeType.numeric) {
      return double.tryParse(val.toString().toEnglishNum()) ?? 0.0;
    } else if (col.type == GradeType.checkbox) {
      int checkedCount = int.tryParse(val.toString().toEnglishNum()) ?? 0;
      if (col.subCount == 0) return 0.0;
      return checkedCount * (col.maxScore / col.subCount);
    } else if (col.type == GradeType.numericList) {
      if (val is List && val.isNotEmpty) {
        double sum = 0.0;
        int count = 0;
        for (var v in val) {
          double? d = double.tryParse(v.toString().toEnglishNum());
          if (d != null) {
            sum += d;
            count++;
          }
        }
        if (count > 0) return sum / count;
        return 0.0;
      }
      return 0.0;
    } else if (col.type == GradeType.averagePair) {
      if (val is List && val.length >= 2) {
        double v1 = double.tryParse(val[0].toString().toEnglishNum()) ?? 0.0;
        double v2 = double.tryParse(val[1].toString().toEnglishNum()) ?? 0.0;
        return (v1 + v2) / 2.0;
      }
      return 0.0;
    }
    return double.tryParse(val.toString().toEnglishNum()) ?? 0.0;
  }

  // 3. تعديل دالة جلب الطلاب (لتعكس الترتيب والفترة)
  List<Student> _getStudentsForLevel(String levelLabel) {
    // 1. تصفية الطلاب حسب المستوى (بناءً على tempScore المحسوب في _calculateStats)
    final filteredList = _students.where((s) {
      final lvl = AnalysisCalculator.getLevelForScore(
        score: s.tempScore ?? 0,
        maxScore: _stats?.maxScore ?? 100,
        useSum: true,
        selectedTag: _selectedTag,
        activeLevels: _activeLevels,
      );
      return lvl == levelLabel;
    }).toList();

    // 2. ترتيب القائمة
    return sortStudentsList(filteredList, _currentSortMode);
  }

  // --- دالة الترتيب (يفضل نقلها لملف Student أو استيرادها) ---
  // سأضعها هنا احتياطاً لتجنب الأخطاء
  List<Student> sortStudentsList(List<Student> students, StudentSortMode mode) {
    List<Student> sortedList = List.from(students);
    switch (mode) {
      case StudentSortMode.byScore:
        sortedList.sort(
          (a, b) => (b.tempScore ?? 0).compareTo(a.tempScore ?? 0),
        );
        break;
      case StudentSortMode.byClass:
        // الترتيب حسب الاسم كبديل
        sortedList.sort((a, b) => a.name.compareTo(b.name));
        break;
      case StudentSortMode.byName:
        sortedList.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
    return sortedList;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppSettings.useArabicNumbers,
      builder: (context, isArabic, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: const Color(0xFFF6F7F8),
            appBar: AppBar(
              centerTitle: true,
              title: Column(
                children: [
                  Text(
                    'تحليل ${widget.classTitle}'.toAppNum(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D6F),
                    ),
                  ),
                  // عرض الفترة الحالية تحت العنوان
                  Text(
                    _selectedPeriod == 0
                        ? 'المحصلة النهائية'
                        : 'الفترة ${_selectedPeriod.toString().toAppNum()}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Color(0xFF2E7D6F)),
              actions: [
                // 1. القائمة المنسدلة لاختيار الفترة
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedPeriod,
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Color(0xFF2E7D6F),
                    ),
                    style: const TextStyle(
                      color: Color(0xFF2E7D6F),
                      fontWeight: FontWeight.bold,
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('فترة 1')),
                      DropdownMenuItem(value: 2, child: Text('فترة 2')),
                      DropdownMenuItem(value: 0, child: Text('شامل')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedPeriod = val;
                          _calculateStats(); // إعادة الحساب عند التغيير
                        });
                      }
                    },
                  ),
                ),

                // 2. زر المقارنة (سينقلك للصفحة الجديدة لاحقاً)
                IconButton(
                  tooltip: 'مقارنة الفترات',
                  icon: const Icon(Icons.compare_arrows),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PeriodComparisonClassPage(
                          classId: widget.classId,
                          classTitle: widget.classTitle,
                        ),
                      ),
                    );
                  },
                ),
                _buildSortIcon(),

                IconButton(
                  tooltip: 'طباعة التقرير',
                  icon: const Icon(Icons.print),
                  onPressed: () {
                    if (_stats == null) return;
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => AnalysisPrintDialog(
                        initialClassTitle:
                            '${widget.classTitle} (${_selectedPeriod == 0 ? "شامل" : "ف$_selectedPeriod"})',
                        stats: _stats!,
                        activeLevels: _activeLevels,
                        students: _students,
                        getStudentsForLevel: _getStudentsForLevel,
                      ),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'إعدادات المستويات',
                  icon: const Icon(Icons.tune),
                  onPressed: () async {
                    if (_stats == null) return;
                    final changed = await showDialog<bool>(
                      context: context,
                      builder: (_) =>
                          LevelSettingsDialog(maxScore: _stats!.maxScore),
                    );
                    if (changed == true) {
                      await _loadData();
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
                        const SizedBox(height: 5),
                        if (_stats != null) ...[
                          _buildStatsCards(),
                          const SizedBox(height: 1),
                          _buildGridTablesLayout(),
                          Transform.translate(
                            offset: const Offset(0, -0),
                            child: _buildBottomChartsOnly(),
                          ),
                        ],
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  // ... (بقية الوديجت _buildFilterBar, _buildStatsCards, إلخ كما هي في ملفك الأصلي)
  // سأعيد كتابتها هنا لضمان أن الملف كامل ولا ينقصه شيء

  Widget _buildFilterBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6F3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Text(
            'اختر البيانات المراد تحليلها',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF2E7D6F),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _availableTags
                .where((tag) {
                  if (_selectedPeriod == 1 || _selectedPeriod == 2) {
                    if (tag == 'Comprehensive' || _isFinalExamTag(tag))
                      return false;
                  } else if (_selectedPeriod == 0) {
                    if (tag == 'PeriodTotal')
                      return false; // المجموع الكلي يظهر فقط في الفترات
                  }
                  return true;
                })
                .map((tag) {
                  final isSelected = _selectedTag == tag;
                  String label = tag;
                  if (tag == 'Comprehensive') {
                    label = 'المحصلة النهائية';
                  } else if (tag == 'PeriodTotal') {
                    label = 'المجموع الكلي (مهام + اختبار)';
                  } else if (tag == 'PerformanceTasks') {
                    if (_selectedPeriod == 1 || _selectedPeriod == 2) {
                      label = 'المهام الأدائية';
                    } else {
                      label = 'المهام الأدائية للفترتين';
                    }
                  }
                  return ChoiceChip(
                    label: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
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
                          _selectedTag = tag;
                          _calculateStats();
                        });
                      }
                    },
                  );
                })
                .toList(),
          ),
        ],
      ),
    );
  }

  // ... (قم بنسخ بقية الوديجت _buildStatsCards وما بعدها من ملفك القديم إذا كنت تريد اختصار المساحة،
  // أو استخدم الملف القديم واستبدل الدوال التي عدلناها فقط: _calculateStats, _getRealScoreForColumn, build, _getStudentsForLevel)

  // لضمان عمل الكود، سأضع لك بقية الوديجت الأساسية هنا

  Widget _buildStatsCards() {
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
            title: 'عدد الطلاب',
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
            title: 'متوسط الدرجات',
            value: formatNumberForDisplay(_stats!.average),
            color: const Color(0xFF42A5F5),
          ),
          _StatCardLarge(
            icon: Icons.check_circle,
            title: 'نسبة الإتقان',
            value: '${formatNumberForDisplay(_stats!.achievementPercent)}%',
            color: const Color(0xFF66BB6A),
          ),
          _StatCardLarge(
            icon: Icons.functions,
            title: sumTitle,
            value: formatNumberForDisplay(_stats!.sum),
            color: const Color(0xFF9C27B0),
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
    const double smallTableHeight = 300;
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildLevelCardSafe(
                3,
                smallTableHeight,
                const Color(0xFFFFA726),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildLevelCardSafe(
                4,
                smallTableHeight,
                const Color(0xFFEF5350),
              ),
            ),
            const SizedBox(width: 16),
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
    );
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
                title.toAppNum(),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Transform.translate(
            offset: const Offset(0, -0),
            child: _buildAchievementDonut(),
          ),
        ),
        const SizedBox(width: 20),
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
                            '${(axisMax * (1 - index / 5)).toInt()}'.toAppNum(),
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
                        '${formatNumberForDisplay(achievement)}%'.toAppNum(),
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

  const _LevelStudentsCard({
    required this.title,
    required this.color,
    required this.height,
    required this.students,
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
                      children: const [
                        Expanded(
                          flex: 1,
                          child: Text(
                            '#',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'الاسم',
                            textAlign: TextAlign.right,
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                        ),
                        Expanded(
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
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          '${index + 1}'.toAppNum(),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 11,
                                          ), //تسلسل
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          s.name,
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight
                                                .bold, // ✅ تم إضافة هذا السطر
                                          ), //اسماء الطلاب داخل الجدول
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),

                                      //درجة الطالب داخل الجدول
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
