import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart PDF Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.indigo, useMaterial3: true),
      home: const ScanHomePage(),
    );
  }
}

class ScanHomePage extends StatefulWidget {
  const ScanHomePage({super.key});

  @override
  State<ScanHomePage> createState() => _ScanHomePageState();
}

class _ScanHomePageState extends State<ScanHomePage> {
  String _selectedSize = 'Sedang';
  String? _generatedPdfPath;
  int? _fileSizeBytes;
  bool _isLoading = false;

  final Map<String, int> _compressionQuality = {
    'Besar': 85,
    'Sedang': 55,
    'Kecil': 25,
  };

  Future<void> _startDocumentScan() async {
    try {
      final options = DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg,
        mode: ScannerMode.full,
        isGalleryImport: true,
        pageLimit: 10,
      );
      final documentScanner = DocumentScanner(options: options);
      final result = await documentScanner.scanDocument();

      if (result.images != null && result.images!.isNotEmpty) {
        setState(() => _isLoading = true);
        String pdfPath = await _generateCompressedPdf(
          result.images!,
          _compressionQuality[_selectedSize] ?? 55,
        );
        final file = File(pdfPath);
        final sizeInBytes = await file.length();
        setState(() {
          _generatedPdfPath = pdfPath;
          _fileSizeBytes = sizeInBytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan saat scan: $e')),
        );
      }
    }
  }

  Future<String> _generateCompressedPdf(List<String> imagePaths, int quality) async {
    final pdf = pw.Document();
    final tempDir = await getTemporaryDirectory();

    for (int i = 0; i < imagePaths.length; i++) {
      final imagePath = imagePaths[i];
      final compressedImagePath = '${tempDir.path}/temp_img_$i.jpg';
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imagePath,
        compressedImagePath,
        quality: quality,
      );
      final imageBytes = compressedFile != null
          ? await compressedFile.readAsBytes()
          : await File(imagePath).readAsBytes();
      final pdfImage = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
    }

    final outputDir = await getApplicationDocumentsDirectory();
    final outputPath = '${outputDir.path}/Scan_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final pdfFile = File(outputPath);
    await pdfFile.writeAsBytes(await pdf.save());
    return outputPath;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart PDF Scanner'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pilih Ukuran Output PDF:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Column(
                      children: ['Besar', 'Sedang', 'Kecil'].map((size) {
                        return RadioListTile<String>(
                          title: Text(size == 'Besar' ? 'Besar (Kualitas Asli)' : size == 'Sedang' ? 'Sedang (Rekomendasi)' : 'Kecil (Hemat Ukuran / WA)'),
                          value: size,
                          groupValue: _selectedSize,
                          onChanged: (val) => setState(() => _selectedSize = val!),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _startDocumentScan,
              icon: const Icon(Icons.camera_alt, size: 28),
              label: const Text('Scan Dokumen Sekarang', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: Column(children: [CircularProgressIndicator(), SizedBox(height: 12), Text('Memproses & Mengompres PDF...')]))
            else if (_generatedPdfPath != null)
              Expanded(
                child: Card(
                  color: Colors.green.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 50),
                        const SizedBox(height: 12),
                        const Text('PDF Berhasil Dibuat!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                        const SizedBox(height: 8),
                        if (_fileSizeBytes != null) Text('Ukuran File: ${_formatFileSize(_fileSizeBytes!)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
