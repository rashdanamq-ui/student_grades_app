import '../core/config/class_grading_config.dart';

class CsvColumnBinding {
  final String csvHeader;
  GradeColumn? targetColumn;
  int? subIndex;
  bool ignore;
  bool isName; // ✅ جديد

  CsvColumnBinding({
    required this.csvHeader,
    this.targetColumn,
    this.subIndex,
    this.ignore = false,
    this.isName = false,
  });

  bool get isResolved => isName || targetColumn != null || ignore;
}
