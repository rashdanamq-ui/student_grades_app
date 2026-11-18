//= ملف شريط الفلترة =//

import 'package:flutter/material.dart';
import '../../../core/utils/number_utils.dart';

class AnalysisFilterBar extends StatelessWidget {
  final List<String> examTags; // قائمة التاقات
  final String selectedTag; // التاق المختار حالياً
  final bool useSum; // هل نستخدم المجموع أم النسبة؟
  final Function(String) onTagSelected; // عند تغيير التاق
  final Function(bool) onToggleSum; // عند تغيير السويتش

  const AnalysisFilterBar({
    super.key,
    required this.examTags,
    required this.selectedTag,
    required this.useSum,
    required this.onTagSelected,
    required this.onToggleSum,
  });

  @override
  Widget build(BuildContext context) {
    // استخراج التاقات الفريدة
    final uniqueTags = examTags
        .where((t) => t.trim().isNotEmpty)
        .toSet()
        .toList();
    final options = ['Comprehensive', ...uniqueTags];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.shade50, // شريط العلوي تحليل مرحلة بلون الاخضار كان
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        children: [
          const Text(
            'اختر المهارة/التاق للتحليل',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 8),

          // السويتش (عرض المجموع / النسبة)
          SwitchListTile(
            title: Text(
              useSum ? 'عرض المجموع' : 'عرض النسبة المئوية',
              style: const TextStyle(fontSize: 12),
            ),
            value: useSum,
            onChanged: onToggleSum,
            dense: true,
            activeColor: Colors.teal,
          ),

          // شريط التاقات
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: options.map((tag) {
                String label = tag == 'Comprehensive' ? 'شامل (الكل)' : tag;
                bool isSelected = selectedTag == tag;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(
                      label.toAppNum(),
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: Colors.teal,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 0,
                    ),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                    onSelected: (_) => onTagSelected(tag),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
