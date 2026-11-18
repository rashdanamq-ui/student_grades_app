import '../../Features/analysis/models/analysis_view_models.dart';

class LevelSettings {
  final int count;
  final List<LevelConfigV2> levels;

  LevelSettings({required this.count, required this.levels});

  Map<String, dynamic> toJson() => {
    'count': count,
    'levels': levels
        .map((l) => {'label': l.label, 'minPercent': l.minPercent})
        .toList(),
  };

  factory LevelSettings.fromJson(Map<String, dynamic> json) {
    final List raw = json['levels'] ?? [];
    return LevelSettings(
      count: json['count'] ?? raw.length,
      levels: raw
          .map(
            (e) => LevelConfigV2(
              label: e['label'],
              minPercent: (e['minPercent'] as num).toDouble(),
            ),
          )
          .toList(),
    );
  }
}
