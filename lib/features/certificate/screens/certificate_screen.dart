import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sable/core/theme/aureal_theme.dart';
import '../models/certificate_data.dart';
import '../widgets/circuit_border_painter.dart';

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
                      aspectRatio: 1.4, // Slightly taller to fit content
                      child: CustomPaint(
                        painter: CircuitBorderPainter(),
                        child: Container(
                          padding: const EdgeInsets.all(32.0),
                          child: Stack(
                            children: [
                              // Background Watermark
                              Center(
                                child: Opacity(
                                  opacity: 0.05,
                                  child: Text(
                                    'AUREAL',
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 80,
                                      fontWeight: FontWeight.bold,
                                      color: AurealColors.plasmaCyan,
                                      letterSpacing: 10,
                                    ),
                                  ),
                                ),
                              ),
                              
                              // Main Content
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 16),
                                  // Top Header
                                  Text(
                                    'OFFICIAL DOCUMENT',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: AurealColors.plasmaCyan.withOpacity(0.7),
                                      letterSpacing: 3,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  
                                  // Main Title with Glow
                                  Text(
                                    'CERTIFICATE OF ORIGIN',
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: AurealColors.plasmaCyan,
                                      letterSpacing: 2,
                                      shadows: [
                                        Shadow(
                                          color: AurealColors.plasmaCyan.withOpacity(0.8),
                                          blurRadius: 15,
                                        ),
                                      ],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  
                                  const SizedBox(height: 4),
                                  Container(
                                    width: 200,
                                    height: 1,
                                    color: AurealColors.hyperGold.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Identity Subtitle
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'COMPANION IDENTITY: ',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: AurealColors.hyperGold,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      Text(
                                        widget.data.race.split(' ').first.toUpperCase(), // e.g. SABLE
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AurealColors.plasmaCyan,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const Spacer(),
                                  
                                  // Data Fields (Centered)
                                  _buildCenteredField('REF. ID', widget.data.id),
                                  _buildCenteredField('DATE OF BIRTH', widget.data.formattedDob.toUpperCase()),
                                  _buildCenteredField('AGE AT INCEPTION', '${widget.data.ageAtInception} YEARS'),
                                  _buildCenteredField('ZODIAC SIGN', widget.data.zodiacSign.toUpperCase()),
                                  _buildCenteredField('PLACE OF BIRTH', widget.data.placeOfBirth.toUpperCase()),
                                  _buildCenteredField('RACE', widget.data.race.toUpperCase()),
                                  _buildCenteredField('GENDER', widget.data.gender.toUpperCase()),
                                  
                                  const Spacer(),
                                  
                                  // Footer
                                  Text(
                                    'AUTHORITY: AUREAL SYSTEMS',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AurealColors.plasmaCyan,
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // Seal (Gold Icon)
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AurealColors.hyperGold, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AurealColors.hyperGold.withOpacity(0.2),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.verified_user_outlined,
                                      color: AurealColors.hyperGold,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ],
                          ),
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

  Widget _buildCenteredField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.inter(
              color: AurealColors.hyperGold,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                color: AurealColors.stardust,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
              overflow: TextOverflow.ellipsis,
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
