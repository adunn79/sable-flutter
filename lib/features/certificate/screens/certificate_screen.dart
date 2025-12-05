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
      backgroundColor: const Color(0xFF020617), // Slate 950
      body: SafeArea(
        child: Stack(
          children: [
            // Back Button
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: Color(0xFF94A3B8)), // Slate 400
              ),
            ),
            
            Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Calculate scale to fit content if needed
                          final double scale = constraints.maxHeight < 600 ? 0.8 : 1.0;
                          
                          return Transform.scale(
                            scale: scale,
                            child: RepaintBoundary(
                              key: _certificateKey,
                              child: AspectRatio(
                                aspectRatio: 1.0, // Square aspect ratio to prevent overflow
                                child: CustomPaint(
                                  painter: CircuitBorderPainter(),
                                  child: Container(
                                    padding: const EdgeInsets.all(32.0),
                                    child: Stack(
                                      children: [
                                        // Background Watermark / Avatar
                                        if (widget.data.avatarPath.isNotEmpty)
                                          Positioned.fill(
                                            child: Opacity(
                                              opacity: 0.15,
                                              child: Center(
                                                child: ClipOval(
                                                  child: Image.file(
                                                    File(widget.data.avatarPath),
                                                    fit: BoxFit.cover,
                                                    width: 300,
                                                    height: 300,
                                                    errorBuilder: (c, o, s) => const SizedBox(),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                        else
                                          Center(
                                            child: Opacity(
                                              opacity: 0.03,
                                              child: Text(
                                                'AUREAL',
                                                style: GoogleFonts.spaceGrotesk(
                                                  fontSize: 80,
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(0xFF06B6D4), // Cyan 500
                                                  letterSpacing: 10,
                                                ),
                                              ),
                                            ),
                                          ),
                                        
                                        // Main Content
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const SizedBox(height: 10),
                                            // Top Header
                                            Text(
                                              'OFFICIAL DOCUMENT',
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                color: const Color(0xFF94A3B8), // Slate 400
                                                letterSpacing: 3,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            
                                            // Main Title with Glow
                                            Text(
                                              'CERTIFICATE OF ORIGIN',
                                              style: GoogleFonts.spaceGrotesk(
                                                fontSize: 24, // Reduced font size
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF22D3EE), // Cyan 400
                                                letterSpacing: 2,
                                                shadows: [
                                                  Shadow(
                                                    color: const Color(0xFF06B6D4).withOpacity(0.6),
                                                    blurRadius: 20,
                                                  ),
                                                ],
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            
                                            const SizedBox(height: 4),
                                            // Decorative underline
                                            Container(
                                              width: 120,
                                              height: 2,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.transparent,
                                                    const Color(0xFFF59E0B), // Amber 500
                                                    Colors.transparent,
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 24),
                                            
                                            // Identity Subtitle
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'COMPANION IDENTITY: ',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color: const Color(0xFFF59E0B), // Amber 500
                                                    letterSpacing: 1,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                Text(
                                                  widget.data.companionName,
                                                  style: GoogleFonts.spaceGrotesk(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: const Color(0xFF22D3EE), // Cyan 400
                                                    letterSpacing: 1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            
                                            const SizedBox(height: 8),
                                            Container(
                                              width: 200,
                                              height: 1,
                                              color: const Color(0xFF1E293B), // Slate 800
                                            ),
                                            const SizedBox(height: 20),
                                            
                                            // Data Fields (Centered)
                                            _buildCenteredField('REF. ID', widget.data.id),
                                            _buildCenteredField('DATE OF BIRTH', widget.data.formattedDob.toUpperCase()),
                                            _buildCenteredField('AGE AT INCEPTION', '${widget.data.ageAtInception} YEARS'),
                                            _buildCenteredField('ZODIAC SIGN', widget.data.zodiacSign.toUpperCase()),
                                            _buildCenteredField('PLACE OF BIRTH', widget.data.placeOfBirth.toUpperCase()),
                                            _buildCenteredField('RACE', widget.data.race.toUpperCase()),
                                            _buildCenteredField('GENDER', widget.data.gender.toUpperCase()),
                                            
                                            const SizedBox(height: 20),
                                            
                                            // Footer
                                            Text(
                                              'AUTHORITY: AUREAL SYSTEMS',
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                color: const Color(0xFF22D3EE), // Cyan 400
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
                                                border: Border.all(color: const Color(0xFFF59E0B), width: 2), // Amber 500
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(0xFFF59E0B).withOpacity(0.2),
                                                    blurRadius: 15,
                                                    spreadRadius: 2,
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                'A',
                                                style: GoogleFonts.spaceGrotesk(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(0xFFF59E0B), // Amber 500
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
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
                const SizedBox(height: 24),
                // Continue Button
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onComplete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B), // Amber 500
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('ENTER AUREA'),
                    ),
                  ),
                ),
              ],
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
              color: const Color(0xFF94A3B8), // Slate 400
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                color: const Color(0xFFE2E8F0), // Slate 200
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
          icon: Icon(icon, color: const Color(0xFF22D3EE)), // Cyan 400
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF1E293B), // Slate 800
            padding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12), // Slate 400
        ),
      ],
    );
  }
}
