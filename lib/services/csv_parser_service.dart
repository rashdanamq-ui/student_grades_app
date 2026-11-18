import 'dart:io';
import 'dart:convert';

class CsvTable {
  final List<String> headers;
  final List<List<String>> rows;

  CsvTable({required this.headers, required this.rows});
}

class CsvParserService {
  static Future<CsvTable> parse(File file) async {
    final raw = await file.readAsString(encoding: utf8);

    final lines = raw
        .split(RegExp(r'\r\n|\n|\r'))
        .where((l) => l.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      throw Exception('ملف CSV فارغ');
    }

    final delimiter = _detectDelimiter(lines.first);

    final parsed = lines.map((l) => _splitLine(l, delimiter)).toList();

    final headers = parsed.first.map((e) => e.trim()).toList();
    final rows = parsed.skip(1).toList();

    return CsvTable(headers: headers, rows: rows);
  }

  static String _detectDelimiter(String headerLine) {
    final semicolon = ';'.allMatches(headerLine).length;
    final comma = ','.allMatches(headerLine).length;
    return semicolon >= comma ? ';' : ',';
  }

  static List<String> _splitLine(String line, String delimiter) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final c = line[i];

      if (c == '"') {
        inQuotes = !inQuotes;
        continue;
      }

      if (c == delimiter && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(c);
      }
    }

    result.add(buffer.toString());
    return result;
  }
}
