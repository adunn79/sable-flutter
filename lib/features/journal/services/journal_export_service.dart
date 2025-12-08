import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/journal_entry.dart';
import 'journal_storage_service.dart';

/// Service for exporting journal entries to beautifully formatted PDF
class JournalExportService {
  
  // Premium color palette
  static const _primaryColor = PdfColor.fromInt(0xFF6B5B95); // Elegant purple
  static const _accentColor = PdfColor.fromInt(0xFF88B04B);  // Sage green
  static const _warmGray = PdfColor.fromInt(0xFF4A4A4A);
  static const _lightGray = PdfColor.fromInt(0xFFF5F5F5);
  static const _mediumGray = PdfColor.fromInt(0xFFE0E0E0);
  
  /// Export all entries (or filtered entries) to beautifully formatted PDF
  static Future<void> exportToPdf({
    List<JournalEntry>? entries,
    String? bucketId,
    DateTime? startDate,
    DateTime? endDate,
    String journalTitle = 'My Journal',
  }) async {
    // Get entries to export
    List<JournalEntry> entriesToExport;
    if (entries != null) {
      entriesToExport = entries;
    } else if (bucketId != null) {
      entriesToExport = JournalStorageService.getEntriesForBucket(bucketId);
    } else if (startDate != null && endDate != null) {
      entriesToExport = JournalStorageService.getEntriesInRange(startDate, endDate);
    } else {
      entriesToExport = JournalStorageService.getAllEntries();
    }
    
    if (entriesToExport.isEmpty) {
      throw Exception('No entries to export');
    }
    
    // Sort by date (oldest first for reading chronologically)
    entriesToExport.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    // Create PDF document
    final pdf = pw.Document(
      title: journalTitle,
      author: 'Sable Journal',
      creator: 'Sable App',
    );
    
    final exportDate = DateFormat('MMMM d, y').format(DateTime.now());
    
    // ═══════════════════════════════════════
    // ELEGANT COVER PAGE
    // ═══════════════════════════════════════
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Stack(
          children: [
            // Subtle gradient background
            pw.Positioned.fill(
              child: pw.Container(
                decoration: const pw.BoxDecoration(
                  gradient: pw.LinearGradient(
                    begin: pw.Alignment.topLeft,
                    end: pw.Alignment.bottomRight,
                    colors: [PdfColors.white, _lightGray],
                  ),
                ),
              ),
            ),
            // Decorative corner accent
            pw.Positioned(
              top: 0,
              right: 0,
              child: pw.Container(
                width: 200,
                height: 200,
                decoration: const pw.BoxDecoration(
                  color: _primaryColor,
                  borderRadius: pw.BorderRadius.only(
                    bottomLeft: pw.Radius.circular(200),
                  ),
                ),
              ),
            ),
            // Bottom accent
            pw.Positioned(
              bottom: 0,
              left: 0,
              child: pw.Container(
                width: 150,
                height: 150,
                decoration: pw.BoxDecoration(
                  color: _accentColor.shade(0.3),
                  borderRadius: const pw.BorderRadius.only(
                    topRight: pw.Radius.circular(150),
                  ),
                ),
              ),
            ),
            // Main content
            pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(30),
                    child: pw.Column(
                      children: [
                        // Decorative line
                        pw.Container(
                          width: 60,
                          height: 4,
                          decoration: const pw.BoxDecoration(
                            color: _primaryColor,
                            borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                          ),
                        ),
                        pw.SizedBox(height: 40),
                        // Title
                        pw.Text(
                          journalTitle,
                          style: pw.TextStyle(
                            fontSize: 42,
                            fontWeight: pw.FontWeight.bold,
                            color: _warmGray,
                            letterSpacing: 2,
                          ),
                        ),
                        pw.SizedBox(height: 16),
                        // Subtitle
                        pw.Text(
                          'A Collection of Thoughts & Reflections',
                          style: pw.TextStyle(
                            fontSize: 14,
                            color: PdfColors.grey600,
                            fontStyle: pw.FontStyle.italic,
                          ),
                        ),
                        pw.SizedBox(height: 50),
                        // Stats box
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: _mediumGray, width: 1),
                            borderRadius: pw.BorderRadius.circular(8),
                          ),
                          child: pw.Row(
                            mainAxisSize: pw.MainAxisSize.min,
                            children: [
                              _buildStatColumn('${entriesToExport.length}', 'Entries'),
                              pw.Container(
                                width: 1,
                                height: 40,
                                color: _mediumGray,
                                margin: const pw.EdgeInsets.symmetric(horizontal: 30),
                              ),
                              _buildStatColumn(
                                _calculateTotalWords(entriesToExport),
                                'Words',
                              ),
                              pw.Container(
                                width: 1,
                                height: 40,
                                color: _mediumGray,
                                margin: const pw.EdgeInsets.symmetric(horizontal: 30),
                              ),
                              _buildStatColumn(
                                _getDateRange(entriesToExport),
                                'Time Span',
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 60),
                        // Decorative line
                        pw.Container(
                          width: 60,
                          height: 4,
                          decoration: const pw.BoxDecoration(
                            color: _primaryColor,
                            borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Footer
            pw.Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: pw.Center(
                child: pw.Text(
                  'Exported on $exportDate',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    
    // ═══════════════════════════════════════
    // ENTRY PAGES - ELEGANT LAYOUT
    // ═══════════════════════════════════════
    for (final entry in entriesToExport) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.fromLTRB(50, 50, 50, 40),
          header: (context) => _buildEntryHeader(entry, context),
          footer: (context) => _buildPageFooter(entry, context),
          build: (context) => [
            // Entry content with elegant typography
            pw.Paragraph(
              text: entry.plainText,
              style: const pw.TextStyle(
                fontSize: 11,
                lineSpacing: 6,
                color: _warmGray,
              ),
              textAlign: pw.TextAlign.justify,
            ),
            
            // Tags section
            if (entry.tags.isNotEmpty) ...[
              pw.SizedBox(height: 30),
              pw.Container(
                padding: const pw.EdgeInsets.only(top: 15),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(color: _mediumGray, width: 0.5)),
                ),
                child: pw.Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: entry.tags.map((tag) => pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: pw.BoxDecoration(
                      color: _lightGray,
                      borderRadius: pw.BorderRadius.circular(15),
                    ),
                    child: pw.Text(
                      '#$tag',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: _primaryColor,
                      ),
                    ),
                  )).toList(),
                ),
              ),
            ],
          ],
        ),
      );
    }
    
    // Save to temp file
    final output = await getTemporaryDirectory();
    final fileName = 'journal_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    
    // Share the file
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: '$journalTitle - Exported $exportDate',
    );
  }
  
  static pw.Widget _buildStatColumn(String value, String label) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: _primaryColor,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey600,
          ),
        ),
      ],
    );
  }
  
  static pw.Widget _buildEntryHeader(JournalEntry entry, pw.Context context) {
    final dateFormat = DateFormat('EEEE');
    final fullDateFormat = DateFormat('MMMM d, y');
    final timeFormat = DateFormat('h:mm a');
    
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 25),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Date box
          pw.Container(
            width: 70,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: _primaryColor,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  entry.timestamp.day.toString(),
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.Text(
                  DateFormat('MMM').format(entry.timestamp).toUpperCase(),
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.white,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 20),
          // Date details
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  dateFormat.format(entry.timestamp),
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: _warmGray,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '${fullDateFormat.format(entry.timestamp)} at ${timeFormat.format(entry.timestamp)}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
                if (entry.location != null && entry.location!.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    entry.location!,
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey500,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Mood indicator
          if (entry.moodScore != null)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: pw.BoxDecoration(
                color: _getMoodColor(entry.moodScore!),
                borderRadius: pw.BorderRadius.circular(20),
              ),
              child: pw.Text(
                _getMoodLabel(entry.moodScore!),
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  static pw.Widget _buildPageFooter(JournalEntry entry, pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 15),
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _mediumGray, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Sable Journal',
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey400,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
          pw.Text(
            'Page ${context.pageNumber}',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey500,
            ),
          ),
        ],
      ),
    );
  }
  
  static String _calculateTotalWords(List<JournalEntry> entries) {
    int total = 0;
    for (final e in entries) {
      total += e.plainText.split(RegExp(r'\s+')).length;
    }
    if (total >= 1000) {
      return '${(total / 1000).toStringAsFixed(1)}k';
    }
    return total.toString();
  }
  
  static String _getDateRange(List<JournalEntry> entries) {
    if (entries.isEmpty) return '-';
    if (entries.length == 1) return '1 day';
    
    final sorted = List<JournalEntry>.from(entries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    final days = sorted.last.timestamp.difference(sorted.first.timestamp).inDays;
    if (days < 30) return '$days days';
    if (days < 365) return '${(days / 30).round()} months';
    return '${(days / 365).toStringAsFixed(1)} years';
  }
  
  static PdfColor _getMoodColor(int score) {
    return const [
      PdfColor.fromInt(0xFFE57373), // Red - Terrible
      PdfColor.fromInt(0xFFFFB74D), // Orange - Bad
      PdfColor.fromInt(0xFFFFD54F), // Yellow - Okay
      PdfColor.fromInt(0xFF81C784), // Light green - Good
      PdfColor.fromInt(0xFF4CAF50), // Green - Great
    ][score - 1];
  }
  
  static String _getMoodLabel(int score) {
    return const ['Terrible', 'Bad', 'Okay', 'Good', 'Great'][score - 1];
  }
  
  /// Export to plain text format
  static Future<void> exportToText({
    List<JournalEntry>? entries,
  }) async {
    final entriesToExport = entries ?? JournalStorageService.getAllEntries();
    
    if (entriesToExport.isEmpty) {
      throw Exception('No entries to export');
    }
    
    entriesToExport.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    final buffer = StringBuffer();
    final dateFormat = DateFormat('EEEE, MMMM d, y • h:mm a');
    
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('           MY JOURNAL');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('');
    buffer.writeln('${entriesToExport.length} entries');
    buffer.writeln('Exported: ${DateFormat('MMMM d, y').format(DateTime.now())}');
    buffer.writeln('');
    
    for (final entry in entriesToExport) {
      buffer.writeln('───────────────────────────────────────');
      buffer.writeln(dateFormat.format(entry.timestamp));
      if (entry.moodScore != null) {
        buffer.writeln('Mood: ${_getMoodLabel(entry.moodScore!)}');
      }
      if (entry.location != null && entry.location!.isNotEmpty) {
        buffer.writeln('Location: ${entry.location}');
      }
      buffer.writeln('');
      buffer.writeln(entry.plainText);
      if (entry.tags.isNotEmpty) {
        buffer.writeln('');
        buffer.writeln('Tags: ${entry.tags.map((t) => '#$t').join(' ')}');
      }
      buffer.writeln('');
    }
    
    buffer.writeln('═══════════════════════════════════════');
    
    final output = await getTemporaryDirectory();
    final fileName = 'journal_${DateFormat('yyyyMMdd').format(DateTime.now())}.txt';
    final file = File('${output.path}/$fileName');
    await file.writeAsString(buffer.toString());
    
    await Share.shareXFiles([XFile(file.path)], subject: 'My Journal Export');
  }
}
