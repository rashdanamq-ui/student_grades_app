import 'package:flutter/material.dart';
import '../../../core/utils/number_utils.dart';
import '../models/analysis_view_models.dart';
import 'wave_bar_chart.dart'; // Import WaveBarChart

class AnalysisChartsSection extends StatelessWidget {
  final AnalysisStatsV2 stats;
  final List<LevelConfigV2> activeLevels;

  const AnalysisChartsSection({
    super.key,
    required this.stats,
    required this.activeLevels,
  });

  @override
  Widget build(BuildContext context) {
    // ... (rest of the build method data prep)
    final levels = stats.levelsWithRanges(activeLevels);
    final maxCount = levels.fold<int>(
      0,
      (prev, lvl) => lvl.count > prev ? lvl.count : prev,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'التحليل البياني للنتائج',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              bool isMobile = constraints.maxWidth < 600;

              // قسم الدوائر
              Widget donutSection = Column(
                children: [
                  const Text(
                    'نسب الطلاب',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: levels.asMap().entries.map((entry) {
                        final index = entry.key;
                        final lvl = entry.value;
                        final percent = stats.totalActive == 0
                            ? 0.0
                            : (lvl.count / stats.totalActive) * 100.0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: DonutChartV2(
                            label: lvl.label,
                            percent: percent,
                            color: lvl.color,
                            levelIndex: index,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );

              // قسم المسطرة الأفقية (الجديد)
              Widget barSection = Column(
                children: [
                  const Text(
                    'عدد الطلاب',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  WaveBarChart(
                    items: levels
                        .map(
                          (l) => WaveLevelItem(
                            label: l.label,
                            count: l.count,
                            color: l.color,
                          ),
                        )
                        .toList(),
                    maxCount: maxCount,
                    height: 180, // Adjust height as needed
                  ),
                ],
              );

              if (isMobile) {
                return Column(
                  children: [
                    donutSection,
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 10),
                    barSection,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: donutSection),
                  Container(width: 1, height: 150, color: Colors.grey.shade200),
                  Expanded(child: barSection),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// الكلاس المساعد للرسم الدائري (تم نقله هنا)
class DonutChartV2 extends StatelessWidget {
  final String label;
  final double percent;
  final Color color;
  final int levelIndex;

  const DonutChartV2({
    super.key,
    required this.label,
    required this.percent,
    required this.color,
    required this.levelIndex,
  });

  IconData get icon {
    switch (levelIndex) {
      case 0:
        return Icons.sentiment_very_satisfied_rounded; // Enthusiastic
      case 1:
        return Icons.sentiment_satisfied_alt_rounded; // Happy
      case 2:
        return Icons.sentiment_neutral_rounded; // Neutral
      case 3:
        return Icons.sentiment_dissatisfied_rounded; // Sad
      case 4:
        return Icons.mood_bad_rounded; // Upset
      default:
        return Icons.sentiment_neutral_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = (percent.clamp(0, 100)) / 100.0;
    return Column(
      children: [
        SizedBox(
          width: 85, // Increased from 70
          height: 85, // Increased from 70
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 85,
                height: 85,
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 10, // Increased from 7
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.grey.shade300,
                  ),
                ),
              ),
              SizedBox(
                width: 85,
                height: 85,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 10, // Increased from 7
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  backgroundColor: Colors.transparent,
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${percent.toStringAsFixed(0)}%'.toAppNum(),
                    style: const TextStyle(
                      fontSize: 14, // Increased from 10
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4), // Increased spacing
                  Icon(icon, color: color, size: 28), // Increased from 20
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
