import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../calendar_service.dart';
import 'package:sable/core/theme/aeliana_theme.dart';

/// A widget that allows users to filter which calendars to display
/// Persists filter preferences to SharedPreferences
class CalendarFilterSheet extends StatefulWidget {
  final VoidCallback? onFilterChanged;
  
  const CalendarFilterSheet({super.key, this.onFilterChanged});
  
  @override
  State<CalendarFilterSheet> createState() => _CalendarFilterSheetState();
  
  /// Get list of enabled calendar IDs
  static Future<Set<String>> getEnabledCalendarIds() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getStringList('enabled_calendar_ids');
    if (enabled == null) {
      // By default, all calendars are enabled
      return <String>{};
    }
    return enabled.toSet();
  }
  
  /// Check if a calendar is enabled
  static Future<bool> isCalendarEnabled(String calendarId) async {
    final prefs = await SharedPreferences.getInstance();
    final enabledList = prefs.getStringList('enabled_calendar_ids');
    
    if (enabledList == null) {
      // By default, all are enabled if no filtering has been set
      return true;
    }
    
    return enabledList.contains(calendarId);
  }
  
  /// Check if any filtering is active
  static Future<bool> hasActiveFilter() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('enabled_calendar_ids') != null;
  }
  
  /// Reset filter to show all calendars
  static Future<void> resetFilter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('enabled_calendar_ids');
  }
}

class _CalendarFilterSheetState extends State<CalendarFilterSheet> {
  List<Calendar> _calendars = [];
  Set<String> _enabledIds = {};
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadCalendars();
  }
  
  Future<void> _loadCalendars() async {
    try {
      final calendars = await CalendarService.getCalendars();
      final prefs = await SharedPreferences.getInstance();
      final enabledList = prefs.getStringList('enabled_calendar_ids');
      
      if (enabledList == null) {
        // No filter set - all calendars enabled
        _enabledIds = calendars.map((c) => c.id ?? '').toSet();
      } else {
        _enabledIds = enabledList.toSet();
      }
      
      if (mounted) {
        setState(() {
          _calendars = calendars;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading calendars: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _saveFilter() async {
    final prefs = await SharedPreferences.getInstance();
    
    // If all calendars are enabled, remove the filter (show all)
    if (_enabledIds.length == _calendars.length) {
      await prefs.remove('enabled_calendar_ids');
    } else {
      await prefs.setStringList('enabled_calendar_ids', _enabledIds.toList());
    }
    
    widget.onFilterChanged?.call();
  }
  
  Color _parseCalendarColor(Calendar calendar) {
    // device_calendar provides color as int
    if (calendar.color != null) {
      return Color(calendar.color!);
    }
    return AelianaColors.plasmaCyan;
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AelianaColors.carbon,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(LucideIcons.filter, color: AelianaColors.plasmaCyan),
              const SizedBox(width: 12),
              Text(
                'Filter Calendars',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  // Select/Deselect all
                  setState(() {
                    if (_enabledIds.length == _calendars.length) {
                      _enabledIds.clear();
                    } else {
                      _enabledIds = _calendars.map((c) => c.id ?? '').toSet();
                    }
                  });
                  await _saveFilter();
                },
                child: Text(
                  _enabledIds.length == _calendars.length ? 'None' : 'All',
                  style: GoogleFonts.inter(color: AelianaColors.plasmaCyan),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Select which calendars to show in your schedule',
            style: GoogleFonts.inter(
              color: AelianaColors.ghost,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          
          // Calendar List
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_calendars.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No calendars found',
                  style: GoogleFonts.inter(color: AelianaColors.ghost),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _calendars.length,
                itemBuilder: (context, index) {
                  final calendar = _calendars[index];
                  final isEnabled = _enabledIds.contains(calendar.id);
                  final color = _parseCalendarColor(calendar);
                  
                  return ListTile(
                    leading: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    title: Text(
                      calendar.name ?? 'Unnamed Calendar',
                      style: GoogleFonts.inter(
                        color: isEnabled ? Colors.white : AelianaColors.ghost,
                        fontWeight: isEnabled ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                    subtitle: calendar.accountName != null
                        ? Text(
                            calendar.accountName!,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AelianaColors.ghost,
                            ),
                          )
                        : null,
                    trailing: Switch(
                      value: isEnabled,
                      onChanged: (value) async {
                        setState(() {
                          if (value) {
                            _enabledIds.add(calendar.id ?? '');
                          } else {
                            _enabledIds.remove(calendar.id ?? '');
                          }
                        });
                        await _saveFilter();
                      },
                      activeColor: color,
                    ),
                    onTap: () async {
                      setState(() {
                        if (isEnabled) {
                          _enabledIds.remove(calendar.id ?? '');
                        } else {
                          _enabledIds.add(calendar.id ?? '');
                        }
                      });
                      await _saveFilter();
                    },
                  );
                },
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Done button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AelianaColors.hyperGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                'Done',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
