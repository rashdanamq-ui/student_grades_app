// lib/features/analysis/models/analysis_view_models.dart

import 'package:flutter/material.dart';

// ==========================================
// كلاسات مساعدة للتحليل
// ==========================================

class PdfStudentRow {
  final String name;
  final String className;
  final String score;

  PdfStudentRow({
    required this.name,
    required this.className,
    required this.score,
  });
}

class LevelConfigV2 {
  String label;
  double minPercent;
  LevelConfigV2({required this.label, required this.minPercent});
  Map<String, dynamic> toJson() => {'label': label, 'minPercent': minPercent};
  factory LevelConfigV2.fromJson(Map<String, dynamic> m) => LevelConfigV2(
    label: m['label']?.toString() ?? '',
    minPercent: (m['minPercent'] as num?)?.toDouble() ?? 0.0,
  );
}

class AnalysisStatsV2 {
  final double maxScore;
  final int totalStudents;
  final int activeStudents;
  final double highest;
  final double lowest;
  final double average;
  final double sum;
  final double achievementPercent;
  final Map<String, int> levelCounts;
  final List<String> levelLabels;

  bool get hasData => activeStudents > 0;
  int get totalActive => activeStudents;

  AnalysisStatsV2({
    required this.maxScore,
    required this.totalStudents,
    required this.activeStudents,
    required this.highest,
    required this.lowest,
    required this.average,
    required this.sum,
    required this.achievementPercent,
    required this.levelCounts,
    required this.levelLabels,
  });

  factory AnalysisStatsV2.empty({
    required double maxScore,
    required int totalStudents,
    required List<String> levelLabels,
  }) => AnalysisStatsV2(
    maxScore: maxScore,
    totalStudents: totalStudents,
    activeStudents: 0,
    highest: 0,
    lowest: 0,
    average: 0,
    sum: 0,
    achievementPercent: 0,
    levelCounts: {for (final lbl in levelLabels) lbl: 0},
    levelLabels: levelLabels,
  );

  List<LevelRowV2> levelsWithRanges(List<LevelConfigV2> configs) {
    final max = maxScore <= 0 ? 20.0 : maxScore;
    final sorted = List<LevelConfigV2>.from(configs)
      ..sort((a, b) => b.minPercent.compareTo(a.minPercent));
    String fmt(double v) {
      String s = v.toStringAsFixed(1);
      if (s.endsWith('.0')) return s.substring(0, s.length - 2);
      return s;
    }

    final List<LevelRowV2> rows = [];
    const colors = [
      Color(0xFF00C853), // Vibrant Green (Excellent)
      Color(0xFF27ae60), // Dark Green (Very Good)
      Color(0xFF2980b9), // Strong Blue (Good)
      Color(0xFFf39c12), // Darker Orange (Acceptable)
      Color(0xFFc0392b), // Darker/Stronger Red (Poor)
    ];
    for (int i = 0; i < sorted.length; i++) {
      final lvl = sorted[i];
      final minP = lvl.minPercent.clamp(0, 100);
      final maxP = i == 0
          ? 100.0
          : sorted[i - 1].minPercent.clamp(0, 100) - 0.01;
      rows.add(
        LevelRowV2(
          label: lvl.label,
          rangeLabel:
              '${fmt(max * (minP / 100.0))} - ${fmt(max * (maxP / 100.0))}',
          count: levelCounts[lvl.label] ?? 0,
          color: colors[i.clamp(0, colors.length - 1)],
        ),
      );
    }
    return rows;
  }
}

class LevelRowV2 {
  final String label;
  final String rangeLabel;
  final int count;
  final Color color;
  LevelRowV2({
    required this.label,
    required this.rangeLabel,
    required this.count,
    required this.color,
  });
}
