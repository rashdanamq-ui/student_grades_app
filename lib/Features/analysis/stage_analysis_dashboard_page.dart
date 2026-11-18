// lib/Features/analysis/stage_analysis_dashboard_page.dart

import 'package:flutter/material.dart';
import 'dart:math';

class StageAnalysisDashboardPage extends StatelessWidget {
  const StageAnalysisDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 246, 247, 248),
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'تحليل نتائج الطلاب - المرحلة',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              tooltip: 'طباعة',
              icon: const Icon(Icons.print),
              onPressed: () {},
            ),
            IconButton(
              tooltip: 'تصدير Excel',
              icon: const Icon(Icons.table_chart),
              onPressed: () {},
            ),
            IconButton(
              tooltip: 'الإعدادات',
              icon: const Icon(Icons.tune),
              onPressed: () {},
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildTopFilterBar(),
              const SizedBox(height: 16),
              _buildStatsCards(),
              const SizedBox(height: 20),

              // شبكة الجداول
              _buildGridTablesLayout(),

              const SizedBox(height: 30),

              // الرسوم البيانية في الأسفل
              _buildBottomChartsOnly(),

              // مسافة إضافية في الأسفل لضمان عدم التصاق الرسم البياني بالحافة
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  // -----------------------------
  // الشريط العلوي
  Widget _buildTopFilterBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: List.generate(5, (index) {
              final bool isSelected = index == 4;
              return ChoiceChip(
                label: Text(
                  'الاختبار ${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.white : const Color(0xFF2E7D6F),
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
                onSelected: (_) {},
              );
            }),
          ),
        ],
      ),
    );
  }

  // -----------------------------
  // كروت الإحصائيات
  Widget _buildStatsCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        children: const [
          _StatCardLarge(
            icon: Icons.groups,
            title: 'عدد الطلاب',
            value: '37',
            color: Color(0xFF2EAD8B),
          ),
          _StatCardLarge(
            icon: Icons.emoji_events,
            title: 'أعلى درجة',
            value: '60',
            color: Color(0xFFFFA726),
          ),
          _StatCardLarge(
            icon: Icons.arrow_downward,
            title: 'أقل درجة',
            value: '10',
            color: Color(0xFFEF5350),
          ),
          _StatCardLarge(
            icon: Icons.bar_chart,
            title: 'متوسط الدرجات',
            value: '43.7',
            color: Color(0xFF42A5F5),
          ),
          _StatCardLarge(
            icon: Icons.check_circle,
            title: 'نسبة الإتقان',
            value: '72.1%',
            color: Color(0xFF66BB6A),
          ),
          _StatCardLarge(
            icon: Icons.straighten,
            title: 'درجة القياس',
            value: '60',
            color: Color(0xFF7E57C2),
          ),
        ],
      ),
    );
  }

  // -----------------------------
  // ترتيب الجداول (شبكة)
  Widget _buildGridTablesLayout() {
    // تحديد ارتفاعات الصفوف هنا للتحكم بها بسهولة
    const double topRowHeight = 280; // ارتفاع الصف الأول (ممتاز، جيد جدا، جيد)
    const double bottomRowHeight =
        380; // ارتفاع الصف الثاني (مقبول، ضعيف، النطاق) -> قمنا بزيادته

    return Column(
      children: [
        // الصف الأول
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Expanded(
              child: _LevelStudentsCard(
                title: 'ممتاز جداً',
                color: Color(0xFF00C853),
                height: topRowHeight,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _LevelStudentsCard(
                title: 'جيد جداً',
                color: Color(0xFF2979FF),
                height: topRowHeight,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _LevelStudentsCard(
                title: 'جيد',
                color: Color(0xFF7E57C2),
                height: topRowHeight,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // الصف الثاني
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: _LevelStudentsCard(
                title: 'مقبول',
                color: Color(0xFFFFA726),
                height: bottomRowHeight,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: _LevelStudentsCard(
                title: 'ضعيف',
                color: Color(0xFFEF5350),
                height: bottomRowHeight,
              ),
            ),
            const SizedBox(width: 16),

            // جدول النطاق
            Expanded(
              child: _buildLevelsSummaryTableContent(height: bottomRowHeight),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // جدول النطاق (تم حل مشكلة الارتفاع هنا)
  // ==========================================
  Widget _buildLevelsSummaryTableContent({required double height}) {
    return SizedBox(
      height: height, // استخدام الارتفاع الجديد (380)
      child: Card(
        elevation: 1.5,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Column(
            children: [
              // ترويسة الجدول
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
                        'النطاق',
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

              // الصفوف (يوجد هنا Expanded ليأخذ المساحة المتاحة كاملة)
              Expanded(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceEvenly, // توزيع المسافات بالتساوي
                  children: [
                    _buildNitaqRow(
                      'ممتاز',
                      '60 - 54',
                      '10',
                      const Color(0xFF2EAD8B),
                    ),
                    _buildNitaqRow(
                      'جيد جداً',
                      '53 - 46',
                      '14',
                      const Color(0xFF2979FF),
                    ),
                    _buildNitaqRow(
                      'جيد',
                      '45 - 36',
                      '6',
                      const Color(0xFF7E57C2),
                    ),
                    _buildNitaqRow(
                      'مقبول',
                      '35 - 24',
                      '6',
                      const Color(0xFFFFA726),
                    ),
                    _buildNitaqRow(
                      'ضعيف',
                      '23 - 0',
                      '1',
                      const Color(0xFFEF5350),
                    ),
                  ],
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
          // زر المستوى
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: 8,
              ), // زيادة البادينغ قليلاً
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
          // النطاق
          Expanded(
            flex: 2,
            child: Text(
              range,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          // العدد
          Expanded(
            flex: 1,
            child: Text(
              count,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // -----------------------------
  // الرسوم البيانية في الأسفل
  Widget _buildBottomChartsOnly() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // الدائرة (يمين)
        Expanded(flex: 2, child: _buildAchievementDonut()),
        const SizedBox(width: 20),
        // الأعمدة (يسار)
        Expanded(flex: 3, child: _buildDetailedVerticalBarChart()),
      ],
    );
  }

  // ==========================================
  // الشارت العمودي
  // ==========================================
  Widget _buildDetailedVerticalBarChart() {
    final data = [
      {'label': 'ضعيف', 'value': 1, 'color': const Color(0xFFEF5350)},
      {'label': 'مقبول', 'value': 6, 'color': const Color(0xFFFFA726)},
      {'label': 'جيد', 'value': 6, 'color': const Color(0xFF7E57C2)},
      {'label': 'جيد جدا', 'value': 6, 'color': const Color(0xFF5C6BC0)},
      {'label': 'ممتاز', 'value': 10, 'color': const Color(0xFF2EAD8B)},
    ];

    const int maxValueY = 12;
    const int step = 2;

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
                  // المحور الصادي
                  SizedBox(
                    width: yAxisWidth,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate((maxValueY / step).floor() + 1, (
                        index,
                      ) {
                        int labelValue = maxValueY - (index * step);
                        return SizedBox(
                          height: 20,
                          child: Text(
                            '$labelValue',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 11,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // منطقة الرسم
                  Expanded(
                    child: Stack(
                      children: [
                        // خطوط الخلفية
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(
                            (maxValueY / step).floor() + 1,
                            (index) {
                              return Container(
                                height: 20,
                                alignment: Alignment.center,
                                child: Divider(
                                  color: Colors.grey[200],
                                  thickness: 1,
                                ),
                              );
                            },
                          ),
                        ),

                        // الأعمدة
                        Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: data.map((item) {
                              final int val = item['value'] as int;
                              final double percentage = val / maxValueY;

                              return Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    '$val',
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
                                      fontSize: 11,
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

  // الدائرة
  Widget _buildAchievementDonut() {
    final segments = [
      _DonutSegment('ممتاز', 25, const Color(0xFF00C853)),
      _DonutSegment('جيد جدًا', 30, const Color(0xFF2979FF)),
      _DonutSegment('جيد', 16, const Color(0xFF7E57C2)),
      _DonutSegment('مقبول', 16, const Color(0xFFFFA726)),
      _DonutSegment('ضعيف', 3, const Color(0xFFEF5350)),
    ];

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
                    painter: _DonutPainter(segments),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        '72.1%',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'الإتقان',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
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
                        Text(e.label, style: const TextStyle(fontSize: 11)),
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

// ===================================================================
// Widgets مساعدة

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
  final double height; // تم إضافة هذا المتغير للتحكم بالارتفاع

  const _LevelStudentsCard({
    required this.title,
    required this.color,
    this.height = 280, // القيمة الافتراضية
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height, // استخدام الارتفاع الممرر
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
                          flex: 2,
                          child: Text(
                            'الصف',
                            textAlign: TextAlign.center,
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
                      child: title == 'ضعيف' || title == 'مقبول'
                          ? Center(
                              child: Text(
                                'لا يوجد طلاب',
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                            )
                          : ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                _StudentRow(
                                  index: 1,
                                  name: 'حسن بن احمد بن حسن',
                                  className: '-',
                                  score: '500',
                                ),
                                _StudentRow(
                                  index: 2,
                                  name: 'علي بن حسن بن احمد',
                                  className: '-',
                                  score: '500',
                                ),
                                _StudentRow(
                                  index: 3,
                                  name: 'عباس بن مصطفى',
                                  className: '-',
                                  score: '500',
                                ),
                              ],
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

class _StudentRow extends StatelessWidget {
  final int index;
  final String name;
  final String className;
  final String score;
  const _StudentRow({
    required this.index,
    required this.name,
    required this.className,
    required this.score,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              index.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              name,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              className,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              score,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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
  _DonutPainter(this.segments);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 22;
    const double strokeWidth = 22;
    final basePaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth - 6
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, basePaint);
    double startAngle = -pi / 2;
    const double total = 100;
    for (final segment in segments) {
      final sweepAngle = (segment.percent / total) * 2 * pi;
      final outerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 2
        ..strokeCap = StrokeCap.round
        ..color = segment.color.withOpacity(0.85);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        outerPaint,
      );
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
      final angle = startAngle + sweepAngle / 2;
      final labelOffset = Offset(
        center.dx + (radius + 35) * cos(angle),
        center.dy + (radius + 35) * sin(angle),
      );
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${segment.percent.toInt()}%',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: segment.color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        labelOffset - Offset(textPainter.width / 2, textPainter.height / 2),
      );
      startAngle += sweepAngle;
    }
    final innerShadowPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.transparent, Colors.black.withOpacity(0.1)],
        stops: const [5.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, innerShadowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
