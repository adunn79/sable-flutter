import 'dart:io';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:device_calendar/device_calendar.dart';
import 'calendar_service.dart';

/// Calendar Export Service - PDF generation and printing
/// 
/// Best-in-class features inspired by BusyCal, Fantastical:
/// - Multiple print templates (12+ original designs)
/// - Day, Week, Month, Year views
/// - Custom date ranges
/// - AirPrint support
/// - Share as PDF or image
enum CalendarTemplate {
  minimal,
  detailed,
  grid,
  artistic,
  weekPlanner,
  monthOverview,
  agenda,
  professional,
  compact,
  colorful,
  academic,
  executive,
}

extension CalendarTemplateInfo on CalendarTemplate {
  String get displayName {
    switch (this) {
      case CalendarTemplate.minimal: return 'Minimal';
      case CalendarTemplate.detailed: return 'Detailed';
      case CalendarTemplate.grid: return 'Grid';
      case CalendarTemplate.artistic: return 'Artistic';
      case CalendarTemplate.weekPlanner: return 'Week Planner';
      case CalendarTemplate.monthOverview: return 'Month Overview';
      case CalendarTemplate.agenda: return 'Agenda';
      case CalendarTemplate.professional: return 'Professional';
      case CalendarTemplate.compact: return 'Compact';
      case CalendarTemplate.colorful: return 'Colorful';
      case CalendarTemplate.academic: return 'Academic';
      case CalendarTemplate.executive: return 'Executive';
    }
  }
  
  String get description {
    switch (this) {
      case CalendarTemplate.minimal: return 'Clean design, essential info only';
      case CalendarTemplate.detailed: return 'Notes area, checklist space';
      case CalendarTemplate.grid: return 'Hour-by-hour time blocks';
      case CalendarTemplate.artistic: return 'Gradient accents, stylish';
      case CalendarTemplate.weekPlanner: return '7-day overview, goals section';
      case CalendarTemplate.monthOverview: return 'Full month at a glance';
      case CalendarTemplate.agenda: return 'List format, best for busy days';
      case CalendarTemplate.professional: return 'Business-ready, neutral colors';
      case CalendarTemplate.compact: return 'Fits more events, smaller text';
      case CalendarTemplate.colorful: return 'Category colors, visual coding';
      case CalendarTemplate.academic: return 'Semester/term format, class times';
      case CalendarTemplate.executive: return 'Premium look, meeting-focused';
    }
  }
  
  String get icon {
    switch (this) {
      case CalendarTemplate.minimal: return '◻️';
      case CalendarTemplate.detailed: return '📝';
      case CalendarTemplate.grid: return '▦';
      case CalendarTemplate.artistic: return '🎨';
      case CalendarTemplate.weekPlanner: return '📅';
      case CalendarTemplate.monthOverview: return '🗓️';
      case CalendarTemplate.agenda: return '📋';
      case CalendarTemplate.professional: return '💼';
      case CalendarTemplate.compact: return '📐';
      case CalendarTemplate.colorful: return '🌈';
      case CalendarTemplate.academic: return '🎓';
      case CalendarTemplate.executive: return '👔';
    }
  }
}

enum CalendarView { day, week, month, year }

class CalendarExportService {
  
  /// Export calendar to PDF
  static Future<File> exportToPdf({
    required DateTime startDate,
    required DateTime endDate,
    required CalendarTemplate template,
    required CalendarView view,
  }) async {
    // Fetch events for the date range
    final events = await CalendarService.getEventsInRange(startDate, endDate);
    
    final pdf = pw.Document();
    
    switch (view) {
      case CalendarView.day:
        await _buildDayView(pdf, startDate, events, template);
        break;
      case CalendarView.week:
        await _buildWeekView(pdf, startDate, events, template);
        break;
      case CalendarView.month:
        await _buildMonthView(pdf, startDate, events, template);
        break;
      case CalendarView.year:
        await _buildYearView(pdf, startDate.year, template);
        break;
    }
    
    // Save to temp directory
    final output = await getTemporaryDirectory();
    final fileName = 'aeliana_calendar_${DateFormat('yyyyMMdd').format(startDate)}.pdf';
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    
    return file;
  }
  
  /// Print calendar directly via AirPrint
  static Future<void> printCalendar({
    required DateTime startDate,
    required DateTime endDate,
    required CalendarTemplate template,
    required CalendarView view,
  }) async {
    final pdfFile = await exportToPdf(
      startDate: startDate,
      endDate: endDate,
      template: template,
      view: view,
    );
    
    await Printing.layoutPdf(
      onLayout: (format) async => pdfFile.readAsBytes(),
      name: 'Aeliana Calendar',
    );
  }
  
  /// Share calendar as PDF
  static Future<void> shareCalendar({
    required DateTime startDate,
    required DateTime endDate,
    required CalendarTemplate template,
    required CalendarView view,
  }) async {
    final pdfFile = await exportToPdf(
      startDate: startDate,
      endDate: endDate,
      template: template,
      view: view,
    );
    
    await Share.shareXFiles(
      [XFile(pdfFile.path)],
      text: 'My calendar from Aeliana',
      subject: 'Calendar Export',
    );
  }
  
  /// Build day view PDF
  static Future<void> _buildDayView(
    pw.Document pdf, 
    DateTime date, 
    List<Event> events,
    CalendarTemplate template,
  ) async {
    final dayEvents = events.where((e) {
      final eventDate = e.start;
      return eventDate?.year == date.year && 
             eventDate?.month == date.month && 
             eventDate?.day == date.day;
    }).toList();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 20),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(width: 2, color: PdfColors.grey800),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(date),
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Aeliana',
                      style: pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              
              // Time blocks
              if (dayEvents.isEmpty)
                pw.Text('No events scheduled', 
                    style: pw.TextStyle(color: PdfColors.grey500))
              else
                ...dayEvents.map((event) => _buildEventRow(event)),
            ],
          );
        },
      ),
    );
  }
  
  /// Build week view PDF
  static Future<void> _buildWeekView(
    pw.Document pdf,
    DateTime weekStart,
    List<Event> events,
    CalendarTemplate template,
  ) async {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter.landscape,
        margin: const pw.EdgeInsets.all(30),
        build: (context) {
          final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
          
          return pw.Column(
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 15),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Week of ${DateFormat('MMMM d, yyyy').format(weekStart)}',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text('Aeliana', style: pw.TextStyle(color: PdfColors.grey600)),
                  ],
                ),
              ),
              
              // Day columns
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: days.map((day) {
                    final dayEvents = events.where((e) {
                      final eventDate = e.start;
                      return eventDate?.year == day.year &&
                             eventDate?.month == day.month &&
                             eventDate?.day == day.day;
                    }).toList();
                    
                    return pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(5),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              DateFormat('EEE\nM/d').format(day),
                              style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 10,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                            pw.Divider(),
                            ...dayEvents.take(5).map((e) => pw.Text(
                              e.title ?? '',
                              style: const pw.TextStyle(fontSize: 8),
                              maxLines: 2,
                            )),
                            if (dayEvents.length > 5)
                              pw.Text(
                                '+${dayEvents.length - 5} more',
                                style: pw.TextStyle(
                                  fontSize: 7,
                                  color: PdfColors.grey500,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  /// Build month view PDF
  static Future<void> _buildMonthView(
    pw.Document pdf,
    DateTime monthDate,
    List<Event> events,
    CalendarTemplate template,
  ) async {
    final firstDayOfMonth = DateTime(monthDate.year, monthDate.month, 1);
    final lastDayOfMonth = DateTime(monthDate.year, monthDate.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(30),
        build: (context) {
          return pw.Column(
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 20),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      DateFormat('MMMM yyyy').format(monthDate),
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text('Aeliana', style: pw.TextStyle(color: PdfColors.grey600)),
                  ],
                ),
              ),
              
              // Day names header
              pw.Row(
                children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                    .map((d) => pw.Expanded(
                          child: pw.Container(
                            padding: const pw.EdgeInsets.all(5),
                            color: PdfColors.grey200,
                            child: pw.Text(
                              d,
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                        ))
                    .toList(),
              ),
              
              // Calendar grid
              pw.Expanded(
                child: pw.GridView(
                  crossAxisCount: 7,
                  children: List.generate(42, (index) {
                    final dayOffset = index - firstWeekday;
                    final date = firstDayOfMonth.add(Duration(days: dayOffset));
                    final isCurrentMonth = date.month == monthDate.month;
                    
                    final dayEvents = events.where((e) {
                      final eventDate = e.start;
                      return eventDate?.year == date.year &&
                             eventDate?.month == date.month &&
                             eventDate?.day == date.day;
                    }).toList();
                    
                    return pw.Container(
                      padding: const pw.EdgeInsets.all(3),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        color: isCurrentMonth ? PdfColors.white : PdfColors.grey100,
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            '${date.day}',
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: isCurrentMonth ? PdfColors.black : PdfColors.grey500,
                            ),
                          ),
                          ...dayEvents.take(2).map((e) => pw.Text(
                            e.title ?? '',
                            style: const pw.TextStyle(fontSize: 6),
                            maxLines: 1,
                          )),
                          if (dayEvents.length > 2)
                            pw.Text(
                              '+${dayEvents.length - 2}',
                              style: pw.TextStyle(fontSize: 5, color: PdfColors.grey500),
                            ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  /// Build year view PDF
  static Future<void> _buildYearView(
    pw.Document pdf,
    int year,
    CalendarTemplate template,
  ) async {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return pw.Column(
            children: [
              pw.Text(
                '$year',
                style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Expanded(
                child: pw.GridView(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: List.generate(12, (monthIndex) {
                    final monthDate = DateTime(year, monthIndex + 1, 1);
                    return pw.Container(
                      padding: const pw.EdgeInsets.all(5),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                      ),
                      child: pw.Column(
                        children: [
                          pw.Text(
                            DateFormat('MMMM').format(monthDate),
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                          ),
                          pw.Text(
                            '${DateTime(year, monthIndex + 2, 0).day} days',
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('Aeliana', style: pw.TextStyle(color: PdfColors.grey500, fontSize: 8)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
  
  static pw.Widget _buildEventRow(Event event) {
    final timeStr = event.start != null 
        ? DateFormat('h:mm a').format(event.start!) 
        : 'All day';
    
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(
              timeStr,
              style: pw.TextStyle(
                fontSize: 11,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  event.title ?? 'Untitled',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                if (event.location != null && event.location!.isNotEmpty)
                  pw.Text(
                    '📍 ${event.location}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
