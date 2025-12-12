import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import '../services/prescription_ocr_service.dart';
import '../models/prescription.dart';
import 'prescription_edit_screen.dart';

/// Camera screen for scanning prescription labels
class PrescriptionScanScreen extends StatefulWidget {
  const PrescriptionScanScreen({super.key});

  @override
  State<PrescriptionScanScreen> createState() => _PrescriptionScanScreenState();
}

class _PrescriptionScanScreenState extends State<PrescriptionScanScreen> {
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No camera available';
        });
        return;
      }

      // Use back camera
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Camera error: $e';
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.x, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Scan Prescription',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _errorMessage != null
          ? _buildError()
          : !_isInitialized
              ? const Center(child: CircularProgressIndicator())
              : _buildCamera(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.cameraOff, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: GoogleFonts.inter(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AelianaColors.obsidian,
            ),
            child: Text('Go Back', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildCamera() {
    return Stack(
      children: [
        // Camera preview
        Positioned.fill(
          child: CameraPreview(_cameraController!),
        ),
        
        // Overlay guide
        Positioned.fill(
          child: CustomPaint(
            painter: _ScanGuidePainter(),
          ),
        ),
        
        // Instructions
        Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.info, color: AelianaColors.plasmaCyan, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Align the prescription label within the frame. Ensure good lighting.',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Capture button
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _isProcessing ? null : _capture,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isProcessing ? Colors.grey : AelianaColors.plasmaCyan,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: _isProcessing
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Icon(LucideIcons.camera, color: Colors.black, size: 28),
              ),
            ),
          ),
        ),
        
        // Privacy notice
        Positioned(
          bottom: 130,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.lock, color: AelianaColors.hyperGold, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Photo processed on-device only',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _capture() async {
    if (_isProcessing || _cameraController == null) return;
    
    setState(() => _isProcessing = true);
    
    try {
      final image = await _cameraController!.takePicture();
      final bytes = await File(image.path).readAsBytes();
      
      // Process with OCR
      final result = await PrescriptionOcrService.scanFromFile(image.path);
      
      if (!mounted) return;
      
      if (result.success && result.hasData) {
        // Show review screen with extracted data
        final prescription = await Navigator.push<Prescription>(
          context,
          MaterialPageRoute(
            builder: (_) => PrescriptionEditScreen(
              scanResult: result,
              photoPath: image.path,
            ),
          ),
        );
        
        if (prescription != null && mounted) {
          Navigator.pop(context, prescription);
        }
      } else {
        // OCR didn't find much, let user enter manually
        _showScanResultDialog(result);
      }
    } catch (e) {
      debugPrint('Capture error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showScanResultDialog(PrescriptionScanResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AelianaColors.obsidian,
        title: Text(
          'Limited Scan Results',
          style: GoogleFonts.spaceGrotesk(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We couldn\'t extract much from this image. This can happen with worn labels or poor lighting.',
              style: GoogleFonts.inter(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Text(
              'Would you like to try again or enter the details manually?',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Try Again', style: GoogleFonts.inter(color: AelianaColors.plasmaCyan)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final prescription = await Navigator.push<Prescription>(
                context,
                MaterialPageRoute(
                  builder: (_) => PrescriptionEditScreen(scanResult: result),
                ),
              );
              if (prescription != null && mounted) {
                Navigator.pop(context, prescription);
              }
            },
            child: Text('Enter Manually', style: GoogleFonts.inter(color: AelianaColors.hyperGold)),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for scan guide overlay
class _ScanGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AelianaColors.plasmaCyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    // Calculate frame dimensions
    final frameWidth = size.width * 0.85;
    final frameHeight = size.height * 0.35;
    final left = (size.width - frameWidth) / 2;
    final top = (size.height - frameHeight) / 2 - 40;
    
    // Draw corner brackets
    const cornerLength = 30.0;
    
    // Top-left corner
    canvas.drawLine(Offset(left, top + cornerLength), Offset(left, top), paint);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), paint);
    
    // Top-right corner
    canvas.drawLine(Offset(left + frameWidth - cornerLength, top), Offset(left + frameWidth, top), paint);
    canvas.drawLine(Offset(left + frameWidth, top), Offset(left + frameWidth, top + cornerLength), paint);
    
    // Bottom-left corner
    canvas.drawLine(Offset(left, top + frameHeight - cornerLength), Offset(left, top + frameHeight), paint);
    canvas.drawLine(Offset(left, top + frameHeight), Offset(left + cornerLength, top + frameHeight), paint);
    
    // Bottom-right corner
    canvas.drawLine(Offset(left + frameWidth - cornerLength, top + frameHeight), Offset(left + frameWidth, top + frameHeight), paint);
    canvas.drawLine(Offset(left + frameWidth, top + frameHeight), Offset(left + frameWidth, top + frameHeight - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
