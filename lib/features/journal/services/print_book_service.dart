import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import '../models/journal_entry.dart';
import 'package:intl/intl.dart';

/// Service for creating print-quality PDF books from journal entries
class PrintBookService {
  /// Generate PDF book from journal entries
  static Future<pw.Document> generateBook({
    required List<JournalEntry> entries,
    DateTime? startDate,
    DateTime? endDate,
    String title = 'My Journal',
    bool includePrivate = false,
    bool includeMetadata = true,
  }) async {
    final pdf = pw.Document();
    
    // Filter entries
    var filteredEntries = entries.where((e) {
      if (!includePrivate && e.isPrivate) return false;
      if (startDate != null && e.timestamp.isBefore(startDate)) return false;
      if (endDate != null && e.timestamp.isAfter(endDate)) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    if (filteredEntries.isEmpty) {
      throw Exception('No entries found for the selected criteria');
    }
    
    // Load custom font (optional)
    final font = await PdfGoogleFonts.notoSerifRegular();
    final boldFont = await PdfGoogleFonts.notoSerifBold();
    
    // Add title page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        build: (context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 36,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  '${DateFormat('MMMM d, yyyy').format(filteredEntries.first.timestamp)} - ${DateFormat('MMMM d, yyyy').format(filteredEntries.last.timestamp)}',
                  style: pw.TextStyle(font: font, fontSize: 14),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  '${filteredEntries.length} entries',
                  style: pw.TextStyle(font: font, fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
    
    // Add entries
    for (var entry in filteredEntries) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a5,
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Date header
                pw.Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(entry.timestamp),
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 16,
                  ),
                ),
                
                // Metadata row (if enabled)
                if (includeMetadata) ...[
                  pw.SizedBox(height: 8),
                  pw.Row(
                    children: [
                      if (entry.moodScore != null)
                        pw.Text(
                          'Mood: ${_getMoodEmoji(entry.moodScore!)}',
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                      if (entry.weather != null) ...[
                        pw.SizedBox(width: 10),
                        pw.Text(
                          entry.weather!,
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                      ],
                      if (entry.location != null) ...[
                        pw.SizedBox(width: 10),
                        pw.Text(
                          '📍 ${entry.location}',
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ],
                
                pw.SizedBox(height: 12),
                pw.Divider(),
                pw.SizedBox(height: 12),
                
                // Entry content
                pw.Expanded(
                  child: pw.Text(
                    entry.plainText,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
                
                // Tags
                if (entry.tags.isNotEmpty) ...[
                  pw.SizedBox(height: 12),
                  pw.Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: entry.tags.map((tag) {
                      return pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey400),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          '#$tag',
                          style: pw.TextStyle(font: font, fontSize: 9),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            );
          },
        ),
      );
    }
    
    return pdf;
  }
  
  /// Save PDF to device
  static Future<void> savePdf(pw.Document pdf, String filename) async {
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: filename,
    );
  }
  
  /// Print PDF directly
  static Future<void> printPdf(pw.Document pdf) async {
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }
  
  static String _getMoodEmoji(int score) {
    const moods = ['😢', '😔', '😐', '🙂', '😊'];
    return moods[score - 1];
  }
}
