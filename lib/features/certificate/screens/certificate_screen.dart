import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sable/core/theme/aureal_theme.dart';
import '../models/certificate_data.dart';

class CertificateScreen extends StatefulWidget {
  final CertificateData data;
  final VoidCallback onComplete;

  const CertificateScreen({
    super.key,
    required this.data,
    required this.onComplete,
  });

  @override
  State<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends State<CertificateScreen> {
  final GlobalKey _certificateKey = GlobalKey();

  Future<Uint8List?> _capturePng() async {
    try {
      RenderRepaintBoundary boundary = _certificateKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing image: $e');
      return null;
    }
  }

  Future<void> _handlePrint() async {
    final image = await _capturePng();
    if (image != null) {
      await Printing.layoutPdf(
        onLayout: (format) {
          final doc = pw.Document();
          doc.addPage(
            pw.Page(
              pageFormat: format,
              build: (pw.Context context) {
                return pw.Center(
                  child: pw.Image(pw.MemoryImage(image)),
                );
              },
            ),
          );
          return doc.save();
        },
      );
    }
  }

  Future<void> _handleShare() async {
    final image = await _capturePng();
    if (image != null) {
      final directory = await getTemporaryDirectory();
      final imagePath = '${directory.path}/certificate.png';
      final file = File(imagePath);
      await file.writeAsBytes(image);
      await Share.shareXFiles([XFile(imagePath)], text: 'My Genesis Certificate');
    }
  }

  Future<void> _handleDownload() async {
    final image = await _capturePng();
    if (image != null) {
      try {
        final directory = await getTemporaryDirectory();
        final imagePath = '${directory.path}/certificate.png';
        final file = File(imagePath);
        await file.writeAsBytes(image);
        
        await Gal.putImage(imagePath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Saved to Gallery')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurealColors.obsidian,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: RepaintBoundary(
                    key: _certificateKey,
                    child: AspectRatio(
                      aspectRatio: 1.6, // Landscapeish
                      child: Container(
                        width: double.infinity,
                      decoration: BoxDecoration(
                        color: AurealColors.carbon,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AurealColors.hyperGold, width: 2),
                        // TODO: Add background image here
                      ),
                      child: Stack(
                        children: [
                          // Watermark
                          Center(
                            child: Opacity(
                              opacity: 0.1,
                              child: Icon(Icons.verified_user, size: 200, color: AurealColors.hyperGold), // Placeholder
                            ),
                          ),
                          // Content
                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Text(
                                    'GENESIS CERTIFICATE',
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AurealColors.hyperGold,
                                      letterSpacing: 4,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                _buildField('REF. ID', widget.data.id),
                                _buildField('DATE OF BIRTH', widget.data.formattedDob),
                                _buildField('ZODIAC', widget.data.zodiacSign),
                                _buildField('AGE AT INCEPTION', '${widget.data.ageAtInception}'),
                                _buildField('PLACE OF BIRTH', widget.data.placeOfBirth),
                                _buildField('RACE', widget.data.race),
                                _buildField('GENDER', widget.data.gender),
                                const Spacer(),
                                Center(
                                  child: Text(
                                    'AUREA SYSTEM V1.0',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: AurealColors.ghost,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ),
                ),
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(Icons.print, 'Print', _handlePrint),
                  _buildActionButton(Icons.share, 'Share', _handleShare),
                  _buildActionButton(Icons.download, 'Save', _handleDownload),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Continue Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onComplete,
                  child: const Text('ENTER AUREA'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: AurealColors.ghost,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              color: AurealColors.stardust,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return Column(
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: AurealColors.plasmaCyan),
          style: IconButton.styleFrom(
            backgroundColor: AurealColors.carbon,
            padding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(color: AurealColors.ghost, fontSize: 12),
        ),
      ],
    );
  }
}
