// انماط التعلم //

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import '../../core/utils/number_utils.dart';
import '../../core/widgets/main_bottom_bar.dart';
import '../../core/widgets/app_dialogs.dart';
import '../home/home_page.dart';
import '../../services/backup_service.dart';
import '../security/security/security_settings_page.dart';

class StudentStylesPage extends StatefulWidget {
  final String classId;
  final String classTitle;
  final List<String> studentNames;

  const StudentStylesPage({
    super.key,
    required this.classId,
    required this.classTitle,
    required this.studentNames,
  });

  @override
  State<StudentStylesPage> createState() => _StudentStylesPageState();
}

class _StudentStylesPageState extends State<StudentStylesPage> {
  int _bottomIndex = 0;

  final List<String> _columns = ['سمعي', 'بصري', 'حسي حركي', 'قرائي كتابي'];

  Map<String, Map<String, bool>> _styleData = {};
  bool _isLoading = true;

  // ✅ متغيرات التحكم في الترتيب
  // ✅ قائمة أعمدة الترتيب (الأول لثاني لثالث...)
  List<String> _sortColumns = [];
  List<String> _sortedNames = [];

  final Color _headerColor = const Color(0xFFe0e0e0);
  final Color _rowColorEven = const Color(0xFFebeff2);
  final Color _rowColorOdd = Colors.white;

  @override
  void initState() {
    super.initState();
    _sortedNames = List.from(widget.studentNames);
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString(
      'student_styles_data_${widget.classId}',
    );
    if (stored != null) {
      Map<String, dynamic> decoded = jsonDecode(stored);
      _styleData = decoded.map((key, value) {
        return MapEntry(key, Map<String, bool>.from(value));
      });
    }
    _applySort(); // تطبيق الترتيب بعد تحميل البيانات
    setState(() => _isLoading = false);
  }

  // ✅ دالة تطبيق الترتيب المتعدد
  void _applySort() {
    if (_sortColumns.isEmpty) {
      // ترتيب هجائي افتراضي
      _sortedNames.sort((a, b) => a.compareTo(b));
    } else {
      // ترتيب حسب قائمة الأعمدة المختارة
      _sortedNames.sort((a, b) {
        for (String col in _sortColumns) {
          bool valA = _styleData[a]?[col] ?? false;
          bool valB = _styleData[b]?[col] ?? false;

          if (valA && !valB) return -1;
          if (!valA && valB) return 1;
          // إذا تساويا في هذا العمود، ننتقل للعمود التالي في الأولوية
        }
        return a.compareTo(b); // إذا تساويا في كل شيء، نرتب هجائياً
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'student_styles_data_${widget.classId}',
      jsonEncode(_styleData),
    );
  }

  void _toggleStyle(String studentName, String colName) {
    setState(() {
      if (!_styleData.containsKey(studentName)) {
        _styleData[studentName] = {};
      }
      bool current = _styleData[studentName]![colName] ?? false;
      _styleData[studentName]![colName] = !current;
      _saveData();
      if (_sortColumns.contains(colName)) {
        _applySort(); // إعادة الترتيب إذا كان العمود ضمن قائمة الترتيب
      }
    });
  }

  void _resetStudent(String studentName) {
    setState(() {
      _styleData.remove(studentName);
      if (_sortColumns.isNotEmpty) {
        _applySort();
      }
    });
    _saveData();
  }

  // ===================== دالة الطباعة PDF =====================
  Future<void> _exportPdf() async {
    final orientation = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('اختيار تخطيط الصفحة', textAlign: TextAlign.center),
        children: [
          SimpleDialogOption(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            onPressed: () => Navigator.pop(context, 'portrait'),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('عمودي (رأسي)'),
                SizedBox(width: 10),
                Icon(Icons.portrait),
              ],
            ),
          ),
          SimpleDialogOption(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            onPressed: () => Navigator.pop(context, 'landscape'),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('أفقي (عرضي)'),
                SizedBox(width: 10),
                Icon(Icons.landscape),
              ],
            ),
          ),
        ],
      ),
    );

    if (orientation == null) return;

    final pageFormat = orientation == 'portrait'
        ? PdfPageFormat.a4
        : PdfPageFormat.a4.landscape;
    final doc = pw.Document();

    final regularFontData = await rootBundle.load(
      'assets/fonts/Amiri-Regular.ttf',
    );
    final boldFontData = await rootBundle.load('assets/fonts/Amiri-Bold.ttf');
    final fontRegular = pw.Font.ttf(regularFontData);
    final fontBold = pw.Font.ttf(boldFontData);

    final List<String> headers = [];
    for (var col in _columns.reversed) {
      headers.add(col);
    }
    headers.add('الاسم');
    headers.add('ت');

    pw.Widget buildTable() {
      final List<pw.TableRow> rows = [];
      // ✅ يمكنك التحكم في ارتفاع الهيدر من هنا (تغيير الرقم 90.0)
      const double tableHeaderHeight = 60.0;
      rows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: headers.map((h) {
            if (h == 'الاسم' || h == 'ت') {
              return pw.Container(
                height: tableHeaderHeight,
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.all(2),
                child: pw.Text(
                  h,
                  style: pw.TextStyle(font: fontBold, fontSize: 10),
                  textAlign: pw.TextAlign.center,
                ),
              );
            } else {
              return pw.Container(
                height: tableHeaderHeight,
                alignment: pw.Alignment.center,
                child: pw.Transform.rotate(
                  angle: 1.571,
                  child: pw.Container(
                    width: tableHeaderHeight,
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      h,
                      style: pw.TextStyle(font: fontBold, fontSize: 9),
                      textAlign: pw.TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      overflow: pw.TextOverflow.visible,
                    ),
                  ),
                ),
              );
            }
          }).toList(),
        ),
      );

      for (int i = 0; i < _sortedNames.length; i++) {
        final name = _sortedNames[i];
        final idx = i + 1;
        final isEven = idx.isEven;
        final rowColor = isEven ? PdfColor.fromHex("#ebeff2") : PdfColors.white;

        List<pw.Widget> cells = [];
        for (var col in _columns.reversed) {
          bool isChecked = _styleData[name]?[col] ?? false;
          cells.add(
            pw.Container(
              height: 18,
              alignment: pw.Alignment.center,
              child: isChecked
                  ? pw.SizedBox(
                      width: 8,
                      height: 8,
                      child: pw.CustomPaint(
                        painter: (canvas, size) {
                          canvas.setStrokeColor(PdfColors.green900);
                          canvas.setLineWidth(1.5);
                          canvas.moveTo(size.x * 0.1, size.y * 0.5);
                          canvas.lineTo(size.x * 0.4, size.y * 0.1);
                          canvas.lineTo(size.x * 0.9, size.y * 0.9);
                          canvas.strokePath();
                        },
                      ),
                    )
                  : pw.SizedBox(),
            ),
          );
        }
        cells.add(
          pw.Container(
            alignment: pw.Alignment.centerRight,
            padding: const pw.EdgeInsets.symmetric(horizontal: 4),
            child: pw.Text(
              name,
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(font: fontRegular, fontSize: 10),
              maxLines: 1,
            ),
          ),
        );
        cells.add(
          pw.Container(
            alignment: pw.Alignment.center,
            child: pw.Text(
              idx.toString().toAppNum(),
              style: pw.TextStyle(font: fontBold, fontSize: 10),
            ),
          ),
        );
        rows.add(
          pw.TableRow(
            decoration: pw.BoxDecoration(color: rowColor),
            children: cells,
          ),
        );
      }

      Map<int, pw.TableColumnWidth> colWidths = {
        // ✅ عرض عمود التسلسل (ت) في الـ PDF
        headers.length - 1: const pw.FixedColumnWidth(25),
        // ✅ عرض عمود الاسم في الـ PDF
        headers.length - 2: const pw.FixedColumnWidth(140),
      };
      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
        columnWidths: colWidths,
        defaultColumnWidth: const pw.FlexColumnWidth(1),
        children: rows,
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(20),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'أصناف الطلاب: ${widget.classTitle}'.toAppNum(),
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 5),
          buildTable(),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) => doc.save(),
      name: 'StudentStyles_${widget.classTitle}',
    );
  }

  Widget _buildFixedHeader(
    double colWidth,
    double idWidth,
    double nameWidth,
    double totalWidth,
  ) {
    return Container(
      height: 100,
      width: totalWidth,
      color: _headerColor,
      child: Row(
        children: [
          Container(
            width: idWidth,
            height: 100,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: _headerColor),
            child: const Text(
              'ت',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            width: nameWidth,
            height: 100,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _headerColor,
              border: Border(left: BorderSide(color: Colors.grey.shade400)),
            ),
            child: const Text(
              'الاسم',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ..._columns.map(
            (col) => InkWell(
              onTap: () {
                setState(() {
                  // إذا كان موجوداً، نحذفه لكي نضعه في المقدمة (أعلى أولوية)
                  _sortColumns.remove(col);
                  _sortColumns.insert(0, col);
                  _applySort();
                });
              },
              child: Container(
                width: colWidth,
                height: 100,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: Colors.grey.shade400)),
                  color: _sortColumns.contains(col)
                      ? Colors.deepPurple.shade100.withOpacity(
                          (1.0 - (_sortColumns.indexOf(col) * 0.2)).clamp(
                            0.2,
                            1.0,
                          ),
                        )
                      : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        col,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _sortColumns.contains(col)
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _sortColumns.contains(col)
                              ? Colors.deepPurple
                              : null,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                    if (_sortColumns.contains(col))
                      Positioned(
                        top: 2,
                        right: 2,
                        child: CircleAvatar(
                          radius: 7,
                          backgroundColor: Colors.deepPurple,
                          child: Text(
                            '${_sortColumns.indexOf(col) + 1}',
                            style: const TextStyle(
                              fontSize: 8,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('أصناف الطلاب - ${widget.classTitle}'.toAppNum()),
          centerTitle: true,
          backgroundColor: const Color(0xFF673AB7),
          actions: [
            IconButton(
              icon: Icon(
                _sortColumns.isEmpty ? Icons.sort_by_alpha : Icons.abc,
                color: _sortColumns.isEmpty ? Colors.white : Colors.white70,
              ),
              tooltip: 'ترتيب هجائي',
              onPressed: () {
                setState(() {
                  _sortColumns.clear();
                  _applySort();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'طباعة التقرير',
              onPressed: _exportPdf,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'تصفير الجميع',
              onPressed: () async {
                bool confirm =
                    await showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('تصفير السجل'),
                        content: const Text(
                          'هل أنت متأكد من حذف جميع أصناف الطلاب في هذا الفصل؟',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('لا'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('نعم'),
                          ),
                        ],
                      ),
                    ) ??
                    false;
                if (confirm) {
                  setState(() => _styleData.clear());
                  _saveData();
                }
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  const SizedBox(height: 10),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        double screenWidth = constraints.maxWidth;
                        const double idWidth = 35;
                        // ✅ عرض عمود الاسم في واجهة التطبيق
                        const double nameWidth = 200;

                        double calculatedColWidth =
                            (screenWidth - idWidth - nameWidth) /
                            _columns.length;
                        double colWidth = calculatedColWidth < 40
                            ? 40
                            : calculatedColWidth;

                        double totalWidth =
                            idWidth + nameWidth + (colWidth * _columns.length);
                        double headerHeight = 100;
                        double listAvailableHeight =
                            constraints.maxHeight - headerHeight;

                        double rowHeight = 32;
                        double bottomPadding = listAvailableHeight - rowHeight;
                        if (bottomPadding < 0) bottomPadding = 0;

                        return ScrollConfiguration(
                          behavior: ScrollConfiguration.of(
                            context,
                          ).copyWith(scrollbars: false),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const ClampingScrollPhysics(),
                            child: Stack(
                              children: [
                                // ب. جسم الجدول (قائمة الطلاب) كـ Stack لتدخل الأسماء تحت الرأس
                                SizedBox(
                                  width: totalWidth,
                                  height: constraints.maxHeight,
                                  child: ListView.builder(
                                    padding: EdgeInsets.only(
                                      top: headerHeight,
                                      bottom: bottomPadding,
                                    ), // ✅ الحشوة السحرية
                                    itemCount: _sortedNames.length,
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    itemBuilder: (context, i) {
                                      final name = _sortedNames[i];
                                      final idx = i + 1;
                                      bool isEven = idx.isEven;
                                      Color rowColor = isEven
                                          ? _rowColorEven
                                          : _rowColorOdd;

                                      return Container(
                                        height: rowHeight,
                                        color: rowColor,
                                        child: Row(
                                          children: [
                                            Container(
                                              width: idWidth,
                                              height: rowHeight,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  bottom: BorderSide(
                                                    color: Colors.grey.shade300,
                                                  ),
                                                ),
                                              ),
                                              child: Text(
                                                '$idx'.toAppNum(),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            InkWell(
                                              onLongPress: () =>
                                                  _resetStudent(name),
                                              child: Container(
                                                width: nameWidth,
                                                height: rowHeight,
                                                alignment:
                                                    Alignment.centerRight,
                                                padding: const EdgeInsets.only(
                                                  right: 5,
                                                ),
                                                decoration: BoxDecoration(
                                                  border: Border(
                                                    bottom: BorderSide(
                                                      color:
                                                          Colors.grey.shade300,
                                                    ),
                                                    left: BorderSide(
                                                      color:
                                                          Colors.grey.shade300,
                                                    ),
                                                  ),
                                                ),
                                                child: Text(
                                                  name,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                            ..._columns.map((col) {
                                              bool isChecked =
                                                  _styleData[name]?[col] ??
                                                  false;
                                              return InkWell(
                                                onTap: () =>
                                                    _toggleStyle(name, col),
                                                child: Container(
                                                  width: colWidth,
                                                  height: rowHeight,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    border: Border(
                                                      bottom: BorderSide(
                                                        color: Colors
                                                            .grey
                                                            .shade300,
                                                      ),
                                                      left: BorderSide(
                                                        color: Colors
                                                            .grey
                                                            .shade300,
                                                      ),
                                                    ),
                                                  ),
                                                  child: isChecked
                                                      ? const Text(
                                                          '✓',
                                                          style: TextStyle(
                                                            color: Colors.green,
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        )
                                                      : const SizedBox.shrink(),
                                                ),
                                              );
                                            }),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child: _buildFixedHeader(
                                    colWidth,
                                    idWidth,
                                    nameWidth,
                                    totalWidth,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: MainBottomBar(
          currentIndex: _bottomIndex,
          onIndexChange: (index) => setState(() => _bottomIndex = index),
          onHomeTap: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const HomePage()),
              (route) => false,
            );
          },
          onFileTap: () {
            AppDialogs.showFileDialog(
              context,
              onExportTap: () => BackupService.exportBackup(context),
              onImportTap: () => BackupService.importBackup(context),
              onSettingsTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SecuritySettingsPage()),
              ),
            );
          },
          onContactTap: () => AppDialogs.showContactDialog(context),
          onHelpTap: () => AppDialogs.showInfoDialog(context),
        ),
      ),
    );
  }
}
