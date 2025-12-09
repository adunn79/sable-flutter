import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sable/features/clock/widgets/clock_face_widget.dart';
import 'package:sable/features/clock/screens/alarm_screen.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:sable/core/emotion/weather_service.dart';

/// A full-screen clock mode with avatar and clock display
/// Supports both portrait and landscape orientations
class ClockModeScreen extends StatefulWidget {
  final String archetypeId;
  final bool isAnalog;
  final String? nextAlarmTime;
  final VoidCallback? onExit;

  const ClockModeScreen({
    super.key,
    required this.archetypeId,
    this.isAnalog = false,
    this.nextAlarmTime,
    this.onExit,
  });

  @override
  State<ClockModeScreen> createState() => _ClockModeScreenState();
}

class _ClockModeScreenState extends State<ClockModeScreen> {
  bool _showControls = true;
  bool _isAnalog = false;
  bool _use24Hour = false;
  TimeOfDay? _alarmTime;
  bool _alarmActive = false;
  String? _weatherTemp;
  String? _weatherCondition;

  @override
  void initState() {
    super.initState();
    _isAnalog = widget.isAnalog;
    _loadPreferences();
    _fetchWeather();
    
    // Hide controls after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _showControls = false);
      }
    });
    
    // Keep screen awake and hide system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _fetchWeather() async {
    try {
      // WeatherService.getWeather already handles geocoding internally
      // Just pass a city name like "San Francisco" 
      final weather = await WeatherService.getWeather('San Francisco');
      if (weather != null && mounted) {
        setState(() {
          _weatherTemp = '${weather.temperature.round()}°';
          _weatherCondition = weather.description.split(' ').first;
        });
      }
    } catch (e) {
      debugPrint('Error fetching weather for clock: $e');
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _use24Hour = prefs.getBool('clock_use_24hour') ?? false;
      _isAnalog = prefs.getBool('clock_is_analog') ?? false;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('clock_use_24hour', _use24Hour);
    await prefs.setBool('clock_is_analog', _isAnalog);
  }

  @override
  void dispose() {
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    
    // Auto-hide after 5 seconds
    if (_showControls) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _showControls) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  Future<void> _setAlarm() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _alarmTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AelianaColors.hyperGold,
              surface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _alarmTime = picked;
        _alarmActive = true;
      });
      
      // Show confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Alarm set for ${_formatAlarmTime(picked)}',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.black87,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _formatAlarmTime(TimeOfDay time) {
    if (_use24Hour) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
      final period = time.period == DayPeriod.am ? 'AM' : 'PM';
      return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
    }
  }

  void _cancelAlarm() {
    setState(() {
      _alarmActive = false;
      _alarmTime = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: OrientationBuilder(
          builder: (context, orientation) {
            if (orientation == Orientation.landscape) {
              return _buildLandscapeLayout();
            }
            return _buildPortraitLayout();
          },
        ),
      ),
    );
  }

  Widget _buildPortraitLayout() {
    return Stack(
      children: [
        Column(
          children: [
            // Avatar - top 50%
            Expanded(
              flex: 1,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/archetypes/${widget.archetypeId}.png'),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                        Colors.black,
                      ],
                      stops: const [0.0, 0.5, 0.85, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // Clock - bottom 50%
            Expanded(
              flex: 1,
              child: Center(
                child: ClockFaceWidget(
                  isAnalog: _isAnalog,
                  use24Hour: _use24Hour,
                  size: 337,
                  primaryColor: Colors.white,
                  secondaryColor: Colors.white70,
                  nextAlarmTime: _alarmActive && _alarmTime != null 
                      ? _formatAlarmTime(_alarmTime!)
                      : null,
                  weatherTemp: _weatherTemp,
                  weatherCondition: _weatherCondition,
                ),
              ),
            ),
          ],
        ),
        
        // Controls overlay
        _buildControlsOverlay(),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    return Stack(
      children: [
        Row(
          children: [
            // Avatar - left side
            Expanded(
              flex: 1,
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/archetypes/${widget.archetypeId}.png'),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                        Colors.black,
                      ],
                      stops: const [0.0, 0.5, 0.85, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // Clock - right side
            Expanded(
              flex: 1,
              child: Center(
                child: ClockFaceWidget(
                  isAnalog: _isAnalog,
                  use24Hour: _use24Hour,
                  size: 412,
                  primaryColor: Colors.white,
                  secondaryColor: Colors.white70,
                  nextAlarmTime: _alarmActive && _alarmTime != null 
                      ? _formatAlarmTime(_alarmTime!)
                      : null,
                  weatherTemp: _weatherTemp,
                  weatherCondition: _weatherCondition,
                ),
              ),
            ),
          ],
        ),
        
        // Controls overlay
        _buildControlsOverlay(),
      ],
    );
  }

  Widget _buildControlsOverlay() {
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: !_showControls,
        child: Container(
          color: Colors.black.withOpacity(0.4),
          child: SafeArea(
            child: Column(
              children: [
                // Top bar with exit
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Exit button
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                        onPressed: () {
                          if (widget.onExit != null) {
                            widget.onExit!();
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                      // Alarm indicator
                      if (_alarmActive && _alarmTime != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AelianaColors.hyperGold.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AelianaColors.hyperGold),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.alarm, color: AelianaColors.hyperGold, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                _formatAlarmTime(_alarmTime!),
                                style: GoogleFonts.inter(
                                  color: AelianaColors.hyperGold,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Bottom controls
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // 24hr toggle
                      _buildControlButton(
                        icon: Icons.schedule,
                        label: _use24Hour ? '12hr' : '24hr',
                        onTap: () {
                          setState(() => _use24Hour = !_use24Hour);
                          _savePreferences();
                        },
                      ),
                      // Analog/Digital toggle
                      _buildControlButton(
                        icon: _isAnalog ? Icons.watch_later_outlined : Icons.access_time,
                        label: _isAnalog ? 'Digital' : 'Analog',
                        onTap: () {
                          setState(() => _isAnalog = !_isAnalog);
                          _savePreferences();
                        },
                      ),
                      // Set alarm
                      _buildControlButton(
                        icon: Icons.alarm_add,
                        label: 'Alarms',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AlarmScreen()),
                          );
                        },
                        highlight: true,
                      ),
                      // Cancel alarm (if active)
                      if (_alarmActive)
                        _buildControlButton(
                          icon: Icons.alarm_off,
                          label: 'Cancel',
                          onTap: _cancelAlarm,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: highlight 
                  ? AelianaColors.hyperGold.withOpacity(0.2) 
                  : Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: highlight 
                  ? Border.all(color: AelianaColors.hyperGold)
                  : null,
            ),
            child: Icon(
              icon,
              color: highlight ? AelianaColors.hyperGold : Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
