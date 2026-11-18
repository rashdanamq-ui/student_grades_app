// lib/behavior_tracking_page.dart
// ==============/صفحة السلوك/===================
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/number_utils.dart'; // لدالة toAppNum

// مكتبات الطباعة والـ PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart'; // <--- استيراد لتحميل الخطوط

import '../../core/widgets/main_bottom_bar.dart';
import '../../core/widgets/app_dialogs.dart';
import '../home/home_page.dart';
import '../../services/backup_service.dart';
import '../security/security/security_settings_page.dart';

enum BehaviorType { negative, positive, neutral }

class BehaviorColumn {
  final String name;
  final BehaviorType type;
  BehaviorColumn(this.name, this.type);
}

class BehaviorTrackingPage extends StatefulWidget {
  final String classId;
  final String classTitle;
  final List<String> studentNames;

  const BehaviorTrackingPage({
    super.key,
    required this.classId,
    required this.classTitle,
    required this.studentNames,
  });

  @override
  State<BehaviorTrackingPage> createState() => _BehaviorTrackingPageState();
}

class _BehaviorTrackingPageState extends State<BehaviorTrackingPage> {
  int _bottomIndex = 0;

  // قائمة السلوكيات
  final List<BehaviorColumn> _columns = [
    // --- سلبيات ---
    BehaviorColumn('ضرب زملائه', BehaviorType.negative),
    BehaviorColumn('حركة زائدة', BehaviorType.negative),
    BehaviorColumn('لعب بالدرس', BehaviorType.negative),
    BehaviorColumn('نسيان أدوات', BehaviorType.negative),
    BehaviorColumn('كثرة الكلام', BehaviorType.negative),
    BehaviorColumn('تأخر عن الحصة', BehaviorType.negative),
    BehaviorColumn('غياب عن الحصة', BehaviorType.negative),
    BehaviorColumn('غير مرتب', BehaviorType.negative),
    BehaviorColumn('نوم بالحصة', BehaviorType.negative),
    BehaviorColumn('أكل بالحصة', BehaviorType.negative),

    // --- سمات شخصية ---
    BehaviorColumn('خجول', BehaviorType.neutral),
    BehaviorColumn('سرحان', BehaviorType.neutral),
    BehaviorColumn('يحتاج متابعة', BehaviorType.neutral),
    BehaviorColumn('كثرة الحمام', BehaviorType.neutral),

    // --- إيجابيات ---
    BehaviorColumn('هادئ', BehaviorType.positive),
    BehaviorColumn('مؤدب', BehaviorType.positive),
    BehaviorColumn('متميز', BehaviorType.positive),
    BehaviorColumn('مبادر', BehaviorType.positive),
    BehaviorColumn('مشاركة فعالة', BehaviorType.positive),
    BehaviorColumn('نظافة', BehaviorType.positive),
    BehaviorColumn('مساعد للمعلم', BehaviorType.positive),
  ];

  Map<String, Map<String, int>> _behaviorData = {};
  bool _isLoading = true;

  final Color _headerColor = const Color(0xFFe0e0e0);
  final Color _rowColorEven = const Color(0xFFebeff2);
  final Color _rowColorOdd = Colors.white;

  // ⚠️ تم حذف ScrollControllers لأننا سنستخدم هيكلية LayoutBuilder الموحدة

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString('behavior_data_${widget.classId}');
    if (stored != null) {
      Map<String, dynamic> decoded = jsonDecode(stored);
      _behaviorData = decoded.map((key, value) {
        return MapEntry(key, Map<String, int>.from(value));
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'behavior_data_${widget.classId}',
      jsonEncode(_behaviorData),
    );
  }

  void _incrementCount(String studentName, String colName) {
    setState(() {
      if (!_behaviorData.containsKey(studentName)) {
        _behaviorData[studentName] = {};
      }
      int current = _behaviorData[studentName]![colName] ?? 0;
      if (current < 10) {
        _behaviorData[studentName]![colName] = current + 1;
        _saveData();
      }
    });
  }

  void _decrementCount(String studentName, String colName) {
    setState(() {
      if (_behaviorData.containsKey(studentName)) {
        int current = _behaviorData[studentName]![colName] ?? 0;
        if (current > 0) {
          _behaviorData[studentName]![colName] = current - 1;
        }
      }
    });
    _saveData();
  }

  void _resetStudent(String studentName) {
    setState(() {
      _behaviorData.remove(studentName);
    });
    _saveData();
  }

  Color _getColumnColor(BehaviorType type) {
    switch (type) {
      case BehaviorType.negative:
        return const Color(0xFFffebee);
      case BehaviorType.positive:
        return const Color(0xFFe8f5e9);
      case BehaviorType.neutral:
        return const Color(0xFFfff3e0);
    }
  }

  Color _getHeaderColor(BehaviorType type) {
    switch (type) {
      case BehaviorType.negative:
        return const Color(0xFFef9a9a);
      case BehaviorType.positive:
        return const Color(0xFFa5d6a7);
      case BehaviorType.neutral:
        return const Color(0xFFffcc80);
    }
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
      headers.add(col.name);
    }
    headers.add('الاسم');
    headers.add('ت');

    pw.Widget buildTable() {
      final List<pw.TableRow> rows = [];
      const double headerHeight = 90.0;
      rows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: headers.map((h) {
            if (h == 'الاسم' || h == 'ت') {
              return pw.Container(
                height: headerHeight,
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.all(2),
                child: pw.Text(
                  h,
                  style: pw.TextStyle(font: fontBold, fontSize: 10),
                  textAlign: pw.TextAlign.center,
                ),
              );
            }
            return pw.Container(
              height: headerHeight,
              alignment: pw.Alignment.center,
              child: pw.Transform.rotate(
                angle: 1.571,
                child: pw.Container(
                  width: headerHeight,
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    h,
                    style: pw.TextStyle(font: fontBold, fontSize: 8),
                    textAlign: pw.TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    overflow: pw.TextOverflow.visible,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );

      for (int i = 0; i < widget.studentNames.length; i++) {
        final name = widget.studentNames[i];
        final idx = i + 1;
        final isEven = idx.isEven;
        final rowColor = isEven ? PdfColor.fromHex("#ebeff2") : PdfColors.white;

        List<pw.Widget> cells = [];
        for (var col in _columns.reversed) {
          int count = _behaviorData[name]?[col.name] ?? 0;
          PdfColor? cellColor;
          if (count > 0) {
            if (col.type == BehaviorType.negative) {
              cellColor = PdfColor.fromHex("#ffebee");
            } else if (col.type == BehaviorType.positive)
              cellColor = PdfColor.fromHex("#e8f5e9");
            else
              cellColor = PdfColor.fromHex("#fff3e0");
          }
          cells.add(
            pw.Container(
              height: 15,
              alignment: pw.Alignment.center,
              child: pw.Text(
                count > 0 ? count.toString().toAppNum() : '',
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 9,
                  color: count > 0 ? PdfColors.black : PdfColors.grey400,
                ),
              ),
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
        headers.length - 1: const pw.FixedColumnWidth(25),
        headers.length - 2: const pw.FixedColumnWidth(120),
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
              'سجل السلوك والمواظبة: ${widget.classTitle}'.toAppNum(),
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
      name: 'Behavior_${widget.classTitle}',
    );
  }

  // ===================== بناء الواجهة (الهيكلية الجديدة) =====================

  // 1. ويدجت لبناء صف العنوان الثابت (لم يعد يحتوي على ScrollView خاص به)
  Widget _buildFixedHeader(
    double colWidth,
    double idWidth,
    double nameWidth,
    double totalWidth,
  ) {
    return Container(
      height: 100, // ارتفاع الرأس الثابت
      width: totalWidth,
      color: _headerColor, // خلفية الرأس
      child: Row(
        children: [
          // ت
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
          // الاسم
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
          // الأعمدة
          ..._columns.map(
            (col) => Container(
              width: colWidth,
              height: 100,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: _getHeaderColor(col.type).withOpacity(0.3),
                border: Border(left: BorderSide(color: Colors.grey.shade400)),
              ),
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  col.name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  textAlign: TextAlign.center,
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
          title: Text('سجل السلوك - ${widget.classTitle}'.toAppNum()),
          centerTitle: true,
          backgroundColor: const Color(0xFFa2b2bf),
          actions: [
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
                          'هل أنت متأكد من حذف جميع سجلات السلوك؟',
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
                  setState(() => _behaviorData.clear());
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
                  // مسافة لحماية المحتوى من الـ AppBar
                  SizedBox(height: 10),

                  // استخدام Expanded لحساب المساحة المتبقية للجدول
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // 1. حساب الأبعاد
                        double screenWidth = constraints.maxWidth;
                        const double idWidth = 35;
                        const double nameWidth = 200;

                        // حساب عرض العمود الواحد
                        // ملاحظة: إذا كان العدد كبيراً قد نحتاج لعرض أكبر من الشاشة، لذا نستخدم منطق الحد الأدنى
                        double calculatedColWidth =
                            (screenWidth - idWidth - nameWidth) /
                            _columns.length;
                        double colWidth = calculatedColWidth < 40
                            ? 40
                            : calculatedColWidth;

                        double totalWidth =
                            idWidth + nameWidth + (colWidth * _columns.length);

                        // 2. حساب الارتفاع المتاح للقائمة
                        double headerHeight = 100;
                        double listAvailableHeight =
                            constraints.maxHeight - headerHeight;

                        // 3. حساب الحشوة السفلية (Bottom Padding) لتمكين الطالب الأخير من الصعود للأعلى
                        double rowHeight = 32;
                        double bottomPadding = listAvailableHeight - rowHeight;
                        if (bottomPadding < 0) bottomPadding = 0;

                        return ScrollConfiguration(
                          behavior: ScrollConfiguration.of(
                            context,
                          ).copyWith(scrollbars: false),
                          child: SingleChildScrollView(
                            scrollDirection: Axis
                                .horizontal, // هذا السكرول يحرك الرأس والجسم معاً
                            physics: const ClampingScrollPhysics(),
                            child: Stack(
                              children: [
                                SizedBox(
                                  width: totalWidth,
                                  height: constraints.maxHeight,
                                  child: ListView.builder(
                                    padding: EdgeInsets.only(
                                      top: headerHeight,
                                      bottom: bottomPadding,
                                    ), // ✅ الحشوة السحرية
                                    itemCount: widget.studentNames.length,
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    itemBuilder: (context, i) {
                                      final name = widget.studentNames[i];
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
                                            // ت
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
                                            // الاسم
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
                                            // الخلايا
                                            ..._columns.map((col) {
                                              int count =
                                                  _behaviorData[name]?[col
                                                      .name] ??
                                                  0;
                                              return InkWell(
                                                onTap: () => _incrementCount(
                                                  name,
                                                  col.name,
                                                ),
                                                onLongPress: () =>
                                                    _decrementCount(
                                                      name,
                                                      col.name,
                                                    ),
                                                child: Container(
                                                  width: colWidth,
                                                  height: rowHeight,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    color: count > 0
                                                        ? _getColumnColor(
                                                            col.type,
                                                          )
                                                        : null,
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
                                                  child: count > 0
                                                      ? Text(
                                                          '$count'.toAppNum(),
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        )
                                                      : const Text(
                                                          '',
                                                          style: TextStyle(
                                                            color: Colors.grey,
                                                            fontSize: 10,
                                                          ),
                                                        ),
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

        // الشريط السفلي
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
