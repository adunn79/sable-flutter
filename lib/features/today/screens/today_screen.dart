import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:sable/core/calendar/calendar_service.dart';
import 'package:sable/core/calendar/moon_phase_service.dart';
import 'package:sable/core/calendar/ical_subscription_service.dart';
import 'package:sable/core/calendar/sports_schedule_service.dart';
import 'package:sable/core/calendar/weather_history_service.dart';
import 'package:sable/core/contacts/birthday_service.dart';
import 'package:sable/core/reminders/reminders_service.dart' as reminders_svc;
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:sable/core/emotion/location_service.dart';
import 'package:sable/src/config/app_config.dart';
import 'package:sable/features/onboarding/services/onboarding_state_service.dart';
import 'package:sable/features/journal/widgets/avatar_journal_overlay.dart';
import 'package:sable/src/shared/weather_widget.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> with SingleTickerProviderStateMixin {
  List<Event> _todayEvents = [];
  List<Event> _upcomingEvents = [];
  bool _isLoading = true;
  bool _hasPermission = false;
  DateTime _selectedDate = DateTime.now();
  late TabController _tabController;
  
  // Location & Avatar
  String? _currentLocation;
  String _archetypeId = 'sable';
  bool _isAiThinking = false;
  
  // Vibe Layers
  List<ContactBirthday> _todayBirthdays = [];
  List<ContactBirthday> _upcomingBirthdays = [];
  MoonPhase _moonPhase = MoonPhase.newMoon;
  String _moonEmoji = '🌑';
  List<reminders_svc.Reminder> _reminders = [];
  
  // Subscription Layers
  List<ICalEvent> _todayHolidays = [];
  List<SportsEvent> _todaySports = [];
  List<SportsEvent> _upcomingSports = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // 3 tabs now: Events, Tasks, Vibe
    _checkPermissionAndLoadEvents();
    _loadLocationAndArchetype();
    _loadVibeLayers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionAndLoadEvents() async {
    final hasPermission = await CalendarService.hasPermission();
    setState(() => _hasPermission = hasPermission);
    
    if (hasPermission) {
      await _loadEvents();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _requestPermission() async {
    final granted = await CalendarService.requestPermission();
    if (granted) {
      setState(() => _hasPermission = true);
      await _loadEvents();
    }
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    
    try {
      final todayEvents = await CalendarService.getTodayEvents();
      final upcomingEvents = await CalendarService.getUpcomingEvents(days: 7);
      
      if (mounted) {
        setState(() {
          _todayEvents = todayEvents;
          _upcomingEvents = upcomingEvents;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading calendar events: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadVibeLayers() async {
    // Load moon phase (synchronous calculation)
    final phase = MoonPhaseService.getPhaseForDate(_selectedDate);
    final emoji = MoonPhaseService.getPhaseEmoji(phase);
    
    if (mounted) {
      setState(() {
        _moonPhase = phase;
        _moonEmoji = emoji;
      });
    }
    
    // Load birthdays
    try {
      final todayBirthdays = await BirthdayService.getTodayBirthdays();
      final upcomingBirthdays = await BirthdayService.getUpcomingBirthdays(days: 7);
      
      if (mounted) {
        setState(() {
          _todayBirthdays = todayBirthdays;
          _upcomingBirthdays = upcomingBirthdays;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading birthdays: $e');
    }
    
    // Load reminders
    try {
      final reminders = await reminders_svc.RemindersService.getReminders();
      if (mounted) {
        setState(() => _reminders = reminders);
      }
    } catch (e) {
      debugPrint('❌ Error loading reminders: $e');
    }
    
    // Load holidays
    try {
      final holidays = await ICalSubscriptionService.getTodayHolidays();
      if (mounted) {
        setState(() => _todayHolidays = holidays);
      }
    } catch (e) {
      debugPrint('❌ Error loading holidays: $e');
    }
    
    // Load sports events
    try {
      final todaySports = await SportsScheduleService.getTodayGames();
      final upcomingSports = await SportsScheduleService.getUpcomingGames(days: 7);
      if (mounted) {
        setState(() {
          _todaySports = todaySports;
          _upcomingSports = upcomingSports;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading sports: $e');
    }
    
    // Auto-record today's weather
    if (_currentLocation != null) {
      WeatherHistoryService.autoRecordFromCurrent(_currentLocation!);
    }
  }

  Future<void> _loadLocationAndArchetype() async {
    try {
      // Load archetype
      final stateService = await OnboardingStateService.create();
      if (mounted) {
        setState(() {
          _archetypeId = stateService.selectedArchetypeId ?? 'sable';
        });
      }
      
      // Load current location
      final apiKey = AppConfig.googleMapsApiKey;
      if (apiKey.isNotEmpty) {
        final location = await LocationService.getCurrentLocationName(apiKey);
        if (location != null && mounted) {
          setState(() => _currentLocation = location);
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading location/archetype: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AelianaColors.obsidian,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildDateSelector(),
            _buildTabBar(),
            Expanded(
              child: _hasPermission 
                  ? _buildCalendarContent()
                  : _buildPermissionRequest(),
            ),
          ],
        ),
      ),
      floatingActionButton: _hasPermission ? FloatingActionButton(
        onPressed: _showCreateEventDialog,
        backgroundColor: AelianaColors.hyperGold,
        child: const Icon(LucideIcons.plus, color: Colors.black),
      ) : null,
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side: Date info + Location
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE').format(_selectedDate),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  DateFormat('MMMM d, y').format(_selectedDate),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AelianaColors.ghost,
                  ),
                ),
                // Location badge
                if (_currentLocation != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AelianaColors.carbon,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AelianaColors.plasmaCyan.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.mapPin, size: 12, color: AelianaColors.plasmaCyan),
                        const SizedBox(width: 4),
                        Text(
                          _currentLocation!,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AelianaColors.plasmaCyan,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Moon phase indicator
                        Text(_moonEmoji, style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ],
                // Moon phase badge (if no location)
                if (_currentLocation == null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AelianaColors.carbon,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_moonEmoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(
                          MoonPhaseService.getPhaseName(_moonPhase),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AelianaColors.ghost,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Right side: Avatar + Weather
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // AI Companion Avatar (tappable for schedule help)
              GestureDetector(
                onTap: _showAiScheduleHelp,
                child: AvatarJournalOverlay(
                  isPrivate: false,
                  archetype: _archetypeId,
                  isActive: _isAiThinking,
                ),
              ),
              const SizedBox(height: 4),
              const WeatherWidget(),
            ],
          ),
        ],
      ),
    );
  }

  void _showAiScheduleHelp() {
    // Show a bottom sheet where the AI can help with schedule
    showModalBottomSheet(
      context: context,
      backgroundColor: AelianaColors.carbon,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AelianaColors.ghost.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Icon(LucideIcons.sparkles, size: 32, color: AelianaColors.hyperGold),
            const SizedBox(height: 16),
            Text(
              'Schedule Assistant',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "I can help you manage your day! Here's what I see:",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AelianaColors.ghost,
              ),
            ),
            const SizedBox(height: 16),
            // Quick stats about today
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AelianaColors.obsidian,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildQuickStat(
                    LucideIcons.calendarDays,
                    'Today',
                    '${_todayEvents.length} event${_todayEvents.length == 1 ? '' : 's'}',
                  ),
                  const SizedBox(height: 12),
                  _buildQuickStat(
                    LucideIcons.calendarRange,
                    'This Week',
                    '${_upcomingEvents.length} event${_upcomingEvents.length == 1 ? '' : 's'}',
                  ),
                  if (_currentLocation != null) ...[
                    const SizedBox(height: 12),
                    _buildQuickStat(
                      LucideIcons.mapPin,
                      'Location',
                      _currentLocation!,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Action button - go to main chat for deeper help
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to chat tab for more detailed help
                  // The user can use the main chat for complex schedule planning
                },
                icon: const Icon(LucideIcons.messageCircle, size: 18),
                label: const Text('Chat for More Help'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AelianaColors.hyperGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStat(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AelianaColors.plasmaCyan),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AelianaColors.ghost,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    final today = DateTime.now();
    final dates = List.generate(7, (i) => today.add(Duration(days: i)));
    
    return Container(
      height: 90,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = _isSameDay(date, _selectedDate);
          final isToday = _isSameDay(date, today);
          
          return GestureDetector(
            onTap: () => setState(() => _selectedDate = date),
            child: Container(
              width: 56,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected 
                    ? AelianaColors.hyperGold 
                    : AelianaColors.carbon,
                borderRadius: BorderRadius.circular(16),
                border: isToday && !isSelected
                    ? Border.all(color: AelianaColors.plasmaCyan, width: 2)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date).substring(0, 3),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.black : AelianaColors.ghost,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.black : Colors.white,
                    ),
                  ),
                  if (_hasEventsOnDay(date))
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black.withOpacity(0.5) : AelianaColors.plasmaCyan,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AelianaColors.carbon,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AelianaColors.hyperGold,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.black,
        unselectedLabelColor: AelianaColors.ghost,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
        tabs: const [
          Tab(text: 'Events'),
          Tab(text: 'Tasks'),
          Tab(text: 'Vibe'),
        ],
      ),
    );
  }

  Widget _buildCalendarContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AelianaColors.plasmaCyan),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildTodayTab(),
        _buildTasksTab(),
        _buildVibeTab(),
      ],
    );
  }

  Widget _buildTodayTab() {
    final selectedDayEvents = _getEventsForDay(_selectedDate);
    
    if (selectedDayEvents.isEmpty) {
      return _buildEmptyState(
        icon: LucideIcons.calendarCheck,
        title: 'No events',
        subtitle: 'Your day is clear! Tap + to add an event.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      color: AelianaColors.plasmaCyan,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: selectedDayEvents.length,
        itemBuilder: (context, index) => _buildEventCard(selectedDayEvents[index]),
      ),
    );
  }

  Widget _buildWeekTab() {
    if (_upcomingEvents.isEmpty) {
      return _buildEmptyState(
        icon: LucideIcons.calendar,
        title: 'No upcoming events',
        subtitle: 'Nothing scheduled for the next 7 days.',
      );
    }

    // Group events by day
    final eventsByDay = <DateTime, List<Event>>{};
    for (final event in _upcomingEvents) {
      if (event.start != null) {
        final dayKey = DateTime(event.start!.year, event.start!.month, event.start!.day);
        eventsByDay.putIfAbsent(dayKey, () => []).add(event);
      }
    }

    final sortedDays = eventsByDay.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: _loadEvents,
      color: AelianaColors.plasmaCyan,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedDays.length,
        itemBuilder: (context, index) {
          final day = sortedDays[index];
          final events = eventsByDay[day]!;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 8, top: index > 0 ? 16.0 : 0.0),
                child: Text(
                  _formatDayHeader(day),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AelianaColors.plasmaCyan,
                  ),
                ),
              ),
              ...events.map((e) => _buildEventCard(e)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTasksTab() {
    if (_reminders.isEmpty) {
      return _buildEmptyState(
        icon: LucideIcons.checkSquare,
        title: 'No reminders',
        subtitle: 'Open the Reminders app to add tasks.',
      );
    }

    // Separate reminders by status
    final overdue = _reminders.where((r) => 
      r.dueDate != null && r.dueDate!.isBefore(DateTime.now()) && !r.isCompleted
    ).toList();
    final dueToday = _reminders.where((r) {
      if (r.dueDate == null || r.isCompleted) return false;
      final now = DateTime.now();
      return r.dueDate!.year == now.year && 
             r.dueDate!.month == now.month && 
             r.dueDate!.day == now.day;
    }).toList();
    final upcoming = _reminders.where((r) =>
      r.dueDate != null && 
      r.dueDate!.isAfter(DateTime.now()) && 
      !r.isCompleted &&
      !dueToday.contains(r)
    ).toList();

    return RefreshIndicator(
      onRefresh: _loadVibeLayers,
      color: AelianaColors.plasmaCyan,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (overdue.isNotEmpty) ...[
            _buildSectionHeader('⚠️ Overdue', Colors.red),
            ...overdue.map((r) => _buildReminderCard(r, isOverdue: true)),
            const SizedBox(height: 16),
          ],
          if (dueToday.isNotEmpty) ...[
            _buildSectionHeader('📌 Due Today', AelianaColors.hyperGold),
            ...dueToday.map((r) => _buildReminderCard(r)),
            const SizedBox(height: 16),
          ],
          if (upcoming.isNotEmpty) ...[
            _buildSectionHeader('📅 Upcoming', AelianaColors.ghost),
            ...upcoming.take(10).map((r) => _buildReminderCard(r)),
          ],
        ],
      ),
    );
  }

  Widget _buildVibeTab() {
    return RefreshIndicator(
      onRefresh: _loadVibeLayers,
      color: AelianaColors.plasmaCyan,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Moon Phase Card
          _buildVibeCard(
            icon: _moonEmoji,
            title: MoonPhaseService.getPhaseName(_moonPhase),
            subtitle: MoonPhaseService.getPhaseDescription(_moonPhase),
            color: AelianaColors.plasmaCyan,
          ),
          const SizedBox(height: 16),
          
          // Today's Holidays
          if (_todayHolidays.isNotEmpty) ...[
            _buildSectionHeader('🎄 Today\'s Holidays', AelianaColors.hyperGold),
            ..._todayHolidays.map((h) => _buildHolidayCard(h)),
            const SizedBox(height: 16),
          ],
          
          // Today's Sports
          if (_todaySports.isNotEmpty) ...[
            _buildSectionHeader('🏆 Today\'s Games', AelianaColors.plasmaCyan),
            ..._todaySports.map((s) => _buildSportsCard(s)),
            const SizedBox(height: 16),
          ],
          
          // Upcoming Sports
          if (_upcomingSports.where((s) => !_todaySports.any((t) => t.id == s.id)).isNotEmpty) ...[
            _buildSectionHeader('📅 Upcoming Games', AelianaColors.ghost),
            ..._upcomingSports.where((s) => !_todaySports.any((t) => t.id == s.id)).take(5).map((s) => _buildSportsCard(s)),
            const SizedBox(height: 16),
          ],
          
          // Today's Birthdays
          if (_todayBirthdays.isNotEmpty) ...[
            _buildSectionHeader('🎂 Today\'s Birthdays', AelianaColors.hyperGold),
            ..._todayBirthdays.map((b) => _buildBirthdayCard(b, isToday: true)),
            const SizedBox(height: 16),
          ],
          
          // Upcoming Birthdays
          if (_upcomingBirthdays.where((b) => !b.isToday).isNotEmpty) ...[
            _buildSectionHeader('🎁 Upcoming Birthdays', AelianaColors.ghost),
            ..._upcomingBirthdays.where((b) => !b.isToday).take(5).map((b) => _buildBirthdayCard(b)),
            const SizedBox(height: 16),
          ],
          
          // Subscribe Section
          const SizedBox(height: 8),
          _buildSubscribeSection(),
        ],
      ),
    );
  }

  Widget _buildSubscribeSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AelianaColors.carbon,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AelianaColors.hyperGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.plus, color: AelianaColors.hyperGold, size: 18),
              const SizedBox(width: 8),
              Text(
                'Add Vibe Layers',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSubscribeChip('🎄 Holidays', () => _showHolidaySubscriptions()),
              _buildSubscribeChip('🏈 Sports', () => _showSportsSubscriptions()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubscribeChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AelianaColors.obsidian,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AelianaColors.ghost.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }

  void _showHolidaySubscriptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AelianaColors.carbon,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => FutureBuilder<List<String>>(
        future: ICalSubscriptionService.getSubscribedCalendars(),
        builder: (context, snapshot) {
          final subscribed = snapshot.data ?? [];
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Holiday Calendars',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                ...HolidayCalendar.all.map((cal) => ListTile(
                  leading: Text(cal.emoji, style: const TextStyle(fontSize: 24)),
                  title: Text(cal.name, style: GoogleFonts.inter(color: Colors.white)),
                  trailing: Switch(
                    value: subscribed.contains(cal.id),
                    activeColor: AelianaColors.hyperGold,
                    onChanged: (value) async {
                      if (value) {
                        await ICalSubscriptionService.subscribe(cal.id);
                      } else {
                        await ICalSubscriptionService.unsubscribe(cal.id);
                      }
                      Navigator.pop(context);
                      _loadVibeLayers();
                    },
                  ),
                )),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSportsSubscriptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AelianaColors.carbon,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => FutureBuilder<List<String>>(
        future: SportsScheduleService.getSubscribedTeams(),
        builder: (context, snapshot) {
          final subscribed = snapshot.data ?? [];
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            expand: false,
            builder: (context, scrollController) => Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'Sports Teams',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: SportsScheduleService.popularTeams.map((team) => ListTile(
                        leading: Text(team.emoji, style: const TextStyle(fontSize: 24)),
                        title: Text(team.name, style: GoogleFonts.inter(color: Colors.white)),
                        subtitle: Text(team.league, style: GoogleFonts.inter(color: AelianaColors.ghost, fontSize: 12)),
                        trailing: Switch(
                          value: subscribed.contains(team.id),
                          activeColor: AelianaColors.hyperGold,
                          onChanged: (value) async {
                            if (value) {
                              await SportsScheduleService.subscribe(team.id);
                            } else {
                              await SportsScheduleService.unsubscribe(team.id);
                            }
                            Navigator.pop(context);
                            _loadVibeLayers();
                          },
                        ),
                      )).toList(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHolidayCard(ICalEvent holiday) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AelianaColors.hyperGold.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AelianaColors.hyperGold.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Text('🎄', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  holiday.title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  holiday.sourceCalendar,
                  style: GoogleFonts.inter(color: AelianaColors.ghost, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSportsCard(SportsEvent event) {
    final emoji = event.league == 'F1' ? '🏎️' : 
                  event.league == 'NFL' ? '🏈' :
                  event.league == 'NBA' ? '🏀' : '⚽';
    final timeStr = DateFormat('EEE h:mm a').format(event.start);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AelianaColors.plasmaCyan.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AelianaColors.plasmaCyan.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '$timeStr • ${event.league}',
                  style: GoogleFonts.inter(color: AelianaColors.ghost, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildReminderCard(reminders_svc.Reminder reminder, {bool isOverdue = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AelianaColors.carbon,
        borderRadius: BorderRadius.circular(12),
        border: isOverdue ? Border.all(color: Colors.red.withOpacity(0.5)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: reminder.isCompleted ? AelianaColors.hyperGold : AelianaColors.ghost,
                width: 2,
              ),
              color: reminder.isCompleted ? AelianaColors.hyperGold : Colors.transparent,
            ),
            child: reminder.isCompleted 
                ? const Icon(LucideIcons.check, size: 14, color: Colors.black)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    decoration: reminder.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (reminder.dueDate != null)
                  Text(
                    DateFormat('MMM d').format(reminder.dueDate!),
                    style: GoogleFonts.inter(
                      color: isOverdue ? Colors.red : AelianaColors.ghost,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVibeCard({
    required String icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AelianaColors.carbon,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AelianaColors.ghost,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBirthdayCard(ContactBirthday birthday, {bool isToday = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isToday ? AelianaColors.hyperGold.withOpacity(0.1) : AelianaColors.carbon,
        borderRadius: BorderRadius.circular(12),
        border: isToday ? Border.all(color: AelianaColors.hyperGold.withOpacity(0.5)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isToday ? AelianaColors.hyperGold : AelianaColors.plasmaCyan.withOpacity(0.2),
            ),
            child: Center(
              child: Text(
                '🎂',
                style: TextStyle(fontSize: isToday ? 20 : 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  birthday.name,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                Text(
                  isToday 
                      ? 'Turning ${birthday.age} today! 🎉'
                      : birthday.isTomorrow 
                          ? 'Tomorrow - turning ${birthday.age}'
                          : 'In ${birthday.daysUntil} days - turning ${birthday.age}',
                  style: GoogleFonts.inter(
                    color: isToday ? AelianaColors.hyperGold : AelianaColors.ghost,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (birthday.phone != null)
            IconButton(
              icon: Icon(LucideIcons.phone, color: AelianaColors.plasmaCyan, size: 18),
              onPressed: () {
                // Could open phone dialer
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Event event) {
    final timeStr = _formatEventTime(event);
    final isAllDay = event.allDay == true;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AelianaColors.carbon,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AelianaColors.hyperGold.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          // Time indicator
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: isAllDay ? AelianaColors.plasmaCyan : AelianaColors.hyperGold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          // Event details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title ?? 'Untitled Event',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      LucideIcons.clock,
                      size: 14,
                      color: AelianaColors.ghost,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeStr,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AelianaColors.ghost,
                      ),
                    ),
                  ],
                ),
                if (event.location != null && event.location!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.mapPin,
                        size: 14,
                        color: AelianaColors.ghost,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AelianaColors.ghost,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Chevron
          Icon(
            LucideIcons.chevronRight,
            color: AelianaColors.ghost,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AelianaColors.carbon,
              ),
              child: Icon(icon, size: 48, color: AelianaColors.plasmaCyan),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AelianaColors.ghost,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionRequest() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AelianaColors.hyperGold.withOpacity(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Icon(
                LucideIcons.calendar,
                size: 64,
                color: AelianaColors.hyperGold,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Calendar Access',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Allow Aeliana to access your calendar to show your schedule and help manage your day.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AelianaColors.ghost,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _requestPermission,
              icon: const Icon(LucideIcons.unlock, size: 18),
              label: const Text('Grant Access'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AelianaColors.hyperGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateEventDialog() {
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    DateTime eventDate = _selectedDate;
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AelianaColors.carbon,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'New Event',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(LucideIcons.x, color: AelianaColors.ghost),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Title
              TextField(
                controller: titleController,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Event Title',
                  labelStyle: TextStyle(color: AelianaColors.ghost),
                  prefixIcon: Icon(LucideIcons.edit3, color: AelianaColors.ghost),
                  filled: true,
                  fillColor: AelianaColors.obsidian,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Location
              TextField(
                controller: locationController,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Location (optional)',
                  labelStyle: TextStyle(color: AelianaColors.ghost),
                  prefixIcon: Icon(LucideIcons.mapPin, color: AelianaColors.ghost),
                  filled: true,
                  fillColor: AelianaColors.obsidian,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Time Row
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: startTime,
                        );
                        if (picked != null) {
                          setModalState(() => startTime = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AelianaColors.obsidian,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(LucideIcons.clock, color: AelianaColors.ghost, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              startTime.format(context),
                              style: GoogleFonts.inter(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('to', style: TextStyle(color: AelianaColors.ghost)),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: endTime,
                        );
                        if (picked != null) {
                          setModalState(() => endTime = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AelianaColors.obsidian,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(LucideIcons.clock, color: AelianaColors.ghost, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              endTime.format(context),
                              style: GoogleFonts.inter(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Create Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter an event title')),
                      );
                      return;
                    }

                    final startDateTime = DateTime(
                      eventDate.year,
                      eventDate.month,
                      eventDate.day,
                      startTime.hour,
                      startTime.minute,
                    );
                    final endDateTime = DateTime(
                      eventDate.year,
                      eventDate.month,
                      eventDate.day,
                      endTime.hour,
                      endTime.minute,
                    );

                    await CalendarService.createEvent(
                      title: titleController.text.trim(),
                      location: locationController.text.trim().isNotEmpty 
                          ? locationController.text.trim() 
                          : null,
                      start: startDateTime,
                      end: endDateTime,
                    );

                    if (mounted) {
                      Navigator.pop(context);
                      await _loadEvents();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Event "${titleController.text}" created'),
                          backgroundColor: AelianaColors.hyperGold,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AelianaColors.hyperGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Create Event',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _hasEventsOnDay(DateTime date) {
    return _upcomingEvents.any((e) => 
      e.start != null && _isSameDay(e.start!, date)
    );
  }

  List<Event> _getEventsForDay(DateTime date) {
    return _upcomingEvents.where((e) => 
      e.start != null && _isSameDay(e.start!, date)
    ).toList();
  }

  String _formatEventTime(Event event) {
    if (event.allDay == true) return 'All day';
    if (event.start == null) return '';
    
    final start = event.start!;
    final hour = start.hour > 12 ? start.hour - 12 : (start.hour == 0 ? 12 : start.hour);
    final period = start.hour >= 12 ? 'PM' : 'AM';
    final minute = start.minute.toString().padLeft(2, '0');
    
    if (event.end != null) {
      final end = event.end!;
      final endHour = end.hour > 12 ? end.hour - 12 : (end.hour == 0 ? 12 : end.hour);
      final endPeriod = end.hour >= 12 ? 'PM' : 'AM';
      final endMinute = end.minute.toString().padLeft(2, '0');
      return '$hour:$minute $period - $endHour:$endMinute $endPeriod';
    }
    
    return '$hour:$minute $period';
  }

  String _formatDayHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;
    
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return DateFormat('EEEE, MMM d').format(date);
  }
}
