import '../core/config/class_grading_config.dart';
import 'csv_binding_models.dart';

class CsvAutoMatcher {
  static List<CsvColumnBinding> match({
    required List<String> csvHeaders,
    required List<GradeColumn> gradeColumns,
  }) {
    final bindings = <CsvColumnBinding>[];

    for (final header in csvHeaders) {
      final clean = _normalize(header);
      if (header.trim() == 'الاسم' ||
          header.trim() == 'اسم الطالب' ||
          header.trim().toLowerCase() == 'name') {
        bindings.add(CsvColumnBinding(csvHeader: header, isName: true));
        continue;
      }

      // الاسم
      if (clean == 'الاسم' || clean == 'name' || clean == 'student') {
        bindings.add(CsvColumnBinding(csvHeader: header, ignore: true));
        continue;
      }
      if (header.trim() == 'الاسم' || header.trim().toLowerCase() == 'name') {
        bindings.add(CsvColumnBinding(csvHeader: header, isName: true));
        continue;
      }

      for (final col in gradeColumns) {
        if (col.subCount > 1) {
          bindings.add(CsvColumnBinding(csvHeader: header, ignore: true));
          continue;
        }
        // تطابق مباشر
        final direct = gradeColumns.where((c) => _normalize(c.name) == clean);

        if (direct.isNotEmpty) {
          bindings.add(
            CsvColumnBinding(csvHeader: header, targetColumn: direct.first),
          );
          continue;
        }

        // اسم + رقم
        final match = RegExp(r'^(.*?)[\s_-]*(\d+)$').firstMatch(header);
        if (match != null) {
          final base = _normalize(match.group(1)!);
          final index = int.parse(match.group(2)!) - 1;

          final col = gradeColumns.where((c) => _normalize(c.name) == base);

          if (col.isNotEmpty &&
              (col.first.type == GradeType.numericList ||
                  col.first.type == GradeType.averagePair)) {
            bindings.add(
              CsvColumnBinding(
                csvHeader: header,
                targetColumn: col.first,
                subIndex: index,
              ),
            );
            continue;
          }
        }

        bindings.add(CsvColumnBinding(csvHeader: header));
      }
    }
    return bindings;
  }

  static String _normalize(String v) {
    return v
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('_', '')
        .replaceAll('-', '');
  }
}
