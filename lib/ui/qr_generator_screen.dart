import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

const Color primaryColor = Color(0xFF3A2EC3);
const List<Color> qrColors = [
  Colors.white, Colors.grey, Colors.orange, Colors.yellow,
  Colors.green, Colors.cyan, Colors.purple,
];

class QrGeneratorScreen extends StatefulWidget {
  const QrGeneratorScreen({super.key});

  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  final TextEditingController _textController = TextEditingController();

  String? _qrData;
  Color _qrColor = Colors.white;
  bool _isLoading = false;

  // --- TUGAS 1: SEND VIA EMAIL/SHARE ---
  Future<void> _handleSendEmail() async {
    if (_qrData == null) return;
    setState(() => _isLoading = true);
    
    try {
      final Uint8List? imageBytes = await _screenshotController.capture(
        pixelRatio: MediaQuery.of(context).devicePixelRatio,
      );

      if (imageBytes != null) {
        await Share.shareXFiles(
          [XFile.fromData(imageBytes, name: 'qr_code.png', mimeType: 'image/png')],
          text: 'QR Code untuk: $_qrData\nDibuat dengan QR S&G',
          subject: 'QR Code dari QR S&G App',
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- TUGAS 2 & BONUS: PRINT, SAVE & OPEN PDF ---
  Future<void> _handlePrintAndSave() async {
    if (_qrData == null) return;
    setState(() => _isLoading = true);

    try {
      final imageBytes = await _screenshotController.capture(pixelRatio: 3.0);
      if (imageBytes == null) return;

      final pdf = pw.Document();
      final qrImage = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('QR Code Generated', 
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Image(qrImage, width: 200, height: 200),
                pw.SizedBox(height: 20),
                pw.Text('Link/Teks: $_qrData', style: pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 10),
                // Bonus: Watermark/Logo info
                pw.Text('Dibuat oleh: Jose Shabra ~ - QR S&G App', 
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
              ],
            ),
          ),
        ),
      );

      // Tampilkan Preview/Print Dialog
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());

      // Bonus: Simpan ke storage dan buka otomatis
      final output = await getTemporaryDirectory();
      final file = File("${output.path}/QR_SG_${DateTime.now().millisecondsSinceEpoch}.pdf");
      await file.writeAsBytes(await pdf.save());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("PDF Berhasil dibuat!"),
            action: SnackBarAction(label: "BUKA", onPressed: () => OpenFile.open(file.path)),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isInputEmpty = _qrData == null || _qrData!.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create QR', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Header
          Column(
            children: [
              Container(height: 220, color: primaryColor),
              Expanded(child: Container(color: Colors.grey.shade50)),
            ],
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Column(
                      children: [
                        // PREVIEW AREA
                        Screenshot(
                          controller: _screenshotController,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _qrColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black12, width: 2),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))],
                            ),
                            child: isInputEmpty
                                ? const Padding(
                                    padding: EdgeInsets.all(40),
                                    child: Text('Masukkan teks/link untuk generate QR', 
                                      style: TextStyle(color: Colors.grey, fontSize: 16), textAlign: TextAlign.center),
                                  )
                                : PrettyQrView.data(
                                    data: _qrData!,
                                    decoration: const PrettyQrDecoration(shape: PrettyQrSmoothSymbol()),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // INPUT FIELD
                        TextField(
                          controller: _textController,
                          decoration: InputDecoration(
                            labelText: 'Link atau Teks',
                            hintText: 'https://example.com',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          maxLines: 3,
                          onChanged: (value) => setState(() => _qrData = value.trim().isEmpty ? null : value.trim()),
                        ),
                        const SizedBox(height: 24),

                        // COLOR PICKER
                        Text('Pilih Warna Background QR', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12, runSpacing: 12,
                          children: qrColors.map((color) => GestureDetector(
                            onTap: () => setState(() => _qrColor = color),
                            child: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle,
                                border: Border.all(color: _qrColor == color ? Colors.black : Colors.transparent, width: 3),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                              ),
                            ),
                          )).toList(),
                        ),
                        const SizedBox(height: 32),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // ACTION BUTTONS (TUGAS 1 & 2)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() { _qrData = null; _qrColor = Colors.white; _textController.clear(); });
                                },
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Reset'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: isInputEmpty ? null : _handleSendEmail,
                                icon: const Icon(Icons.send, size: 18),
                                label: const Text('Send'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: isInputEmpty ? null : _handlePrintAndSave,
                                icon: const Icon(Icons.print, size: 18),
                                label: const Text('Print'),
                                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // BONUS: LOADING OVERLAY
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }
}