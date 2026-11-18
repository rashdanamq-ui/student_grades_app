import 'dart:convert';
import 'dart:math'; // للمكتبات الرياضية
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_grades_app/models/mock_student.dart';

// استيراد الموديلات والخدمات
import '../../../models/student.dart';
import '../../../core/grading_levels/level_settings_service.dart';
import '../../../core/utils/number_utils.dart';
import '../models/analysis_view_models.dart';
import '../services/analysis_calculator.dart';
import '../widgets/analysis_print_dialog.dart';
import '../widgets/level_settings_dialog.dart';

// تحليل مهارة

class ModernMockSkillPage extends StatefulWidget {
  final String classId;
  final String classTitle;

  const ModernMockSkillPage({
    super.key,
    required this.classId,
    required this.classTitle,
  });

  @override
  State<ModernMockSkillPage> createState() => _ModernMockSkillPageState();
}

class _ModernMockSkillPageState extends State<ModernMockSkillPage> {
  // 1️⃣ متغير حالة الترتيب
  StudentSortMode _currentSortMode = StudentSortMode.byScore;

  // 2️⃣ دالة تبديل الترتيب
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

  // 3️⃣ دالة بناء الأيقونة
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

  // === البيانات الخام ===
  List<MockStudent> _rawStudents = []; // طلاب الاختبار المحاكي
  List<String> _columnTitles = []; // أسماء المهارات/الأعمدة
  List<double> _columnMaxScores = []; // الدرجة العظمى لكل عمود

  // === بيانات العرض ===
  List<Student> _displayStudents = []; // قائمة محولة للعرض في الواجهة

  // === إعدادات التحليل ===
  List<LevelConfigV2> _activeLevels = [];
  AnalysisStatsV2? _stats;

  // === حالة الواجهة ===
  bool _isLoading = true;
  int _selectedColumnIndex =
      -1; // -1 تعني المجموع الكلي، 0 وما فوق تعني رقم العمود

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // 1. تحميل بيانات الاختبار المحاكي
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    // أ) تحميل المستويات
    final levelSettings = await LevelSettingsService.load();
    _activeLevels = levelSettings.levels
      ..sort((a, b) => b.minPercent.compareTo(a.minPercent));

    // ب) تحميل الميتاداتا (أسماء الأعمدة والدرجات العظمى)
    final metaKey = 'mock_exam_${widget.classId}_v1_meta';
    final metaStr = prefs.getString(metaKey);

    // قيم افتراضية
    int colCount = 8;
    _columnTitles = List.filled(colCount, '');
    _columnMaxScores = List.filled(colCount, 20.0);

    if (metaStr != null) {
      try {
        final Map<String, dynamic> meta = jsonDecode(metaStr);
        colCount = meta['count'] ?? 8;

        if (meta['titles'] != null) {
          final List t = meta['titles'];
          _columnTitles = t.map((e) => e.toString()).toList();
        }

        if (meta['max_scores'] != null) {
          final List m = meta['max_scores'];
          _columnMaxScores = m
              .map((e) => double.tryParse(e.toString()) ?? 20.0)
              .toList();
        }

        // التأكد من تطابق الأطوال
        if (_columnTitles.length < colCount) {
          _columnTitles = List.filled(colCount, '');
        }
      } catch (e) {
        debugPrint('Error loading meta: $e');
      }
    }

    // ج) تحميل الطلاب ودرجاتهم
    final storageKey = 'mock_exam_${widget.classId}_v1';
    final str = prefs.getString(storageKey);
    if (str != null) {
      final List decoded = jsonDecode(str);
      _rawStudents = decoded
          .map((e) => MockStudent.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    // د) الحساب الأولي (المجموع)
    _calculateStats();

    setState(() => _isLoading = false);
  }

  // 2. المحرك: حساب الدرجات بناءً على العمود المختار
  void _calculateStats() {
    double currentMaxScore = 0.0;

    // تحديد الدرجة العظمى
    if (_selectedColumnIndex == -1) {
      // المجموع الكلي
      currentMaxScore = _columnMaxScores.fold(0.0, (sum, val) => sum + val);
    } else {
      // عمود محدد
      if (_selectedColumnIndex < _columnMaxScores.length) {
        currentMaxScore = _columnMaxScores[_selectedColumnIndex];
      }
    }
    if (currentMaxScore == 0) currentMaxScore = 100; // حماية

    // تجهيز قائمة الطلاب للعرض
    _displayStudents.clear();

    for (var ms in _rawStudents) {
      double studentScore = 0.0;

      if (_selectedColumnIndex == -1) {
        // جمع كل الدرجات
        for (var score in ms.exams) {
          studentScore += (score ?? 0.0);
        }
      } else {
        // درجة العمود المحدد فقط
        if (_selectedColumnIndex < ms.exams.length) {
          studentScore = ms.exams[_selectedColumnIndex] ?? 0.0;
        }
      }

      // إنشاء كائن طالب للعرض (نستخدم كلاس Student العادي ليتوافق مع الواجهة)
      final displayS = Student(name: ms.name);
      displayS.tempScore = studentScore;
      _displayStudents.add(displayS);
    }

    // توليد الإحصائيات
    final scoresList = _displayStudents.map((s) => s.tempScore ?? 0.0).toList();
    scoresList.sort();

    final Map<String, int> counts = {for (var l in _activeLevels) l.label: 0};
    for (var s in scoresList) {
      final lvl = AnalysisCalculator.getLevelForScore(
        score: s,
        maxScore: currentMaxScore,
        useSum: true, // نستخدم المجموع دائماً هنا لأننا نقارن درجة بدرجة
        selectedTag: 'Mock',
        activeLevels: _activeLevels,
      );
      counts[lvl] = (counts[lvl] ?? 0) + 1;
    }

    double sum = scoresList.fold(0, (a, b) => a + b);

    _stats = AnalysisStatsV2(
      maxScore: currentMaxScore,
      totalStudents: _displayStudents.length,
      activeStudents: scoresList.length,
      highest: scoresList.isEmpty ? 0 : scoresList.last,
      lowest: scoresList.isEmpty ? 0 : scoresList.first,
      average: scoresList.isEmpty ? 0 : sum / scoresList.length,
      sum: sum,
      achievementPercent:
          (sum / (_displayStudents.length * currentMaxScore)) * 100,
      levelCounts: counts,
      levelLabels: _activeLevels.map((e) => e.label).toList(),
    );
  }

  List<Student> _getStudentsForLevel(String levelLabel) {
    // 1. التصفية
    final filteredList = _displayStudents.where((s) {
      final lvl = AnalysisCalculator.getLevelForScore(
        score: s.tempScore ?? 0,
        maxScore: _stats?.maxScore ?? 100,
        useSum: true,
        activeLevels: _activeLevels,
        selectedTag: 'Comprehensive',
      );
      return lvl == levelLabel;
    }).toList();

    // 2. الترتيب باستخدام الدالة الجديدة المتوافقة مع Student
    // 👇 استخدم sortStudentListV2 بدلاً من sortStudentsList
    return sortStudentListV2(filteredList, _currentSortMode);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7F8),
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'تحليل مهارة (محاكي)',
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
                    initialClassTitle: widget.classTitle,
                    stats: _stats!,
                    activeLevels: _activeLevels,
                    students: _displayStudents,
                    getStudentsForLevel: (label) => _getStudentsForLevel(label),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.tune),
              onPressed: () async {
                final changed = await showDialog<bool>(
                  context: context,
                  builder: (_) =>
                      LevelSettingsDialog(maxScore: _stats?.maxScore ?? 100),
                );
                if (changed == true) {
                  // إزاحة التحميل
                  final levelSettings = await LevelSettingsService.load();
                  setState(() {
                    _activeLevels = levelSettings.levels
                      ..sort((a, b) => b.minPercent.compareTo(a.minPercent));
                    _calculateStats();
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
                    if (_stats != null) ...[
                      /* Text(
                        widget.classTitle, // اسم الاختبار
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
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
  }

  // -----------------------------
  // 1. شريط الفلترة (المهارات/الأعمدة)
  // -----------------------------
  Widget _buildFilterBar() {
    return Container(
      width: double.infinity,
      // 1. إضافة هامش خارجي (اختياري) إذا كنت تريد تصغير عرض الصندوق نفسه
      margin: const EdgeInsets.symmetric(horizontal: 10),

      // 2. تقليل الـ vertical padding (من 15 إلى 8 مثلاً) لتصغير طول الصندوق
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),

      decoration: BoxDecoration(
        color: const Color(0xFFEAF6F3),
        borderRadius: BorderRadius.circular(
          15,
        ), // تصغير نصف القطر قليلاً ليناسب الحجم الجديد
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // لضمان أن الصندوق يأخذ أقل مساحة ممكنة
        children: [
          // السطر العلوي
          SizedBox(
            height: 25, // 3. تقليل ارتفاع منطقة النصوص (من 30 إلى 25)
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Text(
                  'اختر المهارة/السؤال للتحليل',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12, // تصغير الخط درجة واحدة
                    color: Color(0xFF2E7D6F),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    widget.classTitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 10, // تصغير الخط درجة واحدة
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. تقليل المسافة الفاصلة بين النصوص والأزرار (من 15 إلى 5)
          const SizedBox(height: 5),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(-1, 'المجموع الكلي'),
                ...List.generate(_columnTitles.length, (index) {
                  String title = _columnTitles[index];
                  if (title.trim().isEmpty) title = 'سؤال ${index + 1}';
                  return _buildFilterChip(index, title);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _selectedColumnIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : const Color(0xFF2E7D6F),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        selectedColor: const Color(0xFF1FAF8E),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: const Color(0xFF1FAF8E).withOpacity(0.3)),
        ),
        onSelected: (val) {
          if (val) {
            setState(() {
              _selectedColumnIndex = index;
              _calculateStats();
            });
          }
        },
      ),
    );
  }

  // -----------------------------
  // (نفس الويدجتات المستخدمة سابقاً - معاد استخدامها)
  // -----------------------------

  Widget _buildStatsCards() {
    // تحديد عنوان الكرت بناءً على العمود المختار
    String sumTitle = 'مجموع الدرجات';
    if (_selectedColumnIndex != -1 &&
        _selectedColumnIndex < _columnTitles.length) {
      String skillName = _columnTitles[_selectedColumnIndex];
      if (skillName.trim().isNotEmpty) {
        sumTitle = 'مجموع ($skillName)';
      }
    }

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
            value: '${_stats!.totalStudents}'.toAppNum(), // ✅ إضافة التحويل هنا
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

// دالة ترتيب مخصصة لنوع Student (وليس MockStudent)
List<Student> sortStudentListV2(List<Student> students, StudentSortMode mode) {
  List<Student> sortedList = List.from(students);

  switch (mode) {
    case StudentSortMode.byScore:
      // ترتيب تنازلي حسب الدرجة
      sortedList.sort((a, b) => (b.tempScore ?? 0).compareTo(a.tempScore ?? 0));
      break;

    case StudentSortMode.byClass:
      // ترتيب تصاعدي حسب الصف (إذا لم يوجد className نستخدم الاسم)
      // ملاحظة: كلاس Student غالباً لا يحتوي على className بشكل مباشر مثل MockStudent
      // إذا كان يحتوي، استخدم: a.className.compareTo(b.className)
      sortedList.sort((a, b) => a.name.compareTo(b.name));
      break;

    case StudentSortMode.byName:
      // ترتيب أبجدي حسب الاسم
      sortedList.sort((a, b) => a.name.compareTo(b.name));
      break;
  }
  return sortedList;
}
