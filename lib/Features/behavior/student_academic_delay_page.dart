//صفحة التاخر الدراسي//
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

class StudentAcademicDelayPage extends StatefulWidget {
  final String classId;
  final String classTitle;
  final List<String> studentNames;

  const StudentAcademicDelayPage({
    super.key,
    required this.classId,
    required this.classTitle,
    required this.studentNames,
  });

  @override
  State<StudentAcademicDelayPage> createState() =>
      _StudentAcademicDelayPageState();
}

class _StudentAcademicDelayPageState extends State<StudentAcademicDelayPage> {
  int _bottomIndex = 0;

  List<String> _columns = [
    'صعوبات تعلم',
    'أمراض',
    'خوف',
    'ضعف الثقة',
    'كراهية المادة',
    'فرط حركة',
    'نقص الانتباه',
    'دافعية',
    'غياب متكرر',
    'إهمال',
    'صحبة سيئة',
  ];

  Map<String, Map<String, bool>> _delayData = {};
  List<String> _trackedStudents = [];
  bool _isLoading = true;

  // Selection for multi-remove
  Set<String> _selectedStudents = {};
  bool _isSelectionMode = false;

  // Sorting
  List<String> _sortColumns = [];
  List<String> _sortedNames = [];

  final Color _headerColor = const Color(0xFFe0e0e0);
  final Color _rowColorEven = const Color(0xFFebeff2);
  final Color _rowColorOdd = Colors.white;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Columns
    final String? colStored = prefs.getString(
      'academic_delay_columns_${widget.classId}',
    );
    if (colStored != null) {
      _columns = List<String>.from(jsonDecode(colStored));
    }

    // Load Tracked Students
    final String? studentsStored = prefs.getString(
      'academic_delay_tracked_students_${widget.classId}',
    );
    if (studentsStored != null) {
      _trackedStudents = List<String>.from(jsonDecode(studentsStored));
    } else {
      // First time: load all class students
      _trackedStudents = List.from(widget.studentNames);
    }

    // Load Data
    final String? dataStored = prefs.getString(
      'academic_delay_data_${widget.classId}',
    );
    if (dataStored != null) {
      Map<String, dynamic> decoded = jsonDecode(dataStored);
      _delayData = decoded.map((key, value) {
        return MapEntry(key, Map<String, bool>.from(value));
      });
    }

    _applySort();
    setState(() => _isLoading = false);
  }

  void _applySort() {
    _sortedNames = List.from(_trackedStudents);
    if (_sortColumns.isEmpty) {
      _sortedNames.sort((a, b) => a.compareTo(b));
    } else {
      _sortedNames.sort((a, b) {
        for (String col in _sortColumns) {
          bool valA = _delayData[a]?[col] ?? false;
          bool valB = _delayData[b]?[col] ?? false;
          if (valA && !valB) return -1;
          if (!valA && valB) return 1;
        }
        return a.compareTo(b);
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'academic_delay_columns_${widget.classId}',
      jsonEncode(_columns),
    );
    await prefs.setString(
      'academic_delay_tracked_students_${widget.classId}',
      jsonEncode(_trackedStudents),
    );
    await prefs.setString(
      'academic_delay_data_${widget.classId}',
      jsonEncode(_delayData),
    );
  }

  void _toggleStyle(String studentName, String colName) {
    if (_isSelectionMode) {
      _toggleSelection(studentName);
      return;
    }
    setState(() {
      if (!_delayData.containsKey(studentName)) {
        _delayData[studentName] = {};
      }
      bool current = _delayData[studentName]![colName] ?? false;
      _delayData[studentName]![colName] = !current;
      _saveData();
      if (_sortColumns.contains(colName)) {
        _applySort();
      }
    });
  }

  void _toggleSelection(String name) {
    setState(() {
      if (_selectedStudents.contains(name)) {
        _selectedStudents.remove(name);
        if (_selectedStudents.isEmpty) _isSelectionMode = false;
      } else {
        _selectedStudents.add(name);
        _isSelectionMode = true;
      }
    });
  }

  void _showAddStudentDialog() {
    List<String> available = widget.studentNames
        .where((s) => !_trackedStudents.contains(s))
        .toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'جميع طلاب الصف مضافون بالفعل',
            textAlign: TextAlign.right,
          ),
        ),
      );
      return;
    }

    Set<String> tempSelected = {};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('إضافة طلاب للقائمة', textAlign: TextAlign.right),
            content: SizedBox(
              width: 300,
              height: 400,
              child: ListView.builder(
                itemCount: available.length,
                itemBuilder: (c, i) {
                  final name = available[i];
                  final isSel = tempSelected.contains(name);
                  return ListTile(
                    title: Text(name, textAlign: TextAlign.right),
                    trailing: Icon(
                      isSel ? Icons.check_box : Icons.check_box_outline_blank,
                      color: isSel ? Colors.brown : Colors.grey,
                    ),
                    onTap: () {
                      setDialogState(() {
                        if (isSel)
                          tempSelected.remove(name);
                        else
                          tempSelected.add(name);
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
              TextButton(
                onPressed: tempSelected.isEmpty
                    ? null
                    : () {
                        setState(() {
                          _trackedStudents.addAll(tempSelected);
                          _applySort();
                          _saveData();
                        });
                        Navigator.pop(ctx);
                      },
                child: Text('إضافة (${tempSelected.length})'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _removeSelectedStudents() async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('تأكيد الاستبعاد'),
            content: Text(
              'هل أنت متأكد من استبعاد ${_selectedStudents.length} طلاب من هذه الصفحة؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('استبعاد'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      setState(() {
        for (var name in _selectedStudents) {
          _trackedStudents.remove(name);
          _delayData.remove(name);
        }
        _selectedStudents.clear();
        _isSelectionMode = false;
        _applySort();
        _saveData();
      });
    }
  }

  void _showManageColumnsDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'إدارة مسببات التأخر',
                textAlign: TextAlign.right,
              ),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // New column field
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onSubmitted: (val) {
                              if (val.isNotEmpty) {
                                setState(() => _columns.add(val));
                                setDialogState(() {});
                                _saveData();
                              }
                            },
                            textAlign: TextAlign.right,
                            decoration: const InputDecoration(
                              hintText: 'إضافة سبب جديد...',
                              prefixIcon: Icon(Icons.add_circle_outline),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    SizedBox(
                      height: 300,
                      child: ListView.builder(
                        itemCount: _columns.length,
                        itemBuilder: (c, i) {
                          final name = _columns[i];
                          return ListTile(
                            leading: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _columns.removeAt(i);
                                  _sortColumns.remove(name);
                                });
                                setDialogState(() {});
                                _saveData();
                              },
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                _showRenameColumnDialog(i, setDialogState);
                              },
                            ),
                            title: Text(name, textAlign: TextAlign.right),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إغلاق'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRenameColumnDialog(int index, StateSetter setDialogState) {
    TextEditingController controller = TextEditingController(
      text: _columns[index],
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل اسم السبب'),
        content: TextField(controller: controller, textAlign: TextAlign.right),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  String old = _columns[index];
                  String newName = controller.text;
                  _columns[index] = newName;

                  // Update data map
                  for (var student in _delayData.keys) {
                    if (_delayData[student]?.containsKey(old) ?? false) {
                      _delayData[student]![newName] =
                          _delayData[student]![old]!;
                      _delayData[student]!.remove(old);
                    }
                  }

                  // Update sort columns
                  int sIdx = _sortColumns.indexOf(old);
                  if (sIdx != -1) _sortColumns[sIdx] = newName;
                  _saveData();
                });
                setDialogState(() {});
                Navigator.pop(ctx);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  // ===================== PDF Export =====================
  Future<void> _exportPdf() async {
    final orientation = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('اختيار تخطيط الصفحة', textAlign: TextAlign.center),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'portrait'),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('عمودي'),
                SizedBox(width: 10),
                Icon(Icons.portrait),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'landscape'),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('أفقي'),
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
    final fontRegular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Amiri-Regular.ttf'),
    );
    final fontBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Amiri-Bold.ttf'),
    );

    final List<String> pdfHeaders = [];
    for (var col in _columns.reversed) pdfHeaders.add(col);
    pdfHeaders.add('الاسم');
    pdfHeaders.add('ت');

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'سجل المتأخرين دراسياً: ${widget.classTitle}'.toAppNum(),
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(width: 0.5),
            columnWidths: {
              pdfHeaders.length - 1: const pw.FixedColumnWidth(25),
              pdfHeaders.length - 2: const pw.FixedColumnWidth(120),
            },
            defaultColumnWidth: const pw.FlexColumnWidth(1),
            children: [
              // Header Row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: pdfHeaders.map((h) {
                  if (h == 'الاسم' || h == 'ت') {
                    return pw.Container(
                      height: 60,
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        h,
                        style: pw.TextStyle(fontSize: 10, font: fontBold),
                      ),
                    );
                  }
                  return pw.Container(
                    height: 60,
                    alignment: pw.Alignment.center,
                    child: pw.Transform.rotate(
                      angle: 1.571,
                      child: pw.Text(
                        h,
                        style: pw.TextStyle(fontSize: 8, font: fontBold),
                        maxLines: 1,
                      ),
                    ),
                  );
                }).toList(),
              ),
              // Data Rows
              ..._sortedNames.asMap().entries.map((entry) {
                int i = entry.key;
                String name = entry.value;
                List<pw.Widget> cells = [];
                for (var col in _columns.reversed) {
                  bool isChecked = _delayData[name]?[col] ?? false;
                  cells.add(
                    pw.Container(
                      height: 20,
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
                          : null,
                    ),
                  );
                }
                cells.add(
                  pw.Container(
                    alignment: pw.Alignment.centerRight,
                    padding: const pw.EdgeInsets.all(2),
                    child: pw.Text(
                      name,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                );
                cells.add(
                  pw.Container(
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      (i + 1).toString().toAppNum(),
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                );
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: i.isEven
                        ? PdfColors.white
                        : PdfColor.fromHex("#f0f0f0"),
                  ),
                  children: cells,
                );
              }),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) => doc.save(),
      name: 'AcademicDelay_${widget.classTitle}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text('المتأخرين دراسياً - ${widget.classTitle}'.toAppNum()),
          centerTitle: true,
          backgroundColor: Colors.brown.shade700,
          actions: [
            if (_isSelectionMode)
              IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.amber),
                onPressed: _removeSelectedStudents,
              )
            else ...[
              IconButton(
                icon: Icon(
                  _sortColumns.isEmpty ? Icons.sort_by_alpha : Icons.abc,
                ),
                onPressed: () => setState(() {
                  _sortColumns.clear();
                  _applySort();
                }),
              ),
              IconButton(
                icon: const Icon(Icons.person_add),
                onPressed: _showAddStudentDialog,
                tooltip: 'إضافة طالب من الصف',
              ),
              IconButton(
                icon: const Icon(Icons.view_column_rounded),
                onPressed: _showManageColumnsDialog,
                tooltip: 'إدارة الأعمدة',
              ),
              IconButton(
                icon: const Icon(Icons.print),
                onPressed: _exportPdf,
                tooltip: 'طباعة',
              ),
            ],
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  if (_isSelectionMode)
                    Container(
                      color: Colors.amber.shade100,
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Text('تم تحديد ${_selectedStudents.length} طلاب'),
                          const Spacer(),
                          TextButton(
                            onPressed: () => setState(() {
                              _selectedStudents.clear();
                              _isSelectionMode = false;
                            }),
                            child: const Text('إلغاء التحديد'),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        double idWidth = 40;
                        double nameWidth = 220;
                        double colWidth = 60;
                        double totalWidth =
                            idWidth + nameWidth + (colWidth * _columns.length);

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          child: SizedBox(
                            width: totalWidth < constraints.maxWidth
                                ? constraints.maxWidth
                                : totalWidth,
                            child: Column(
                              children: [
                                // Header
                                Container(
                                  height: 100,
                                  color: _headerColor,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: idWidth,
                                        alignment: Alignment.center,
                                        child: const Text(
                                          'ت',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: nameWidth,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          border: Border(
                                            left: BorderSide(
                                              color: Colors.grey.shade400,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'الاسم',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      ..._columns.asMap().entries.map((entry) {
                                        int idx = entry.key;
                                        String col = entry.value;
                                        bool isSorting = _sortColumns.contains(
                                          col,
                                        );
                                        return InkWell(
                                          onTap: () => setState(() {
                                            _sortColumns.remove(col);
                                            _sortColumns.insert(0, col);
                                            _applySort();
                                          }),
                                          onLongPress: () =>
                                              _showRenameColumnDialog(
                                                idx,
                                                (fn) => setState(fn),
                                              ),
                                          child: Container(
                                            width: colWidth,
                                            decoration: BoxDecoration(
                                              border: Border(
                                                left: BorderSide(
                                                  color: Colors.grey.shade400,
                                                ),
                                              ),
                                              color: isSorting
                                                  ? Colors.brown.shade200
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
                                                      fontWeight: isSorting
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                                if (isSorting)
                                                  Positioned(
                                                    top: 4,
                                                    right: 4,
                                                    child: CircleAvatar(
                                                      radius: 8,
                                                      backgroundColor:
                                                          Colors.brown,
                                                      child: Text(
                                                        '${_sortColumns.indexOf(col) + 1}',
                                                        style: const TextStyle(
                                                          fontSize: 9,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                                // List
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: _sortedNames.length,
                                    itemBuilder: (context, i) {
                                      String name = _sortedNames[i];
                                      bool isEven = i.isEven;
                                      bool isSelected = _selectedStudents
                                          .contains(name);
                                      return Container(
                                        height:
                                            45, // Taller rows for better mobile touch
                                        color: isSelected
                                            ? Colors.amber.shade200
                                            : (isEven
                                                  ? _rowColorEven
                                                  : _rowColorOdd),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: idWidth,
                                              alignment: Alignment.center,
                                              child: Text(
                                                '${i + 1}'.toAppNum(),
                                              ),
                                            ),
                                            InkWell(
                                              onTap: () =>
                                                  _toggleSelection(name),
                                              onLongPress: () =>
                                                  _toggleSelection(name),
                                              child: Container(
                                                width: nameWidth,
                                                alignment:
                                                    Alignment.centerRight,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  border: Border(
                                                    left: BorderSide(
                                                      color:
                                                          Colors.grey.shade300,
                                                    ),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    if (_isSelectionMode ||
                                                        isSelected)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              left: 8,
                                                            ),
                                                        child: Icon(
                                                          isSelected
                                                              ? Icons.check_box
                                                              : Icons
                                                                    .check_box_outline_blank,
                                                          color: Colors.brown,
                                                          size: 20,
                                                        ),
                                                      ),
                                                    Expanded(
                                                      child: Text(
                                                        name,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            ..._columns.map((col) {
                                              bool checked =
                                                  _delayData[name]?[col] ??
                                                  false;
                                              return InkWell(
                                                onTap: () =>
                                                    _toggleStyle(name, col),
                                                child: Container(
                                                  width: colWidth,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    border: Border(
                                                      left: BorderSide(
                                                        color: Colors
                                                            .grey
                                                            .shade300,
                                                      ),
                                                    ),
                                                  ),
                                                  child: checked
                                                      ? const Icon(
                                                          Icons.check_circle,
                                                          color: Colors.green,
                                                          size: 24,
                                                        )
                                                      : null,
                                                ),
                                              );
                                            }),
                                          ],
                                        ),
                                      );
                                    },
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
          onHomeTap: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomePage()),
            (route) => false,
          ),
          onFileTap: () => AppDialogs.showFileDialog(
            context,
            onExportTap: () => BackupService.exportBackup(context),
            onImportTap: () => BackupService.importBackup(context),
            onSettingsTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SecuritySettingsPage()),
            ),
          ),
          onContactTap: () => AppDialogs.showContactDialog(context),
          onHelpTap: () => AppDialogs.showInfoDialog(context),
        ),
      ),
    );
  }
}
