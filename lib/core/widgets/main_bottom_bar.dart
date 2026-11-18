// lib/widgets/main_bottom_bar.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // للهزاز الخفيف (HapticFeedback)

class MainBottomBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onIndexChange;
  final VoidCallback onHomeTap;
  final VoidCallback onFileTap;
  final VoidCallback onContactTap;
  final VoidCallback onHelpTap;

  const MainBottomBar({
    super.key,
    required this.currentIndex,
    required this.onIndexChange,
    required this.onHomeTap,
    required this.onFileTap,
    required this.onContactTap,
    required this.onHelpTap,
  });

  @override
  Widget build(BuildContext context) {
    // نستخدم SafeArea لضمان عدم التصاق الشريط بحافة أجهزة الآيفون الحديثة
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 5), // هوامش جانبية وسفلية ليبدو طافياً
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25), // زوايا دائرية ناعمة
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // تأثير الزجاج
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                // لون أبيض شفاف جداً
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(25),
                // حدود بيضاء خفيفة
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(
                    context,
                    index: 0,
                    icon: Icons.home_rounded,
                    label: 'الرئيسية',
                    onTap: onHomeTap,
                  ),
                  _buildNavItem(
                    context,
                    index: 1,
                    icon: Icons.folder_copy_rounded,
                    label: 'الملفات',
                    onTap: onFileTap,
                  ),
                  _buildNavItem(
                    context,
                    index: 2,
                    icon: Icons.mail_rounded,
                    label: 'تواصل',
                    onTap: onContactTap,
                  ),
                  _buildNavItem(
                    context,
                    index: 3,
                    icon: Icons.help_outline_rounded,
                    label: 'مساعدة',
                    onTap: onHelpTap,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact(); // هزاز خفيف عند الضغط
        onIndexChange(index);
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuint,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 20 : 10,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          // إذا تم الاختيار، تصبح الخلفية بيضاء، وإلا شفافة
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 26,
              // إذا تم الاختيار، الأيقونة تأخذ لون الثيم (بنفسجي/أزرق)، وإلا تكون بيضاء
              color: isSelected ? const Color(0xFF4A00E0) : Colors.white70,
            ),

            // إظهار النص فقط عند الاختيار
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF4A00E0),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}