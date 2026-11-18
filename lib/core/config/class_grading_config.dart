// lib/class_grading_config.dart
//========== صفحة اعداد الدرجات ==========//
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// أنواع التقييم المتاحة
enum GradeType { numeric, checkbox, numericList, averagePair }

// تعريف العمود (مهمة أو اختبار)
class GradeColumn {
  String id;
  String name; // الاسم الظاهر في الجدول (مثلاً: تطبيق الفقه 1)
  String tag; // التعديل الجديد: التصنيف الموحد (مثلاً: واجبات، اختبارات)
  GradeType type;
  double maxScore;
  int subCount; // عدد الخانات (للمربعات أو القوائم)
  bool isPerformanceTask; // هل تحسب ضمن المهام الأدائية؟

  GradeColumn({
    required this.id,
    required this.name,
    this.tag = 'عام', // القيمة الافتراضية للتصنيف
    required this.type,
    this.maxScore = 10.0,
    this.subCount = 5,
    this.isPerformanceTask = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'tag': tag, // حفظ التصنيف
    'type': type.index,
    'maxScore': maxScore,
    'subCount': subCount,
    'isPerformanceTask': isPerformanceTask,
  };

  factory GradeColumn.fromJson(Map<String, dynamic> map) {
    return GradeColumn(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      // استرجاع التصنيف، وإذا كان قديماً (null) نضعه "عام"
      tag: map['tag'] ?? 'عام',
      type: GradeType.values[map['type'] ?? 0],
      maxScore: (map['maxScore'] as num?)?.toDouble() ?? 10.0,
      subCount: map['subCount'] ?? 5,
      isPerformanceTask: map['isPerformanceTask'] ?? false,
    );
  }
}

// إعدادات الفصل (قائمة المهام والاختبارات)
class ClassGradingConfig {
  List<GradeColumn> items = []; // المهام (واجبات، مشاركة...)
  List<GradeColumn> exams = []; // الاختبارات

  ClassGradingConfig();

  // حساب المجموع الكلي
  double getTotalMaxScore() {
    double total = 0.0;
    // جمع درجات المهام
    for (var i in items) {
      total += i.maxScore;
    }
    // جمع درجات الاختبارات
    for (var e in exams) {
      total += e.maxScore;
    }
    return total;
  }

  Map<String, dynamic> toJson() => {
    'items': items.map((e) => e.toJson()).toList(),
    'exams': exams.map((e) => e.toJson()).toList(),
  };

  factory ClassGradingConfig.fromJson(Map<String, dynamic> map) {
    final cfg = ClassGradingConfig();
    if (map['items'] != null) {
      cfg.items = (map['items'] as List)
          .map((e) => GradeColumn.fromJson(e))
          .toList();
    }
    if (map['exams'] != null) {
      cfg.exams = (map['exams'] as List)
          .map((e) => GradeColumn.fromJson(e))
          .toList();
    }
    return cfg;
  }

  // حفظ الإعدادات لصف معين
  Future<void> save(String classId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('class_config_$classId', jsonEncode(toJson()));
  }

  // تحميل الإعدادات لصف معين
  static Future<ClassGradingConfig> load(String classId) async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('class_config_$classId');
    if (str != null) {
      return ClassGradingConfig.fromJson(jsonDecode(str));
    }
    return ClassGradingConfig(); // إرجاع إعدادات افتراضية
  }
}

// === إضافة جديدة: إدارة قائمة التصنيفات الموحدة (Tags) ===
// هذه الكلاس ستساعدنا في حفظ القائمة المنسدلة لتظهر في كل الفصول
class GlobalGradingTags {
  static const String _kTagsKey = 'global_grading_tags_list';

  // القائمة الافتراضية للبدء
  static const List<String> defaultTags = [
    'واجبات',
    'مشاركة',
    'حفظ',
    'اختبار فترة',
    'اختبار نهائي',
    'القراءة',
    'إملاء',
    'سلوك',
  ];

  // تحميل قائمة التاقات المحفوظة، أو إرجاع الافتراضي
  static Future<List<String>> loadTags() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? saved = prefs.getStringList(_kTagsKey);
    if (saved == null || saved.isEmpty) {
      return defaultTags;
    }
    return saved;
  }

  // حفظ قائمة تاقات جديدة (عند إضافة المستخدم تصنيفاً جديداً)
  static Future<void> saveTags(List<String> tags) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kTagsKey, tags);
  }
}
