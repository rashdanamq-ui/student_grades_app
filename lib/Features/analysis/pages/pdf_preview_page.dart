import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfPreviewPage extends StatefulWidget {
  final String title;
  final Future<Uint8List> Function(dynamic format) generatePdfFunction;

  const PdfPreviewPage({
    super.key,
    required this.title,
    required this.generatePdfFunction,
  });

  @override
  State<PdfPreviewPage> createState() => _PdfPreviewPageState();
}

class _PdfPreviewPageState extends State<PdfPreviewPage> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();

  Future<Uint8List>? _pdfFuture;
  Uint8List? _loadedBytes;

  // متغير لتخزين الزوم المناسب لعرض الصفحة كاملة
  double _fitPageZoom = 0.6;

  @override
  void initState() {
    super.initState();
    _pdfFuture = widget.generatePdfFunction(PdfPageFormat.a4);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.teal,
        centerTitle: true,
        // ✅ سهم الرجوع سيظهر تلقائياً جهة اليمين بسبب (RTL)
        // ✅ زر الطباعة سيظهر جهة اليسار لأنه في actions
        actions: [
          if (_loadedBytes != null)
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'طباعة / حفظ',
              onPressed: () async {
                await Printing.layoutPdf(
                  onLayout: (_) => _loadedBytes!,
                  name: widget.title,
                );
              },
            ),
        ],
      ),

      bottomNavigationBar: _loadedBytes == null ? null : _buildBottomToolbar(),

      body: LayoutBuilder(
        builder: (context, constraints) {
          return FutureBuilder<Uint8List>(
            future: _pdfFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.teal),
                );
              } else if (snapshot.hasError) {
                return Center(child: Text('خطأ: ${snapshot.error}'));
              } else if (snapshot.hasData) {
                if (_loadedBytes == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _loadedBytes = snapshot.data);
                  });
                }

                return SfPdfViewer.memory(
                  snapshot.data!,
                  key: _pdfViewerKey,
                  controller: _pdfViewerController,
                  // استخدام single يضمن ظهور صفحة واحدة في المنتصف
                  pageLayoutMode: PdfPageLayoutMode.single,
                  canShowScrollHead: true,
                  onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                    // ✅✅✅ المعادلة السحرية ✅✅✅
                    // حساب الزوم اللازم لتظهر ورقة A4 كاملة بناء على ارتفاع شاشتك
                    // A4 Ratio = الارتفاع / العرض تقريبا 1.41
                    double screenRatio =
                        constraints.maxHeight / constraints.maxWidth;

                    // إذا كانت الشاشة عريضة (كمبيوتر)، نصغر الزوم
                    // المعادلة: نسبة الشاشة / نسبة الورقة
                    _fitPageZoom = (screenRatio / 1.41).clamp(0.1, 1.0);

                    // تطبيق الزوم فوراً
                    _pdfViewerController.zoomLevel = _fitPageZoom;
                  },
                );
              }
              return const SizedBox();
            },
          );
        },
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return BottomAppBar(
      color: Colors.white,
      elevation: 10,
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.zoom_out, color: Colors.teal),
            tooltip: 'تصغير',
            onPressed: () {
              _pdfViewerController.zoomLevel =
                  (_pdfViewerController.zoomLevel - 0.1).clamp(0.1, 3.0);
            },
          ),

          // ✅ زر "احتواء الصفحة" يستخدم القيمة المحسوبة
          IconButton(
            icon: const Icon(Icons.fit_screen, color: Colors.teal),
            tooltip: 'عرض الصفحة كاملة',
            onPressed: () {
              _pdfViewerController.zoomLevel = _fitPageZoom;
            },
          ),

          IconButton(
            icon: const Icon(Icons.zoom_in, color: Colors.teal),
            tooltip: 'تكبير',
            onPressed: () {
              _pdfViewerController.zoomLevel =
                  (_pdfViewerController.zoomLevel + 0.1).clamp(0.1, 3.0);
            },
          ),
        ],
      ),
    );
  }
}
