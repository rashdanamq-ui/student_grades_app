//=  ملف "شبكة الطلاب =//

import 'package:flutter/material.dart';
import '../../../core/utils/number_utils.dart';
import '../../../models/mock_student.dart'; // الموديل الموحد
import '../models/analysis_view_models.dart'; // موديلات التحليل

class RankedStudentsGrid extends StatelessWidget {
  final AnalysisStatsV2 stats;
  final List<LevelConfigV2> activeLevels;

  // دالة نمررها من الصفحة الرئيسية لجلب طلاب مستوى معين
  final List<MockStudent> Function(LevelConfigV2 level) onGetStudentsForLevel;

  final bool isComprehensive; // هل التحليل شامل؟ (لإظهار عمود الصف)
  final String defaultClassName; // اسم الفصل الافتراضي

  const RankedStudentsGrid({
    super.key,
    required this.stats,
    required this.activeLevels,
    required this.onGetStudentsForLevel,
    required this.isComprehensive,
    required this.defaultClassName,
  });

  @override
  Widget build(BuildContext context) {
    const levelColors = [
      Color(0xFF2ecc71),
      Color(0xFF27ae60),
      Color(0xFF2980b9),
      Color(0xFFe67e22),
      Color(0xFFc0392b),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = constraints.maxWidth > 800
              ? 3
              : (constraints.maxWidth > 500 ? 2 : 1);
          double width =
              (constraints.maxWidth - ((crossAxisCount - 1) * 12)) /
              crossAxisCount;

          List<Widget> gridItems = [];

          // بناء كروت المستويات
          for (int i = 0; i < activeLevels.length; i++) {
            final lvl = activeLevels[i];
            final list = onGetStudentsForLevel(lvl);
            gridItems.add(
              _buildRankedStudentsCard(
                title: lvl.label,
                students: list,
                color: levelColors[i % levelColors.length],
              ),
            );
          }

          // إضافة كرت الإحصائيات التفصيلية
          gridItems.add(_buildDetailedStatsCard());

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            // ✅ Wrap سيتبع الآن اتجاه Directionality (من اليمين)
            children: gridItems
                .map((item) => SizedBox(width: width, height: 350, child: item))
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildRankedStudentsCard({
    required String title,
    required List<MockStudent> students,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                const Expanded(
                  flex: 1,
                  child: Text(
                    '#',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: const Text(
                    'الاسم',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'الصف',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
                const Expanded(
                  flex: 2,
                  child: Text(
                    'الدرجة',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: students.isEmpty
                ? const Center(
                    child: Text(
                      'لا يوجد طلاب',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  )
                : ListView.builder(
                    itemCount: students.length,
                    padding: EdgeInsets.zero,
                    itemBuilder: (ctx, idx) {
                      final s = students[idx];
                      String displayName = s.name;
                      String displayClass = defaultClassName;

                      if (s.name.contains('(')) {
                        var parts = s.name.split('(');
                        displayName = parts[0].trim();
                        if (parts.length > 1) {
                          String extracted = parts[1]
                              .replaceAll(')', '')
                              .trim();
                          if (extracted.isNotEmpty) displayClass = extracted;
                        }
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade50),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: Text(
                                (idx + 1).toString().toAppNum(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Text(
                                displayName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                displayClass.toAppNum(),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(
                                  formatGrade(s.tempScore ?? 0),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
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
    );
  }

  Widget _buildDetailedStatsCard() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.black),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: const Text(
              'الإحصائيات التفصيلية',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            color: Colors.grey.shade100,
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'المستوى',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'النطاق',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'العدد',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: stats.levelsWithRanges(activeLevels).map((lvl) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade50),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            lvl.label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            lvl.rangeLabel.toAppNum(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            lvl.count.toString().toAppNum(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // دالة مساعدة لتنسيق الدرجة (نفس الموجودة في صفحتك)
  String formatGrade(double val) {
    String text = (val % 1 == 0)
        ? val.toInt().toString()
        : val.toStringAsFixed(1);
    text = text.toAppNum();
    return text.replaceAll('.', ',');
  }
}
// تحليل مرحلة ممكن