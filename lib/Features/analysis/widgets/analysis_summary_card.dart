//= ملف "لوحة الملخص =//

import 'package:flutter/material.dart';
import '../../../core/utils/number_utils.dart'; // تأكد من المسار
import '../models/analysis_view_models.dart'; // تأكد من المسار

class AnalysisSummaryCard extends StatelessWidget {
  final AnalysisStatsV2 stats;

  const AnalysisSummaryCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // الشريط العلوي الملون
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFe0f2f1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildHighlightStat(
                  'عدد الطلاب',
                  stats.totalStudents.toString(),
                ),
                Container(width: 1, height: 25, color: Colors.teal.shade200),
                _buildHighlightStat(
                  'درجة القياس',
                  stats.maxScore.toStringAsFixed(0),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // الإحصائيات التفصيلية
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDashStat(
                  'أعلى درجة',
                  formatNumberForDisplay(
                    stats.highest,
                  ), // ✅ استخدام دالة التنسيق للفاصلة

                  Icons.arrow_upward,
                ),
                _verticalLine(),
                _buildDashStat(
                  'أقل درجة',
                  formatNumberForDisplay(
                    stats.lowest,
                  ), // ✅ استخدام دالة التنسيق للفاصلة

                  Icons.arrow_downward,
                ),
                _verticalLine(),
                _buildDashStat(
                  'المتوسط',
                  formatNumberForDisplay(
                    stats.average,
                  ), // ✅ استخدام دالة التنسيق للفاصلة

                  Icons.functions,
                ),
                _verticalLine(),
                _buildDashStat(
                  'التحصيل',
                  '${formatNumberForDisplay(stats.achievementPercent)}%', // ✅ استخدام دالة التنسيق للفاصلة
                  Icons.pie_chart,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightStat(String label, String value) => Row(
    children: [
      Text(
        '$label: ',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.teal.shade800,
        ),
      ),
      Text(
        value.toAppNum(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.teal.shade900,
        ),
      ),
    ],
  );

  Widget _buildDashStat(String label, String value, IconData icon) => Column(
    children: [
      Icon(icon, size: 18, color: Colors.grey.shade400),
      const SizedBox(height: 4),
      Text(
        value.toAppNum(),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Colors.black87,
        ),
      ),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
    ],
  );

  Widget _verticalLine() =>
      Container(height: 30, width: 1, color: Colors.grey.shade200);
}
