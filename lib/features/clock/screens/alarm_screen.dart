import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/alarm_service.dart';

/// Compact modern alarm screen - fits on one screen
class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  final AlarmService _alarmService = AlarmService();
  bool _isLoading = true;
  
  int _selectedHour = 7;
  int _selectedMinute = 0;
  List<int> _selectedDays = [];

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    await _alarmService.init();
    final now = TimeOfDay.now();
    _selectedHour = now.hour;
    _selectedMinute = now.minute;
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _alarmService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
            : isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
      ),
    );
  }

  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        // Left side - Time picker and controls
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 8),
                Expanded(child: _buildCompactTimePicker()),
                const SizedBox(height: 8),
                _buildCompactDaySelector(),
                const SizedBox(height: 8),
                _buildCompactAddButton(),
              ],
            ),
          ),
        ),
        // Right side - Existing alarms & timers
        Expanded(
          flex: 2,
          child: Container(
            color: Colors.grey[900],
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Alarms', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                Expanded(child: _buildAlarmsList()),
                const Divider(color: Colors.grey),
                Text('Quick Timer', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 8),
                _buildCompactTimerRow(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 8),
          _buildCompactTimePicker(),
          const SizedBox(height: 12),
          _buildCompactDaySelector(),
          const SizedBox(height: 12),
          _buildCompactAddButton(),
          const SizedBox(height: 16),
          Expanded(child: _buildAlarmsList()),
          _buildCompactTimerRow(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 12),
        Text(
          'Alarms',
          style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildCompactTimePicker() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: CupertinoPicker(
              itemExtent: 40,
              scrollController: FixedExtentScrollController(initialItem: _selectedHour),
              onSelectedItemChanged: (index) => setState(() => _selectedHour = index),
              children: List.generate(24, (index) => Center(
                child: Text(
                  index.toString().padLeft(2, '0'),
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w300),
                ),
              )),
            ),
          ),
          Text(':', style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w200)),
          Expanded(
            child: CupertinoPicker(
              itemExtent: 40,
              scrollController: FixedExtentScrollController(initialItem: _selectedMinute),
              onSelectedItemChanged: (index) => setState(() => _selectedMinute = index),
              children: List.generate(60, (index) => Center(
                child: Text(
                  index.toString().padLeft(2, '0'),
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w300),
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDaySelector() {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(7, (index) {
        final isSelected = _selectedDays.contains(index);
        return GestureDetector(
          onTap: () => setState(() {
            isSelected ? _selectedDays.remove(index) : _selectedDays.add(index);
          }),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? Colors.cyan : Colors.grey[850],
              border: Border.all(color: isSelected ? Colors.cyan : Colors.grey[700]!, width: 2),
            ),
            child: Center(
              child: Text(days[index], style: GoogleFonts.inter(
                color: isSelected ? Colors.white : Colors.white54, fontSize: 13, fontWeight: FontWeight.w600,
              )),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCompactAddButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.cyan,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () async {
          await _alarmService.addAlarm(
            hour: _selectedHour, minute: _selectedMinute, repeatDays: List.from(_selectedDays),
          );
          setState(() => _selectedDays.clear());
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Alarm set for ${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')}'),
            backgroundColor: Colors.grey[900], duration: const Duration(seconds: 2),
          ));
        },
        child: Text('Set Alarm', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildAlarmsList() {
    final alarms = _alarmService.alarms;
    if (alarms.isEmpty) {
      return Center(child: Text('No alarms', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)));
    }
    return ListView.builder(
      itemCount: alarms.length,
      itemBuilder: (context, index) {
        final alarm = alarms[index];
        return Dismissible(
          key: Key('alarm-${alarm.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
            child: const Icon(LucideIcons.trash2, color: Colors.white, size: 18),
          ),
          onDismissed: (_) async {
            await _alarmService.deleteAlarm(alarm.id);
            setState(() {});
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.grey[850], borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alarm.time24String, style: GoogleFonts.inter(
                        color: alarm.enabled ? Colors.white : Colors.white38, fontSize: 20, fontWeight: FontWeight.w300,
                      )),
                      Text(alarm.repeatString, style: GoogleFonts.inter(
                        color: alarm.enabled ? Colors.cyan : Colors.grey, fontSize: 10,
                      )),
                    ],
                  ),
                ),
                Switch(
                  value: alarm.enabled, activeColor: Colors.cyan,
                  onChanged: (v) async {
                    await _alarmService.toggleAlarm(alarm.id);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactTimerRow() {
    return Row(
      children: [1, 5, 10, 30].map((m) => Expanded(
        child: GestureDetector(
          onTap: () async {
            await _alarmService.startTimer(durationSeconds: m * 60, label: '${m}m');
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('$m min timer started'), backgroundColor: Colors.grey[900],
            ));
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.cyan.withOpacity(0.15), borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.cyan.withOpacity(0.3)),
            ),
            child: Center(child: Text('${m}m', style: GoogleFonts.inter(color: Colors.cyan, fontSize: 14, fontWeight: FontWeight.w600))),
          ),
        ),
      )).toList(),
    );
  }
}
