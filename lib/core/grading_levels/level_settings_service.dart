import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'level_settings_model.dart';
import '../../Features/analysis/models/analysis_view_models.dart';

class LevelSettingsService {
  static const _prefsKey = 'grading_levels_settings';

  /// جلب الإعدادات (أو إنشاء افتراضي)
  static Future<LevelSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);

    if (raw == null) {
      return await createDefault(count: 5);
    }

    return LevelSettings.fromJson(jsonDecode(raw));
  }

  /// حفظ الإعدادات
  static Future<void> save(LevelSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(settings.toJson()));
  }

  /// إنشاء توزيع تلقائي
  static Future<LevelSettings> createDefault({required int count}) async {
    final safeCount = count.clamp(1, 10);

    final step = (100 / safeCount).floor();
    final List<LevelConfigV2> levels = [];

    int current = 100;

    for (int i = 0; i < safeCount; i++) {
      final min = i == safeCount - 1 ? 0 : current - step + 1;

      levels.add(
        LevelConfigV2(label: 'المستوى ${i + 1}', minPercent: min.toDouble()),
      );

      current -= step;
    }

    final settings = LevelSettings(count: safeCount, levels: levels);

    await save(settings);
    return settings;
  }
}
