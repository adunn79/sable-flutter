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
import 'package:sable/core/emotion/location_service.dart';
import 'package:sable/src/config/app_config.dart';
import 'package:sable/features/onboarding/services/onboarding_state_service.dart';
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
  String _placeOfOrigin = 'Loading...';
  String _companionName = 'SABLE';

  @override
  void initState() {
    super.initState();
    _loadLocationAndArchetype();
  }

  Future<void> _loadLocationAndArchetype() async {
    // Fetch current GPS location
    try {
      final apiKey = AppConfig.googleMapsApiKey;
      if (apiKey.isNotEmpty) {
        final locationName = await LocationService.getCurrentLocationName(apiKey);
        if (locationName != null && mounted) {
          setState(() {
            _placeOfOrigin = locationName.toUpperCase();
          });
        }
      }
    } catch (e) {
      debugPrint('Location fetch error: $e');
    }

    // If GPS failed, use stored location
    if (_placeOfOrigin == 'Loading...') {
      final stateService = await OnboardingStateService.create();
      final storedLocation = stateService.userCurrentLocation;
      if (storedLocation != null && mounted) {
        setState(() {
          _placeOfOrigin = storedLocation.toUpperCase();
        });
      } else {
        setState(() {
          _placeOfOrigin = widget.data.placeOfBirth.toUpperCase();
        });
      }
    }

    // Load archetype
    final stateService = await OnboardingStateService.create();
    final archetypeId = stateService.selectedArchetypeId;
    if (mounted) {
      setState(() {
        _companionName = archetypeId.toUpperCase();
      });
    }
  }

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
      await Share.shareXFiles([XFile(imagePath)], text: 'My Certificate of Origin');
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
      backgroundColor: const Color(0xFF020617),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: RepaintBoundary(
                  key: _certificateKey,
                  child: _buildCertificate(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(Icons.print, 'Print', _handlePrint),
                  _buildActionButton(Icons.share, 'Share', _handleShare),
                  _buildActionButton(Icons.download, 'Save', _handleDownload),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.onComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    'ENTER AUREA',
                    style: GoogleFonts.spaceGrotesk(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificate() {
    return FittedBox(
      fit: BoxFit.contain,
      child: Container(
        width: 480,
        height: 720,
        decoration: BoxDecoration(
          color: const Color(0xFF0A0F1A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: CustomPaint(
          painter: _CertificateBorderPainter(),
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                // Top decorative chevron
                CustomPaint(
                  size: const Size(100, 20),
                  painter: _ChevronPainter(isTop: true),
                ),
                const SizedBox(height: 16),
                // Header
                Text(
                  'OFFICIAL DOCUMENT',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                    letterSpacing: 6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                // Main title with gradient
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF22D3EE), Color(0xFF06B6D4), Color(0xFF0891B2)],
                  ).createShader(bounds),
                  child: Text(
                    'CERTIFICATE',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 8,
                    ),
                  ),
                ),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF22D3EE), Color(0xFF06B6D4), Color(0xFF0891B2)],
                  ).createShader(bounds),
                  child: Text(
                    'OF ORIGIN',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 6,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Decorative line
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildDecorativeLine(),
                    const SizedBox(width: 12),
                    Icon(Icons.circle, size: 6, color: const Color(0xFFF59E0B)),
                    const SizedBox(width: 12),
                    _buildDecorativeLine(),
                  ],
                ),
                const SizedBox(height: 20),
                // Companion identity block
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF22D3EE).withOpacity(0.5), width: 1),
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF06B6D4).withOpacity(0.05),
                        Colors.transparent,
                        const Color(0xFF06B6D4).withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'COMPANION IDENTITY:  ',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFFF59E0B),
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _companionName,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF22D3EE),
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Data fields
                _buildDataField('REF. ID', widget.data.id),
                _buildDataField('DATE OF BIRTH', widget.data.formattedDob.toUpperCase()),
                _buildDataField('AGE AT INCEPTION', '${widget.data.ageAtInception} YEARS'),
                _buildDataField('ZODIAC SIGN', widget.data.zodiacSign),
                _buildDataField('PLACE OF BIRTH', _placeOfOrigin),
                _buildDataField('RACE', 'HYPER HUMAN AI'),
                _buildDataField('GENDER', widget.data.gender.toUpperCase()),
                const SizedBox(height: 28),
                // Authority section
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        const Color(0xFFF59E0B).withOpacity(0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Text(
                    'AUTHORITY: AUREA SYSTEMS',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFFF59E0B),
                      letterSpacing: 4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Gold seal
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFFFBBF24), Color(0xFFF59E0B), Color(0xFFB45309)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withOpacity(0.6),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                    border: Border.all(color: const Color(0xFFFBBF24), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      'A',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Bottom chevron
                CustomPaint(
                  size: const Size(100, 20),
                  painter: _ChevronPainter(isTop: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDecorativeLine() {
    return Container(
      width: 60,
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            const Color(0xFF334155),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildDataField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 180,
            child: Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: const Color(0xFFE2E8F0),
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1E293B),
            border: Border.all(color: const Color(0xFF22D3EE).withOpacity(0.3)),
          ),
          child: IconButton(
            onPressed: onTap,
            icon: Icon(icon, color: const Color(0xFF22D3EE)),
            padding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11)),
      ],
    );
  }
}

class _CertificateBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Outer glow
    final outerGlowPaint = Paint()
      ..color = const Color(0xFF22D3EE).withOpacity(0.2)
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15)
      ..style = PaintingStyle.stroke;

    // Main cyan border
    final cyanPaint = Paint()
      ..color = const Color(0xFF06B6D4)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Inner border
    final innerPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Gold accent paint
    final goldPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw glow
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(8, 8, size.width - 16, size.height - 16),
      const Radius.circular(6),
    ), outerGlowPaint);

    // Draw main frame
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(8, 8, size.width - 16, size.height - 16),
      const Radius.circular(6),
    ), cyanPaint);

    // Draw inner frame
    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(16, 16, size.width - 32, size.height - 32),
      const Radius.circular(4),
    ), innerPaint);

    // Corner brackets
    _drawCornerBrackets(canvas, size, cyanPaint);
    
    // Gold corner accents
    _drawGoldCorners(canvas, size, goldPaint);
  }

  void _drawCornerBrackets(Canvas canvas, Size size, Paint paint) {
    const len = 40.0;
    const offset = 4.0;

    // Top-left
    canvas.drawLine(Offset(offset, offset + len), Offset(offset, offset), paint);
    canvas.drawLine(Offset(offset, offset), Offset(offset + len, offset), paint);

    // Top-right
    canvas.drawLine(Offset(size.width - offset - len, offset), Offset(size.width - offset, offset), paint);
    canvas.drawLine(Offset(size.width - offset, offset), Offset(size.width - offset, offset + len), paint);

    // Bottom-left
    canvas.drawLine(Offset(offset, size.height - offset - len), Offset(offset, size.height - offset), paint);
    canvas.drawLine(Offset(offset, size.height - offset), Offset(offset + len, size.height - offset), paint);

    // Bottom-right
    canvas.drawLine(Offset(size.width - offset - len, size.height - offset), Offset(size.width - offset, size.height - offset), paint);
    canvas.drawLine(Offset(size.width - offset, size.height - offset - len), Offset(size.width - offset, size.height - offset), paint);
  }

  void _drawGoldCorners(Canvas canvas, Size size, Paint paint) {
    const len = 12.0;
    const offset = 22.0;

    // Draw small gold L-shapes at each corner
    canvas.drawLine(Offset(offset, offset), Offset(offset + len, offset), paint);
    canvas.drawLine(Offset(offset, offset), Offset(offset, offset + len), paint);

    canvas.drawLine(Offset(size.width - offset, offset), Offset(size.width - offset - len, offset), paint);
    canvas.drawLine(Offset(size.width - offset, offset), Offset(size.width - offset, offset + len), paint);

    canvas.drawLine(Offset(offset, size.height - offset), Offset(offset + len, size.height - offset), paint);
    canvas.drawLine(Offset(offset, size.height - offset), Offset(offset, size.height - offset - len), paint);

    canvas.drawLine(Offset(size.width - offset, size.height - offset), Offset(size.width - offset - len, size.height - offset), paint);
    canvas.drawLine(Offset(size.width - offset, size.height - offset), Offset(size.width - offset, size.height - offset - len), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChevronPainter extends CustomPainter {
  final bool isTop;
  _ChevronPainter({required this.isTop});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (isTop) {
      path.moveTo(0, size.height);
      path.lineTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width / 2, size.height);
      path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
