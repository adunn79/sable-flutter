import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/journal_storage_service.dart';
import '../models/journal_entry.dart';
import 'journal_editor_screen.dart';

/// Calendar view for journal entries showing mood indicators
class JournalCalendarScreen extends StatefulWidget {
  const JournalCalendarScreen({super.key});

  @override
  State<JournalCalendarScreen> createState() => _JournalCalendarScreenState();
}

class _JournalCalendarScreenState extends State<JournalCalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<JournalEntry> _selectedDayEntries = [];
  
  // Cache of entries by date for calendar markers
  Map<DateTime, List<JournalEntry>> _entriesByDate = {};
  
  @override
  void initState() {
    super.initState();
    _loadEntriesForMonth(_focusedDay);
    _selectedDay = DateTime.now();
    _loadEntriesForDay(_selectedDay!);
  }
  
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
  
  void _loadEntriesForMonth(DateTime month) {
    final start = DateTime(month.year, month.month - 1, 1);
    final end = DateTime(month.year, month.month + 2, 0);
    
    final entries = JournalStorageService.getEntriesInRange(start, end);
    
    _entriesByDate = {};
    for (final entry in entries) {
      final date = _normalizeDate(entry.timestamp);
      _entriesByDate[date] ??= [];
      _entriesByDate[date]!.add(entry);
    }
    setState(() {});
  }
  
  void _loadEntriesForDay(DateTime day) {
    final normalizedDay = _normalizeDate(day);
    _selectedDayEntries = _entriesByDate[normalizedDay] ?? [];
    setState(() {});
  }
  
  List<JournalEntry> _getEntriesForDay(DateTime day) {
    final normalizedDay = _normalizeDate(day);
    return _entriesByDate[normalizedDay] ?? [];
  }
  
  String _getMoodEmoji(int? score) {
    if (score == null) return '';
    return ['😢', '😔', '😐', '🙂', '😊'][score - 1];
  }
  
  Color _getMoodColor(int? score) {
    if (score == null) return Colors.grey;
    return [
      Colors.red[300]!,
      Colors.orange[300]!,
      Colors.yellow[400]!,
      Colors.lightGreen[300]!,
      Colors.green[400]!,
    ][score - 1];
  }
  
  void _openEditor({String? entryId}) async {
    final buckets = JournalStorageService.getAllBuckets();
    final bucketId = buckets.isNotEmpty ? buckets.first.id : 'default';
    
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => JournalEditorScreen(
          entryId: entryId,
          bucketId: bucketId,
        ),
      ),
    );
    
    if (result == true) {
      _loadEntriesForMonth(_focusedDay);
      if (_selectedDay != null) {
        _loadEntriesForDay(_selectedDay!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Journal Calendar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Calendar widget
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TableCalendar<JournalEntry>(
              firstDay: DateTime(2020, 1, 1),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              eventLoader: _getEntriesForDay,
              startingDayOfWeek: StartingDayOfWeek.sunday,
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                defaultTextStyle: const TextStyle(color: Colors.white),
                weekendTextStyle: const TextStyle(color: Colors.white70),
                todayDecoration: BoxDecoration(
                  color: Colors.cyan.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: const TextStyle(color: Colors.cyan),
                selectedDecoration: const BoxDecoration(
                  color: Colors.cyan,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                markerDecoration: const BoxDecoration(
                  color: Colors.purple,
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 3,
                markerSize: 6,
                markersAnchor: 1.3,
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonDecoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                formatButtonTextStyle: const TextStyle(color: Colors.white, fontSize: 12),
                leftChevronIcon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
                rightChevronIcon: const Icon(LucideIcons.chevronRight, color: Colors.white),
                titleTextStyle: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                weekendStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, entries) {
                  if (entries.isEmpty) return null;
                  
                  // Show mood-colored dots for entries
                  return Positioned(
                    bottom: 1,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: entries.take(3).map((entry) {
                        return Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: _getMoodColor(entry.moodScore),
                            shape: BoxShape.circle,
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                _loadEntriesForDay(selectedDay);
              },
              onFormatChanged: (format) {
                setState(() => _calendarFormat = format);
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
                _loadEntriesForMonth(focusedDay);
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Selected day header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDay != null 
                    ? DateFormat('EEEE, MMMM d').format(_selectedDay!)
                    : 'Select a day',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_selectedDayEntries.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_selectedDayEntries.length} ${_selectedDayEntries.length == 1 ? 'entry' : 'entries'}',
                      style: const TextStyle(color: Colors.purple, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Entries for selected day
          Expanded(
            child: _selectedDayEntries.isEmpty
                ? _buildEmptyDayState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _selectedDayEntries.length,
                    itemBuilder: (context, index) => _buildEntryCard(_selectedDayEntries[index]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        backgroundColor: Colors.white,
        child: const Icon(LucideIcons.plus, color: Colors.black),
      ),
    );
  }
  
  Widget _buildEmptyDayState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.bookOpen, size: 48, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 12),
          Text(
            'No entries for this day',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _openEditor(),
            icon: const Icon(LucideIcons.plus, size: 16),
            label: const Text('Write one'),
            style: TextButton.styleFrom(foregroundColor: Colors.cyan),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEntryCard(JournalEntry entry) {
    final timeFormat = DateFormat('h:mm a');
    
    return GestureDetector(
      onTap: () => _openEditor(entryId: entry.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mood emoji
            if (entry.moodScore != null) ...[
              Text(_getMoodEmoji(entry.moodScore), style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
            ],
            
            // Entry content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time
                  Text(
                    timeFormat.format(entry.timestamp),
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  
                  // Preview
                  Text(
                    entry.plainText.length > 100 
                      ? '${entry.plainText.substring(0, 100)}...'
                      : entry.plainText,
                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  // Tags
                  if (entry.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: entry.tags.take(3).map((tag) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '#$tag',
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                        ),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
            
            // Arrow
            Icon(LucideIcons.chevronRight, color: Colors.white.withOpacity(0.3), size: 20),
          ],
        ),
      ),
    );
  }
}
