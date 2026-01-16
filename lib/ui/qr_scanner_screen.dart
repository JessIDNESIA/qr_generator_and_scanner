import 'dart:developer' as dev; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

const Color primaryColor = Color(0xFFE91E63);

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: true,
    formats: [BarcodeFormat.qrCode],
  );

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
    WidgetsBinding.instance.addObserver(this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const ScanGuideBottomSheet(),
      );
    });
  }

  Future<void> _requestCameraPermission() async {
    dev.log('Mengecek izin kamera...', name: 'SCANNER');
    final status = await Permission.camera.status;
    if (!status.isGranted) {
      final result = await Permission.camera.request();
      if (result.isGranted) {
        dev.log('Izin kamera diberikan oleh user.', name: 'SCANNER');
        _controller.start();
      } else if (result.isPermanentlyDenied) {
        dev.log('Izin kamera ditolak permanen. Mengarahkan ke settings.', name: 'SCANNER');
        openAppSettings();
      }
    } else {
      _controller.start();
    }
  }

  Future<void> _pickImageFromGallery() async {
    final ImagePicker picker = ImagePicker();
    
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image == null) {
        dev.log('User membatalkan pemilihan gambar.', name: 'GALLERY');
        return;
      }

      dev.log('Menganalisis gambar: ${image.name}', name: 'GALLERY');
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sedang menganalisis gambar...'), 
          duration: Duration(milliseconds: 1000),
        ),
      );

      final BarcodeCapture? capture = await _controller.analyzeImage(image.path);
      
      if (capture != null && capture.barcodes.isNotEmpty) {
        dev.log('QR Berhasil ditemukan!', name: 'GALLERY');
        _handleBarcode(capture);
      } else {
        dev.log('Gagal: Tidak ada data QR terdeteksi di gambar.', name: 'GALLERY');
        _showErrorMessage('Maaf, tidak ditemukan QR Code pada gambar tersebut. Pastikan gambar jelas.');
      }
    } catch (e) {
      dev.log('System Error: $e', name: 'GALLERY', error: e);
      _showErrorMessage('Terjadi kendala saat membaca file. Silakan coba gambar lain.');
    }
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    dev.log('Status Aplikasi: ${state.name}', name: 'SYSTEM');
    if (state == AppLifecycleState.inactive) {
      _controller.stop();
    } else if (state == AppLifecycleState.resumed) {
      _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: primaryColor,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          _buildJDHeader(context),
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _handleBarcode,
                ),
                Center(
                  child: CustomPaint(
                    size: const Size(280, 280),
                    painter: ScannerOverlayPainter(),
                  ),
                ),
                Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: const Text(
                        'Arahkan QR Code ke dalam kotak',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJDHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 8,
        bottom: 16,
      ),
      decoration: const BoxDecoration(
        color: primaryColor,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              const Text(
                'Scan QR Code',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 28),
            onPressed: _pickImageFromGallery,
            tooltip: "Pilih dari Galeri",
          ),
        ],
      ),
    );
  }

  void _handleBarcode(BarcodeCapture capture) async {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    _controller.stop();
    final String code = barcode.rawValue!;
    dev.log('QR Terdeteksi: $code', name: 'DECODER');

    final Uri? uri = Uri.tryParse(code);
    final bool isURL = uri != null && (uri.scheme == 'http' || uri.scheme == 'https');

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(isURL ? Icons.language : Icons.text_snippet, color: primaryColor),
            const SizedBox(width: 10),
            const Text('Hasil Pemindaian'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (capture.image != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(capture.image!, height: 120, width: double.infinity, fit: BoxFit.cover),
                ),
              ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: SelectableText(code, textAlign: TextAlign.center),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil disalin!')));
            },
            child: const Text('Salin', style: TextStyle(color: Colors.grey)),
          ),
          if (isURL)
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_browser, size: 18),
              label: const Text('Buka Link'),
              onPressed: () => _launchURL(code),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _controller.start();
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            child: const Text('Tutup', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    dev.log('Mencoba membuka URL: $url', name: 'BROWSER');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      dev.log('Gagal: Browser tidak merespon.', name: 'BROWSER');
      _showErrorMessage('Tidak dapat membuka tautan ini. Pastikan format URL benar.');
    }
  }
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    const cornerLength = 30.0;
    final path = Path();
    path.moveTo(0, cornerLength); path.lineTo(0, 0); path.lineTo(cornerLength, 0);
    path.moveTo(size.width - cornerLength, 0); path.lineTo(size.width, 0); path.lineTo(size.width, cornerLength);
    path.moveTo(0, size.height - cornerLength); path.lineTo(0, size.height); path.lineTo(cornerLength, size.height);
    path.moveTo(size.width - cornerLength, size.height); path.lineTo(size.width, size.height); path.lineTo(size.width, size.height - cornerLength);
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ScanGuideBottomSheet extends StatelessWidget {
  const ScanGuideBottomSheet({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.qr_code_scanner, size: 80, color: primaryColor),
          const SizedBox(height: 16),
          const Text('Scan QR Code', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('Arahkan kamera ke QR atau pilih dari galeri untuk membaca data secara instan.', textAlign: TextAlign.center),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, padding: const EdgeInsets.all(16)),
              child: const Text('Mulai Scan Sekarang', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}