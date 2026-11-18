import 'package:flutter/material.dart';

import '../../../core/grading_levels/level_settings_service.dart';
import '../../../core/grading_levels/level_settings_model.dart';
import '../models/analysis_view_models.dart';

class LevelSettingsDialog extends StatefulWidget {
  final double maxScore;
  const LevelSettingsDialog({super.key, required this.maxScore});

  @override
  State<LevelSettingsDialog> createState() => _LevelSettingsDialogState();
}

class _LevelSettingsDialogState extends State<LevelSettingsDialog> {
  late LevelSettings _settings;

  final List<TextEditingController> _nameCtrls = [];
  final List<TextEditingController> _minCtrls = [];

  bool _useScoreDistribution = false;
  bool _loading = true;

  // ===== تحويلات =====
  double _percentToScore(double percent) => (percent / 100) * widget.maxScore;

  double _scoreToPercent(double score) =>
      widget.maxScore == 0 ? 0 : (score / widget.maxScore) * 100;

  void _convertControllers({required bool toScore}) {
    for (int i = 0; i < _minCtrls.length; i++) {
      final val = double.tryParse(_minCtrls[i].text) ?? 0;
      final converted = toScore ? _percentToScore(val) : _scoreToPercent(val);

      _minCtrls[i].text = converted.toStringAsFixed(1);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await LevelSettingsService.load();

    _settings = s;
    _nameCtrls.clear();
    _minCtrls.clear();

    for (final lvl in s.levels) {
      _nameCtrls.add(TextEditingController(text: lvl.label));
      _minCtrls.add(
        TextEditingController(text: lvl.minPercent.toInt().toString()),
      );
    }

    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final List<LevelConfigV2> updated = [];

    for (int i = 0; i < _settings.count; i++) {
      final name = _nameCtrls[i].text.trim();
      final raw = double.tryParse(_minCtrls[i].text.trim()) ?? 0;

      final minPercent = _useScoreDistribution
          ? (raw / widget.maxScore) * 100
          : raw;

      updated.add(
        LevelConfigV2(
          label: name.isEmpty ? 'المستوى ${i + 1}' : name,
          minPercent: minPercent,
        ),
      );
    }

    updated.sort((a, b) => b.minPercent.compareTo(a.minPercent));

    final newSettings = LevelSettings(count: _settings.count, levels: updated);

    await LevelSettingsService.save(newSettings);

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إعدادات المستويات'),
      content: _loading
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // ===== Slider عدد المستويات =====
                    Row(
                      children: [
                        const Text('عدد المستويات'),
                        Expanded(
                          child: Slider(
                            min: 1,
                            max: 10,
                            divisions: 9,
                            value: _settings.count.toDouble(),
                            label: _settings.count.toString(),
                            onChanged: (v) async {
                              final newCount = v.toInt();

                              final newSettings =
                                  await LevelSettingsService.createDefault(
                                    count: newCount,
                                  );

                              setState(() {
                                _settings = newSettings;
                                _useScoreDistribution = false;
                              });

                              await _load();
                            },
                          ),
                        ),
                      ],
                    ),

                    const Divider(),

                    // ===== زر توزيع نسبة / درجة =====
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: Text('٪ توزيع نسبي'),
                          selected: !_useScoreDistribution,
                          onSelected: (v) {
                            if (v && _useScoreDistribution) {
                              setState(() {
                                _convertControllers(toScore: false);
                                _useScoreDistribution = false;
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text('🧮 توزيع بالدرجة'),
                          selected: _useScoreDistribution,
                          onSelected: (v) {
                            if (v && !_useScoreDistribution) {
                              setState(() {
                                _convertControllers(toScore: true);
                                _useScoreDistribution = true;
                              });
                            }
                          },
                        ),
                      ],
                    ),

                    const Divider(),

                    // ===== قائمة المستويات =====
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _settings.count,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _nameCtrls[i],
                                decoration: const InputDecoration(
                                  labelText: 'اسم المستوى',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _minCtrls[i],
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: _useScoreDistribution
                                      ? 'الحد الأدنى (درجة)'
                                      : 'الحد الأدنى %',
                                  isDense: true,
                                ),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('حفظ')),
      ],
    );
  }
}
