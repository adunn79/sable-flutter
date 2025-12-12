import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/vital_reading.dart';
import '../services/medical_document_service.dart';
import '../services/health_data_service.dart';

/// Document Scan Screen - OCR scanning for medical documents
/// 
/// Supports:
/// - Lab reports
/// - Vital signs records
/// - Prescription labels
class DocumentScanScreen extends StatefulWidget {
  const DocumentScanScreen({super.key});

  @override
  State<DocumentScanScreen> createState() => _DocumentScanScreenState();
}

class _DocumentScanScreenState extends State<DocumentScanScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isProcessing = false;
  String _scanType = 'lab_report'; // lab_report, vital_signs
  
  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }
  
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showError('No camera available');
        return;
      }
      
      final camera = cameras.first;
      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      
      await _controller!.initialize();
      
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      _showError('Camera error: $e');
    }
  }
  
  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Scan Document',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.settings2),
            color: const Color(0xFF2A2A34),
            initialValue: _scanType,
            onSelected: (type) => setState(() => _scanType = type),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'lab_report',
                child: Row(
                  children: [
                    Icon(LucideIcons.testTube, size: 16),
                    SizedBox(width: 8),
                    Text('Lab Report'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'vital_signs',
                child: Row(
                  children: [
                    Icon(LucideIcons.heartPulse, size: 16),
                    SizedBox(width: 8),
                    Text('Vital Signs'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Privacy Notice
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.green.withOpacity(0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.shieldCheck, color: Colors.green, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Photo processed on-device only',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.green[300],
                  ),
                ),
              ],
            ),
          ),
          
          // Camera Preview
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_isInitialized && _controller != null)
                  CameraPreview(_controller!)
                else
                  const Center(child: CircularProgressIndicator()),
                
                // Scan overlay
                _buildScanOverlay(),
                
                // Processing indicator
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 16),
                          Text(
                            'Processing document...',
                            style: GoogleFonts.inter(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1A1A24),
            child: Column(
              children: [
                Text(
                  _scanType == 'lab_report' 
                      ? '📄 Position lab report in frame'
                      : '❤️ Position vital signs record in frame',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // TODO: Pick from gallery
                        },
                        icon: const Icon(LucideIcons.image),
                        label: const Text('Gallery'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _captureAndProcess,
                        icon: const Icon(LucideIcons.camera),
                        label: const Text('Capture'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildScanOverlay() {
    return CustomPaint(
      painter: ScanOverlayPainter(),
      child: Container(),
    );
  }
  
  Future<void> _captureAndProcess() async {
    if (_controller == null || !_isInitialized || _isProcessing) return;
    
    setState(() => _isProcessing = true);
    
    try {
      final image = await _controller!.takePicture();
      final file = File(image.path);
      
      if (_scanType == 'lab_report') {
        final result = await MedicalDocumentService.scanLabReport(file);
        _showLabResults(result);
      } else {
        final result = await MedicalDocumentService.scanVitalRecord(file);
        _showVitalResults(result);
      }
    } catch (e) {
      _showError('Scan failed: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }
  
  void _showLabResults(LabReportScanResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _LabResultsReview(
          result: result,
          scrollController: scrollController,
          onSave: _saveLabResults,
        ),
      ),
    );
  }
  
  void _showVitalResults(VitalScanResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => _VitalResultsReview(
          result: result,
          scrollController: scrollController,
          onSave: _saveVitalReadings,
        ),
      ),
    );
  }
  
  Future<void> _saveLabResults(List<ParsedLabResult> results) async {
    for (final result in results) {
      await HealthDataService.addLabResult(
        testName: result.testName,
        value: result.value,
        unit: result.unit,
        testDate: DateTime.now(),
        category: result.category,
        source: 'ocr',
      );
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved ${results.length} lab results')),
    );
    
    Navigator.pop(context);
    Navigator.pop(context);
  }
  
  Future<void> _saveVitalReadings(List<ParsedVitalReading> readings) async {
    for (final reading in readings) {
      await HealthDataService.addVitalReading(
        vitalType: reading.vitalType,
        primaryValue: reading.primaryValue,
        secondaryValue: reading.secondaryValue,
        unit: reading.unit,
        source: 'ocr',
      );
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved ${readings.length} vital readings')),
    );
    
    Navigator.pop(context);
    Navigator.pop(context);
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

/// Overlay painter for scan frame
class ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: size.width * 0.85,
        height: size.height * 0.6,
      ),
      const Radius.circular(12),
    );
    
    canvas.drawRRect(rect, paint);
    
    // Corner markers
    final cornerPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    
    const cornerLength = 30.0;
    final left = size.width * 0.075;
    final right = size.width * 0.925;
    final top = size.height * 0.2;
    final bottom = size.height * 0.8;
    
    // Top left
    canvas.drawLine(Offset(left, top + cornerLength), Offset(left, top), cornerPaint);
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), cornerPaint);
    
    // Top right
    canvas.drawLine(Offset(right - cornerLength, top), Offset(right, top), cornerPaint);
    canvas.drawLine(Offset(right, top), Offset(right, top + cornerLength), cornerPaint);
    
    // Bottom left
    canvas.drawLine(Offset(left, bottom - cornerLength), Offset(left, bottom), cornerPaint);
    canvas.drawLine(Offset(left, bottom), Offset(left + cornerLength, bottom), cornerPaint);
    
    // Bottom right
    canvas.drawLine(Offset(right - cornerLength, bottom), Offset(right, bottom), cornerPaint);
    canvas.drawLine(Offset(right, bottom - cornerLength), Offset(right, bottom), cornerPaint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Review sheet for lab results
class _LabResultsReview extends StatefulWidget {
  final LabReportScanResult result;
  final ScrollController scrollController;
  final Function(List<ParsedLabResult>) onSave;
  
  const _LabResultsReview({
    required this.result,
    required this.scrollController,
    required this.onSave,
  });

  @override
  State<_LabResultsReview> createState() => _LabResultsReviewState();
}

class _LabResultsReviewState extends State<_LabResultsReview> {
  late List<ParsedLabResult> _results;
  
  @override
  void initState() {
    super.initState();
    _results = List.from(widget.result.labResults);
  }
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(LucideIcons.testTube, color: Colors.cyan),
              const SizedBox(width: 10),
              Text(
                'Review Lab Results',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Found ${_results.length} results. Tap to edit.',
            style: GoogleFonts.inter(color: Colors.white54),
          ),
          const SizedBox(height: 20),
          
          // Results list
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      'No results detected.\nTry scanning again or add manually.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    controller: widget.scrollController,
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final result = _results[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    result.testName,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    '${result.value} ${result.unit}',
                                    style: GoogleFonts.inter(
                                      color: Colors.cyan,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (result.referenceRange != null)
                                    Text(
                                      'Ref: ${result.referenceRange}',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.white38,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(LucideIcons.x, size: 18, color: Colors.white38),
                              onPressed: () {
                                setState(() => _results.removeAt(index));
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          
          // Save button
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _results.isEmpty ? null : () => widget.onSave(_results),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('Save ${_results.length} Results'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Review sheet for vital readings
class _VitalResultsReview extends StatelessWidget {
  final VitalScanResult result;
  final ScrollController scrollController;
  final Function(List<ParsedVitalReading>) onSave;
  
  const _VitalResultsReview({
    required this.result,
    required this.scrollController,
    required this.onSave,
  });
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.heartPulse, color: Colors.red),
              const SizedBox(width: 10),
              Text(
                'Review Vital Signs',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Expanded(
            child: result.vitalReadings.isEmpty
                ? Center(
                    child: Text(
                      'No vitals detected.',
                      style: GoogleFonts.inter(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    itemCount: result.vitalReadings.length,
                    itemBuilder: (context, index) {
                      final reading = result.vitalReadings[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Text(
                              VitalTypes.getIcon(reading.vitalType),
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  VitalTypes.getDisplayName(reading.vitalType),
                                  style: GoogleFonts.inter(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  reading.secondaryValue != null
                                      ? '${reading.primaryValue.toInt()}/${reading.secondaryValue!.toInt()} ${reading.unit}'
                                      : '${reading.primaryValue} ${reading.unit}',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: result.vitalReadings.isEmpty 
                  ? null 
                  : () => onSave(result.vitalReadings),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('Save ${result.vitalReadings.length} Readings'),
            ),
          ),
        ],
      ),
    );
  }
}
