import 'package:flutter/material.dart';
import 'package:student_grades_app/core/utils/number_utils.dart'; // Ensure this path is correct

class HorizontalRulerChart extends StatelessWidget {
  final List<RulerLevelItem> items;
  final int maxCount;

  const HorizontalRulerChart({
    super.key,
    required this.items,
    required this.maxCount,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(
        height: 50,
        child: Center(
          child: Text('لا توجد بيانات', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    // Determine the step for the ruler (e.g., 0, 5, 10, 15...)
    // We want about 5-8 ticks.
    int step = 5;
    if (maxCount > 50) step = 10;
    if (maxCount > 100) step = 20;
    if (maxCount <= 10) step = 1;

    // Calculate max value for the scale (slightly larger than maxCount)
    int maxValue = ((maxCount / step).ceil() * step);
    if (maxValue == 0) maxValue = step; // Prevent division by zero
    if (maxValue < maxCount) maxValue += step; // Ensure it covers the max

    return Column(
      children: [
        // 1. The Bars
        ...items.map((item) => _buildBarRow(context, item, maxValue)).toList(),

        const SizedBox(height: 12),

        // 2. The Ruler Scale
        _buildRulerScale(maxValue, step),
      ],
    );
  }

  Widget _buildBarRow(BuildContext context, RulerLevelItem item, int maxValue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16), // Increased spacing
      child: Row(
        children: [
          // Label (e.g. Excellent)
          SizedBox(
            width: 50,
            child: Text(
              item.label,
              style: const TextStyle(
                fontSize: 13, // Increased from 11
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),

          // The Bar Area
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double maxWidth = constraints.maxWidth;
                final double percentage = (item.count / maxValue).clamp(
                  0.0,
                  1.0,
                );
                final double barWidth = maxWidth * percentage;

                return Stack(
                  alignment: Alignment.centerRight,
                  clipBehavior: Clip.none,
                  children: [
                    // Background Line
                    Container(
                      height: 1,
                      width: double.infinity,
                      color: Colors.grey.withOpacity(0.1),
                    ),

                    // Animated Bar
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutQuart,
                      tween: Tween<double>(begin: 0, end: barWidth),
                      builder: (context, val, child) {
                        return Container(
                          height: 25, // Increased thickness here
                          width: val,
                          decoration: BoxDecoration(
                            color: item.color,
                            borderRadius: BorderRadius.circular(
                              6,
                            ), // Adjusted radius
                          ),
                        );
                      },
                    ),

                    // Indicator Circle & Text
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutQuart,
                      tween: Tween<double>(begin: 0, end: barWidth),
                      builder: (context, val, child) {
                        return Positioned(
                          right: val - (val > 0 ? 0 : -8), // Adjusted position
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // The Circle Indicator
                              Container(
                                width: 20, // Increased from 14
                                height: 20, // Increased from 14
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: item.color,
                                    width: 3, // Maintains proportion
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: item.color.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              // The Count Number
                              Text(
                                item.count.toString().toAppNum(),
                                style: TextStyle(
                                  fontSize: 14, // Increased from 11
                                  fontWeight: FontWeight.bold,
                                  color: item.color,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulerScale(int maxValue, int step) {
    List<int> ticks = [];
    for (int i = 0; i <= maxValue; i += step) {
      ticks.add(i);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalWidth = constraints.maxWidth;
        return Row(
          children: [
            const SizedBox(width: 58),
            Expanded(
              child: SizedBox(
                height: 30,
                child: Stack(
                  children: ticks.map((val) {
                    final double percentage = (val / maxValue).clamp(0.0, 1.0);
                    final double position = totalWidth * percentage;

                    return Positioned(
                      right: position,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 1,
                            height: 8, // Slightly taller tick
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            val.toString().toAppNum(),
                            style: TextStyle(
                              fontSize: 12, // Increased from 9
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold,
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
        );
      },
    );
  }
}

class RulerLevelItem {
  final String label;
  final int count;
  final Color color;

  RulerLevelItem({
    required this.label,
    required this.count,
    required this.color,
  });
}
