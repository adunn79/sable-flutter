import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:sable/core/calendar/calendar_service.dart';
import 'package:sable/core/theme/aeliana_theme.dart';

/// Calendar Filter Widget - Multi-calendar selection UI
/// 
/// Allows users to enable/disable specific calendars from view.
/// Persists selections to SharedPreferences.
class CalendarFilterWidget extends StatefulWidget {
  final VoidCallback? onFilterChanged;
  
  const CalendarFilterWidget({
    super.key,
    this.onFilterChanged,
  });
  
  @override
  State<CalendarFilterWidget> createState() => _CalendarFilterWidgetState();
  
  /// Get the list of enabled calendar IDs
  static Future<List<String>> getEnabledCalendarIds() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getStringList('enabled_calendar_ids');
    // If null, all calendars are enabled by default
    return enabled ?? [];
  }
  
  /// Check if a specific calendar is enabled
  static Future<bool> isCalendarEnabled(String calendarId) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getStringList('enabled_calendar_ids');
    if (enabled == null) return true; // All enabled by default
    return enabled.contains(calendarId);
  }
}

class _CalendarFilterWidgetState extends State<CalendarFilterWidget> {
  List<Calendar> _calendars = [];
  Set<String> _enabledIds = {};
  bool _isLoading = true;
  bool _showAll = true; // True = show all calendars
  
  @override
  void initState() {
    super.initState();
    _loadCalendars();
  }
  
  Future<void> _loadCalendars() async {
    final calendars = await CalendarService.getCalendars();
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('enabled_calendar_ids');
    
    setState(() {
      _calendars = calendars;
      if (saved == null || saved.isEmpty) {
        // All enabled by default
        _enabledIds = calendars.map((c) => c.id ?? '').toSet();
        _showAll = true;
      } else {
        _enabledIds = saved.toSet();
        _showAll = _enabledIds.length == calendars.length;
      }
      _isLoading = false;
    });
  }
  
  Future<void> _toggleCalendar(String calendarId, bool enabled) async {
    setState(() {
      if (enabled) {
        _enabledIds.add(calendarId);
      } else {
        _enabledIds.remove(calendarId);
      }
      _showAll = _enabledIds.length == _calendars.length;
    });
    
    // Persist
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('enabled_calendar_ids', _enabledIds.toList());
    
    widget.onFilterChanged?.call();
  }
  
  Future<void> _toggleAll(bool enable) async {
    setState(() {
      if (enable) {
        _enabledIds = _calendars.map((c) => c.id ?? '').toSet();
      } else {
        _enabledIds.clear();
      }
      _showAll = enable;
    });
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('enabled_calendar_ids', _enabledIds.toList());
    
    widget.onFilterChanged?.call();
  }
  
  Color _getCalendarColor(Calendar calendar) {
    if (calendar.color != null) {
      return Color(calendar.color!);
    }
    // Default colors based on account type
    final name = calendar.name?.toLowerCase() ?? '';
    if (name.contains('google')) return Colors.blue;
    if (name.contains('icloud')) return Colors.orange;
    if (name.contains('outlook') || name.contains('exchange')) return Colors.indigo;
    if (name.contains('work')) return Colors.green;
    return AelianaColors.plasmaCyan;
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 60,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AelianaColors.plasmaCyan,
          ),
        ),
      );
    }
    
    if (_calendars.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.calendar, color: Colors.white38, size: 20),
            const SizedBox(width: 12),
            Text(
              'No calendars found',
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(LucideIcons.filter, color: AelianaColors.plasmaCyan, size: 18),
              const SizedBox(width: 8),
              Text(
                'Calendars',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Show All toggle
              GestureDetector(
                onTap: () => _toggleAll(!_showAll),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _showAll 
                        ? AelianaColors.plasmaCyan.withOpacity(0.2)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _showAll ? 'All' : '${_enabledIds.length}/${_calendars.length}',
                    style: GoogleFonts.inter(
                      color: _showAll ? AelianaColors.plasmaCyan : Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Calendar list
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _calendars.map((calendar) {
              final isEnabled = _enabledIds.contains(calendar.id);
              final color = _getCalendarColor(calendar);
              
              return GestureDetector(
                onTap: () => _toggleCalendar(calendar.id ?? '', !isEnabled),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isEnabled 
                        ? color.withOpacity(0.2)
                        : Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isEnabled 
                          ? color.withOpacity(0.5)
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isEnabled ? color : Colors.white24,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        calendar.name ?? 'Unnamed',
                        style: GoogleFonts.inter(
                          color: isEnabled ? Colors.white : Colors.white38,
                          fontSize: 13,
                          fontWeight: isEnabled ? FontWeight.w500 : FontWeight.w400,
                        ),
                      ),
                      if (isEnabled) ...[
                        const SizedBox(width: 6),
                        Icon(
                          LucideIcons.check,
                          size: 14,
                          color: color,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          
          // Account info
          if (_calendars.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Tap to toggle calendars • ${_calendars.length} total',
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
