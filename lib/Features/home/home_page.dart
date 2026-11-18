// lib/home_page.dart

import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_grades_app/Features/analysis/modern/modern_stage_analysis_page.dart';
import 'package:student_grades_app/Features/grading/generic_class_page_v2.dart';
import '../../core/config/class_grading_config.dart';
import 'package:student_grades_app/Features/analysis/multi_class_analysis_page.dart';
import 'package:student_grades_app/Features/analysis/stage_analysis_dashboard_page.dart';

import '../../core/settings/app_settings.dart';
import '../../core/utils/number_utils.dart';
import '../../services/backup_service.dart';

// ✅✅✅ استيراد الصفحتين (القديمة والجديدة) ✅✅✅
import 'package:student_grades_app/Features/analysis/mock_exam_analysis_v2 _page.dart';
import 'package:student_grades_app/Features/analysis/mock_exam_analysis_page.dart';
import '../grading/generic_class_page.dart';
import '../security/security/secure_services.dart';
import '../security/security/security_settings_page.dart';
import '../../core/widgets/main_bottom_bar.dart';
import '../../core/widgets/app_dialogs.dart';
import '../grading/mock_exam_page.dart';
import '../security/lock_screen.dart';

// أضف هذه الأسطر في الأعلى مع بقية الـ imports
import '../analysis/modern/modern_class_analysis_page.dart';
import '../analysis/modern/modern_stage_analysis_page.dart';
import '../analysis/modern/modern_multi_mock_page.dart';
import '../analysis/modern/modern_mock_skill_page.dart'; // الصفحة الثالثة

// ================== الموديلات ==================
class BaseCardConfig {
  String emoji;
  String title;
  String subtitle;
  bool visible;
  BaseCardConfig({
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.visible = true,
  });
  Map<String, dynamic> toJson() => {
    'emoji': emoji,
    'title': title,
    'subtitle': subtitle,
    'visible': visible,
  };
  factory BaseCardConfig.fromJson(Map<String, dynamic> m) => BaseCardConfig(
    emoji: m['emoji'] ?? '📘',
    title: m['title'] ?? '',
    subtitle: m['subtitle'] ?? '',
    visible: m['visible'] is bool ? m['visible'] : true,
  );
}

class ExtraClassItem {
  final String id;
  String title;
  String subtitle;
  String emoji;
  ExtraClassItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.emoji,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'emoji': emoji,
  };
  factory ExtraClassItem.fromJson(Map<String, dynamic> m) => ExtraClassItem(
    id: m['id'] ?? '',
    title: m['title'] ?? '',
    subtitle: m['subtitle'] ?? '',
    emoji: m['emoji'] ?? '📘',
  );
}

class MockClassItem {
  final String id;
  String displayTitle;
  String examTitle;
  String emoji;
  String subtitle;
  MockClassItem({
    required this.id,
    required this.displayTitle,
    required this.examTitle,
    required this.emoji,
    required this.subtitle,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'displayTitle': displayTitle,
    'examTitle': examTitle,
    'emoji': emoji,
    'subtitle': subtitle,
  };
  factory MockClassItem.fromJson(Map<String, dynamic> m) => MockClassItem(
    id: m['id'] ?? '',
    displayTitle: m['displayTitle'] ?? (m['title'] ?? ''),
    examTitle: m['examTitle'] ?? (m['title'] ?? ''),
    emoji: m['emoji'] ?? '📝',
    subtitle: m['subtitle'] ?? '',
  );
}

// ================== الصفحة الرئيسية ==================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

// ================== الشريط الجديد ==================
class ModernSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onAdd;
  final VoidCallback onSave;
  final VoidCallback? onDelete;
  const ModernSectionHeader({
    super.key,
    required this.title,
    required this.onAdd,
    required this.onSave,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final deleteButton = onDelete == null
        ? null
        : _MiniActionButton(
            icon: Icons.delete_outline,
            color: Colors.redAccent.shade100,
            tooltip: 'حذف',
            onTap: onDelete!,
          );

    final buttonGroup = ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (deleteButton != null) ...[deleteButton, _VerticalDivider()],
              _MiniActionButton(
                icon: Icons.save_alt,
                color: Colors.white70,
                tooltip: 'حفظ',
                onTap: onSave,
              ),
              _VerticalDivider(),
              InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.add, size: 18, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        "إضافة",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final titleWidget = Row(
      children: [
        Container(
          width: 4,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        children: [
          titleWidget,
          const Spacer(flex: 1),
          buttonGroup,
          const Spacer(flex: 20),
        ],
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _MiniActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    icon: Icon(icon, size: 20, color: color),
    tooltip: tooltip,
    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    style: IconButton.styleFrom(padding: EdgeInsets.zero),
  );
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 16,
    width: 1,
    color: Colors.white30,
    margin: const EdgeInsets.symmetric(horizontal: 2),
  );
}

// ================== حالة الصفحة الرئيسية ==================

class _HomePageState extends State<HomePage> {
  static const _classesKey = 'home_extra_classes_v2';
  static const _baseClassesKey = 'home_base_classes_cfg_v1';
  static const _mockClassesKey = 'home_mock_classes_v1';

  int _bottomIndex = 0;
  bool _isLoading = false;

  bool _isSelectionMode = false;
  final Set<String> _selectedClassIds = {}; // لتخزين معرفات الفصول المختارة
  final Map<String, String> _selectedClassTitles = {}; // لتخزين أسماء الفصول

  final List<ExtraClassItem> _extraClasses = [];
  final List<MockClassItem> _mockClasses = [];

  final TextEditingController _mockClassController = TextEditingController();
  final TextEditingController _mockExamTitleController =
      TextEditingController();
  final TextEditingController _mockSubtitleController = TextEditingController();

  final Map<String, BaseCardConfig> _baseClassesConfig = {};
  final List<String> _emojiChoicesClasses = [
    '📚',
    '📘',
    '📗',
    '📙',
    '🧮',
    '🧑‍🏫',
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _loadHomeExtras().then((_) {
      _ensureBaseCardsExist();
      if (mounted) setState(() {});
    });
  }

  // دوال التهيئة
  Future<void> _initFourth5DynamicIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('class_config_c5')) return;
    final config = ClassGradingConfig();
    config.items.addAll([
      GradeColumn(
        id: 'homework',
        name: 'الواجبات',
        tag: 'واجبات',
        type: GradeType.checkbox,
      ),
      GradeColumn(
        id: 'participation',
        name: 'المشاركة',
        tag: 'مشاركة',
        type: GradeType.checkbox,
      ),
      GradeColumn(
        id: 'hifz',
        name: 'الحفظ',
        tag: 'تطبيقات',
        type: GradeType.checkbox,
      ),
      GradeColumn(
        id: 'read',
        name: 'القراءة',
        tag: 'القراءة',
        type: GradeType.numericList,
      ),
      GradeColumn(
        id: 'imla',
        name: 'الإملاء',
        tag: 'الإملاء',
        type: GradeType.numericList,
      ),
    ]);
    config.exams.addAll([
      GradeColumn(
        id: 'exam_avg',
        name: 'اختبار الفترة',
        tag: 'اختبار قصير',
        type: GradeType.averagePair,
        maxScore: 20,
      ),
      GradeColumn(
        id: 'final',
        name: 'النهائي',
        tag: 'اختبار نهائي',
        type: GradeType.numeric,
        maxScore: 40,
      ),
    ]);
    await config.save('c5');
    if (!prefs.containsKey('class_students_c5')) {
      await prefs.setString(
        'class_students_c5',
        jsonEncode(
          [
            "أحمد بن محمد بن احمد آل قريش",
            "أمير بن عبدالعزيز بن مهدي السيهاتي",
            "احمد بن هاشم بن احمد العرادي",
            "حسن بن احمد بن حسن الستاروه",
            "حسن بن علي بن أحمد الحجاب",
            "حسن بن مؤيد بن حسن الفرحان",
            "حسين بن ايمن بن حسين آل درويش",
            "حسين بن علي بن عبدالله الشهاب",
            "حيدر بن علي بن صالح آل درويش",
            "دانيال بن احمد بن حسين آل مبارك",
            "رضا بن محمد بن عبد الله النمر",
            "سجاد بن بلال بن سلمان المحمد",
            "صادق بن مصطفى بن صالح آل عمران",
            "صالح بن ناصر بن صالح آل درويش",
            "عباس بن مصطفى بن عدنان العلويات",
            "عبدالعزيز بن حسين بن علي آل مدن",
            "عبدالله بن حسين بن احمد آل متعب",
            "عبدالله بن محمد بن عبدالله المسبح",
            "عبدالله محمد بن حمزه الزيداني",
            "علي بن احمد بن حبيب المدلوح",
            "علي بن حسين بن احمد الدلي",
            "علي بن حسين بن عبدالجليل العلي",
            "علي بن ناصر بن حسن آل رميح",
            "عمر حسن محمود السراقبي",
            "غسان بن ميثم بن احمد آل براك",
            "فارس بن عبدالاله بن عيسى آل إسماعيل",
            "فارس بن عبدالله بن أحمد آل زواد",
            "كرار بن حسين بن محمد السيهاتي",
            "كرار حسين علي القلاف",
            "ماهر بن غازي بن مهدي المحروس",
            "محمد بن حبيب بن محمد الحايك",
            "محمد بن علي بن ابراهيم النحوى",
            "مهدي ابراهيم حسين السلمان",
            "مهدي بن احمد بن غازي بخيت",
            "مهدي بن حسين بن سعيد آل مزعل",
            "هادي بن عبد الله بن خير الله المؤمن",
            "يوسف بن قاسم بن حسن المطوع",
          ].map((n) => {'name': n, 'isSelected': false}).toList(),
        ),
      );
    }
  }

  Future<void> _initFourth6DynamicIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('class_config_c6')) return;
    final config = ClassGradingConfig();
    config.items.addAll([
      GradeColumn(
        id: 'homework',
        name: 'الواجبات',
        tag: 'واجبات',
        type: GradeType.checkbox,
      ),
      GradeColumn(
        id: 'participation',
        name: 'المشاركة',
        tag: 'مشاركة',
        type: GradeType.checkbox,
      ),
      GradeColumn(
        id: 'hifz',
        name: 'الحفظ',
        tag: 'الحفظ',
        type: GradeType.checkbox,
      ),
      GradeColumn(
        id: 'read',
        name: 'القراءة',
        tag: 'القراءة',
        type: GradeType.numericList,
      ),
      GradeColumn(
        id: 'imla',
        name: 'الإملاء',
        tag: 'الإملاء',
        type: GradeType.numericList,
      ),
    ]);
    config.exams.addAll([
      GradeColumn(
        id: 'exam_avg',
        name: 'اختبار الفترة',
        tag: 'اختبار قصير',
        type: GradeType.averagePair,
        maxScore: 20,
      ),
      GradeColumn(
        id: 'final',
        name: 'النهائي',
        tag: 'اختبار نهائي',
        type: GradeType.numeric,
        maxScore: 40,
      ),
    ]);
    await config.save('c6');
    if (!prefs.containsKey('class_students_c6')) {
      await prefs.setString(
        'class_students_c6',
        jsonEncode(
          [
            "أحمد بن محمد بن سعود المسكين",
            "أمير بن مازن بن عبدالكريم المسبح",
            "باقر بن كامل بن سلمان آل زاهر",
            "جواد بن محمد بن محيسن النخلي",
            "حسن بن مجتبى بن حسين السيهاتي",
            "حسن بن محمد بن منصور مسلم",
            "حسين بن خليل بن ابراهيم القطان",
            "حسين بن هاني بن عبدالله البن سعد",
            "دانيال بن محمد بن زهير الشهاب",
            "ريان عبدالمعين مكي الجنبي",
            "صادق بن محمد بن خير الله المؤمن",
            "عباس بن اسامه بن حسن الخليفه",
            "عباس بن فاضل بن عباس الساده",
            "عبدالله بن أنور بن أحمد آل حمد",
            "عبدالعزيز بن طارق بن محمد بوصالح",
            "عبدالله بن علي بن ابراهيم الخليفه",
            "عبدالله منتظر عبدالله آل راشد",
            "علي أحم مكي آل عمران",
            "علي بن حسين بن ابراهيم المقداد",
            "علي بن حسين بن هلال البيابي",
            "علي بن حسين بن يوسف البدر",
            "علي بن محمد بن حسن الجفال",
            "علي بن نجيب بن احمد الحلوه",
            "فارس بن فاضل بن عباس المحسن",
            "قيس علاء حسن رسلان",
            "كرار علي بن قاسم آل بشير",
            "مازن زياد عبدالكريم القاسم",
            "محسن بن احمد بن عبدالواحد العسيف",
            "محمد بن حمد بن عبد الكريم المؤمن",
            "محمد بن عبدالله بن حسن الزاكي",
            "محمد بن كفاح بن عبد الله الدحبوس",
            "مختار بن عبد العزيز بن خليل الراشد",
            "مصطفى بن حسن بن عبد المجيد المسكين",
            "مهدي بن سجاد بن منصور الجشي",
            "يوسف إبراهيم محمد",
            "يوسف بن مصطفى بن أحمد الماجد",
          ].map((n) => {'name': n, 'isSelected': false}).toList(),
        ),
      );
    }
  }

  Future<void> _initFourth7DynamicIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey('class_config_c7')) return;
    final config = ClassGradingConfig();
    config.items.addAll([
      GradeColumn(
        id: 'homework',
        name: 'الواجبات',
        tag: 'واجبات',
        type: GradeType.checkbox,
      ),
      GradeColumn(
        id: 'participation',
        name: 'المشاركة',
        tag: 'مشاركة',
        type: GradeType.checkbox,
      ),
      GradeColumn(
        id: 'hifz',
        name: 'الحفظ',
        tag: 'الحفظ',
        type: GradeType.checkbox,
      ),
      GradeColumn(
        id: 'read',
        name: 'القراءة',
        tag: 'القراءة ',
        type: GradeType.numericList,
      ),
      GradeColumn(
        id: 'imla',
        name: 'الإملاء',
        tag: 'الإملاء',
        type: GradeType.numericList,
      ),
    ]);
    config.exams.addAll([
      GradeColumn(
        id: 'exam_avg',
        name: 'اختبار الفترة',
        tag: 'اختبار قصير',
        type: GradeType.averagePair,
        maxScore: 20,
      ),
      GradeColumn(
        id: 'final',
        name: 'النهائي',
        tag: 'اختبار نهائي',
        type: GradeType.numeric,
        maxScore: 40,
      ),
    ]);
    await config.save('c7');
    if (!prefs.containsKey('class_students_c7')) {
      await prefs.setString(
        'class_students_c7',
        jsonEncode(
          [
            "أحمد بن حسن بن أحمد الزواد",
            "أحمد بن مصطفى بن احمد العبدالعظيم",
            "أمين بن عبدالحكيم بن توفيق المسكين ",
            "باسل بن منصور بن سعود المبارك",
            "جواد بن مراد بن علي ال عيسى",
            "حسن بن محمد بن حسن الحلال",
            "حسين بن حبيب بن منصور المسكين",
            "حسين  سلمان  حسن العبدرب الرضا",
            "حمزة بن محمد بن حسن الغانم",
            "حمزة إسلام محمد شونه",
            "حيدر بن سامي بن عبدالله آل سعدون",
            "حيدر بن عبدالهادي بن عبدالله القويعي",
            "رشاد بن هاني بن صالح الزواد",
            "سجاد بن فاضل بن عباس آل شويخات",
            "صالح بن عبد الله بن صالح الصقر",
            "عبد العزيز بن جاسم بن علي الشايب",
            "عبدالعزيز بن علي بن صالح آل زواد",
            "عبدالله علي طاهر آل جعفر",
            "عبدالله مهدي عبدالله آل منيان",
            "عبدالمجيد بن علي بن عبدالله بن صالح",
            "علي بن حسن بن خليفه الدبيان",
            "علي بن حسن بن مهدي آل فردان",
            "علي بن خليل بن ابراهيم الراشد",
            "علي بن سلمان بن حسن العبدرب الرضا",
            "علي بن محمد بن احمد العباس",
            "علي بن نذير بن إبراهيم الناصر",
            "علي يعقوب بن يوسف الباشا",
            "قاسم بن يوسف بن علي المقابي",
            "مجتبى بن خليل بن منصور آل درويش",
            "محمد بن أسامه بن حسن الغانم",
            "محمد بن علي بن عبدالرزاق آل غريب",
            "محمد بن مصطفى بن محسن آل قريش",
            "مختار بن رائد بن احمد مكيحيل",
            "مختار بن قاسم بن محمد القلاف",
            "مهند بن حسين بن علي أل عيد",
            "نصار بن علي بن حسن القلاف",
          ].map((n) => {'name': n, 'isSelected': false}).toList(),
        ),
      );
    }
  }

  void _ensureBaseCardsExist() {
    _getBaseClassCfg(
      keyId: 'c5',
      defaultEmoji: '📚',
      defaultTitle: 'رابع 5',
      defaultSubtitle: 'كشف متابعة الطلاب 5',
    );
    _getBaseClassCfg(
      keyId: 'c6',
      defaultEmoji: '🎒',
      defaultTitle: 'رابع 6',
      defaultSubtitle: 'كشف متابعة الطلاب 6',
    );
    _getBaseClassCfg(
      keyId: 'c7',
      defaultEmoji: '✏️',
      defaultTitle: 'رابع 7',
      defaultSubtitle: 'كشف متابعة الطلاب 7',
    );
  }

  Future<void> _loadHomeExtras() async {
    final prefs = await SharedPreferences.getInstance();
    final cStr = prefs.getString(_classesKey);
    if (cStr != null && cStr.isNotEmpty)
      try {
        _extraClasses
          ..clear()
          ..addAll(
            (jsonDecode(cStr) as List).map(
              (e) => ExtraClassItem.fromJson(Map<String, dynamic>.from(e)),
            ),
          );
      } catch (_) {}
    final mStr = prefs.getString(_mockClassesKey);
    if (mStr != null && mStr.isNotEmpty)
      try {
        _mockClasses
          ..clear()
          ..addAll(
            (jsonDecode(mStr) as List).map(
              (e) => MockClassItem.fromJson(Map<String, dynamic>.from(e)),
            ),
          );
      } catch (_) {}
    final baseCStr = prefs.getString(_baseClassesKey);
    if (baseCStr != null && baseCStr.isNotEmpty)
      try {
        final decoded = jsonDecode(baseCStr) as Map<String, dynamic>;
        _baseClassesConfig
          ..clear()
          ..addAll(
            decoded.map(
              (k, v) => MapEntry(
                k,
                BaseCardConfig.fromJson(Map<String, dynamic>.from(v)),
              ),
            ),
          );
      } catch (_) {}
    setState(() {});
  }

  Future<void> _saveHomeExtras({bool showSnack = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _classesKey,
      jsonEncode(_extraClasses.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _mockClassesKey,
      jsonEncode(_mockClasses.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      _baseClassesKey,
      jsonEncode(_baseClassesConfig.map((k, v) => MapEntry(k, v.toJson()))),
    );
    if (mounted && showSnack)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ التغييرات')));
  }

  BaseCardConfig _getBaseClassCfg({
    required String keyId,
    required String defaultEmoji,
    required String defaultTitle,
    required String defaultSubtitle,
  }) {
    return _baseClassesConfig.putIfAbsent(
      keyId,
      () => BaseCardConfig(
        emoji: defaultEmoji,
        title: defaultTitle,
        subtitle: defaultSubtitle,
      ),
    );
  }

  // =================== بناء الصفحة ===================

  // ✅✅ دالة التعامل مع تحديد الفصل
  void _toggleClassSelection(String id, String title) {
    setState(() {
      if (_selectedClassIds.contains(id)) {
        _selectedClassIds.remove(id);
        _selectedClassTitles.remove(id);
        // إذا ألغى تحديد الكل، نخرج من وضع التحديد
        if (_selectedClassIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedClassIds.add(id);
        _selectedClassTitles[id] = title;
        _isSelectionMode = true; // تفعيل الوضع
      }
    });
  }

  // ✅✅ الخروج من وضع التحديد
  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedClassIds.clear();
      _selectedClassTitles.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // ✅ استخدام PopScope للتعامل مع زر الرجوع في الأندرويد
    return PopScope(
      canPop:
          !_isSelectionMode, // إذا كان في وضع التحديد، لا يغلق التطبيق بل يلغي التحديد
      onPopInvoked: (didPop) {
        if (!didPop && _isSelectionMode) {
          _exitSelectionMode();
        }
      },
      child: ValueListenableBuilder<bool>(
        valueListenable: AppSettings.useArabicNumbers,
        builder: (context, isArabic, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              extendBody: true,
              extendBodyBehindAppBar: true,
              backgroundColor: Colors.transparent,

              appBar: AppBar(
                toolbarHeight: 60,
                // ✅ تغيير العنوان عند وضع التحديد
                title: _isSelectionMode
                    ? Text(
                        '${_selectedClassIds.length} محدد'.toAppNum(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'راصد الدرجات 👋'.toAppNum(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'نظام متابعة الطلاب الذكي'.toAppNum(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                centerTitle: false,
                backgroundColor: _isSelectionMode
                    ? Colors.black.withOpacity(0.5)
                    : Colors.transparent,
                elevation: 0,
                leading: _isSelectionMode
                    ? IconButton(
                        onPressed: _exitSelectionMode,
                        icon: const Icon(Icons.close, color: Colors.white),
                      )
                    : null,
                actions: [
                  if (!_isSelectionMode)
                    Container(
                      margin: const EdgeInsets.all(8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                // ✅ زر فتح تحليل المرحلة
                                IconButton(
                                  tooltip: 'تحليل المرحلة'.toAppNum(),
                                  icon: const Icon(
                                    Icons.analytics,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const StageAnalysisDashboardPage(),
                                      ),
                                    );
                                  },
                                ),

                                // زر الإعدادات (كما هو)
                                IconButton(
                                  icon: const Icon(
                                    Icons.settings,
                                    color: Colors.white,
                                  ),
                                  onPressed: _showSettingsDialog,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // ✅ زر التحليل العائم
              floatingActionButton: _isSelectionMode
                  ? FloatingActionButton.extended(
                      onPressed:
                          _showSelectionAnalysisOptions, // ✅ استدعاء الدالة الجديدة
                      backgroundColor: Colors.teal,
                      icon: const Icon(Icons.analytics),
                      label: const Text('تحليل الفصول المحددة'),
                    )
                  : null,
              body: Stack(
                children: [
                  // 1. الخلفية
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF30c9cd), Color(0xFF330d69)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: -50,
                    left: -50,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -50,
                    right: -50,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),

                  // 2. المحتوى المتجاوب
                  SafeArea(
                    bottom: false,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        bool isWideScreen = constraints.maxWidth > 700;
                        if (isWideScreen) {
                          return _buildWideLayout();
                        } else {
                          return _buildNarrowLayout();
                        }
                      },
                    ),
                  ),

                  if (_isLoading)
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.black.withOpacity(0.5),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
              bottomNavigationBar: _isSelectionMode
                  ? null // إخفاء الشريط السفلي عند التحديد
                  : MainBottomBar(
                      currentIndex: _bottomIndex,
                      onIndexChange: (index) =>
                          setState(() => _bottomIndex = index),
                      onHomeTap: () {},
                      onFileTap: () => AppDialogs.showFileDialog(
                        context,
                        onExportTap: () => BackupService.exportBackup(context),
                        onImportTap: () => BackupService.importBackup(context),
                        onSettingsTap: _showSettingsDialog,
                      ),
                      onContactTap: () => AppDialogs.showContactDialog(context),
                      onHelpTap: () => AppDialogs.showInfoDialog(
                        context,
                        onRestoreHidden: _restoreHiddenClassesAndLotteries,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  // =================== بناء الواجهات الفرعية ===================
  Widget _buildNarrowLayout() {
    // ... نفس الكود الأصلي ...
    return ListView(
      padding: EdgeInsets.only(top: kToolbarHeight, bottom: 120),
      children: [
        ModernSectionHeader(
          title: 'الصفوف'.toAppNum(),
          onAdd: _showAddClassDialog,
          onSave: () => _saveHomeExtras(),
          onDelete: _extraClasses.isEmpty
              ? null
              : _showDeleteSpecificClassesDialog,
        ),
        const SizedBox(height: 5),
        _buildHorizontalClasses(), // هذا سيستخدم الدالة المعدلة تلقائياً
        const SizedBox(height: 25),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'مركز التحليل'.toAppNum(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Icon(Icons.analytics_outlined, color: Colors.white70),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildAnalysisGrid(),
        const SizedBox(height: 10),
        ModernSectionHeader(
          title: 'الاختبارات'.toAppNum(),
          onAdd: _showAddMockClassDialog,
          onSave: () => _saveHomeExtras(),
          onDelete: _mockClasses.isEmpty
              ? null
              : _showDeleteSpecificMockExamsDialog,
        ),
        const SizedBox(height: 10),
        _buildHorizontalMockExams(),
      ],
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: ListView(
            padding: EdgeInsets.only(
              top: kToolbarHeight,
              bottom: 120,
              right: 8,
              left: 8,
            ),
            children: [
              ModernSectionHeader(
                title: 'الصفوف'.toAppNum(),
                onAdd: _showAddClassDialog,
                onSave: () => _saveHomeExtras(),
                onDelete: _extraClasses.isEmpty
                    ? null
                    : _showDeleteSpecificClassesDialog,
              ),
              const SizedBox(height: 5),
              _buildHorizontalClasses(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'مركز التحليل'.toAppNum(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Icon(Icons.analytics_outlined, color: Colors.white70),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              _buildAnalysisGrid(crossAxisCount: 2, childAspectRatio: 3.0),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: ListView(
            padding: EdgeInsets.only(
              top: kToolbarHeight,
              bottom: 120,
              left: 8,
              right: 8,
            ),
            children: [
              const SizedBox(height: 20),
              ModernSectionHeader(
                title: 'الاختبارات'.toAppNum(),
                onAdd: _showAddMockClassDialog,
                onSave: () => _saveHomeExtras(),
                onDelete: _mockClasses.isEmpty
                    ? null
                    : _showDeleteSpecificMockExamsDialog,
              ),
              const SizedBox(height: 10),
              _buildHorizontalMockExams(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisGrid({
    int crossAxisCount = 2,
    double childAspectRatio = 1.8,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
        children: [
          _buildGlassAnalysisCard(
            'تحليل صف'.toAppNum(),
            Icons.pie_chart,
            Colors.blueAccent,
            _showSingleClassAnalysisDialog,
          ),
          _buildGlassAnalysisCard(
            'تحليل مرحلة'.toAppNum(),
            Icons.bar_chart,
            Colors.purpleAccent,
            _showStageAnalysisDialog,
          ),
          _buildGlassAnalysisCard(
            'مهارات (فصل)'.toAppNum(),
            Icons.assignment_turned_in,
            Colors.orangeAccent,
            _showMockClassSelectionDialog,
          ),
          _buildGlassAnalysisCard(
            'مهارات شامل'.toAppNum(),
            Icons.grid_view,
            Colors.redAccent,
            _showMultiSkillAnalysisDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildGlassAnalysisCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 28, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  title.toAppNum(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniClassCard({
    required String emoji,
    required String title,
    required VoidCallback onTap,
    required VoidCallback onEdit,
    // ✅ بارامترات جديدة للتحديد
    required VoidCallback onLongPress,
    required bool isSelected,
    required bool isSelectionMode,
  }) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress, // ✅ تفعيل الضغط المطول
              borderRadius: BorderRadius.circular(15),
              child: Container(
                width: 95,
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.teal.withOpacity(0.4)
                      : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: isSelected
                        ? Colors.tealAccent
                        : Colors.white.withOpacity(0.2),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    Text(emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        title.toAppNum(),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ✅ زر التعديل يختفي في وضع التحديد
        if (!isSelectionMode)
          Positioned(
            top: 6,
            right: 8,
            child: InkWell(
              onTap: onEdit,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, size: 12, color: Colors.white),
              ),
            ),
          ),

        // ✅ علامة الصح تظهر عند التحديد
        if (isSelected)
          const Positioned(
            top: 6,
            left: 8,
            child: Icon(Icons.check_circle, color: Colors.tealAccent, size: 20),
          ),
      ],
    );
  }

  Widget _buildHorizontalClasses() {
    final List<Widget> cards = [];
    _baseClassesConfig.forEach((key, cfg) {
      if (cfg.visible) {
        cards.add(
          _buildMiniClassCard(
            emoji: cfg.emoji,
            title: cfg.title.toAppNum(),
            // ✅ تمرير حالة التحديد
            isSelectionMode: _isSelectionMode,
            isSelected: _selectedClassIds.contains(key),
            onLongPress: () => _toggleClassSelection(key, cfg.title),

            // ✅ تعديل وظيفة الضغط العادي
            onTap: () async {
              if (_isSelectionMode) {
                _toggleClassSelection(key, cfg.title);
              } else {
                if (key == 'c5')
                  await _initFourth5DynamicIfNeeded();
                else if (key == 'c6')
                  await _initFourth6DynamicIfNeeded();
                else if (key == 'c7')
                  await _initFourth7DynamicIfNeeded();
                if (mounted)
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GenericClassPage(
                        classId: key,
                        classTitle: cfg.subtitle,
                      ),
                    ),
                  );
              }
            },
            onEdit: () => _editBaseClassGeneric(key, cfg),
          ),
        );
      }
    });

    // الفصول الإضافية
    for (int i = 0; i < _extraClasses.length; i++) {
      final c = _extraClasses[i];
      cards.add(
        _buildMiniClassCard(
          emoji: c.emoji,
          title: c.title.toAppNum(),
          isSelectionMode: _isSelectionMode,
          isSelected: _selectedClassIds.contains(c.id),
          onLongPress: () => _toggleClassSelection(c.id, c.title),
          onTap: () {
            if (_isSelectionMode) {
              _toggleClassSelection(c.id, c.title);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      GenericClassPage(classId: c.id, classTitle: c.subtitle),
                ),
              );
            }
          },
          onEdit: () => _editExtraClass(i),
        ),
      );
    }

    // زر الإضافة (نخفيه أو نعطله أثناء التحديد)
    if (!_isSelectionMode) {
      cards.add(
        InkWell(
          onTap: _showAddClassDialog,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 80,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Center(
              child: Icon(Icons.add, color: Colors.white, size: 30),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: cards,
      ),
    );
  }

  Widget _buildHorizontalMockExams() {
    if (_mockClasses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: InkWell(
          onTap: _showAddMockClassDialog,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    "إضافة اختبار محاكي",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 5,
          mainAxisSpacing: 5,
          childAspectRatio: 2.0,
        ),
        itemCount: _mockClasses.length,
        itemBuilder: (context, index) {
          final item = _mockClasses[index];
          return _buildMiniClassCard(
            emoji: item.emoji,
            title: item.displayTitle,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    MockExamPage(classId: item.id, classTitle: item.examTitle),
              ),
            ),
            onEdit: () => _editMockClass(index),
            onLongPress: () {},
            isSelected: false,
            isSelectionMode: _isSelectionMode,
          );
        },
      ),
    );
  }

  Future<void> _showSettingsDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final nameController = TextEditingController(
      text: prefs.getString('user_name') ?? '',
    );
    final emailController = TextEditingController(
      text: prefs.getString('user_email') ?? '',
    );
    final phoneController = TextEditingController(
      text: prefs.getString('user_phone') ?? '',
    );
    bool tempUseArabicNums = AppSettings.useArabicNumbers.value;
    bool hasPin = await SecureServices.hasPin();

    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('الإعدادات'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'البيانات الشخصية',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم المعلم',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(
                        labelText: 'رقم الجوال',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'إعدادات عامة',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('الأرقام العربية (١٢٣)'),
                      subtitle: const Text('تفعيل الأرقام العربية'),
                      value: tempUseArabicNums,
                      activeThumbColor: Colors.teal,
                      onChanged: (value) {
                        setStateDialog(() {
                          tempUseArabicNums = value;
                        });
                      },
                    ),

                    SwitchListTile(
                      title: const Text('واجهة التحليل الحديثة (Modern)'),
                      subtitle: const Text(
                        'تفعيل التصميم الجديد للرسوم البيانية والجداول',
                      ),
                      value: AppSettings.useModernAnalysis.value,
                      activeColor: Colors.teal,
                      onChanged: (value) {
                        // تحديث الحالة وحفظها
                        setStateDialog(() {
                          // أو setState حسب سياق الكود عندك
                          AppSettings.setModernAnalysis(value);
                        });
                        // تحديث الصفحة الرئيسية أيضاً لضمان تطبيق التغيير فوراً
                        setState(() {});
                      },
                    ),

                    const Divider(), // فاصل جمالي

                    StatefulBuilder(
                      builder: (context, setSwitchState) {
                        return SwitchListTile(
                          title: const Text('أزرار الرصد السريع'),
                          subtitle: const Text('إظهار أيقونات النرد'),
                          value: AppSettings.showQuickGradingButtons.value,
                          activeThumbColor: Colors.orange,
                          onChanged: (value) {
                            AppSettings.setQuickGradingButtons(value);
                            setSwitchState(() {});
                            setState(() {});
                          },
                        );
                      },
                    ),
                    const Divider(),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'الأمان والبيانات',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: hasPin ? Colors.red : Colors.green,
                          side: BorderSide(
                            color: hasPin ? Colors.red : Colors.green,
                          ),
                        ),
                        icon: Icon(
                          hasPin
                              ? Icons.no_encryption_gmailerrorred
                              : Icons.lock,
                        ),
                        label: Text(
                          hasPin ? 'تعطيل رمز الدخول' : 'تفعيل رمز الدخول',
                        ),
                        onPressed: () async {
                          if (hasPin) {
                            bool confirm =
                                await showDialog(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const Text('تعطيل الحماية'),
                                    content: const Text(
                                      'هل أنت متأكد من إزالة رمز الدخول؟',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(c, false),
                                        child: const Text('إلغاء'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(c, true),
                                        child: const Text(
                                          'إزالة',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;
                            if (confirm) {
                              await SecureServices.setPin('');
                              setStateDialog(() => hasPin = false);
                              if (mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تم تعطيل رمز الدخول'),
                                  ),
                                );
                            }
                          } else {
                            Navigator.pop(ctx);
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LockScreen(
                                  onUnlocked: () {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('تم تفعيل الرمز بنجاح'),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _showAddClassDialog,
                          icon: const Icon(Icons.add_box_outlined),
                          label: const Text('إضافة صف'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _showAddMockClassDialog,
                          icon: const Icon(Icons.post_add),
                          label: const Text('إضافة اختبار'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _restoreHiddenClassesAndLotteries,
                          icon: const Icon(Icons.visibility),
                          label: const Text('إرجاع المخفي'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await prefs.setString(
                      'user_email',
                      emailController.text.trim(),
                    );
                    await prefs.setString(
                      'user_phone',
                      phoneController.text.trim(),
                    );
                    await prefs.setString(
                      'user_name',
                      nameController.text.trim(),
                    );
                    await AppSettings.setArabicNumbers(tempUseArabicNums);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم حفظ الإعدادات')),
                      );
                      setState(() {});
                    }
                    Navigator.pop(ctx);
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showSingleClassAnalysisDialog() {
    final allClasses = <Map<String, String>>[];
    if (_baseClassesConfig['c5']?.visible ?? true)
      allClasses.add({
        'id': 'c5',
        'name': _baseClassesConfig['c5']?.title ?? 'رابع 5',
      });
    if (_baseClassesConfig['c6']?.visible ?? true)
      allClasses.add({
        'id': 'c6',
        'name': _baseClassesConfig['c6']?.title ?? 'رابع 6',
      });
    if (_baseClassesConfig['c7']?.visible ?? true)
      allClasses.add({
        'id': 'c7',
        'name': _baseClassesConfig['c7']?.title ?? 'رابع 7',
      });
    for (var c in _extraClasses) {
      allClasses.add({'id': c.id, 'name': c.title});
    }
    String? selectedClassId;
    String selectedTag = 'total';
    bool isLoadingLabels = false;
    List<String> availableTags = ['total', 'perform'];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> loadTagsForClass(String classId) async {
            setLocal(() => isLoadingLabels = true);
            final config = await ClassGradingConfig.load(classId);
            final Set<String> tags = {};
            for (var item in config.items) {
              tags.add(item.tag);
            }
            for (var item in config.exams) {
              tags.add(item.tag);
            }
            setLocal(() {
              availableTags = ['total', 'perform', ...tags];
              selectedTag = 'total';
              isLoadingLabels = false;
            });
          }

          return AlertDialog(
            title: const Text('تحليل صف دراسي'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    isExpanded: true,
                    hint: const Text('1. اختر الفصل'),
                    value: selectedClassId,
                    items: allClasses
                        .map(
                          (c) => DropdownMenuItem(
                            value: c['id'],

                            child: Text(c['name']!.toAppNum()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setLocal(() => selectedClassId = v);
                        loadTagsForClass(v);
                      }
                    },
                  ),
                  const SizedBox(height: 15),
                  if (isLoadingLabels)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(),
                    )
                  else
                    DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text('2. اختر معيار التحليل'),
                      value: selectedClassId == null ? null : selectedTag,
                      items: availableTags.map((t) {
                        String label = t;
                        if (t == 'total') {
                          label = 'المجموع الكلي';
                        } else if (t == 'perform')
                          label = 'المهام الأدائية (مجموع)';
                        return DropdownMenuItem(
                          value: t,

                          child: Text(label.toAppNum()),
                        );
                      }).toList(),
                      onChanged: selectedClassId == null
                          ? null
                          : (v) => setLocal(() => selectedTag = v!),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selectedClassId == null) return;
                  String className = allClasses.firstWhere(
                    (e) => e['id'] == selectedClassId,
                  )['name']!;
                  String metricLabel = selectedTag == 'total'
                      ? 'المجموع الكلي'
                      : (selectedTag == 'perform'
                            ? 'المهام الأدائية'
                            : selectedTag);
                  _processSingleClassAnalysis(
                    selectedClassId!,
                    selectedTag,
                    className,
                    metricLabel,
                  );
                },
                child: const Text('بدء التحليل'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _processSingleClassAnalysis(
    String classId,
    String tag,
    String className,
    String metricLabel,
  ) async {
    // ✅ 1. إغلاق صندوق اختيار الفصل فوراً في كل الحالات
    Navigator.pop(context);

    // 2. التحقق من النظام المختار
    if (AppSettings.useModernAnalysis.value) {
      print("🚀 توجيه للصفحة الحديثة (تحليل صف)");
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ModernClassAnalysisPage(classId: classId, classTitle: className),
        ),
      );
      return; // التوقف هنا وعدم إكمال الكود القديم
    }

    // ✅✅✅ [نهاية الإضافة] ✅✅✅

    Navigator.pop(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> analysisData = [];
      double maxScoreTotal = 0.0;
      final config = await ClassGradingConfig.load(classId);
      final allConfigItems = [...config.items, ...config.exams];
      if (tag == 'total') {
        maxScoreTotal = config.getTotalMaxScore();
      } else if (tag == 'perform') {
        for (var c in allConfigItems) {
          if (c.isPerformanceTask) maxScoreTotal += c.maxScore;
        }
      } else {
        for (var c in allConfigItems) {
          if (c.tag == tag) maxScoreTotal += c.maxScore;
        }
      }
      if (maxScoreTotal == 0) maxScoreTotal = 1;
      final studentsKey = 'class_students_$classId';
      final studentsJson = prefs.getString(studentsKey);
      if (studentsJson != null) {
        final List studentList = jsonDecode(studentsJson);
        for (var studentJson in studentList) {
          final String name = studentJson['name'];
          final detailKey = 'student_detail_${name}_$classId';
          final detailStr = prefs.getString(detailKey);
          double finalScore = 0.0;
          if (detailStr != null) {
            final studentData = jsonDecode(detailStr) as Map<String, dynamic>;
            double getColScore(GradeColumn col) {
              final val = studentData[col.id];
              if (val == null) return 0.0;
              if (col.type == GradeType.numeric)
                return double.tryParse(val.toString()) ?? 0.0;
              if (col.type == GradeType.checkbox)
                return (int.tryParse(val.toString()) ?? 0) *
                    (col.subCount > 0 ? col.maxScore / col.subCount : 0);
              if (col.type == GradeType.numericList) {
                if (val is List && val.isNotEmpty) {
                  double s = 0;
                  int c = 0;
                  for (var v in val) {
                    double? n = double.tryParse(v.toString());
                    if (n != null) {
                      s += n;
                      c++;
                    }
                  }
                  return c > 0 ? s / c : 0;
                }
              }
              if (col.type == GradeType.averagePair) {
                if (val is List && val.length >= 2) {
                  return ((double.tryParse(val[0].toString()) ?? 0) +
                          (double.tryParse(val[1].toString()) ?? 0)) /
                      2;
                }
              }
              return 0.0;
            }

            if (tag == 'total') {
              finalScore = allConfigItems.fold(
                0.0,
                (s, c) => s + getColScore(c),
              );
            } else if (tag == 'perform') {
              finalScore = allConfigItems
                  .where((c) => c.isPerformanceTask)
                  .fold(0.0, (s, c) => s + getColScore(c));
            } else {
              finalScore = allConfigItems
                  .where((c) => c.tag == tag)
                  .fold(0.0, (s, c) => s + getColScore(c));
            }
          }
          analysisData.add({
            'name': name,
            'exams': List.filled(8, finalScore),
            'isSelected': false,
          });
        }
      }
      const tempKey = 'mock_exam_single_class_analysis_v1';
      const tempMetaKey = 'mock_exam_single_class_analysis_v1_meta';
      await prefs.setString(tempKey, jsonEncode(analysisData));
      await prefs.setString(
        tempMetaKey,
        jsonEncode(List.filled(8, maxScoreTotal)),
      );
      if (mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MockExamAnalysisPage(
              classId: 'single_class_analysis',
              classTitle: '$className - $metricLabel',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showStageAnalysisDialog() {
    final allClasses = <Map<String, String>>[];

    // 1. حل مشكلة الأسماء والفصول المضافة (رابع 9 وغيرها)
    // نأخذ البيانات مباشرة من الكوّن المتاح في الصفحة بدلاً من الذاكرة فقط
    if (_baseClassesConfig['c5']?.visible ?? true) {
      allClasses.add({
        'id': 'c5',
        'name': _baseClassesConfig['c5']?.title ?? 'رابع 5'.toAppNum(),
      });
    }
    if (_baseClassesConfig['c6']?.visible ?? true) {
      allClasses.add({
        'id': 'c6',
        'name': _baseClassesConfig['c6']?.title ?? 'رابع 6'.toAppNum(),
      });
    }
    if (_baseClassesConfig['c7']?.visible ?? true) {
      allClasses.add({
        'id': 'c7',
        'name': _baseClassesConfig['c7']?.title ?? 'رابع 7'.toAppNum(),
      });
    }

    // إضافة الفصول الإضافية (مثل رابع 9) الموجودة في القائمة لديك

    for (var c in _extraClasses) {
      // ✅ أضف .toAppNum() هنا لتحويل "رابع 9" إلى "رابع ٩"
      allClasses.add({
        'id': c.id,
        'name': c.title.toAppNum(), // تحويل الأرقام في الاسم
      });
    }

    final selectedClasses = <String>{};
    String selectedTag = 'total';
    List<String> availableTags = ['total', 'perform']; // التاقات الأساسية
    bool isLoadingTags = true;
    bool isInitialized = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          if (!isInitialized) {
            isInitialized = true;
            // 2. حل مشكلة التاقات (واجبات، مشاركة، إلخ)
            GlobalGradingTags.loadTags().then((tags) {
              if (ctx.mounted) {
                setLocal(() {
                  final Set<String> uniqueTags = {'total', 'perform', ...tags};
                  availableTags = uniqueTags.toList();
                  isLoadingTags = false;
                });
              }
            });
          }

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              // 4. تصغير وتجميل الصندوق
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: const Text(
                'إعداد تحليل المرحلة', // إذا أضفت أرقاماً هنا استخدم .toAppNum()
                style: TextStyle(fontSize: 18),
              ),
              content: SizedBox(
                width: 350, // تحديد عرض أصغر للصندوق
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'معيار التحليل:', // إذا أضفت أرقاماً هنا استخدم .toAppNum()
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      if (isLoadingTags)
                        const LinearProgressIndicator()
                      else
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          value: availableTags.contains(selectedTag)
                              ? selectedTag
                              : availableTags.first,
                          items: availableTags.map((t) {
                            String label = t;
                            if (t == 'total')
                              label = 'المجموع الكلي';
                            else if (t == 'perform')
                              label = 'المهام الأدائية';
                            return DropdownMenuItem(
                              value: t,
                              child: Text(label.toAppNum()),
                            );
                          }).toList(),
                          onChanged: (v) => setLocal(() => selectedTag = v!),
                        ),
                      const SizedBox(height: 15),
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'اختر الفصول للدمج:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        height: 150, // تحديد ارتفاع ثابت للقائمة لتصغير الصندوق
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          itemCount: allClasses.length,
                          itemBuilder: (context, index) {
                            final c = allClasses[index];
                            return CheckboxListTile(
                              title: Text(
                                c['name']!.toAppNum(),
                                style: const TextStyle(fontSize: 14),
                              ),
                              value: selectedClasses.contains(c['id']),
                              onChanged: (v) => setLocal(
                                () => v!
                                    ? selectedClasses.add(c['id']!)
                                    : selectedClasses.remove(c['id']!),
                              ),
                              dense: true,
                              activeColor: Colors.purple,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: selectedClasses.isEmpty
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          String metricLabel = selectedTag == 'total'
                              ? 'المجموع الكلي'
                              : (selectedTag == 'perform'
                                    ? 'المهام الأدائية'
                                    : selectedTag);

                          // الانتقال لصفحة التحليل
                          _processStageAnalysis(
                            selectedClasses.toList(),
                            selectedTag,
                            metricLabel,
                          );
                        },
                  child: const Text('بدء التحليل'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _processStageAnalysis(
    List<String> classIds,
    String tag,
    String metricLabel,
  ) {
    // ✅ الشرط الذكي
    if (AppSettings.useModernAnalysis.value) {
      // 🆕 فتح الصفحة الحديثة (المرحلة)
      // ملاحظة: نحتاج تجميع العناوين (Titles) أيضاً لتمريرها
      List<String> titles = [];
      for (var id in classIds) {
        // منطق جلب الاسم (نفس الموجود في كودك القديم)
        if (id == 'c5')
          titles.add(_baseClassesConfig['c5']?.title ?? 'رابع 5');
        else if (id == 'c6')
          titles.add(_baseClassesConfig['c6']?.title ?? 'رابع 6');
        else if (id == 'c7')
          titles.add(_baseClassesConfig['c7']?.title ?? 'رابع 7');
        else {
          final extra = _extraClasses.firstWhere(
            (e) => e.id == id,
            orElse: () =>
                ExtraClassItem(id: '', title: 'فصل', subtitle: '', emoji: ''),
          );
          titles.add(extra.title);
        }
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ModernStageAnalysisPage(classIds: classIds, classTitles: titles),
        ),
      );
    } else {
      // 🏛️ فتح الصفحة الكلاسيكية (القديمة)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MultiClassAnalysisPage(
            classIds: classIds,
            classTitles: classIds.map((id) {
              // نفس منطق جلب الأسماء القديم لديك
              if (id == 'c5')
                return _baseClassesConfig['c5']?.title ?? 'رابع 5';
              // ... الخ
              return 'فصل';
            }).toList(),
            analysisTag: tag,
          ),
        ),
      );
    }
  }

  void _showDeleteSpecificClassesDialog() {
    final Set<String> idsToDelete = {};
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('حذف فصول محددة'),
              content: SizedBox(
                width: double.maxFinite,
                child: _extraClasses.isEmpty
                    ? const Text("لا توجد فصول")
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _extraClasses.length,
                        itemBuilder: (ctx, i) {
                          final item = _extraClasses[i];
                          final isSelected = idsToDelete.contains(item.id);
                          return CheckboxListTile(
                            title: Text(item.title.toAppNum()),
                            subtitle: Text(item.subtitle.toAppNum()),
                            value: isSelected,
                            activeColor: Colors.red,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  idsToDelete.add(item.id);
                                } else {
                                  idsToDelete.remove(item.id);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: Text('حذف (${idsToDelete.length})'.toAppNum()),
                  onPressed: idsToDelete.isEmpty
                      ? null
                      : () {
                          setState(() {
                            _extraClasses.removeWhere(
                              (item) => idsToDelete.contains(item.id),
                            );
                          });
                          _saveHomeExtras(showSnack: false);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم الحذف بنجاح')),
                          );
                        },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDeleteSpecificMockExamsDialog() {
    final Set<String> idsToDelete = {};
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('حذف اختبارات محددة'),
              content: SizedBox(
                width: double.maxFinite,
                child: _mockClasses.isEmpty
                    ? const Text("لا توجد اختبارات")
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _mockClasses.length,
                        itemBuilder: (ctx, i) {
                          final item = _mockClasses[i];
                          final isSelected = idsToDelete.contains(item.id);
                          return CheckboxListTile(
                            title: Text(item.displayTitle.toAppNum()),
                            subtitle: Text(item.examTitle.toAppNum()),
                            value: isSelected,
                            activeColor: Colors.red,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  idsToDelete.add(item.id);
                                } else {
                                  idsToDelete.remove(item.id);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: Text('حذف (${idsToDelete.length})'.toAppNum()),
                  onPressed: idsToDelete.isEmpty
                      ? null
                      : () {
                          setState(() {
                            _mockClasses.removeWhere(
                              (item) => idsToDelete.contains(item.id),
                            );
                          });
                          _saveHomeExtras(showSnack: false);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم الحذف بنجاح')),
                          );
                        },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ✅✅✅ 2. مهارات شاملة: تجميعي بحسب التاق (النسخة الجديدة) ✅✅✅
  Future<void> _showMultiSkillAnalysisDialog() async {
    if (_mockClasses.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('لا توجد اختبارات محاكية!')));
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // 1. تجميع كل التاقات المتاحة من الاختبارات
    Set<String> uniqueTags = {};
    for (var mock in _mockClasses) {
      final metaKey = 'mock_exam_${mock.id}_v1_meta';
      final metaStr = prefs.getString(metaKey);
      if (metaStr != null) {
        try {
          final Map<String, dynamic> meta = jsonDecode(metaStr);
          if (meta['col_tags'] != null) {
            for (var t in meta['col_tags']) {
              if (t.toString().trim().isNotEmpty) {
                uniqueTags.add(t.toString().trim());
              }
            }
          }
        } catch (_) {}
      }
    }

    if (!mounted) return;

    final allMock = _mockClasses;
    final selectedMocks = <String>{};

    // الخيار الافتراضي للتاق
    String selectedTag = uniqueTags.isNotEmpty
        ? uniqueTags.first
        : 'Comprehensive';
    final reportTitleController = TextEditingController();
    final ScrollController listScrollController = ScrollController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          // خيارات القائمة: التاقات الموجودة + خيار شامل
          final dropdownItems = ['Comprehensive', ...uniqueTags];

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              width: 350,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'تحليل مهارة شامل (مقارنة)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    '1. اختر الاختبارات:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 5),

                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade50,
                    ),
                    child: Scrollbar(
                      controller: listScrollController,
                      thumbVisibility: true,
                      child: ListView.builder(
                        controller: listScrollController,
                        padding: EdgeInsets.zero,
                        itemCount: allMock.length,
                        itemBuilder: (ctx, i) {
                          final item = allMock[i];
                          return CheckboxListTile(
                            title: Text(
                              item.displayTitle.toAppNum(),
                              style: const TextStyle(fontSize: 13),
                            ),
                            value: selectedMocks.contains(item.id),
                            onChanged: (v) => setLocal(
                              () => v!
                                  ? selectedMocks.add(item.id)
                                  : selectedMocks.remove(item.id),
                            ),
                            dense: true,
                            activeColor: Colors.teal,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),
                  const Divider(),

                  const Text(
                    '2. حدد التاق / المهارة:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),

                  DropdownButtonFormField<String>(
                    value: selectedTag,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true),
                    items: dropdownItems.map((tag) {
                      String label = tag == 'Comprehensive'
                          ? 'شامل (الكل)'
                          : tag;
                      return DropdownMenuItem(
                        value: tag,
                        child: Text(
                          label.toAppNum(),
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setLocal(() {
                        selectedTag = v!;
                        reportTitleController.text = (v == 'Comprehensive')
                            ? 'تقرير شامل'
                            : v;
                      });
                    },
                  ),

                  const SizedBox(height: 10),
                  TextField(
                    controller: reportTitleController,
                    decoration: const InputDecoration(
                      labelText: 'عنوان التقرير (اختياري)',
                      hintText: 'مثال: تحليل مهارات القراءة',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('إلغاء'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            if (selectedMocks.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'يجب اختيار اختبار واحد على الأقل',
                                  ),
                                ),
                              );
                              return;
                            }
                            _processMultiSkillAnalysis(
                              selectedMocks.toList(),
                              selectedTag, // Pass Tag instead of Column Index
                              customTitle: reportTitleController.text,
                            );
                          },
                          child: const Text('تحليل'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ✅✅✅ 3. معالجة التحليل الشامل (دمج كامل للبيانات) ✅✅✅
  Future<void> _processMultiSkillAnalysis(
    List<String> mockIds,
    String tagName, { // ✅ تم تغييرها من int colIndex إلى String tagName
    String customTitle = '',
  }) async {
    // كود التوجيه للنظام الحديث (تم إزالته من مسار التنفيذ هذا لأنه يتبع منطق مختلف)
    if (AppSettings.useModernAnalysis.value) {
      Navigator.of(context).pop();
      List<String> titles = [];
      for (var id in mockIds) {
        final item = _mockClasses.firstWhere(
          (m) => m.id == id,
          orElse: () => MockClassItem(
            id: '',
            displayTitle: 'اختبار',
            examTitle: '',
            emoji: '',
            subtitle: '',
          ),
        );
        titles.add(item.displayTitle);
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ModernMultiMockPage(classIds: mockIds, classTitles: titles),
        ),
      );
      return;
    }

    Navigator.of(context).pop();
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      final prefs = await SharedPreferences.getInstance();

      // سنقوم بنسخ هيكلة الأعمدة (العناوين، الدرجات القصوى، التاقات) من أول اختبار مختار
      // هذا يفترض أن جميع الاختبارات لها نفس الهيكلة (وهو المتوقع في التحليل المقارن للفصول)
      List<dynamic> refTitles = [];
      List<dynamic> refMaxScores = [];
      List<dynamic> refTags = [];

      if (mockIds.isNotEmpty) {
        final firstId = mockIds.first;
        final metaKey = 'mock_exam_${firstId}_v1_meta';
        final metaStr = prefs.getString(metaKey);
        if (metaStr != null) {
          try {
            final Map<String, dynamic> meta = jsonDecode(metaStr);
            if (meta['titles'] != null) refTitles = meta['titles'];
            if (meta['max_scores'] != null) refMaxScores = meta['max_scores'];
            if (meta['col_tags'] != null) refTags = meta['col_tags'];
          } catch (_) {}
        }
      }

      // تجميع الطلاب مع الحفاظ على كامل درجاتهم
      // المفتاح سيكون الاسم (مع اسم الفصل) لضمان الفرادة
      Map<String, List<dynamic>> studentsMap = {};

      for (String id in mockIds) {
        final mockItem = _mockClasses.firstWhere(
          (e) => e.id == id,
          orElse: () => MockClassItem(
            id: '',
            displayTitle: 'اختبار',
            examTitle: '',
            emoji: '',
            subtitle: '',
          ),
        );

        final storageKey = 'mock_exam_${id}_v1';
        final str = prefs.getString(storageKey);
        if (str != null && str.isNotEmpty) {
          try {
            final List decoded = jsonDecode(str);
            for (var sRaw in decoded) {
              final sMap = Map<String, dynamic>.from(sRaw);
              String rawName = sMap['name'] ?? '';
              if (rawName.isEmpty) continue;

              // إضافة اسم الفصل
              String uniqueName = '$rawName (${mockItem.displayTitle})';

              // نسخ قائمة الدرجات كما هي
              List exams = (sMap['exams'] as List?) ?? [];

              // التأكد من أن طول القائمة يتطابق مع المرجع (تعبئة أصفار إذا لزم الأمر)
              // لكن هنا سنكتفي بنسخ ما هو موجود، والصفحة V2 تتعامل مع null
              studentsMap[uniqueName] = exams;
            }
          } catch (e) {
            debugPrint("Error for $id: $e");
          }
        }
      }

      // تحويل البيانات للقائمة النهائية
      final List<Map<String, dynamic>> finalStudentList = [];
      studentsMap.forEach((name, exams) {
        finalStudentList.add({
          'name': name,
          'exams': exams,
          'isSelected': false,
        });
      });

      // بناء الميتا الجديدة (نسخة من المرجع)
      final Map<String, dynamic> newMeta = {
        'count': refTitles.length, // عدد الأعمدة هو نفسه في الاختبار الأصلي
        'max_scores': refMaxScores,
        'titles': refTitles,
        'col_tags': refTags,
        'tag': 'تحليل مقارنة شامل', // وسم عام للصفحة
      };

      // الحفظ في ملف مؤقت
      const tempKey = 'mock_exam_multi_skill_temp_v1';
      const tempMetaKey = 'mock_exam_multi_skill_temp_v1_meta';

      await prefs.setString(tempKey, jsonEncode(finalStudentList));
      await prefs.setString(tempMetaKey, jsonEncode(newMeta));

      if (mounted) {
        setState(() => _isLoading = false);

        String pageTitle = customTitle.trim().isEmpty
            ? 'تحليل شامل ($tagName)'
            : customTitle;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MockExamAnalysisV2Page(
              classId: 'multi_skill_temp',
              classTitle: pageTitle,
              initialTag: tagName, // ✅ تمرير التاق المختار ليبدأ به
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء المعالجة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ✅✅✅ 2. مهارات فصل: تفتح الصفحة الجديدة V2 ✅✅✅
  void _showMockClassSelectionDialog() {
    // 1. التحقق من وجود اختبارات أصلاً
    if (_mockClasses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد اختبارات محاكية للتحليل!')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text(
            'اختر الاختبار لتحليله',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _mockClasses.length,
              separatorBuilder: (ctx, i) => const Divider(),
              itemBuilder: (ctx, i) {
                final item = _mockClasses[i];
                return ListTile(
                  leading: const Icon(Icons.assignment, color: Colors.orange),
                  title: Text(item.displayTitle.toAppNum()),
                  subtitle: Text(item.examTitle.toAppNum()),
                  trailing: const Icon(Icons.arrow_back_ios, size: 14),
                  onTap: () {
                    Navigator.pop(ctx); // إغلاق النافذة

                    // ✅ 2. التوجيه حسب نظام التحليل (مودرن أو كلاسيك)
                    if (AppSettings.useModernAnalysis.value) {
                      // 🚀 الذهاب للصفحة الحديثة (تحليل مهارة)
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ModernMockSkillPage(
                            classId: item.id,
                            classTitle: item.displayTitle,
                          ),
                        ),
                      );
                    } else {
                      // 🏛️ الذهاب للصفحة القديمة
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MockExamAnalysisV2Page(
                            classId: item.id,
                            classTitle: item.displayTitle,
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      ),
    );
  }

  // --- التعديل والمسح للكروت ---
  Future<void> _editBaseClassGeneric(String keyId, BaseCardConfig cfg) async {
    final titleController = TextEditingController(text: cfg.title);
    final subtitleController = TextEditingController(text: cfg.subtitle);
    String emoji = cfg.emoji;
    bool visible = cfg.visible;
    final rnd = Random();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('تعديل كرت الفصل'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'العنوان',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: subtitleController,
                    decoration: const InputDecoration(
                      labelText: 'الوصف',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => setLocal(
                          () => emoji =
                              _emojiChoicesClasses[rnd.nextInt(
                                _emojiChoicesClasses.length,
                              )],
                        ),
                        child: const Text('تغيير الأيقونة'),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    title: const Text('إظهار في الرئيسية'),
                    value: visible,
                    onChanged: (v) => setLocal(() => visible = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _baseClassesConfig[keyId] = BaseCardConfig(
                      emoji: emoji,
                      title: titleController.text,
                      subtitle: subtitleController.text,
                      visible: visible,
                    );
                  });
                  _saveHomeExtras(showSnack: false);
                  Navigator.pop(ctx);
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editExtraClass(int index) async {
    final item = _extraClasses[index];
    final titleController = TextEditingController(text: item.title);
    final subtitleController = TextEditingController(text: item.subtitle);
    String emoji = item.emoji;
    final rnd = Random();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('تعديل الفصل الإضافي'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'اسم الفصل',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: subtitleController,
                    decoration: const InputDecoration(
                      labelText: 'الوصف',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => setLocal(
                          () => emoji =
                              _emojiChoicesClasses[rnd.nextInt(
                                _emojiChoicesClasses.length,
                              )],
                        ),
                        child: const Text('تغيير الأيقونة'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    item.title = titleController.text;
                    item.subtitle = subtitleController.text;
                    item.emoji = emoji;
                  });
                  _saveHomeExtras(showSnack: false);
                  Navigator.pop(ctx);
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddClassDialog() async {
    final tCtrl = TextEditingController();
    final sCtrl = TextEditingController(text: 'كشف متابعة الطلاب');
    String emoji = _emojiChoicesClasses.first;
    final rnd = Random();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('إضافة صف جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tCtrl,
                decoration: const InputDecoration(labelText: 'اسم الصف'),
              ),
              TextField(
                controller: sCtrl,
                decoration: const InputDecoration(labelText: 'الوصف'),
              ),
              Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 28)),
                  TextButton(
                    onPressed: () => setLocal(
                      () => emoji =
                          _emojiChoicesClasses[rnd.nextInt(
                            _emojiChoicesClasses.length,
                          )],
                    ),
                    child: const Text('تغيير'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                if (tCtrl.text.isNotEmpty) {
                  setState(
                    () => _extraClasses.add(
                      ExtraClassItem(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: tCtrl.text,
                        subtitle: sCtrl.text,
                        emoji: emoji,
                      ),
                    ),
                  );
                  _saveHomeExtras(showSnack: false);
                }
                Navigator.pop(ctx);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSelectionAnalysisOptions() async {
    // 1. ✅ تأمين البيانات: نأخذ نسخة محلية فوراً قبل فعل أي شيء
    // هذا يضمن أن البيانات موجودة معنا حتى لو تم إلغاء التحديد بالخطأ لاحقاً
    final List<String> idsSnapshot = List.from(_selectedClassIds);

    // تجميع الأسماء بناءً على الآيديات المختارة لضمان الترتيب
    final List<String> titlesSnapshot = [];
    for (var id in idsSnapshot) {
      if (_selectedClassTitles.containsKey(id)) {
        titlesSnapshot.add(_selectedClassTitles[id]!);
      } else {
        titlesSnapshot.add('فصل'); // احتياط
      }
    }

    if (idsSnapshot.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('لم يتم تحديد أي فصل!')));
      return;
    }

    // طباعة للتأكد (ستظهر في الكونسول)
    debugPrint("سيتم تحليل الفصول: $idsSnapshot");

    // محاولة تحميل التاقات (للعرض فقط)
    List<String> availableTags = ['total', 'perform'];
    try {
      final firstId = idsSnapshot.first;
      final config = await ClassGradingConfig.load(firstId);
      final tags = <String>{};
      for (var i in config.items) tags.add(i.tag);
      for (var i in config.exams) tags.add(i.tag);
      availableTags.addAll(tags.where((t) => t.trim().isNotEmpty));
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'اختر معيار التحليل',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: availableTags.map((tag) {
                String label = tag;
                IconData icon = Icons.label_outline;
                Color color = Colors.teal;

                if (tag == 'total') {
                  label = 'المجموع الكلي';
                  icon = Icons.functions;
                  color = Colors.purple;
                } else if (tag == 'perform') {
                  label = 'المهام الأدائية';
                  icon = Icons.assignment_turned_in;
                  color = Colors.orange;
                }

                return ActionChip(
                  avatar: Icon(icon, size: 18, color: Colors.white),
                  label: Text(
                    label.toAppNum(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: color,
                  onPressed: () {
                    Navigator.pop(ctx); // إغلاق القائمة

                    // ✅ نستخدم النسخة المجمدة (idsSnapshot) وليس المتغير العام
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MultiClassAnalysisPage(
                          classIds: idsSnapshot, // ✅ القائمة الآمنة
                          classTitles: titlesSnapshot, // ✅ الأسماء الآمنة
                          analysisTag: tag,
                        ),
                      ),
                    );

                    _exitSelectionMode(); // الخروج من وضع التحديد
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddMockClassDialog() async {
    _mockClassController.clear();
    _mockExamTitleController.clear();
    _mockSubtitleController.text = 'اختبار محاكي';
    String emoji = '📝';
    final rnd = Random();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, sl) => AlertDialog(
          title: const Text('إضافة اختبار محاكي'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _mockClassController,
                decoration: const InputDecoration(labelText: 'عنوان الكرت'),
              ),
              TextField(
                controller: _mockExamTitleController,
                decoration: const InputDecoration(labelText: 'عنوان الاختبار'),
              ),
              TextField(
                controller: _mockSubtitleController,
                decoration: const InputDecoration(labelText: 'الوصف'),
              ),
              Row(
                children: [
                  Text(emoji),
                  TextButton(
                    onPressed: () => sl(
                      () => emoji =
                          _emojiChoicesClasses[rnd.nextInt(
                            _emojiChoicesClasses.length,
                          )],
                    ),
                    child: const Text('تغيير'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                if (_mockClassController.text.isNotEmpty) {
                  setState(() {
                    _mockClasses.add(
                      MockClassItem(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        displayTitle: _mockClassController.text,
                        examTitle: _mockExamTitleController.text,
                        emoji: emoji,
                        subtitle: _mockSubtitleController.text,
                      ),
                    );
                  });
                  _saveHomeExtras(showSnack: false);
                }
                Navigator.pop(ctx);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  void _restoreHiddenClassesAndLotteries() {
    setState(() {
      _baseClassesConfig.forEach((key, cfg) {
        cfg.visible = true;
      });
      _ensureBaseCardsExist();
    });
    _saveHomeExtras(showSnack: false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم الإرجاع')));
  }

  Future<void> _editMockClass(int index) async {
    final item = _mockClasses[index];
    _mockClassController.text = item.displayTitle;
    _mockExamTitleController.text = item.examTitle;
    _mockSubtitleController.text = item.subtitle;
    String emoji = item.emoji;
    final rnd = Random();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('تعديل كرت الاختبار'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _mockClassController,
                    decoration: const InputDecoration(
                      labelText: 'عنوان الكرت',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _mockExamTitleController,
                    decoration: const InputDecoration(
                      labelText: 'عنوان الاختبار',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _mockSubtitleController,
                    decoration: const InputDecoration(
                      labelText: 'الوصف',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => setLocal(
                          () => emoji =
                              _emojiChoicesClasses[rnd.nextInt(
                                _emojiChoicesClasses.length,
                              )],
                        ),
                        child: const Text('تغيير الأيقونة'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    item.displayTitle = _mockClassController.text;
                    item.examTitle = _mockExamTitleController.text;
                    item.subtitle = _mockSubtitleController.text;
                    item.emoji = emoji;
                  });
                  _saveHomeExtras(showSnack: false);
                  Navigator.pop(ctx);
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }
}
