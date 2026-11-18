//=   ملف المحاسب= //

import '../../../models/mock_student.dart';
import '../models/analysis_view_models.dart';

class AnalysisCalculator {
  /// حساب الدرجة لطالب واحد
  static double calculateStudentScore({
    required MockStudent student,
    required String selectedTag,
    required bool useSum,
    required int examCount,
    required List<double> examMaxScores,
    required List<String> examTags,
  }) {
    // ===== شامل =====
    if (selectedTag == 'Comprehensive') {
      // 🔹 عرض المجموع
      if (useSum) {
        double sum = 0.0;
        for (int i = 0; i < examCount; i++) {
          if (i < student.exams.length) {
            sum += student.exams[i] ?? 0.0;
          }
        }
        return sum;
      }

      // 🔹 عرض النسبة المئوية
      double sumNormalized = 0.0;
      int count = 0;
      for (int i = 0; i < examCount; i++) {
        if (i < student.exams.length) {
          final max = (i < examMaxScores.length && examMaxScores[i] > 0)
              ? examMaxScores[i]
              : 20.0;
          final score = student.exams[i] ?? 0.0;
          sumNormalized += (score / max);
          count++;
        }
      }
      if (count == 0) return 0.0;
      return (sumNormalized / count) * 100.0;
    }

    // ===== تحليل مهارة محددة =====
    double totalScore = 0.0;
    for (int i = 0; i < examCount; i++) {
      if (i < examTags.length && examTags[i] == selectedTag) {
        totalScore += (i < student.exams.length
            ? student.exams[i] ?? 0.0
            : 0.0);
      }
    }
    return totalScore;
  }

  /// حساب الدرجة العظمى (للمقارنة)
  static double calculateMaxScore({
    required String selectedTag,
    required bool useSum,
    required int examCount,
    required List<double> examMaxScores,
    required List<String> examTags,
    required List<MockStudent> students, // نحتاجها للتحقق من وجود بيانات
  }) {
    // ===== شامل + مجموع =====
    if (selectedTag == 'Comprehensive' && useSum) {
      double totalMax = 0.0;
      for (int i = 0; i < examCount; i++) {
        // نجمع الدرجة فقط إذا كان هناك طالب لديه درجة في هذا العمود
        bool hasData = students.any(
          (s) => i < s.exams.length && s.exams[i] != null,
        );
        if (hasData) {
          totalMax += (i < examMaxScores.length && examMaxScores[i] > 0)
              ? examMaxScores[i]
              : 20.0;
        }
      }
      return totalMax > 0 ? totalMax : 20.0;
    }

    // ===== شامل (نسبة) =====
    if (selectedTag == 'Comprehensive') {
      return 100.0;
    }

    // ===== تحليل مهارة =====
    for (int i = 0; i < examCount; i++) {
      if (i < examTags.length && examTags[i] == selectedTag) {
        return (i < examMaxScores.length && examMaxScores[i] > 0)
            ? examMaxScores[i]
            : 20.0;
      }
    }
    return 20.0;
  }

  /// تحديد المستوى بناءً على الدرجة
  static String getLevelForScore({
    required double score,
    required double maxScore,
    required bool useSum,
    required String selectedTag,
    required List<LevelConfigV2> activeLevels,
  }) {
    // الترتيب من الأعلى للأقل
    final sortedLevels = List<LevelConfigV2>.from(activeLevels)
      ..sort((a, b) => b.minPercent.compareTo(a.minPercent));

    // إذا كان شامل ومجموع، نحول النسبة إلى درجة
    if (selectedTag == 'Comprehensive' && useSum) {
      for (final lvl in sortedLevels) {
        final minScore = (lvl.minPercent / 100.0) * maxScore;
        if (score >= minScore - 0.01) {
          // -0.01 لمعالجة كسور الفلوس
          return lvl.label;
        }
      }
      return sortedLevels.last.label;
    }

    // النسبة المئوية لبقية الحالات
    final percent = maxScore == 0 ? 0.0 : (score / maxScore) * 100.0;

    // البحث عن المستوى
    for (final lvl in sortedLevels) {
      if (percent >= lvl.minPercent - 0.01) {
        return lvl.label;
      }
    }
    return sortedLevels.last.label;
  }

  /// توليد كائن الإحصائيات الكامل
  static AnalysisStatsV2 generateStats({
    required List<MockStudent> students,
    required double maxScore, // يجب أن تكون محسوبة مسبقاً
    required List<LevelConfigV2> activeLevels,
    required String selectedTag,
    required bool useSum,
  }) {
    // استخراج الدرجات (tempScore يجب أن يكون قد تم تحديثه في الطلاب قبل استدعاء هذه الدالة)
    // أو نعتمد على أن الطلاب لديهم tempScore جاهز
    final scores = students.map((s) => s.tempScore ?? 0.0).toList();

    if (scores.isEmpty) {
      return AnalysisStatsV2.empty(
        maxScore: maxScore,
        totalStudents: students.length,
        levelLabels: activeLevels.map((e) => e.label).toList(),
      );
    }

    scores.sort();
    final sum = scores.fold(0.0, (p, e) => p + e);
    final avg = sum / scores.length;
    final levelCounts = {for (final l in activeLevels) l.label: 0};

    for (final s in scores) {
      final lvl = getLevelForScore(
        score: s,
        maxScore: maxScore,
        useSum: useSum,
        selectedTag: selectedTag,
        activeLevels: activeLevels,
      );
      levelCounts[lvl] = (levelCounts[lvl] ?? 0) + 1;
    }

    return AnalysisStatsV2(
      maxScore: maxScore,
      totalStudents: students.length,
      activeStudents: scores.length,
      highest: scores.last,
      lowest: scores.first,
      average: avg,
      sum: sum,
      achievementPercent: maxScore == 0 ? 0 : (avg / maxScore) * 100.0,
      levelCounts: levelCounts,
      levelLabels: activeLevels.map((e) => e.label).toList(),
    );
  }
}
