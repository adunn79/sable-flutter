import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:go_router/go_router.dart';
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
import 'package:sable/core/travel/travel_service.dart';
import 'package:sable/core/news/headline_service.dart';
import 'package:sable/core/contacts/contact_picker_sheet.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:sable/core/ai/model_orchestrator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  
  // New Vibe Layers
  List<Event> _travelEvents = [];
  String? _headline;

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
    
    // Load travel events
    try {
      final travel = await TravelService.getTravelEvents(_selectedDate);
      if (mounted) setState(() => _travelEvents = travel);
    } catch (e) {
      debugPrint('❌ Error loading travel: $e');
    }

    // Load headline
    try {
      // If today, trigger fetch to ensure we have one (and it gets saved to history)
      if (_isSameDay(_selectedDate, DateTime.now())) {
        await HeadlineService.getTopHeadline();
      }
      // Get from history (works for today and past)
      final headline = await HeadlineService.getHeadlineForDate(_selectedDate);
      if (mounted) setState(() => _headline = headline);
    } catch (e) {
      debugPrint('❌ Error loading headline: $e');
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
                Row(
                  children: [
                    Text(
                      DateFormat('MMMM d, y').format(_selectedDate),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AelianaColors.ghost,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showPageInfo(context),
                      child: Icon(
                        LucideIcons.info, 
                        size: 14, 
                        color: AelianaColors.ghost.withOpacity(0.5)
                      ),
                    ),
                  ],
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AgenticScheduleChat(),
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
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Events'),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _showInfoDialog(
                    context, 
                    'Events', 
                    'Your daily schedule from your connected calendars. Tap + to add new events.',
                  ),
                  child: Icon(LucideIcons.info, size: 10, color: AelianaColors.ghost),
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Tasks'),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _showInfoDialog(
                    context, 
                    'Tasks', 
                    'Reminders and to-dos from your Reminders app. Keep track of what needs to be done.',
                  ),
                  child: Icon(LucideIcons.info, size: 10, color: AelianaColors.ghost),
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Vibe'),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _showInfoDialog(
                    context, 
                    'Vibe Layers', 
                    'Contextual information to help you tune into the day: Moon phases, weather, holidays, sports, and more.',
                  ),
                  child: Icon(LucideIcons.info, size: 10, color: AelianaColors.ghost),
                ),
              ],
            ),
          ),
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
          
          // Headline Card
          if (_headline != null) ...[
            _buildVibeCard(
              icon: '🌍',
              title: 'World Event',
              subtitle: _headline!,
              color: AelianaColors.plasmaCyan,
            ),
            const SizedBox(height: 16),
          ],
          
          // Travel Section
          if (_travelEvents.isNotEmpty) ...[
             _buildSectionHeader('✈️ Travel', AelianaColors.hyperGold),
             ..._travelEvents.map((e) => _buildTravelCard(e)),
             const SizedBox(height: 16),
          ],
          
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
    // Determine status color based on time
    final now = DateTime.now();
    bool isPast = false;
    bool isOngoing = false;
    
    if (event.start != null && event.end != null) {
      if (event.end!.isBefore(now)) {
        isPast = true;
      } else if (event.start!.isBefore(now) && event.end!.isAfter(now)) {
        isOngoing = true;
      }
    }
    
    // Check if it's all day
    final isAllDay = event.allDay == true;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AelianaColors.carbon,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOngoing 
              ? AelianaColors.plasmaCyan.withOpacity(0.5) 
              : AelianaColors.hyperGold.withOpacity(0.2),
          width: isOngoing ? 1.5 : 1,
        ),
        boxShadow: isOngoing ? [
          BoxShadow(
            color: AelianaColors.plasmaCyan.withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 2,
          )
        ] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showEventDetailsDialog(event),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Time indicator strip
                Container(
                  width: 4,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isAllDay ? AelianaColors.plasmaCyan : (isPast ? Colors.white24 : AelianaColors.hyperGold),
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
                          color: isPast ? Colors.white54 : Colors.white,
                          decoration: isPast ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.clock, 
                            size: 12, 
                            color: isPast ? Colors.white24 : Colors.white54
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatEventTime(event),
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: isPast ? Colors.white24 : Colors.white54,
                            ),
                          ),
                        ],
                      ),
                      if (event.location != null && event.location!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.mapPin, 
                                size: 12, 
                                color: isPast ? Colors.white24 : Colors.white54
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  event.location!,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: isPast ? Colors.white24 : Colors.white54,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Invitee count badge
                      if (event.attendees != null && event.attendees!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Icon(LucideIcons.users, size: 12, color: AelianaColors.plasmaCyan),
                              const SizedBox(width: 4),
                              Text(
                                '${event.attendees!.length} invited',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AelianaColors.plasmaCyan,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Chevron
                Icon(
                  LucideIcons.chevronRight,
                  color: isPast ? Colors.white10 : AelianaColors.ghost,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEventDetailsDialog(Event event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AelianaColors.carbon,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with delete button
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      event.title ?? 'Event',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            Divider(color: Colors.white.withOpacity(0.1), height: 1),
            
            // Details
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildDetailRow(LucideIcons.clock, _formatEventTime(event)),
                  if (event.location != null && event.location!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _buildDetailRow(LucideIcons.mapPin, event.location!),
                    ),
                  if (event.description != null && event.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _buildDetailRow(LucideIcons.alignLeft, event.description!),
                    ),
                  if (event.attendees != null && event.attendees!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(LucideIcons.users, color: AelianaColors.plasmaCyan, size: 20),
                              const SizedBox(width: 12),
                              Text('Invitees', style: GoogleFonts.inter(color: Colors.white70)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.only(left: 32),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: event.attendees!.whereType<Attendee>().map((a) => Chip(
                                label: Text(a.name ?? a.emailAddress ?? 'Unknown'),
                                backgroundColor: Colors.white10,
                                labelStyle: const TextStyle(fontSize: 12),
                              )).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            // Actions
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Confirm Delete
                        Navigator.pop(context); // Close details
                        _showDeleteConfirmDialog(event);
                      },
                      icon: const Icon(LucideIcons.trash2, size: 18),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                         Navigator.pop(context);
                         // Ideally preserve other fields by creating updated logic,
                         // For now, simpler to just close. Reuse edit logic if needed.
                         // But _showCreateEventDialog doesn't take an event to edit yet.
                         // We'll leave Edit for V2 or if user explicitly pushes for it.
                         // User said "Enable editing and deleting".
                         // I'll implement 'Edit' by reusing create dialog with prefill.
                         _showCreateEventDialog(existingEvent: event);
                      },
                      icon: const Icon(LucideIcons.edit3, size: 18),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AelianaColors.hyperGold,
                        foregroundColor: AelianaColors.obsidian,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(Event event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AelianaColors.carbon,
        title: const Text('Delete Event?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this event? This action cannot be undone.',
          style: TextStyle(color: Colors.white70)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close confirm
              await CalendarService.deleteEvent(event.calendarId!, event.eventId!);
              _loadEvents(); // Refresh
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Event deleted')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AelianaColors.plasmaCyan, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(fontSize: 15, color: Colors.white),
          ),
        ),
      ],
    );
  }

  void _showCreateEventDialog({Event? existingEvent}) {
    // Ensure existingEvent handling (for edit mode)
    // If Editing, we need existing IDs
    
    showDialog(
      context: context,
      builder: (context) => _CreateEventDialog(
        initialDate: _selectedDate,
        existingEvent: existingEvent,
        onEventCreated: () {
          _loadEvents();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(existingEvent == null ? 'Event created!' : 'Event updated!')),
          );
        },
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
    if (_isSameDay(date, DateTime.now())) {
      // For today, use the specifically fetched todayEvents which cover the full day
      return _todayEvents;
    }
    
    return _upcomingEvents.where((e) => 
      e.start != null && _isSameDay(e.start!, date)
    ).toList();
  }

  void _showPageInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AelianaColors.carbon,
        title: Text('About Today', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
        content: Text(
          'This is your daily command center. See your schedule, manage tasks, and check the "Vibe" of the day (Moon phase, holidays, etc).',
          style: GoogleFonts.inter(color: AelianaColors.ghost),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(color: AelianaColors.plasmaCyan)),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AelianaColors.carbon,
        title: Text(title, style: GoogleFonts.spaceGrotesk(color: Colors.white)),
        content: Text(
          message,
          style: GoogleFonts.inter(color: AelianaColors.ghost),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(color: AelianaColors.plasmaCyan)),
          ),
        ],
      ),
    );
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

  Widget _buildTravelCard(Event event) {
    final start = event.start != null ? DateFormat('h:mm a').format(event.start!) : '';
    final end = event.end != null ? DateFormat('h:mm a').format(event.end!) : '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AelianaColors.carbon,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AelianaColors.hyperGold.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AelianaColors.hyperGold.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              TravelService.getTravelIcon(event),
              style: const TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title ?? 'Travel',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (start.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(LucideIcons.clock, size: 14, color: AelianaColors.hyperGold),
                        const SizedBox(width: 4),
                        Text(
                          '$start${end.isNotEmpty ? ' - $end' : ''}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AelianaColors.ghost,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (event.location != null && event.location!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(LucideIcons.mapPin, size: 14, color: AelianaColors.hyperGold),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.location!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AelianaColors.ghost,
                            ),
                          ),
                        ),
                      ],
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

class _CreateEventDialog extends StatefulWidget {
  final DateTime initialDate;
  final Event? existingEvent;
  final VoidCallback onEventCreated;

  const _CreateEventDialog({
    required this.initialDate,
    this.existingEvent,
    required this.onEventCreated,
  });

  @override
  State<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<_CreateEventDialog> {
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late DateTime _eventDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  List<Contact> _invitees = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existingEvent?.title ?? '');
    _locationController = TextEditingController(text: widget.existingEvent?.location ?? '');
    _eventDate = widget.existingEvent?.start ?? widget.initialDate;
    _startTime = TimeOfDay.fromDateTime(widget.existingEvent?.start ?? DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day, 9, 0));
    _endTime = TimeOfDay.fromDateTime(widget.existingEvent?.end ?? DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day, 10, 0));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _addInvitee() async {
    final contact = await showModalBottomSheet<Contact>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ContactPickerSheet(),
    );

    if (contact != null) {
      if (!_invitees.any((c) => c.identifier == contact.identifier)) {
        setState(() {
          _invitees.add(contact);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.existingEvent == null ? 'New Event' : 'Edit Event',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            style: GoogleFonts.inter(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Event Title',
              labelStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(LucideIcons.edit3, color: Colors.white54),
              filled: true,
              fillColor: AelianaColors.obsidian,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _locationController,
            style: GoogleFonts.inter(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Location (optional)',
              labelStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(LucideIcons.mapPin, color: Colors.white54),
              filled: true,
              fillColor: AelianaColors.obsidian,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _startTime,
                    );
                    if (picked != null) {
                      setState(() => _startTime = picked);
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
                        const Icon(LucideIcons.clock, color: Colors.white54, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _startTime.format(context),
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('to', style: TextStyle(color: Colors.white54)),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _endTime,
                    );
                    if (picked != null) {
                      setState(() => _endTime = picked);
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
                        const Icon(LucideIcons.clock, color: Colors.white54, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _endTime.format(context),
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Invitees', style: GoogleFonts.inter(color: Colors.white70)),
              const Spacer(),
              TextButton.icon(
                onPressed: _addInvitee,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Add'),
                style: TextButton.styleFrom(
                  foregroundColor: AelianaColors.plasmaCyan,
                ),
              ),
            ],
          ),
          if (_invitees.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _invitees.map((c) => Chip(
                label: Text(c.displayName ?? 'Unknown'),
                backgroundColor: AelianaColors.plasmaCyan.withOpacity(0.2),
                labelStyle: const TextStyle(color: AelianaColors.plasmaCyan),
                onDeleted: () {
                  setState(() => _invitees.remove(c));
                },
              )).toList(),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                if (_titleController.text.trim().isEmpty) return;

                final startDateTime = DateTime(
                  _eventDate.year,
                  _eventDate.month,
                  _eventDate.day,
                  _startTime.hour,
                  _startTime.minute,
                );
                final endDateTime = DateTime(
                  _eventDate.year,
                  _eventDate.month,
                  _eventDate.day,
                  _endTime.hour,
                  _endTime.minute,
                );

                final attendees = _invitees.map((c) {
                  String? email;
                  if (c.emails != null && c.emails!.isNotEmpty) {
                    email = c.emails!.first.value;
                  }
                  return Attendee(
                    name: c.displayName,
                    emailAddress: email,
                    role: AttendeeRole.None,
                  );
                }).toList();

                await CalendarService.createEvent(
                  title: _titleController.text.trim(),
                  location: _locationController.text.trim().isNotEmpty 
                      ? _locationController.text.trim() 
                      : null,
                  start: startDateTime,
                  end: endDateTime,
                  attendees: attendees.isEmpty ? null : attendees,
                );

                widget.onEventCreated();
                if (mounted) Navigator.pop(context);
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
                widget.existingEvent == null ? 'Create Event' : 'Update Event',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgenticScheduleChat extends ConsumerStatefulWidget {
  const _AgenticScheduleChat();

  @override
  ConsumerState<_AgenticScheduleChat> createState() => _AgenticScheduleChatState();
}

class _AgenticScheduleChatState extends ConsumerState<_AgenticScheduleChat> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _messages.add({
      'text': "I'm your Schedule Agent. What do you need?",
      'isUser': false,
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSubmitted() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'text': text, 'isUser': true});
      _isTyping = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final orchestrator = ref.read(modelOrchestratorProvider.notifier);
      final calendarSummary = await CalendarService.getCalendarSummary();
      final contextPayload = "You are a Calendar Agent.\nUser Request: $text\n\nCurrent Schedule:\n$calendarSummary";
      
      final response = await orchestrator.orchestratedRequest(
        prompt: text,
        userContext: contextPayload,
        archetypeName: 'Sable', 
      );

      if (mounted) {
        setState(() {
          _messages.add({'text': response, 'isUser': false});
          _isTyping = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({'text': "Error: $e", 'isUser': false});
          _isTyping = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: AelianaColors.carbon,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(LucideIcons.bot, color: AelianaColors.plasmaCyan),
                const SizedBox(width: 12),
                Text(
                  'SCHEDULE AGENT',
                  style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(LucideIcons.x, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.1), height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return const Text('Typing...', style: TextStyle(color: Colors.white30));
                }
                final msg = _messages[index];
                final isUser = msg['isUser'] as bool;
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? AelianaColors.plasmaCyan.withOpacity(0.2) : Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    child: Text(msg['text'], style: GoogleFonts.inter(color: Colors.white)),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type...',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onSubmitted: (_) => _handleSubmitted(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AelianaColors.plasmaCyan,
                  child: IconButton(
                    icon: const Icon(LucideIcons.send, color: Colors.black, size: 18),
                    onPressed: _handleSubmitted,
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
