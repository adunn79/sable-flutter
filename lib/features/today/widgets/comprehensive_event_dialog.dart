import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/calendar/calendar_service.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:device_calendar/device_calendar.dart';

/// Comprehensive event creation dialog matching best-in-class calendar apps
class ComprehensiveEventDialog extends StatefulWidget {
  final DateTime initialDate;
  final Event? existingEvent;
  final VoidCallback onEventCreated;

  const ComprehensiveEventDialog({
    super.key,
    required this.initialDate,
    this.existingEvent,
    required this.onEventCreated,
  });

  @override
  State<ComprehensiveEventDialog> createState() => _ComprehensiveEventDialogState();
}

class _ComprehensiveEventDialogState extends State<ComprehensiveEventDialog> {
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _descriptionController;
  late TextEditingController _urlController;
  
  late DateTime _eventDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  
  bool _isAllDay = false;
  String _repeatOption = 'Never';
  List<int?> _alertMinutes = [15]; // Default: 15 min before
  String _showAs = 'Busy';
  String _selectedCalendar = 'Default';
  
  final _repeatOptions = ['Never', 'Daily', 'Weekly', 'Monthly', 'Yearly', 'Custom'];
  final _showAsOptions = ['Busy', 'Free'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existingEvent?.title ?? '');
    _locationController = TextEditingController(text: widget.existingEvent?.location ?? '');
    _descriptionController = TextEditingController(text: widget.existingEvent?.description ?? '');
    _urlController = TextEditingController(text: widget.existingEvent?.url?.toString() ?? '');
    
    _eventDate = widget.existingEvent?.start ?? widget.initialDate;
    _isAllDay = widget.existingEvent?.allDay ?? false;
    _startTime = TimeOfDay.fromDateTime(
      widget.existingEvent?.start ?? DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day, 9, 0),
    );
    _endTime = TimeOfDay.fromDateTime(
      widget.existingEvent?.end ?? DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day, 10, 0),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Material(
      color: Colors.transparent,
      child: TextField(
        controller: controller,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.white54, size: 20),
          filled: true,
          fillColor: AelianaColors.obsidian,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildDateTimePicker({
    required String label,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AelianaColors.obsidian,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white54, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, color: Colors.white54, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow({
    required String label,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AelianaColors.obsidian,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
          ),
          const Spacer(),
          Switch(
            value: value,
            activeColor: AelianaColors.hyperGold,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Future<void> _saveEvent() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
   }

    final startDateTime = DateTime(
      _eventDate.year,
      _eventDate.month,
      _eventDate.day,
      _isAllDay ? 0 : _startTime.hour,
      _isAllDay ? 0 : _startTime.minute,
    );

    final endDateTime = DateTime(
      _eventDate.year,
      _eventDate.month,
      _eventDate.day,
      _isAllDay ? 23 : _endTime.hour,
      _isAllDay ? 59 : _endTime.minute,
    );

    // Build recurrence rule
    RecurrenceRule? recurrenceRule;
    if (_repeatOption != 'Never') {
      RecurrenceFrequency? frequency;
      switch (_repeatOption) {
        case 'Daily':
          frequency = RecurrenceFrequency.Daily;
          break;
        case 'Weekly':
          frequency = RecurrenceFrequency.Weekly;
          break;
        case 'Monthly':
          frequency = RecurrenceFrequency.Monthly;
          break;
        case 'Yearly':
          frequency = RecurrenceFrequency.Yearly;
          break;
      }
      if (frequency != null) {
        recurrenceRule = RecurrenceRule(frequency);
      }
    }

    // Build reminders list
    List<Reminder>? reminders;
    if (_alertMinutes.isNotEmpty && _alertMinutes.first != null) {
      reminders = _alertMinutes
          .where((minutes) => minutes != null)
          .map((minutes) => Reminder(minutes: minutes!))
          .toList();
    }

    // Build availability
    Availability? availability;
    if (_showAs == 'Busy') {
      availability = Availability.Busy;
    } else if (_showAs == 'Free') {
      availability = Availability.Free;
    }

    final event = await CalendarService.createEvent(
      title: _titleController.text,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      location: _locationController.text.isEmpty ? null : _locationController.text,
      start: startDateTime,
      end: endDateTime,
      allDay: _isAllDay,
      recurrenceRule: recurrenceRule,
      reminders: reminders,
      url: _urlController.text.isEmpty ? null : _urlController.text,
      availability: availability,
    );

    if (event != null && mounted) {
      Navigator.pop(context);
      widget.onEventCreated();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AelianaColors.carbon,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Text(
                    widget.existingEvent == null ? 'New Event' : 'Edit Event',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x, color: Colors.white54),
                  ),
                ],
              ),
            ),
            
            // Scrollable form
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // Title
                  _buildTextField(
                    controller: _titleController,
                    label: 'Event Title *',
                    icon: LucideIcons.type,
                  ),
                  const SizedBox(height: 12),
                  
                  // Location
                  _buildTextField(
                    controller: _locationController,
                    label: 'Location',
                    icon: LucideIcons.mapPin,
                  ),
                  const SizedBox(height: 12),
                  
                  // Date
                  _buildDateTimePicker(
                    label: 'Date',
                    icon: LucideIcons.calendar,
                    value: DateFormat('EEEE, MMMM d, y').format(_eventDate),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _eventDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        builder: (context, child) => Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.dark(
                              primary: AelianaColors.hyperGold,
                              onPrimary: Colors.black,
                              surface: AelianaColors.carbon,
                              onSurface: Colors.white,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() => _eventDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // All-day toggle
                  _buildToggleRow(
                    label: 'All-day event',
                    icon: LucideIcons.sun,
                    value: _isAllDay,
                    onChanged: (value) => setState(() => _isAllDay = value),
                  ),
                  const SizedBox(height: 12),
                  
                  // Time pickers (only if not all-day)
                  if (!_isAllDay) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateTimePicker(
                            label: 'Start time',
                            icon: LucideIcons.clock,
                            value: _startTime.format(context),
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _startTime,
                              );
                              if (picked != null) {
                                setState(() => _startTime = picked);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDateTimePicker(
                            label: 'End time',
                            icon: LucideIcons.clock,
                            value: _endTime.format(context),
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _endTime,
                              );
                              if (picked != null) {
                                setState(() => _endTime = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Repeat
                  _buildDateTimePicker(
                    label: 'Repeat',
                    icon: LucideIcons.repeat,
                    value: _repeatOption,
                    onTap: () async {
                      await showModalBottomSheet(
                        context: context,
                        backgroundColor: AelianaColors.carbon,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        builder: (context) => Container(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Repeat',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ..._repeatOptions.map((option) => ListTile(
                                title: Text(
                                  option,
                                  style: GoogleFonts.inter(color: Colors.white),
                                ),
                                trailing: _repeatOption == option
                                    ? const Icon(LucideIcons.check, color: AelianaColors.hyperGold)
                                    : null,
                                onTap: () {
                                  setState(() => _repeatOption = option);
                                  Navigator.pop(context);
                                },
                              )),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // Alert/Reminder
                  _buildDateTimePicker(
                    label: 'Alert',
                    icon: LucideIcons.bell,
                    value: _alertMinutes.first == null
                        ? 'None'
                        : _alertMinutes.first == 0
                            ? 'At time of event'
                            : _alertMinutes.first! < 60
                                ? '${_alertMinutes.first} minutes before'
                                : _alertMinutes.first! < 1440
                                    ? '${_alertMinutes.first! ~/ 60} hour(s) before'
                                    : '${_alertMinutes.first! ~/ 1440} day(s) before',
                    onTap: () async {
                      final alerts = [
                        (null, 'None'),
                        (0, 'At time of event'),
                        (5, '5 minutes before'),
                        (15, '15 minutes before'),
                        (30, '30 minutes before'),
                        (60, '1 hour before'),
                        (120, '2 hours before'),
                        (1440, '1 day before'),
                        (2880, '2 days before'),
                        (10080, '1 week before'),
                      ];
                      
                      await showModalBottomSheet(
                        context: context,
                        backgroundColor: AelianaColors.carbon,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        builder: (context) => Container(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reminder',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ...alerts.map((alert) => ListTile(
                                title: Text(
                                  alert.$2,
                                  style: GoogleFonts.inter(color: Colors.white),
                                ),
                                trailing: _alertMinutes.first == alert.$1
                                    ? const Icon(LucideIcons.check, color: AelianaColors.hyperGold)
                                    : null,
                                onTap: () {
                                  setState(() => _alertMinutes = [alert.$1]);
                                  Navigator.pop(context);
                                },
                              )),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // Show as (Busy/Free)
                  _buildDateTimePicker(
                    label: 'Show as',
                    icon: LucideIcons.eye,
                    value: _showAs,
                    onTap: () async {
                      await showModalBottomSheet(
                        context: context,
                        backgroundColor: AelianaColors.carbon,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        builder: (context) => Container(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Show as',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ..._showAsOptions.map((option) => ListTile(
                                title: Text(
                                  option,
                                  style: GoogleFonts.inter(color: Colors.white),
                                ),
                                trailing: _showAs == option
                                    ? const Icon(LucideIcons.check, color: AelianaColors.hyperGold)
                                    : null,
                                onTap: () {
                                  setState(() => _showAs = option);
                                  Navigator.pop(context);
                                },
                              )),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // Description
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    icon: LucideIcons.fileText,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  
                  // URL/Attachment
                  _buildTextField(
                    controller: _urlController,
                    label: 'URL (Zoom, Meet, etc.)',
                    icon: LucideIcons.link,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            
            // Create button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AelianaColors.hyperGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.existingEvent == null ? 'Create Event' : 'Save Changes',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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
}
