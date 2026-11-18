import 'package:flutter/material.dart';
import 'package:student_grades_app/core/utils/number_utils.dart';

class WaveBarChart extends StatelessWidget {
  final List<WaveLevelItem> items;
  final int maxCount;
  final double height;

  const WaveBarChart({
    super.key,
    required this.items,
    required this.maxCount,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('لا توجد بيانات', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.stretch, // Changed to stretch to fill height
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: items.map((item) {
          // Calculate height percentage
          final double percentage = (maxCount == 0)
              ? 0.0
              : (item.count / maxCount).clamp(0.0, 1.0);

          return _buildWaveBarColumn(context, item, percentage);
        }).toList(),
      ),
    );
  }

  Widget _buildWaveBarColumn(
    BuildContext context,
    WaveLevelItem item,
    double percentage,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // The Animated Wave Bar
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double maxHeight = constraints.maxHeight;
              final double targetHeight = maxHeight * percentage;

              return Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // Gray Background (Track) with Wave Shape
                  SizedBox(
                    width: 50,
                    height: double.infinity,
                    child: CustomPaint(
                      painter: _WaveBarPainter(
                        color: const Color.fromARGB(235, 220, 223, 226),
                        progress: 1.0,
                      ),
                    ),
                  ),

                  // The Wave Bar Overlay
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.elasticOut,
                    tween: Tween<double>(begin: 0, end: targetHeight),
                    builder: (context, val, child) {
                      // Start from 0 height
                      if (val <= 0) return const SizedBox.shrink();

                      return SizedBox(
                        width: 50, // Fixed width for the bar
                        height: val,
                        child: CustomPaint(
                          painter: _WaveBarPainter(
                            color: item.color,
                            progress: 1.0,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // Level Label (e.g., Excellent)
        Text(
          item.label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        // Count (e.g., 12)
        Text(
          item.count.toString().toAppNum(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: item.color,
          ),
        ),
      ],
    );
  }
}

class _WaveBarPainter extends CustomPainter {
  final Color color;
  final double progress;

  _WaveBarPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0) return;

    final Paint paint = Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(0.6), color],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();

    // Start from bottom left
    path.moveTo(0, size.height);

    // Line to top left (start of wave)
    // We leave some space for the wave crest
    // Let's make the wave be the top 10-15 pixels depending on height
    // Actually, let's draw a sine wave at the top.

    double waveHeight = 10.0;
    if (size.height < 20) waveHeight = size.height * 0.3;

    path.lineTo(0, waveHeight);

    // Cubic Bezier for the wave
    // Control point 1: Up and right
    // Control point 2: Down and right
    // End point: Top right side

    // Simple hump shape
    path.quadraticBezierTo(
      size.width / 2,
      -waveHeight *
          0.5, // Control point roughly above center (negative Y is up)
      size.width,
      waveHeight, // End point at right side
    );

    // Line to bottom right
    path.lineTo(size.width, size.height);

    // Close
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WaveBarPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.progress != progress;
  }
}

class WaveLevelItem {
  final String label;
  final int count;
  final Color color;

  WaveLevelItem({
    required this.label,
    required this.count,
    required this.color,
  });
}
