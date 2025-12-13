import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:sable/features/safety/screens/emergency_screen.dart';
import 'package:sable/features/onboarding/services/onboarding_state_service.dart';
import 'package:sable/features/vital_balance/services/vital_balance_service.dart';
import 'package:sable/features/vital_balance/services/step_tracking_service.dart';
import 'package:sable/core/widgets/unified_avatar_widget.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sable/src/pages/chat/chat_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sable/core/memory/unified_memory_service.dart';
import 'package:sable/core/ai/model_orchestrator.dart';
import 'package:sable/core/ai/providers/openai_provider.dart';
import 'package:sable/features/journal/services/journal_storage_service.dart';
import 'package:sable/features/vital_balance/services/goals_service.dart';
import 'package:sable/features/vital_balance/models/goal_model.dart';
import 'package:sable/features/inspiration/widgets/shareable_quote_card.dart';

/// Vital Balance Screen - Health & Wellness Tracking
/// Uses the "Vitality Strategist" personality for AI interactions
class VitalBalanceScreen extends StatefulWidget {
  const VitalBalanceScreen({super.key});

  @override
  State<VitalBalanceScreen> createState() => _VitalBalanceScreenState();
}

class _VitalBalanceScreenState extends State<VitalBalanceScreen> {
  // Track disposal to prevent setState after dispose
  bool _disposed = false;
  
  // Soothing color palette for wellness
  static const Color _backgroundStart = Color(0xFF0D1B2A); // Deep navy
  static const Color _backgroundMid = Color(0xFF1B263B);   // Slate blue
  static const Color _backgroundEnd = Color(0xFF0D1B2A);   // Deep navy
  static const Color _accentTeal = Color(0xFF5DD9C1);      // Soothing teal
  static const Color _accentLavender = Color(0xFFB8A9D9);  // Soft lavender
  static const Color _cardColor = Color(0xFF1E2D3D);       // Dark card
  static const Color _warningAmber = Color(0xFFFFB74D);    // Warning color

  // Avatar and privacy state
  String? _avatarUrl;
  String _archetypeId = 'sable';
  bool _keepConversationsPrivate = false; // Default: NOT private (observing)
  
  // Metrics Data
  List<HealthMetric> _metrics = [];
  Map<String, String> _latestValues = {};
  Map<String, String> _profile = {}; // Added profile state
  bool _isLoadingMetrics = true;
  
  // Weather Data
  String? _weatherTemp;
  String? _weatherHighLow;
  
  // Inline Chat State
  List<Map<String, String>> _chatMessages = []; // {role: 'user'|'ai', text: '...'}
  bool _isAiThinking = false;
  bool _hideChatMessages = false; // Hides messages without deleting
  final ScrollController _chatScrollController = ScrollController();
  final GlobalKey _chatSectionKey = GlobalKey(); // Key for scrolling to chat
  
  // Dynamic AI-Generated Focus Items
  List<Map<String, dynamic>> _aiFocusItems = []; // {title, description, icon, metricId, enabled}
  bool _isLoadingFocus = true;
  int _daysSinceUpdate = 0; // Days since last wellness metric update
  Set<String> _disabledFocusItems = {}; // User-disabled items by metricId
  
  // Goals
  List<Goal> _goals = [];
  bool _isLoadingGoals = true;
  
  // AI Services
  final UnifiedMemoryService _memoryService = UnifiedMemoryService();
  final ModelOrchestrator _orchestrator = ModelOrchestrator();
  
  static const _keyPrivateConversations = 'vital_balance_private_conversations';

  final TextEditingController _chatInputController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadAllData();
    _loadDynamicPrompts(); // Load AI-personalized prompts
    // Delay check to allow build to finish
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkProfile());
  }
  
  @override
  void dispose() {
    _chatInputController.dispose();
    _disposed = true;
    super.dispose();
  }
  
  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    final stateService = await OnboardingStateService.create();
    
    // Load Metrics
    final metrics = await VitalBalanceService.getMetrics();
    final values = <String, String>{};
    for (var m in metrics) {
      values[m.id] = await VitalBalanceService.getLatestValueFormatted(m);
    }
    
    // Load Weather
    final weatherTemp = prefs.getString('cached_weather_temp');
    final weatherHighLow = prefs.getString('cached_weather_condition'); // Using condition as subtitle/extra if needed
    
    // Load Profile
    final profile = await VitalBalanceService.getProfile();
    
    // Calculate days since last wellness update
    int daysSince = 0;
    final lastWellnessUpdate = prefs.getString('last_wellness_update_date');
    if (lastWellnessUpdate != null) {
      try {
        final lastDate = DateTime.parse(lastWellnessUpdate);
        daysSince = DateTime.now().difference(lastDate).inDays;
      } catch (_) {}
    } else {
      daysSince = 999; // Never updated
    }
    
    if (_disposed || !mounted) return;
    setState(() {
      _avatarUrl = stateService.avatarUrl;
      _archetypeId = stateService.selectedArchetypeId;
      _keepConversationsPrivate = prefs.getBool(_keyPrivateConversations) ?? false;
      _metrics = metrics;
      _latestValues = values;
      _profile = profile;
      _weatherTemp = weatherTemp;
      _weatherHighLow = weatherHighLow;
      _daysSinceUpdate = daysSince;
      _isLoadingMetrics = false;
    });
    
    // Load Goals
    await GoalsService.init();
    if (_disposed || !mounted) return;
    setState(() {
      _goals = GoalsService.getActiveGoals();
      _isLoadingGoals = false;
    });
  }
  
  Future<void> _refreshMetrics() async {
    final metrics = await VitalBalanceService.getMetrics();
    final values = <String, String>{};
    for (var m in metrics) {
      values[m.id] = await VitalBalanceService.getLatestValueFormatted(m);
    }
    if (mounted) {
      setState(() {
        _metrics = metrics;
        _latestValues = values;
      });
    }
  }
  
  /// Load AI-personalized prompts based on user's mental state, chat history, and journal entries
  Future<void> _loadDynamicPrompts() async {
    if (_disposed || !mounted) return; // Early exit if disposed
    
    // Load disabled items from preferences
    final prefs = await SharedPreferences.getInstance();
    if (_disposed || !mounted) return; // Check again after async
    
    _disabledFocusItems = (prefs.getStringList('disabled_focus_items') ?? []).toSet();
    
    try {
      // Analyze which metrics are missing or need attention
      final missingMetrics = <Map<String, dynamic>>[];
      final lowPriorityMetrics = <Map<String, dynamic>>[];
      
      for (final metric in _metrics) {
        if (_disabledFocusItems.contains(metric.id)) continue; // Skip disabled
        
        final value = _latestValues[metric.name];
        final hasValue = value != null && !value.startsWith('--');
        
        if (!hasValue) {
          // Missing data - high priority
          missingMetrics.add({
            'title': _getFocusTitle(metric.id),
            'description': _getFocusDescription(metric.id, hasData: false),
            'icon': VitalBalanceService.getIconData(metric.iconName),
            'metricId': metric.id,
          });
        } else {
          // Has data - could still suggest action
          lowPriorityMetrics.add({
            'title': _getFocusTitle(metric.id),
            'description': _getFocusDescription(metric.id, hasData: true),
            'icon': VitalBalanceService.getIconData(metric.iconName),
            'metricId': metric.id,
          });
        }
      }
      
      if (_disposed || !mounted) return;
      
      // Prioritize missing data, then add some with data for variety
      final focusItems = <Map<String, dynamic>>[];
      focusItems.addAll(missingMetrics.take(2)); // Up to 2 missing
      focusItems.addAll(lowPriorityMetrics.take(2 - focusItems.length.clamp(0, 2))); // Fill to 2-4 items
      
      setState(() {
        _aiFocusItems = focusItems.isEmpty ? _getDefaultFocusItems() : focusItems;
        _isLoadingFocus = false;
      });
    } catch (e) {
      debugPrint('Error loading AI focus: $e');
      _setDefaultFocusItems();
    }
  }
  
  String _getFocusTitle(String metricId) {
    switch (metricId) {
      case 'sleep': return 'Rest';
      case 'sleep_quality': return 'Sleep Quality';
      case 'dreams': return 'Dreams';
      case 'energy': return 'Energy';
      case 'mood': return 'Reflect';
      case 'stress': return 'Calm';
      case 'weight': return 'Weigh In';
      case 'water': return 'Hydrate';
      case 'steps': return 'Move';
      case 'pain': return 'Pain Check';
      case 'heart_rate': return 'Heart';
      case 'meditation': return 'Breathe';
      case 'bp_sys':
      case 'bp_dia': return 'BP Check';
      default: return 'Track';
    }
  }
  
  String _getFocusDescription(String metricId, {required bool hasData}) {
    if (!hasData) {
      switch (metricId) {
        case 'sleep': return 'Log last night\'s sleep';
        case 'sleep_quality': return 'Rate how well you slept';
        case 'dreams': return 'Journal your dreams ✨';
        case 'energy': return 'Rate your energy';
        case 'mood': return 'Log your mood';
        case 'stress': return 'Rate stress level';
        case 'weight': return 'Log your weight';
        case 'water': return 'Track water intake';
        case 'steps': return 'Log your steps';
        case 'pain': return 'Rate pain level';
        case 'heart_rate': return 'Check heart rate';
        case 'meditation': return 'Log meditation';
        case 'bp_sys':
        case 'bp_dia': return 'Check blood pressure';
        default: return 'Log this metric';
      }
    } else {
      switch (metricId) {
        case 'sleep': return 'Review sleep trends';
        case 'sleep_quality': return 'Update sleep rating';
        case 'dreams': return 'Add to dream journal';
        case 'energy': return 'Boost your energy';
        case 'mood': return 'Update your mood';
        case 'stress': return 'Try stress relief';
        case 'weight': return 'Check progress';
        case 'water': return 'Add more water';
        case 'steps': return 'Take a 10m walk';
        case 'pain': return 'Update pain level';
        case 'heart_rate': return 'Monitor heart';
        case 'meditation': return 'Meditate now';
        case 'bp_sys':
        case 'bp_dia': return 'Monitor BP';
        default: return 'Update metric';
      }
    }
  }
  
  List<Map<String, dynamic>> _getDefaultFocusItems() {
    return [
      {'title': 'Move', 'description': 'Take a 10m walk', 'icon': LucideIcons.footprints, 'metricId': 'steps'},
      {'title': 'Reflect', 'description': 'Log your mood', 'icon': LucideIcons.brainCircuit, 'metricId': 'mood'},
    ];
  }
  
  void _setDefaultFocusItems() {
    if (mounted) {
      setState(() {
        _aiFocusItems = _getDefaultFocusItems();
        _isLoadingFocus = false;
      });
    }
  }
  
  Future<void> _toggleFocusItem(String metricId, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (enabled) {
        _disabledFocusItems.remove(metricId);
      } else {
        _disabledFocusItems.add(metricId);
      }
    });
    await prefs.setStringList('disabled_focus_items', _disabledFocusItems.toList());
    _loadDynamicPrompts(); // Refresh
  }
  
  /// Show dialog to edit AI Focus items - toggle which ones appear daily
  void _showEditFocusItemsDialog() {
    // Available focus items that can be toggled
    final focusOptions = [
      {'id': 'steps', 'title': 'Move', 'description': 'Take a 10m walk', 'icon': LucideIcons.footprints},
      {'id': 'mood', 'title': 'Reflect', 'description': 'Log your mood', 'icon': LucideIcons.smile},
      {'id': 'sleep', 'title': 'Rest', 'description': 'Log your sleep hours', 'icon': LucideIcons.moon},
      {'id': 'sleep_quality', 'title': 'Sleep Quality', 'description': 'Rate how well you slept', 'icon': LucideIcons.sparkles},
      {'id': 'dreams', 'title': 'Dreams', 'description': 'Try journaling dreams!', 'icon': LucideIcons.cloudMoon},
      {'id': 'water', 'title': 'Hydrate', 'description': 'Track water intake', 'icon': LucideIcons.glassWater},
      {'id': 'stress', 'title': 'Breathe', 'description': 'Check stress level', 'icon': LucideIcons.brain},
      {'id': 'meditation', 'title': 'Meditate', 'description': 'Log meditation time', 'icon': LucideIcons.wind},
      {'id': 'energy', 'title': 'Energy', 'description': 'Rate your energy', 'icon': LucideIcons.battery},
      {'id': 'pain', 'title': 'Pain Check', 'description': 'Log pain level', 'icon': LucideIcons.activity},
    ];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF15202B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(LucideIcons.sparkles, color: _accentLavender, size: 18),
                  const SizedBox(width: 8),
                  Text('Edit Daily Focus', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: Colors.white38, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Toggle items on/off. Disabled items are hidden from your daily list but data is preserved.', 
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
              const SizedBox(height: 12),
              // Scrollable items - compact size
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: focusOptions.map((item) {
                    final isEnabled = !_disabledFocusItems.contains(item['id']);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isEnabled ? _accentLavender.withOpacity(0.08) : Colors.white.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isEnabled ? _accentLavender.withOpacity(0.2) : Colors.white10),
                        ),
                        child: Row(
                          children: [
                            Icon(item['icon'] as IconData, color: isEnabled ? _accentLavender : Colors.white24, size: 16),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['title'] as String, style: GoogleFonts.inter(color: isEnabled ? Colors.white : Colors.white38, fontSize: 12, fontWeight: FontWeight.w600)),
                                  Text(item['description'] as String, style: GoogleFonts.inter(color: Colors.white30, fontSize: 9)),
                                ],
                              ),
                            ),
                            Transform.scale(
                              scale: 0.7,
                              child: Switch(
                                value: isEnabled,
                                onChanged: (val) {
                                  setSheetState(() {
                                    if (val) {
                                      _disabledFocusItems.remove(item['id']);
                                    } else {
                                      _disabledFocusItems.add(item['id'] as String);
                                    }
                                  });
                                  _toggleFocusItem(item['id'] as String, val);
                                },
                                activeColor: _accentLavender,
                                activeTrackColor: _accentLavender.withOpacity(0.3),
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
          ),
        ),
      ),
    );
  }


  /// Show sheet to add/manage metrics from pre-populated list
  void _showAddMetricSheet() {
    final availableMetrics = [
      {'id': 'sleep', 'name': 'Sleep Hours', 'icon': LucideIcons.moonStar, 'category': 'Rest'},
      {'id': 'energy', 'name': 'Energy Level', 'icon': LucideIcons.zap, 'category': 'Wellness'},
      {'id': 'mood', 'name': 'Mood', 'icon': LucideIcons.smilePlus, 'category': 'Mental'},
      {'id': 'stress', 'name': 'Stress Level', 'icon': LucideIcons.brainCircuit, 'category': 'Mental'},
      {'id': 'weight', 'name': 'Weight', 'icon': LucideIcons.scale3d, 'category': 'Body'},
      {'id': 'water', 'name': 'Water Intake', 'icon': LucideIcons.droplets, 'category': 'Nutrition'},
      {'id': 'steps', 'name': 'Steps/Activity', 'icon': LucideIcons.footprints, 'category': 'Activity'},
      {'id': 'pain', 'name': 'Pain Level', 'icon': LucideIcons.flame, 'category': 'Health'},
      {'id': 'heart_rate', 'name': 'Heart Rate', 'icon': LucideIcons.heartPulse, 'category': 'Vitals'},
      {'id': 'bp_sys', 'name': 'Blood Pressure', 'icon': LucideIcons.heartPulse, 'category': 'Vitals'},
      {'id': 'meditation', 'name': 'Meditation', 'icon': LucideIcons.sparkles, 'category': 'Mental'},
      // Additional medical tests
      {'id': 'blood_glucose', 'name': 'Blood Glucose', 'icon': LucideIcons.droplet, 'category': 'Lab Tests'},
      {'id': 'a1c', 'name': 'HbA1c', 'icon': LucideIcons.testTubes, 'category': 'Lab Tests'},
      {'id': 'cholesterol', 'name': 'Cholesterol', 'icon': LucideIcons.testTube, 'category': 'Lab Tests'},
      {'id': 'vitamin_d', 'name': 'Vitamin D', 'icon': LucideIcons.sun, 'category': 'Lab Tests'},
      {'id': 'iron', 'name': 'Iron/Ferritin', 'icon': LucideIcons.pill, 'category': 'Lab Tests'},
      {'id': 'thyroid', 'name': 'Thyroid (TSH)', 'icon': LucideIcons.activity, 'category': 'Lab Tests'},
      {'id': 'oxygen', 'name': 'Oxygen (SpO2)', 'icon': LucideIcons.wind, 'category': 'Vitals'},
      {'id': 'temperature', 'name': 'Temperature', 'icon': LucideIcons.thermometer, 'category': 'Vitals'},
      {'id': 'medications', 'name': 'Medication Adherence', 'icon': LucideIcons.pill, 'category': 'Health'},
    ];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF15202B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (context, setSheetState) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(LucideIcons.listPlus, color: _accentTeal, size: 20),
                    const SizedBox(width: 8),
                    Text('Manage Health Metrics', style: GoogleFonts.inter(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.white54, size: 20),
                    ),
                  ],
                ),
              ),
              Divider(color: Colors.white.withOpacity(0.1), height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: availableMetrics.length,
                  itemBuilder: (context, index) {
                    final metric = availableMetrics[index];
                    final isDisabled = _disabledFocusItems.contains(metric['id']);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDisabled 
                              ? Colors.white.withOpacity(0.05) 
                              : _accentTeal.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          metric['icon'] as IconData,
                          color: isDisabled ? Colors.white30 : _accentTeal,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        metric['name'] as String,
                        style: GoogleFonts.inter(
                          color: isDisabled ? Colors.white30 : Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        metric['category'] as String,
                        style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                      ),
                      trailing: Switch.adaptive(
                        value: !isDisabled,
                        onChanged: (enabled) {
                          _toggleFocusItem(metric['id'] as String, enabled);
                          setSheetState(() {});
                        },
                        activeColor: _accentTeal,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Show comprehensive summary of all metrics in one readable view
  void _showAllMetricsSummary() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1821),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(LucideIcons.layoutDashboard, color: _accentTeal, size: 22),
                  const SizedBox(width: 10),
                  Text('All Health Metrics', style: GoogleFonts.spaceGrotesk(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    DateFormat('MMM d, yyyy').format(DateTime.now()),
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white.withOpacity(0.1), height: 1),
            // Metrics List
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _metrics.length,
                itemBuilder: (context, index) {
                  final metric = _metrics[index];
                  final value = _latestValues[metric.name] ?? '-- ${metric.unit}';
                  final hasData = !value.startsWith('--');
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: hasData 
                          ? _accentTeal.withOpacity(0.08) 
                          : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: hasData 
                            ? _accentTeal.withOpacity(0.2) 
                            : Colors.white.withOpacity(0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Icon
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: hasData 
                                ? _accentTeal.withOpacity(0.15) 
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            VitalBalanceService.getIconData(metric.iconName),
                            color: hasData ? _accentTeal : Colors.white30,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Name & Value
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                metric.name.toUpperCase(),
                                style: GoogleFonts.inter(
                                  color: Colors.white54,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                value,
                                style: GoogleFonts.spaceGrotesk(
                                  color: hasData ? Colors.white : Colors.white38,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Add button if no data
                        if (!hasData)
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              _showMetricDetailsDialog(metric);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _accentTeal.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.plus, color: _accentTeal, size: 14),
                                  const SizedBox(width: 4),
                                  Text('Add', style: GoogleFonts.inter(color: _accentTeal, fontSize: 12)),
                                ],
                              ),
                            ),
                          )
                        else
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              _showMetricDetailsDialog(metric);
                            },
                            child: Icon(LucideIcons.chevronRight, color: Colors.white38, size: 20),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Send a message and get inline AI response
  Future<void> _sendWellnessMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    // Check if user is confirming/requesting goal creation - use flexible matching
    final lowerText = text.toLowerCase().trim();
    
    // Check for various confirmation patterns
    bool isConfirmation = false;
    
    // Exact matches for short confirmations
    final exactMatches = ['yes', 'yup', 'ok', 'okay', 'sure', 'perfect', 'yeah', 'yea', 'y', 'yep', 'absolutely', 'definitely'];
    if (exactMatches.contains(lowerText) || exactMatches.any((m) => lowerText.startsWith('$m ') || lowerText.startsWith('$m!') || lowerText.startsWith('$m.'))) {
      isConfirmation = true;
    }
    
    // Pattern matches for goal creation requests (anywhere in the message)
    final goalCreationPatterns = [
      'create the goal',
      'create this goal',
      'create it',
      'create goal',
      'make the goal',
      'make this goal',
      'make it',
      'add the goal',
      'add this goal',
      'add it',
      'please create',
      'go ahead',
      'do it',
      'sounds good',
      'let\'s do it',
      'let\'s go',
      'save the goal',
      'save it',
      'set the goal',
      'set it up',
    ];
    if (!isConfirmation && goalCreationPatterns.any((pattern) => lowerText.contains(pattern))) {
      isConfirmation = true;
    }
    
    debugPrint('🔍 User message: "$lowerText" - Is confirmation: $isConfirmation');
    
    if (isConfirmation) {
      debugPrint('✅ Confirmation detected! Looking for proposed goal in ${_chatMessages.length} messages...');
      
      // Look for the most recent AI message with a proposed goal (including "Goal Created" responses that weren't actually saved)
      final proposedGoalMessage = _chatMessages.reversed.firstWhere(
        (m) => m['role'] == 'ai' && (
          m['text']?.contains('Proposed Goal') == true || 
          m['text']?.contains('**Title:**') == true || 
          m['text']?.contains('Title:') == true ||
          m['text']?.contains('Goal Created') == true
        ),
        orElse: () => {},
      );
      
      debugPrint('📋 Found goal message: ${proposedGoalMessage.isNotEmpty}');
      if (proposedGoalMessage.isNotEmpty) {
        debugPrint('📋 Goal message preview: ${proposedGoalMessage['text']?.substring(0, (proposedGoalMessage['text']?.length ?? 0).clamp(0, 100))}...');
      }
      
      if (proposedGoalMessage.isNotEmpty && proposedGoalMessage['text'] != null) {
        final goalCreated = await _parseAndCreateGoalFromAI(proposedGoalMessage['text']!);
        debugPrint('🎯 Goal creation result: $goalCreated');
        if (goalCreated) {
          setState(() {
            _chatMessages.add({'role': 'user', 'text': text});
            _chatMessages.add({'role': 'ai', 'text': '🎯 Awesome! Your goal has been created and added to your Goals section. I\'ll check in with you regularly to see how you\'re progressing. You\'ve got this! 💪'});
          });
          // Refresh goals list
          final goals = GoalsService.getActiveGoals();
          setState(() => _goals = goals);
          return;
        } else {
          debugPrint('⚠️ Goal parsing failed, falling through to regular message flow');
        }
      } else {
        debugPrint('⚠️ No proposed goal message found in chat history');
      }
    }
    
    setState(() {
      _chatMessages.add({'role': 'user', 'text': text});
      _isAiThinking = true;
    });
    
    // Scroll to show user's message immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.jumpTo(
          _chatScrollController.position.maxScrollExtent,
        );
      }
    });
    
    try {
      // Get user identity and preferences - use correct archetype key!
      final prefs = await SharedPreferences.getInstance();
      final archetypeId = prefs.getString('selected_archetype_id') ?? 'sable';
      // Convert archetype ID to display name
      final avatarName = archetypeId.substring(0, 1).toUpperCase() + archetypeId.substring(1);
      final userName = prefs.getString('user_name') ?? 'there';
      
      // Load FULL user context - chat history, journals, memories
      await _memoryService.initialize();
      
      // Get recent chat history (last 20 messages for context)
      final chatHistory = await _memoryService.getAllChatMessages();
      final recentChats = chatHistory.take(20).map((m) => 
        '${m.isUser ? userName : avatarName}: ${m.message}'
      ).join('\n');
      
      // Get journal entries (last 5 for deeper insight)
      await JournalStorageService.initialize();
      final buckets = await JournalStorageService.getAllBuckets();
      final recentJournals = <String>[];
      for (final bucket in buckets.take(5)) {
        final entries = await JournalStorageService.getEntriesForBucket(bucket.id);
        for (final entry in entries.take(3)) {
          final textPreview = entry.plainText.length > 200 
              ? entry.plainText.substring(0, 200) 
              : entry.plainText;
          recentJournals.add('${entry.timestamp.toString().split(' ')[0]}: $textPreview');
        }
      }
      final journalContext = recentJournals.take(8).join('\n');
      
      // Get extracted memories (key facts about user)
      final memories = await _memoryService.getAllMemories();
      final memoryContext = memories.map((m) => 
        '${m.category}: ${m.content}'
      ).join('\n');
      
      // Health profile
      final age = prefs.getString('health_age') ?? '';
      final sex = prefs.getString('health_sex') ?? '';
      final height = prefs.getString('health_height') ?? '';
      
      // Build wellness-focused context with FULL user knowledge
      final metricsContext = _latestValues.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');
      
      // Build goals context for AI awareness
      String goalsContext = '';
      if (_goals.isNotEmpty) {
        final goalSummaries = _goals.map((g) {
          final status = g.isOverdue ? 'OVERDUE' : 
                        g.needsCheckInReminder ? 'needs check-in' : 'on track';
          return '• ${g.title} (${g.progressPercent}%, ${g.daysRemaining} days left, $status)';
        }).join('\n');
        goalsContext = '\nACTIVE GOALS:\n$goalSummaries\n';
      }
      // Build CURRENT wellness chat history (this session's conversation)
      String currentChatContext = '';
      if (_chatMessages.isNotEmpty) {
        final startIndex = _chatMessages.length > 10 ? _chatMessages.length - 10 : 0;
        final lastMessages = _chatMessages.skip(startIndex).map((m) {
          final role = m['role'] == 'user' ? userName : avatarName;
          return '$role: ${m['text']}';
        }).join('\n');
        currentChatContext = '\nCURRENT WELLNESS CONVERSATION (continue from here):\n$lastMessages\n';
      }
      
      // Check if we're in goal-setting mode
      final isGoalSettingMode = _chatMessages.any((m) => 
        m['text']?.contains('Goal Planning Mode') == true ||
        m['text']?.contains('Proposed Goal') == true ||
        m['text']?.toLowerCase()?.contains('setting a goal') == true ||
        m['text']?.toLowerCase()?.contains('want to set a goal') == true
      );
      
      final wellnessPrompt = '''User asks: "$text"

CURRENT HEALTH METRICS: $metricsContext
$goalsContext
${currentChatContext}${isGoalSettingMode ? '\n⚠️ YOU ARE IN GOAL CREATION MODE - Remember to help refine and eventually propose a formatted goal!\n' : ''}
HEALTH PROFILE:
- Name: $userName
- Age: ${age.isEmpty ? 'Not specified' : age}
- Sex: ${sex.isEmpty ? 'Not specified' : sex}  
- Height: ${height.isEmpty ? 'Not specified' : height}

${memoryContext.isNotEmpty ? 'KEY MEMORIES ABOUT $userName:\n$memoryContext\n' : ''}
${recentChats.isNotEmpty ? 'RECENT CONVERSATIONS (main chat):\n$recentChats\n' : ''}
${journalContext.isNotEmpty ? 'RECENT JOURNAL ENTRIES:\n$journalContext' : ''}''';

      final systemPrompt = '''You are $avatarName, the same AI companion that $userName chats with every day. You KNOW them deeply - their name, their history, their struggles, their victories.

YOUR IDENTITY:
- Your name is $avatarName - you ARE their companion, mentor, health guru, and friend
- You have access to ALL their conversations, journal entries, and health data
- You remember everything they've shared with you
- You speak naturally as someone who knows them well

RELATIONSHIP:
- $userName trusts you completely - you are their guide and confidant
- Refer to past conversations and journal entries when relevant
- Be personal - use their name, reference specific things you know about them
- You are NOT a generic assistant - you are THEIR $avatarName

WELLNESS FOCUS:
- In this Vital Balance tab, focus on health and wellness guidance
- Draw from their health metrics, sleep patterns, mood trends
- Be energetic, systematic, resilient, and empowering

GOAL COACHING (Important):
- If user has active goals, naturally weave them into conversation when relevant
- Be supportive and encouraging about goals, NEVER pushy or guilt-tripping
- If a goal needs check-in, gently ask how it's going as part of natural conversation
- If discussing goals, help them refine with SMART criteria (Specific, Measurable, Achievable, Relevant, Time-bound)
- Celebrate progress, no matter how small

GOAL CREATION MODE:
- If the conversation includes phrases like "Goal Planning Mode" or user is discussing setting a new goal:
  1. Help them refine their goal idea into something Specific and Measurable
  2. Suggest a realistic timeline (ask "when would you like to achieve this by?")
  3. When you have enough info, propose the goal in this EXACT format:
     
     📋 **Proposed Goal:**
     **Title:** [Short goal name]
     **Description:** [One sentence description]
     **Target Date:** [Suggested date, e.g., "January 15, 2025"]
     **Check-in:** [Every 3 days / Weekly / etc.]
     
     Type "yes" to create this goal, or tell me what to change!
  4. Be encouraging and make sure they feel ownership of the goal

Keep responses to 2-3 sentences unless proposing a goal. Be warm, personal, and draw from what you know about them.''';

      // Use OpenAI provider directly for reliable wellness chat
      final openAiProvider = OpenAiProvider();
      final rawResponse = await openAiProvider.generateResponse(
        prompt: wellnessPrompt,
        systemPrompt: systemPrompt,
        modelId: 'gpt-4o-mini', // Fast, reliable model for wellness chat
      );
      
      debugPrint('✅ Wellness AI raw response received: ${rawResponse.substring(0, rawResponse.length.clamp(0, 100))}...');
      
      if (_disposed || !mounted) return;
      
      // Apply multi-pass hallucination filtering
      final filterResult = await _filterHallucinations(rawResponse);
      final response = filterResult.filteredText;
      final goalWasAutoCreated = filterResult.goalCreated;
      
      debugPrint('🔍 Hallucination filter result: goalAutoCreated=$goalWasAutoCreated');
      
      // If goal was auto-created during filtering, refresh the goals list
      if (goalWasAutoCreated) {
        final goals = GoalsService.getActiveGoals();
        if (mounted) setState(() => _goals = goals);
      }
      
      setState(() {
        _chatMessages.add({'role': 'ai', 'text': response.trim()});
        _isAiThinking = false;
      });
      
      // Scroll to bottom after adding message - focus on chat messages area
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // First scroll the chat messages to bottom
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e, stackTrace) {
      debugPrint('❌ Wellness chat error: $e');
      debugPrint('📍 Stack trace: ${stackTrace.toString().split('\n').take(5).join('\n')}');
      if (mounted) {
        setState(() {
          // Provide a more helpful fallback that still acknowledges the user
          _chatMessages.add({'role': 'ai', 'text': 'I\'m having a moment of connection issues, but I\'m still here with you. Please try again - your message matters to me.'});
          _isAiThinking = false;
        });
      }
    }
  }

  Future<void> _togglePrivacy(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    await prefs.setBool(_keyPrivateConversations, value);
    if (_disposed || !mounted) return;
    setState(() => _keepConversationsPrivate = value);
  }
  
  /// Parse goal details from AI's proposed goal format and create it
  Future<bool> _parseAndCreateGoalFromAI(String aiMessage) async {
    try {
      debugPrint('🎯 [Goal Parser] Starting to parse message (${aiMessage.length} chars)');
      debugPrint('🎯 [Goal Parser] Message preview: ${aiMessage.substring(0, aiMessage.length.clamp(0, 300))}');
      
      // Use line-by-line parsing for reliability
      final lines = aiMessage.split('\n');
      String? title;
      String? description;
      String? targetDateStr;
      String? checkInStr;
      
      for (final line in lines) {
        final trimmedLine = line.trim();
        
        // Look for Title
        if (title == null) {
          final titlePatterns = [
            RegExp(r'\*\*Title:\*\*\s*(.+)', caseSensitive: false),
            RegExp(r'Title:\s*(.+)', caseSensitive: false),
          ];
          for (final pattern in titlePatterns) {
            final match = pattern.firstMatch(trimmedLine);
            if (match != null) {
              title = match.group(1)?.trim();
              // Clean up any markdown artifacts from title
              title = title?.replaceAll(RegExp(r'\*\*'), '');
              title = title?.replaceAll(RegExp(r'^\*'), '');
              title = title?.trim();
              debugPrint('📋 [Goal Parser] Found title: $title');
              break;
            }
          }
        }
        
        // Look for Description
        if (description == null) {
          final descPatterns = [
            RegExp(r'\*\*Description:\*\*\s*(.+)', caseSensitive: false),
            RegExp(r'Description:\s*(.+)', caseSensitive: false),
          ];
          for (final pattern in descPatterns) {
            final match = pattern.firstMatch(trimmedLine);
            if (match != null) {
              description = match.group(1)?.trim();
              debugPrint('📝 [Goal Parser] Found description: $description');
              break;
            }
          }
        }
        
        // Look for Target Date
        if (targetDateStr == null) {
          final datePatterns = [
            RegExp(r'\*\*Target Date:\*\*\s*(.+)', caseSensitive: false),
            RegExp(r'Target Date:\s*(.+)', caseSensitive: false),
          ];
          for (final pattern in datePatterns) {
            final match = pattern.firstMatch(trimmedLine);
            if (match != null) {
              targetDateStr = match.group(1)?.trim();
              debugPrint('📅 [Goal Parser] Found target date: $targetDateStr');
              break;
            }
          }
        }
        
        // Look for Check-in
        if (checkInStr == null) {
          final checkInPatterns = [
            RegExp(r'\*\*Check-in:\*\*\s*(.+)', caseSensitive: false),
            RegExp(r'Check-in:\s*(.+)', caseSensitive: false),
          ];
          for (final pattern in checkInPatterns) {
            final match = pattern.firstMatch(trimmedLine);
            if (match != null) {
              checkInStr = match.group(1)?.trim();
              debugPrint('🔔 [Goal Parser] Found check-in: $checkInStr');
              break;
            }
          }
        }
      }
      
      // Parse target date
      DateTime targetDate = DateTime.now().add(const Duration(days: 30)); // Default: 30 days
      if (targetDateStr != null && targetDateStr.isNotEmpty) {
        final parsedDate = _parseFlexibleDate(targetDateStr);
        if (parsedDate != null) {
          // If date is in the past, set to 30 days from now
          if (parsedDate.isBefore(DateTime.now())) {
            debugPrint('⚠️ [Goal Parser] Target date was in past, setting to 30 days from now');
            targetDate = DateTime.now().add(const Duration(days: 30));
          } else {
            targetDate = parsedDate;
          }
        }
        debugPrint('📅 [Goal Parser] Final target date: $targetDate');
      }
      
      // Parse check-in frequency
      int checkInDays = 3; // Default: every 3 days
      if (checkInStr != null && checkInStr.isNotEmpty) {
        final lowerCheckIn = checkInStr.toLowerCase();
        if (lowerCheckIn.contains('daily') || lowerCheckIn.contains('every day')) {
          checkInDays = 1;
        } else if (lowerCheckIn.contains('weekly') || lowerCheckIn.contains('every week')) {
          checkInDays = 7;
        } else if (lowerCheckIn.contains('bi-weekly') || lowerCheckIn.contains('every 2 week')) {
          checkInDays = 14;
        } else {
          // Try to extract number of days
          final daysMatch = RegExp(r'(\d+)\s*day').firstMatch(lowerCheckIn);
          if (daysMatch != null) {
            checkInDays = int.tryParse(daysMatch.group(1) ?? '3') ?? 3;
          }
        }
        debugPrint('🔔 [Goal Parser] Check-in frequency: every $checkInDays days');
      }
      
      // FALLBACK: If no title but we have description, generate title from description
      if ((title == null || title.isEmpty) && description != null && description.isNotEmpty) {
        // Take first 50 chars of description as title, or up to first period/comma
        final firstSentence = description.split(RegExp(r'[.,!?]')).first.trim();
        title = firstSentence.length <= 50 ? firstSentence : '${firstSentence.substring(0, 47)}...';
        debugPrint('📋 Generated title from description: $title');
      }
      
      // Validate we have minimum required fields
      if (title == null || title.isEmpty) {
        debugPrint('❌ Goal parsing failed: no title found in message');
        debugPrint('❌ Full message was: $aiMessage');
        return false;
      }
      
      // Use title as description if none provided
      description ??= title;
      
      debugPrint('✅ Creating goal: "$title" - Target: $targetDate - Check-in: $checkInDays days');
      
      // Create the goal
      await GoalsService.init();
      final goal = await GoalsService.addGoal(
        title: title,
        description: description,
        targetDate: targetDate,
        checkInFrequencyDays: checkInDays,
        aiTip: 'Created via AI coaching conversation',
      );
      
      if (goal != null) {
        debugPrint('✅ Goal created successfully: ${goal.title} (ID: ${goal.id})');
        return true;
      } else {
        debugPrint('❌ GoalsService.addGoal returned null - may have hit max goals limit');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error parsing goal from AI: $e');
      debugPrint('📍 Stack: ${stackTrace.toString().split('\n').take(5).join('\n')}');
      return false;
    }
  }
  
  /// Parse flexible date formats like "January 15, 2025" or "in 30 days"
  DateTime? _parseFlexibleDate(String dateStr) {
    try {
      // Try standard formats first
      final formats = [
        DateFormat('MMMM d, yyyy'), // January 15, 2025
        DateFormat('MMM d, yyyy'),  // Jan 15, 2025
        DateFormat('yyyy-MM-dd'),   // 2025-01-15
        DateFormat('M/d/yyyy'),     // 1/15/2025
        DateFormat('d MMMM yyyy'),  // 15 January 2025
      ];
      
      for (final format in formats) {
        try {
          return format.parse(dateStr);
        } catch (_) {}
      }
      
      // Try relative dates like "in 30 days"
      final daysMatch = RegExp(r'in\s*(\d+)\s*days?', caseSensitive: false).firstMatch(dateStr);
      if (daysMatch != null) {
        final days = int.tryParse(daysMatch.group(1) ?? '30') ?? 30;
        return DateTime.now().add(Duration(days: days));
      }
      
      // Try "X weeks"
      final weeksMatch = RegExp(r'in\s*(\d+)\s*weeks?', caseSensitive: false).firstMatch(dateStr);
      if (weeksMatch != null) {
        final weeks = int.tryParse(weeksMatch.group(1) ?? '4') ?? 4;
        return DateTime.now().add(Duration(days: weeks * 7));
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Result from hallucination filtering
  /// Multi-pass hallucination filter for AI responses
  /// Pass 1: Detect false goal creation claims and auto-create if valid
  /// Pass 2: Remove AI identity leaks  
  /// Pass 3: Clean up impossible action claims
  Future<({String filteredText, bool goalCreated})> _filterHallucinations(String aiResponse) async {
    var filtered = aiResponse;
    var goalCreated = false;
    
    debugPrint('🔍 [Hallucination Filter] Starting multi-pass filtering...');
    
    // ===== PASS 1: Detect goal creation claims and auto-create if valid =====
    final goalCreatedPatterns = [
      'goal created',
      'goal has been created',
      'i\'ve created your goal',
      'i\'ve created the goal',
      'your goal is set',
      'i\'ve set up your goal',
      'goal is now set',
      'created your goal',
      'goal! i',  // Catches "Goal! I'm so proud..."
    ];
    
    final claimsGoalCreated = goalCreatedPatterns.any(
      (p) => filtered.toLowerCase().contains(p)
    );
    
    if (claimsGoalCreated) {
      debugPrint('⚠️ [Hallucination Filter] AI claims goal was created - attempting to actually create it...');
      
      // Try to parse and create the goal from this message
      final success = await _parseAndCreateGoalFromAI(filtered);
      
      if (success) {
        goalCreated = true;
        debugPrint('✅ [Hallucination Filter] Goal auto-created from AI response!');
        // Keep the message as-is since goal is now actually created
      } else {
        debugPrint('⚠️ [Hallucination Filter] Could not parse goal from AI response');
        // Replace false claim with proposal format
        // Look for goal details and reformat as proposal
        if (filtered.contains('**Title:**') || filtered.contains('Title:')) {
          // Has goal format but couldn't create - convert to proposal
          filtered = filtered.replaceAll(RegExp(r'\*\*Goal Created[!]*\*\*', caseSensitive: false), '📋 **Proposed Goal:**');
          filtered = filtered.replaceAll(RegExp(r'Goal Created[!]*', caseSensitive: false), '📋 **Proposed Goal:**');
          filtered += '\n\nType "yes" to create this goal!';
          debugPrint('🔄 [Hallucination Filter] Converted false claim to proposal format');
        }
      }
    }
    
    // ===== PASS 2: Remove AI identity leaks =====
    final identityLeakPatterns = [
      RegExp(r'As an AI[^.]*\.', caseSensitive: false),
      RegExp(r'I cannot actually[^.]*\.', caseSensitive: false),
      RegExp(r"I don't have the ability[^.]*\.", caseSensitive: false),
      RegExp(r"I'm just an AI[^.]*\.", caseSensitive: false),
      RegExp(r'As a language model[^.]*\.', caseSensitive: false),
      RegExp(r"I don't have access to[^.]*\.", caseSensitive: false),
    ];
    
    for (final pattern in identityLeakPatterns) {
      if (pattern.hasMatch(filtered)) {
        debugPrint('🧹 [Hallucination Filter] Removing AI identity leak');
        filtered = filtered.replaceAll(pattern, '');
      }
    }
    
    // ===== PASS 3: Clean up impossible action claims =====
    final impossibleActions = [
      RegExp(r"I've (?:set|scheduled|added) (?:a |an |your )?(?:reminder|alarm|notification)[^.]*\.", caseSensitive: false),
      RegExp(r"I've (?:sent|emailed|texted)[^.]*\.", caseSensitive: false),
      RegExp(r"I've (?:booked|scheduled|reserved)[^.]*(?:appointment|meeting)[^.]*\.", caseSensitive: false),
    ];
    
    for (final pattern in impossibleActions) {
      if (pattern.hasMatch(filtered)) {
        debugPrint('🧹 [Hallucination Filter] Removing impossible action claim');
        filtered = filtered.replaceAll(pattern, '');
      }
    }
    
    // Clean up any double spaces or awkward spacing from removals
    filtered = filtered.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    filtered = filtered.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    
    debugPrint('✅ [Hallucination Filter] Complete. goalCreated=$goalCreated');
    
    return (filteredText: filtered, goalCreated: goalCreated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _backgroundStart,
              _backgroundMid,
              _backgroundEnd,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: _isLoadingMetrics 
            ? const Center(child: CircularProgressIndicator(color: _accentTeal))
            : Column(
            children: [
              // Header (Reference: lines 100-176 in original)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Back Button
                      InkWell(
                        onTap: () => context.go('/chat'),
                        borderRadius: BorderRadius.circular(50),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: const Icon(LucideIcons.arrowLeft, color: Colors.white70, size: 24),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title
                      Text('Vital Balance', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                      
                      const Spacer(),
                      const SizedBox(width: 8),

                      // Weather Widget (Right Aligned - Persistent)
                      Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.cloudSun, color: _accentTeal, size: 24),
                              const SizedBox(width: 8),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text((_weatherTemp ?? '--').split(' ').first, style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                  if (_weatherHighLow != null && _weatherHighLow!.isNotEmpty)
                                    Text(_weatherHighLow!, style: GoogleFonts.inter(color: Colors.white70, fontSize: 10)),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                
              // Main content (AI Daily Focus moved to wellness chat section)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Wellness Coach Chat (Top)
                      _buildWellnessChat(),
                      
                      const SizedBox(height: 20),
                      
                      // 2. Daily Quote / Coach Says (moved up)
                      _buildWellnessCard(),
                      
                      const SizedBox(height: 16),
                      
                      // 2.5. Shareable Daily Quote Card
                      const ShareableQuoteCard(showSableObservation: false),
                      
                      // 3. Quick Mood Picker (NEW)
                      _buildQuickMoodPicker(),
                      
                      const SizedBox(height: 16),
                      
                      // 4. Privacy Settings (moved up)
                      _buildPrivacySettings(),
                      
                      const SizedBox(height: 24),

                      // 4. Metrics Section Header & Grid
                      _buildMetricsSection(),
                      
                      const SizedBox(height: 24),
                      
                      // 5. Goals Section (NEW)
                      _buildGoalsSection(),
                      
                      const SizedBox(height: 24),
                      
                      // 6. Health Profile Card
                      _buildProfileCard(),
                      
                      const SizedBox(height: 40),
                      
                      // 6. Disclaimer & Emergency
                      _buildDisclaimer(),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsSection() {
    return Column(
      children: [
        // Section Header with Add Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('Your Vitals', LucideIcons.activity),
            Row(
              children: [
                // Edit Focus Button
                Tooltip(
                  message: 'Edit which wellness items appear in your daily focus list',
                  preferBelow: false,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2D3D),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(color: Colors.white, fontSize: 12),
                  child: GestureDetector(
                    onTap: _showEditFocusItemsDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _accentLavender.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _accentLavender.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.settings2, color: _accentLavender, size: 16),
                          const SizedBox(width: 6),
                          Text('Edit', style: GoogleFonts.inter(color: _accentLavender, fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Add Metric Button
                Tooltip(
                  message: 'Track a new health metric like blood pressure, glucose, cholesterol, etc.',
                  preferBelow: false,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2D3D),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(color: Colors.white, fontSize: 12),
                  child: GestureDetector(
                    onTap: _showAddMetricDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _accentTeal.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _accentTeal.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.plus, color: _accentTeal, size: 16),
                          const SizedBox(width: 6),
                          Text('Add', style: GoogleFonts.inter(color: _accentTeal, fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Action Toolbar - placed right under Your Vitals header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _cardColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Print/Export Button with info
              _buildActionButton(
                icon: LucideIcons.printer,
                label: 'Print',
                tooltip: 'Generate a printable PDF report of all your health metrics',
                onTap: _generateReport,
              ),
              // Email/Share Button with info
              Builder(
                builder: (context) => _buildActionButton(
                  icon: LucideIcons.mail,
                  label: 'Email',
                  tooltip: 'Share your health report via email or other apps',
                  onTap: () => _shareReport(context),
                ),
              ),
              // View All Grid Button with info
              _buildActionButton(
                icon: LucideIcons.layoutGrid,
                label: 'View All',
                tooltip: 'See all your health metrics in one comprehensive view',
                onTap: _showAllMetricsSummary,
                isAccent: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        if (_isLoadingMetrics)
          const Center(child: CircularProgressIndicator(color: _accentTeal))
        else if (_metrics.isEmpty)
           Container(
             padding: const EdgeInsets.all(20),
             decoration: BoxDecoration(
               color: _cardColor,
               borderRadius: BorderRadius.circular(16),
               border: Border.all(color: Colors.white10),
             ),
             child: const Center(child: Text('No metrics tracked yet.', style: TextStyle(color: Colors.white54))),
           )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 75, // Fixed height instead of aspect ratio
            ),
            itemCount: _metrics.length,
            itemBuilder: (context, index) {
              final metric = _metrics[index];
              return _buildMetricCard(metric);
            },
          ),
      ],
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onTap,
    bool isAccent = false,
  }) {
    final color = isAccent ? _accentTeal : Colors.white70;
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      decoration: BoxDecoration(
        color: const Color(0xFF1E2D3D),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: color, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  /// Goals Section - User's active goals with progress tracking
  Widget _buildGoalsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Add button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(LucideIcons.target, color: _accentTeal, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Your Goals',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: _showAddGoalDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _accentTeal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _accentTeal.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.plus, color: _accentTeal, size: 14),
                    const SizedBox(width: 4),
                    Text('Add', style: GoogleFonts.inter(color: _accentTeal, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Goals Content
        if (_isLoadingGoals)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: CircularProgressIndicator(color: _accentTeal, strokeWidth: 2),
            ),
          )
        else if (_goals.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _accentTeal.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Icon(LucideIcons.compass, color: _accentLavender.withOpacity(0.5), size: 36),
                const SizedBox(height: 16),
                Text(
                  'No goals yet',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Let me help you set meaningful goals that work for you.',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // AI-assisted button (primary)
                GestureDetector(
                  onTap: _showAIGoalConversation,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_accentTeal, _accentLavender]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.sparkles, color: Colors.black, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Let\'s Talk About Goals',
                          style: GoogleFonts.inter(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Quick add button (secondary)
                GestureDetector(
                  onTap: _showAddGoalDialog,
                  child: Text(
                    'or add manually →',
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 12, decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              ..._goals.map((goal) => _buildGoalCard(goal)).toList(),
              // AI-assisted add option at bottom
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _showAIGoalConversation,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: _accentTeal.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _accentTeal.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.sparkles, color: _accentTeal, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Discuss a New Goal with AI',
                            style: GoogleFonts.inter(color: _accentTeal, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'I\'ll help you create a SMART goal with timeline & reminders',
                        style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// Individual goal card with progress and actions
  Widget _buildGoalCard(Goal goal) {
    final daysLeft = goal.daysRemaining;
    final isOverdue = goal.isOverdue;
    final needsCheckIn = goal.needsCheckInReminder;
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue ? Colors.red.withOpacity(0.5) : 
                 needsCheckIn ? _accentLavender.withOpacity(0.5) : 
                 _accentTeal.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and menu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  goal.title,
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(LucideIcons.moreVertical, color: Colors.white38, size: 18),
                color: const Color(0xFF2A2F3C),
                onSelected: (value) async {
                  if (value == 'edit') {
                    _showEditGoalDialog(goal);
                  } else if (value == 'complete') {
                    await GoalsService.completeGoal(goal.id);
                    setState(() => _goals = GoalsService.getActiveGoals());
                  } else if (value == 'delete') {
                    await GoalsService.deleteGoal(goal.id);
                    setState(() => _goals = GoalsService.getActiveGoals());
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'edit', child: Row(
                    children: [
                      Icon(LucideIcons.pencil, color: _accentTeal, size: 16),
                      const SizedBox(width: 8),
                      Text('Edit', style: GoogleFonts.inter(color: Colors.white)),
                    ],
                  )),
                  PopupMenuItem(value: 'complete', child: Row(
                    children: [
                      Icon(LucideIcons.checkCircle, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Text('Mark Complete', style: GoogleFonts.inter(color: Colors.white)),
                    ],
                  )),
                  PopupMenuItem(value: 'delete', child: Row(
                    children: [
                      Icon(LucideIcons.trash2, color: Colors.red, size: 16),
                      const SizedBox(width: 8),
                      Text('Delete', style: GoogleFonts.inter(color: Colors.red)),
                    ],
                  )),
                ],
              ),
            ],
          ),
          
          // Description
          if (goal.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              goal.description,
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          
          const SizedBox(height: 12),
          
          // Progress bar
          Stack(
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: goal.progressPercent / 100,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [_accentTeal, _accentLavender]),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Bottom row: progress %, days left, check-in button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '${goal.progressPercent}%',
                    style: GoogleFonts.spaceGrotesk(color: _accentTeal, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    isOverdue ? LucideIcons.alertTriangle : LucideIcons.calendar,
                    color: isOverdue ? Colors.red : Colors.white38,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isOverdue ? 'Overdue' : '$daysLeft days left',
                    style: GoogleFonts.inter(
                      color: isOverdue ? Colors.red : Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => _showGoalCheckInDialog(goal),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: needsCheckIn ? _accentLavender.withOpacity(0.2) : _accentTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.messageCircle, color: needsCheckIn ? _accentLavender : _accentTeal, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'Check In',
                        style: GoogleFonts.inter(
                          color: needsCheckIn ? _accentLavender : _accentTeal,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // AI Tip if available
          if (goal.aiTip != null && goal.aiTip!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _accentLavender.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.sparkles, color: _accentLavender, size: 12),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      goal.aiTip!,
                      style: GoogleFonts.inter(color: _accentLavender, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Dialog to add a new goal with AI assistance
  Future<void> _showAddGoalDialog() async {
    final canAdd = await GoalsService.canAddGoal();
    if (!canAdd) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum goals reached. Complete or delete a goal first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime targetDate = DateTime.now().add(const Duration(days: 30));
    int checkInFrequency = 3;

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1F2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(LucideIcons.target, color: _accentTeal),
              const SizedBox(width: 10),
              Text('New Goal', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Goal title (e.g., Exercise more)',
                    hintStyle: TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Description (optional)',
                    hintStyle: TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Target Date', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: targetDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() => targetDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.calendar, color: _accentTeal, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMM d, yyyy').format(targetDate),
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Check-in Reminder', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButton<int>(
                  value: checkInFrequency,
                  dropdownColor: const Color(0xFF2A2F3C),
                  style: GoogleFonts.inter(color: Colors.white),
                  underline: Container(),
                  items: [
                    DropdownMenuItem(value: 1, child: Text('Daily')),
                    DropdownMenuItem(value: 3, child: Text('Every 3 days')),
                    DropdownMenuItem(value: 7, child: Text('Weekly')),
                    DropdownMenuItem(value: 14, child: Text('Every 2 weeks')),
                  ],
                  onChanged: (v) => setDialogState(() => checkInFrequency = v ?? 3),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                await GoalsService.addGoal(
                  title: titleController.text.trim(),
                  description: descController.text.trim(),
                  targetDate: targetDate,
                  checkInFrequencyDays: checkInFrequency,
                );
                if (mounted) {
                  setState(() => _goals = GoalsService.getActiveGoals());
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentTeal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Create Goal', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog to edit an existing goal
  Future<void> _showEditGoalDialog(Goal goal) async {
    final titleController = TextEditingController(text: goal.title);
    final descController = TextEditingController(text: goal.description);
    DateTime targetDate = goal.targetDate;
    int checkInFrequency = goal.checkInFrequencyDays;

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1F2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(LucideIcons.pencil, color: _accentTeal),
              const SizedBox(width: 10),
              Text('Edit Goal', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Goal title',
                    hintStyle: TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Description',
                    hintStyle: TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Target Date', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: targetDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() => targetDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.calendar, color: _accentTeal, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMM d, yyyy').format(targetDate),
                          style: GoogleFonts.inter(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Check-in Reminder', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                DropdownButton<int>(
                  value: checkInFrequency,
                  dropdownColor: const Color(0xFF2A2F3C),
                  style: GoogleFonts.inter(color: Colors.white),
                  underline: Container(),
                  items: [
                    DropdownMenuItem(value: 1, child: Text('Daily')),
                    DropdownMenuItem(value: 3, child: Text('Every 3 days')),
                    DropdownMenuItem(value: 7, child: Text('Weekly')),
                    DropdownMenuItem(value: 14, child: Text('Every 2 weeks')),
                  ],
                  onChanged: (v) => setDialogState(() => checkInFrequency = v ?? 3),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                final updated = goal.copyWith(
                  title: titleController.text.trim(),
                  description: descController.text.trim(),
                  targetDate: targetDate,
                  checkInFrequencyDays: checkInFrequency,
                );
                await GoalsService.updateGoal(updated);
                if (mounted) {
                  setState(() => _goals = GoalsService.getActiveGoals());
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentTeal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Save Changes', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  /// AI-assisted goal conversation - uses wellness chat to discuss and create goals
  Future<void> _showAIGoalConversation() async {
    // Pre-populate the chat with a goal discussion prompt
    if (mounted) {
      setState(() {
        // Add AI message to start the conversation with clear explanation
        _chatMessages.add({
          'role': 'ai',
          'text': '🎯 **Goal Planning Mode**\n\n'
                  'Let\'s work together to create a meaningful goal! Here\'s what we\'ll do:\n\n'
                  '1. You tell me what you\'ve been wanting to work on\n'
                  '2. We\'ll discuss it and make it SMART (Specific, Measurable, Achievable)\n'
                  '3. I\'ll help you set a realistic timeline and check-in schedule\n\n'
                  'So, what\'s something you\'ve been wanting to improve or accomplish?',
        });
        _hideChatMessages = false;
      });
      
      // Scroll the chat messages to show the new AI message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  /// Create goal from AI conversation (can be called by AI)
  Future<void> createGoalFromAI({
    required String title,
    required String description,
    required DateTime targetDate,
    int checkInFrequencyDays = 3,
  }) async {
    final goal = await GoalsService.addGoal(
      title: title,
      description: description,
      targetDate: targetDate,
      checkInFrequencyDays: checkInFrequencyDays,
    );
    
    if (goal != null && mounted) {
      setState(() => _goals = GoalsService.getActiveGoals());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Goal created: ${goal.title}'),
          backgroundColor: _accentTeal,
        ),
      );
    }
  }

  /// Dialog for checking in on goal progress
  Future<void> _showGoalCheckInDialog(Goal goal) async {
    final noteController = TextEditingController();
    int progress = goal.progressPercent;

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1F2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Check In: ${goal.title}', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How is your progress?', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: progress.toDouble(),
                      min: 0,
                      max: 100,
                      activeColor: _accentTeal,
                      inactiveColor: Colors.white.withOpacity(0.1),
                      onChanged: (v) => setDialogState(() => progress = v.round()),
                    ),
                  ),
                  Text('$progress%', style: GoogleFonts.spaceGrotesk(color: _accentTeal, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'How are you feeling about this goal?',
                  hintStyle: TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                await GoalsService.addCheckIn(
                  goalId: goal.id,
                  note: noteController.text.trim(),
                  progressPercent: progress,
                );
                if (mounted) {
                  setState(() => _goals = GoalsService.getActiveGoals());
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentTeal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Save', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    // If profile is empty/loading, show skeleton or CTA?
    // We'll show a summary card.
    
    // Calculate age from DOB
    String age = '-';
    final dobString = _profile['dob'];
    if (dobString != null && dobString.isNotEmpty) {
      try {
        final dob = DateTime.parse(dobString);
        final now = DateTime.now();
        int calculatedAge = now.year - dob.year;
        if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
          calculatedAge--;
        }
        age = calculatedAge.toString();
      } catch (e) {
        age = '-';
      }
    }
    
    final sex = _profile['sex'] ?? '-';
    final height = _profile['height'] ?? '-';
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.user, color: _accentTeal, size: 20),
                  const SizedBox(width: 8),
                  Text('Health Profile', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              IconButton(
                icon: const Icon(LucideIcons.edit2, color: Colors.white54, size: 18),
                onPressed: () => _showProfileDialog(isFirstTime: false),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Edit Profile',
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Grid layout for compact view
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildProfileItem('Age', age),
              _buildProfileItem('Sex', sex),
              _buildProfileItem('Height', height),
              _buildProfileItem('Race', _profile['race'] ?? '-'),
              _buildProfileItem('Smoking', _profile['smoking'] ?? '-'),
              _buildProfileItem('Drinking', _profile['drinking'] ?? '-'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.inter(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Future<void> _checkProfile() async {
    final profile = await VitalBalanceService.getProfile();
    // If dob (date of birth) or sex is missing, assume first time setup needed
    // Note: We store 'dob' not 'age' since age changes yearly
    if (profile['dob'] == null || profile['sex'] == null) {
      if (mounted) _showProfileDialog(isFirstTime: true);
    }
  }

  Widget _buildDailyFocus() {
    // Mock logic for Focus items - In real app, this comes from AI/Orchestrator based on gaps
    final focusItems = [
      {'icon': LucideIcons.droplets, 'title': 'Hydrate', 'desc': 'Drink 2 more glasses', 'metric': 'water'},
      {'icon': LucideIcons.footprints, 'title': 'Move', 'desc': 'Take a 10m walk', 'metric': 'steps'},
      {'icon': LucideIcons.brainCircuit, 'title': 'Reflect', 'desc': 'Log your mood', 'metric': 'mood'},
    ];

    if (_latestValues['water'] != null && (double.tryParse(_latestValues['water']!.split(' ')[0]) ?? 0) > 60) {
       focusItems.removeWhere((i) => i['metric'] == 'water');
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
               Icon(LucideIcons.sparkles, color: _accentLavender, size: 16),
               const SizedBox(width: 8),
               Text('AI SUGGESTED FOCUS', style: GoogleFonts.inter(color: _accentLavender, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 125, // Increased height to prevent overflow
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: focusItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = focusItems[index];
                final metricId = item['metric'] as String;
                final metric = _metrics.firstWhere((m) => m.id == metricId, orElse: () => _metrics.first);
                
                return GestureDetector(
                  onTap: () => _showMetricDetailsDialog(metric),
                  child: Container(
                    width: 140,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _accentLavender.withOpacity(0.3)),
                      boxShadow: [
                         BoxShadow(color: _accentLavender.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: _accentLavender.withOpacity(0.1), shape: BoxShape.circle),
                          child: Icon(item['icon'] as IconData, color: _accentLavender, size: 20),
                        ),
                        const SizedBox(height: 12),
                        Text(item['title'] as String, style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(item['desc'] as String, style: GoogleFonts.inter(color: Colors.white54, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog({required bool isFirstTime}) {
    final parentContext = context; // Capture parent context
    showDialog(
      context: context,
      barrierDismissible: !isFirstTime, // Force setup if first time? Maybe let them cancel.
      builder: (dialogContext) => _ProfileDialog(
        currentProfile: _profile,
        onSave: (newProfile) async {
          await VitalBalanceService.updateProfile(newProfile);
          if (mounted) {
            setState(() => _profile = newProfile);
            _refreshMetrics();
            // Show success feedback (try-catch to handle edge cases)
            try {
              ScaffoldMessenger.of(parentContext).showSnackBar(
                 const SnackBar(content: Text('Profile Updated', style: TextStyle(color: Colors.white)), backgroundColor: Colors.black87),
              );
            } catch (e) {
              debugPrint('SnackBar display skipped: $e');
            }
          }
        },
      ),
    );
  }
  Widget _buildMetricCard(HealthMetric metric) {
    return GestureDetector(
      onTap: () => _showMetricDetailsDialog(metric),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _accentTeal.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(VitalBalanceService.getIconData(metric.iconName), color: _accentTeal, size: 14),
                  Icon(LucideIcons.plus, color: Colors.white24, size: 10),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _latestValues[metric.id] ?? '--',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    metric.name.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 7,
                      letterSpacing: 0.3,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }




  // --- Dialogs ---

  Future<void> _showAddMetricDialog() async {
    final nameController = TextEditingController();
    final unitController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF15202B),
        title: Text('Add New Metric', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             TextField(
               controller: nameController,
               style: const TextStyle(color: Colors.white),
               decoration: const InputDecoration(
                 labelText: 'Metric Name (e.g. Glucose)',
                 labelStyle: TextStyle(color: Colors.white54),
                 enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
               ),
             ),
             const SizedBox(height: 16),
             TextField(
               controller: unitController,
               style: const TextStyle(color: Colors.white),
               decoration: const InputDecoration(
                 labelText: 'Unit (e.g. mg/dL)',
                 labelStyle: TextStyle(color: Colors.white54),
                 enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
               ),
             ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Add', style: TextStyle(color: _accentTeal, fontWeight: FontWeight.bold)),
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await VitalBalanceService.addMetric(nameController.text, unitController.text);
                if (mounted) {
                  Navigator.pop(context);
                  _refreshMetrics();
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showMetricDetailsDialog(HealthMetric metric) async {
    final valueController = TextEditingController();
    final history = await VitalBalanceService.getEntries(metric.id);
    
    if (!mounted) return;

    // Check for specialized input types
    final bool useFaceSelector = ['mood', 'energy', 'stress', 'pain'].contains(metric.id);
    final bool useWaterSelector = metric.id == 'water';
    
    // Steps Special Handling
    if (metric.id == 'steps') {
      await _showStepsDialog(metric);
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF15202B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _accentTeal.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Icon(VitalBalanceService.getIconData(metric.iconName), color: _accentTeal, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(metric.name, style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        Text(metric.unit.toUpperCase(), style: GoogleFonts.inter(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ],
                    ),
                  ),
                  IconButton(
                     icon: const Icon(LucideIcons.x, color: Colors.white38),
                     onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const SizedBox(height: 24),

              // Question Context
              Text(
                useWaterSelector 
                  ? "Add to your daily hydration:" 
                  : (useFaceSelector 
                      ? "How is your ${metric.id} right now?" 
                      : "${_getMetricQuestion(metric)} (Now):"),
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),

              // Input Area
              if (useFaceSelector)
                _buildFaceSelector((val) {
                  Navigator.pop(context); // Close dialog first
                  _submitMetricValue(metric, val); // Then submit
                })
              else if (useWaterSelector)
                _buildWaterSelector((val) {
                  Navigator.pop(context); // Close dialog first
                  _submitMetricValue(metric, val); // Then submit
                })
              else
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: valueController,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(color: Colors.white12),
                          suffixText: metric.unit,
                          suffixStyle: GoogleFonts.inter(color: _accentTeal, fontSize: 16, fontWeight: FontWeight.w600),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                         final val = double.tryParse(valueController.text);
                         if (val != null) _submitMetric(metric, val);
                      },
                      borderRadius: BorderRadius.circular(50),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(color: _accentTeal, shape: BoxShape.circle),
                        child: const Icon(LucideIcons.check, color: Color(0xFF0D1B2A), size: 24),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 32),
              
              // Recent History with fl_chart - ENHANCED
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text('Recent History', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
                   // Date range selector
                   Container(
                     padding: const EdgeInsets.all(2),
                     decoration: BoxDecoration(
                       color: Colors.white.withOpacity(0.05),
                       borderRadius: BorderRadius.circular(8),
                     ),
                     child: Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         _buildRangeChip('7d', true),
                         _buildRangeChip('14d', false),
                         _buildRangeChip('30d', false),
                       ],
                     ),
                   ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Stats row (min/max/avg)
              if (history.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('Low', history.isEmpty ? '-' : history.map((e) => e.value).reduce((a, b) => a < b ? a : b).toStringAsFixed(1), Colors.redAccent),
                      _buildStatItem('Avg', history.isEmpty ? '-' : (history.map((e) => e.value).reduce((a, b) => a + b) / history.length).toStringAsFixed(1), Colors.amber),
                      _buildStatItem('High', history.isEmpty ? '-' : history.map((e) => e.value).reduce((a, b) => a > b ? a : b).toStringAsFixed(1), _accentTeal),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              
              // Enhanced chart container
              Container(
                height: 180, // Increased from 120 for better visualization
                width: double.infinity,
                padding: const EdgeInsets.only(right: 16, top: 12, bottom: 8, left: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _accentTeal.withOpacity(0.1)),
                ),
                child: history.isEmpty 
                  ? Center(child: Text('No data yet - log your first entry above!', style: GoogleFonts.inter(color: Colors.white24)))
                  : _buildFlChart(history.take(7).toList().reversed.toList(), metric),
              ),
              const SizedBox(height: 8),
              Text('Tap data points for details', style: GoogleFonts.inter(color: Colors.white24, fontSize: 10, fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitMetric(HealthMetric metric, double val) async {
     await VitalBalanceService.addEntry(metric.id, val);
     if (!mounted) return;
     
     // Save last wellness update timestamp for main chat awareness
     final prefs = await SharedPreferences.getInstance();
     final now = DateTime.now();
     final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
     await prefs.setString('last_wellness_update_date', today);
     
     // Capture parent context before closing dialog
     final parentContext = context;
     Navigator.pop(context);
     _refreshMetrics();
     if (metric.id == 'sleep' && val < 6.0) _showAiWellnessCheck(metric, val);
     
     // Use parent context for snackbar (dialog context is now invalid)
     if (mounted) {
       ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(content: Text('Logged ${metric.name}: $val ${metric.unit}', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.black87, duration: const Duration(seconds: 1))
       );
     }
  }
  
  /// Submit metric value without closing dialog (dialog already closed by caller)
  Future<void> _submitMetricValue(HealthMetric metric, double val) async {
     await VitalBalanceService.addEntry(metric.id, val);
     if (!mounted) return;
     _refreshMetrics();
     if (metric.id == 'sleep' && val < 6.0) _showAiWellnessCheck(metric, val);
     ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logged ${metric.name}: $val ${metric.unit}', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.black87, duration: const Duration(seconds: 1))
     );
  }

  Widget _buildFaceSelector(Function(double) onSelected) {
    // Using high-quality system emojis for "Best in Class" feel on native devices
    final faces = [
      {'emoji': '😫', 'val': 2.0, 'label': 'Struggling', 'color': Colors.redAccent},
      {'emoji': '😕', 'val': 5.0, 'label': 'Okay', 'color': Colors.amber},
      {'emoji': '🙂', 'val': 8.0, 'label': 'Good', 'color': Colors.lightGreen},
      {'emoji': '🤩', 'val': 10.0, 'label': 'Thriving', 'color': _accentTeal},
    ];
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: faces.map((f) {
        return GestureDetector(
          onTap: () => onSelected(f['val'] as double),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: (f['color'] as Color).withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: (f['color'] as Color).withOpacity(0.3)),
                ),
                alignment: Alignment.center,
                child: Text(
                  f['emoji'] as String,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
              const SizedBox(height: 8),
              Text(f['label'] as String, style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Build enhanced chart using fl_chart
  Widget _buildFlChart(List<MetricEntry> entries, HealthMetric metric) {
    if (entries.isEmpty) return const SizedBox();
    
    // Prepare data points
    final spots = <FlSpot>[];
    for (var i = 0; i < entries.length; i++) {
      spots.add(FlSpot(i.toDouble(), entries[i].value));
    }
    
    // Calculate min/max for better display
    final values = entries.map((e) => e.value).toList();
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.2; // 20% padding
    
    return LineChart(
      LineChartData(
        minY: minY > 0 ? (minY - padding).clamp(0, minY) : minY - padding,
        maxY: maxY + padding,
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 4 == 0 ? 1 : (maxY - minY) / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withOpacity(0.05),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < entries.length) {
                  final date = entries[index].timestamp;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      DateFormat('E').format(date)[0], // First letter of day
                      style: GoogleFonts.inter(color: Colors.white30, fontSize: 9),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => const Color(0xFF1A2A35),
            tooltipBorderRadius: BorderRadius.circular(8),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.spotIndex;
                final entry = entries[index];
                final dateStr = DateFormat('MMM d').format(entry.timestamp);
                return LineTooltipItem(
                  '${entry.value.toStringAsFixed(1)} ${metric.unit}\n$dateStr',
                  GoogleFonts.inter(color: _accentTeal, fontSize: 12, fontWeight: FontWeight.w600),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: _accentTeal,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 4,
                color: _accentTeal,
                strokeWidth: 2,
                strokeColor: const Color(0xFF15202B),
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _accentTeal.withOpacity(0.3),
                  _accentTeal.withOpacity(0.0),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Build range selector chip for chart
  Widget _buildRangeChip(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        // TODO: Implement dynamic range switching with state
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label range selected', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.black87, duration: const Duration(milliseconds: 800))
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? _accentTeal.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: isSelected ? _accentTeal : Colors.white38,
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  /// Build stat item for chart (min/max/avg)
  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.white38, fontSize: 9)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.inter(color: color, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildWaterSelector(Function(double) onSelected) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _waterButton(8, 'Small\n(8oz)', '🥛'),
        _waterButton(16, 'Medium\n(16oz)', '🥤'),
        _waterButton(32, 'Large\n(32oz)', '💧'), 
      ],
    );
  }

  Widget _waterButton(double amount, String label, String emoji) {
    return GestureDetector(
      onTap: () => _submitMetric(_metrics.firstWhere((m) => m.id == 'water'), amount),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 90,
            padding: const EdgeInsets.symmetric(vertical: 12),
             decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                Text('+${amount.toInt()}', style: GoogleFonts.spaceGrotesk(color: Colors.blue[200], fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Future<void> _showAiWellnessCheck(HealthMetric metric, double value) async {
    // Simple AI logic for now - could be connected to ModelOrchestrator later for dynamic advice
    String title = 'Wellness Check';
    String message = "I noticed you logged a low value for ${metric.name}. Is everything okay?";
    String tip = "";
    
    if (metric.id == 'sleep') {
      title = 'Sleep Check-in';
      message = "You only got $value hours of sleep. That's below the recommended 7-9 hours.";
      tip = "💡 Tip: Try a 20-minute power nap today to recharge, but avoid sleeping late in the afternoon so you can rest better tonight.";
    }
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF15202B), // Dark theme
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(LucideIcons.sparkles, color: _accentLavender),
            const SizedBox(width: 8),
            Text(title, style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: GoogleFonts.inter(color: Colors.white70)),
            if (tip.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _accentTeal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _accentTeal.withOpacity(0.3)),
                ),
                child: Text(tip, style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            child: const Text('I\'m Okay'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Chat with Coach', style: TextStyle(color: _accentTeal, fontWeight: FontWeight.bold)),
            onPressed: () {
               Navigator.pop(context);
               context.go('/chat'); // Encourage talking about it
            },
          ),
        ],
      ),
    );
  }

  String _getMetricQuestion(HealthMetric metric) {
    switch (metric.id) {
      case 'energy': return 'How is your energy level today? (1-10)';
      case 'mood': return 'How are you feeling right now? (1-10)';
      case 'sleep': return 'How many hours did you sleep last night?';
      case 'stress': return 'How high is your stress level? (1-10)';
      case 'pain': return 'What is your pain level? (0-10)';
      case 'water': return 'How much water have you drunk?';
      case 'weight': return 'What is your current weight?';
      default: return 'Log new value for ${metric.name}:';
    }
  }

  String _getMetricHint(HealthMetric metric) {
     if (metric.id == 'energy' || metric.id == 'mood' || metric.id == 'stress') return 'e.g. 7';
     if (metric.id == 'sleep') return 'e.g. 7.5';
     return 'Enter value';
  }

  Future<void> _shareReport(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preparing Export...', style: TextStyle(color: Colors.white)), backgroundColor: Colors.black87, duration: Duration(milliseconds: 800))
    );
    
    final metrics = await VitalBalanceService.getMetrics();
    final buffer = StringBuffer();
    // Use Builder context for RenderBox if valid, otherwise fallback
    final box = context.findRenderObject() as RenderBox?;
    
    buffer.writeln('Vital Balance Report');
    buffer.writeln('Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
    buffer.writeln('\n--- Metrics ---\n');

    for (var m in metrics) {
      final entries = await VitalBalanceService.getEntries(m.id);
      if (entries.isNotEmpty) {
        // Sort by date (newest first)
        final sorted = List.of(entries)..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        final latest = sorted.first;
        buffer.writeln('${m.name}: ${latest.value} ${m.unit} (Latest)');
        
        // Add a few more recent entries if available
        if (sorted.length > 1) {
           buffer.writeln('  History:');
           for (var i = 1; i < sorted.length && i < 6; i++) {
             buffer.writeln('  - ${sorted[i].value} ${m.unit} (${DateFormat('MM/dd').format(sorted[i].timestamp)})');
           }
        }
        buffer.writeln('');
      } else {
        buffer.writeln('${m.name}: No Data\n');
      }
    }
    
    try {
      if (box != null) {
        await Share.share(
          buffer.toString(),
          subject: 'Vital Balance Report - ${DateFormat('MM/dd').format(DateTime.now())}',
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
        );
      } else {
         // Fallback usually not needed if context is good
         await Share.share(
          buffer.toString(),
          subject: 'Vital Balance Report',
        );
      }
    } catch (e) {
      debugPrint('Share error: $e');
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Share failed: $e', style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.black87,
            ),
         );
      }
    }
  }

  Future<void> _generateReport() async {
    final pdf = pw.Document();
    
    // Fetch all data
    final metrics = await VitalBalanceService.getMetrics();
    final data = <HealthMetric, List<MetricEntry>>{};
    
    for (var m in metrics) {
      final entries = await VitalBalanceService.getEntries(m.id);
      if (entries.isNotEmpty) {
        data[m] = entries;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Vital Balance Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text(DateFormat('MMM d, yyyy').format(DateTime.now())),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Paragraph(text: 'Health Metrics for $_archetypeId User' ), // Placeholder name
            pw.SizedBox(height: 20),
            
            ...data.entries.map((entry) {
              final metric = entry.key;
              final history = entry.value;
              
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                   pw.Container(
                     padding: const pw.EdgeInsets.symmetric(vertical: 5),
                     decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 1))),
                     child: pw.Row(children: [
                        pw.Text(metric.name.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Spacer(),
                         pw.Text('Last: ${history.first.value} ${metric.unit}'),
                     ]),
                   ),
                   pw.SizedBox(height: 5),
                   // Table of last 5 entries
                   pw.Table.fromTextArray(
                     context: context,
                     data: <List<String>>[
                       <String>['Date', 'Value', 'Note'],
                       ...history.take(10).map((e) => [
                         DateFormat('MM/dd HH:mm').format(e.timestamp),
                         '${e.value} ${metric.unit}',
                         e.note ?? ''
                       ]),
                     ],
                     headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                     cellStyle: const pw.TextStyle(fontSize: 10),
                     cellAlignments: {
                       0: pw.Alignment.centerLeft,
                       1: pw.Alignment.centerRight,
                       2: pw.Alignment.centerLeft,
                     },
                   ),
                   pw.SizedBox(height: 15),
                ],
              );
            }).toList(),
            
            if (data.isEmpty) pw.Paragraph(text: 'No data recorded available.'),
            
            pw.SizedBox(height: 30),
            pw.Footer(title: pw.Text('Generated by AELIANA AI')),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // --- Widgets from original ---

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _accentTeal, size: 20),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
  
  Widget _buildWellnessChat() {
    return Container(
      key: _chatSectionKey,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentTeal.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: _accentTeal.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with avatar
          Row(
            children: [
              UnifiedAvatarWidget(
                size: 56,
                showStatus: true,
                statusText: 'Observing',
                onTap: () {
                  if (_keepConversationsPrivate) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vital Balance is currently Private.', style: TextStyle(color: Colors.white)),
                        backgroundColor: Colors.black87,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Your companion is observing your wellness.', style: TextStyle(color: Colors.white)),
                        backgroundColor: Colors.black87,
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Wellness Coach', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Vitality Strategist Mode', style: GoogleFonts.inter(color: _accentTeal, fontSize: 12)),
                  ],
                ),
              ),
              Icon(LucideIcons.sparkles, color: _accentTeal, size: 20),
            ],
          ),
          
          // AI Suggested Focus - Compact bullet points
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _accentLavender.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _accentLavender.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.sparkles, color: _accentLavender, size: 12),
                    const SizedBox(width: 6),
                    Text('AI Focus:', style: GoogleFonts.inter(color: _accentLavender, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ],
                ),
                // Stale metrics reminder
                if (_daysSinceUpdate >= 2) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: _accentLavender.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _accentLavender.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.heartHandshake, color: _accentLavender, size: 12),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _daysSinceUpdate >= 999 
                              ? "Hey, take a sec to check in with yourself. 💜 Scroll down to Vitals and log how you're doing!"
                              : "Hey, it's been $_daysSinceUpdate days since your last check-in. How are you really doing? 💜",
                            style: GoogleFonts.inter(color: _accentLavender, fontSize: 10, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                if (_isLoadingFocus)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: _accentLavender)),
                        const SizedBox(width: 8),
                        Text('Analyzing your wellness...', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  )
                else ...[
                  // Goal check-in reminders (before regular focus items)
                  ..._goals.where((g) => g.needsCheckInReminder).take(2).map((goal) => 
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: GestureDetector(
                        onTap: () => _showGoalCheckInDialog(goal),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: _accentTeal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _accentTeal.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(LucideIcons.target, color: _accentTeal, size: 14),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Goal Check-In',
                                      style: GoogleFonts.inter(color: _accentTeal, fontSize: 10, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      'How\'s "${goal.title}" going? (${goal.daysSinceLastCheckIn}d ago)',
                                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(LucideIcons.chevronRight, color: Colors.white38, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Regular AI focus items
                  ..._aiFocusItems.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _buildFocusBullet(
                      item['title'] as String,
                      item['description'] as String,
                      item['icon'] as IconData,
                      item['metricId'] as String,
                    ),
                  )),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          // Chat input
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _accentTeal.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatInputController,
                    textInputAction: TextInputAction.send, // Enter submits
                    minLines: 1,
                    maxLines: 4, // Still allows expansion via paste/long text
                    decoration: const InputDecoration(
                      hintText: "What's on your mind?",
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (text) {
                      if (text.isNotEmpty) {
                        _sendWellnessMessage(text);
                        _chatInputController.clear();
                        setState(() => _hideChatMessages = false); // Show messages when user sends
                      }
                    },
                  ),
                ),
                IconButton(
                  onPressed: () {
                     final text = _chatInputController.text;
                     if (text.isNotEmpty) {
                       _sendWellnessMessage(text);
                       _chatInputController.clear();
                     } else {
                       _sendWellnessMessage('General wellness check');
                     }
                  },
                  icon: const Icon(LucideIcons.send, color: _accentTeal),
                ),
              ],
            ),
          ),
          
          // AI Response Area - Always visible
          const SizedBox(height: 16),
          
          // Clear screen button row - centered
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Bold, visible Clear button
              GestureDetector(
                onTap: () => setState(() => _hideChatMessages = !_hideChatMessages),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _hideChatMessages ? _accentTeal.withOpacity(0.2) : const Color(0xFF2A3A4A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _hideChatMessages ? _accentTeal : Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _hideChatMessages ? LucideIcons.eye : LucideIcons.eraser,
                        color: _hideChatMessages ? _accentTeal : Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _hideChatMessages ? 'Show Chat' : 'Clear txt Screen',
                        style: GoogleFonts.inter(
                          color: _hideChatMessages ? _accentTeal : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(minHeight: 100, maxHeight: 420), // Increased for more message visibility
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Reduced padding
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _accentTeal.withOpacity(0.2)),
            ),
            clipBehavior: Clip.antiAlias, // Smooth clipping at edges
            child: (_chatMessages.isEmpty && !_isAiThinking) || _hideChatMessages
                ? const SizedBox(height: 60) // Empty placeholder
                : ListView.builder(
                    controller: _chatScrollController,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    physics: const ClampingScrollPhysics(), // Use clamping for better nested scroll behavior
                    itemCount: _chatMessages.length + (_isAiThinking ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Show typing indicator as last item when thinking
                      if (index == _chatMessages.length && _isAiThinking) {
                        // Typing indicator
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _accentTeal.withOpacity(0.2),
                                ),
                                child: const Icon(LucideIcons.sparkles, color: _accentTeal, size: 14),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Thinking...',
                                style: GoogleFonts.inter(color: _accentTeal, fontStyle: FontStyle.italic, fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      final msg = _chatMessages[index];
                      final isUser = msg['role'] == 'user';
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            if (!isUser) ...[
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _accentTeal.withOpacity(0.2),
                                ),
                                child: const Icon(LucideIcons.sparkles, color: _accentTeal, size: 14),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isUser 
                                    ? _accentTeal.withOpacity(0.2) 
                                    : Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                                    bottomRight: Radius.circular(isUser ? 4 : 16),
                                  ),
                                ),
                                child: Text(
                                  msg['text'] ?? '',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                            if (isUser) const SizedBox(width: 8),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

    Widget _buildQuickPrompt(String label, IconData icon) {
    return GestureDetector(
      onTap: () => _sendWellnessMessage(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _accentTeal.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _accentTeal.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _accentTeal, size: 14),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(color: _accentTeal, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
  
  /// Build compact AI Focus bullet that links to a metric
  Widget _buildFocusBullet(String title, String description, IconData icon, String metricId) {
    return GestureDetector(
      onTap: () {
        // Special handling for Dreams - navigates to journal with Dream Log suggestion
        if (metricId == 'dreams') {
          context.go('/journal');
          // Show helpful message after navigation
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Text('💭', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Tap + and choose "Dream Log" template to record your dreams!'),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFFB8A9D9),
                duration: const Duration(seconds: 4),
              ),
            );
          });
          return;
        }
        
        // Find and open the metric dialog
        final metric = _metrics.firstWhere(
          (m) => m.id == metricId,
          orElse: () => _metrics.isNotEmpty ? _metrics.first : HealthMetric(id: metricId, name: title, unit: '', iconName: 'activity'),
        );
        _showMetricDetailsDialog(metric);
      },
      child: Row(
        children: [
          Icon(icon, color: _accentLavender, size: 14),
          const SizedBox(width: 8),
          Text(
            '• $title',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              description,
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(LucideIcons.chevronRight, color: _accentLavender.withOpacity(0.5), size: 14),
        ],
      ),
    );
  }
  
  void _startWellnessChat([String prompt = 'Hi']) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: ChatPage(initialPrompt: prompt == 'Hi' ? null : prompt),
        ),
      ),
    );
  }



  Widget _buildWellnessCard() {
    // Default quotes (fallback)
    final defaultQuotes = [
      "Every small step counts. Your wellness journey is uniquely yours.",
      "You are stronger than you know.",
      "Rest is productive.",
      "Healing isn't linear. Be patient with yourself.",
      "Progress, not perfection.",
      "You're doing better than you think.",
    ];
    
    // Time-based greetings
    final hour = DateTime.now().hour;
    final timeContext = hour < 12 ? 'morning' : hour < 17 ? 'afternoon' : 'evening';
    
    String todaysWisdom;
    
    // Check recent chat messages for emotional context
    final recentUserMessages = _chatMessages.where((m) => m['role'] == 'user').toList();
    bool seemsStressed = false;
    bool seemsPositive = false;
    
    if (recentUserMessages.isNotEmpty) {
      final recentText = recentUserMessages.take(3).map((m) => m['text'] ?? '').join(' ').toLowerCase();
      seemsStressed = recentText.contains('stress') || recentText.contains('anxious') || 
                      recentText.contains('overwhelm') || recentText.contains('tired') ||
                      recentText.contains('worry') || recentText.contains('hard');
      seemsPositive = recentText.contains('good') || recentText.contains('great') ||
                      recentText.contains('better') || recentText.contains('happy') ||
                      recentText.contains('excited');
    }
    
    // Priority: Recent mood from chat > Goals > Defaults
    if (seemsStressed) {
      // Supportive message for stressed user
      final stressResponses = [
        "Hey, take a breath. Whatever you're facing, you don't have to figure it all out today. 💜",
        "It's okay to feel overwhelmed sometimes. Be gentle with yourself this $timeContext.",
        "You're carrying a lot right now. Remember to rest when you need to. 🌿",
      ];
      todaysWisdom = stressResponses[DateTime.now().minute % stressResponses.length];
    } else if (seemsPositive) {
      // Celebrate positive energy
      final positiveResponses = [
        "Love to see you in good spirits! Keep riding that wave. 🌟",
        "Your positive energy is contagious! What a beautiful $timeContext to be you.",
        "You're glowing today! Keep doing whatever you're doing. ✨",
      ];
      todaysWisdom = positiveResponses[DateTime.now().minute % positiveResponses.length];
    } else if (_goals.isNotEmpty) {
      // Goal-based wisdom - rephrase for natural reading
      final goalsNeedingCheckIn = _goals.where((g) => g.needsCheckInReminder).toList();
      final overdueGoals = _goals.where((g) => g.isOverdue).toList();
      final highProgressGoals = _goals.where((g) => g.progressPercent >= 70).toList();
      
      if (overdueGoals.isNotEmpty) {
        final goal = overdueGoals.first;
        // Shorten title if too long for natural reading
        final shortTitle = goal.title.length > 25 ? '${goal.title.substring(0, 25)}...' : goal.title;
        todaysWisdom = "It's okay if '$shortTitle' is taking longer than expected. What matters is that you keep moving forward. 💜";
      } else if (goalsNeedingCheckIn.isNotEmpty) {
        final goal = goalsNeedingCheckIn.first;
        todaysWisdom = "How's your goal coming along? Even small progress counts! Check in when you're ready. 🌱";
      } else if (highProgressGoals.isNotEmpty) {
        final goal = highProgressGoals.first;
        todaysWisdom = "You're ${goal.progressPercent}% of the way there! Keep that momentum going! 🌟";
      } else {
        // General goal encouragement - no awkward title insertion
        todaysWisdom = "You've got active goals—that takes courage. Keep showing up for yourself. 💪";
      }
    } else {
      // Time-aware default quotes
      if (hour < 8) {
        todaysWisdom = "Good morning. Today is a fresh start—take it one moment at a time. ☀️";
      } else if (hour >= 21) {
        todaysWisdom = "Winding down for the night? You made it through another day. Rest well. 🌙";
      } else {
        final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
        todaysWisdom = defaultQuotes[dayOfYear % defaultQuotes.length];
      }
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accentTeal.withOpacity(0.2),
            _accentLavender.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentTeal.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.quote, color: _accentTeal, size: 24),
              const SizedBox(width: 12),
              Text('Your Coach Says', style: GoogleFonts.inter(color: _accentTeal, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Text('"$todaysWisdom"', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontStyle: FontStyle.italic, height: 1.5)),
        ],
      ),
    );
  }
  /// Quick mood logging with emoji icons
  Widget _buildQuickMoodPicker() {
    final moods = [
      {'emoji': '😊', 'value': 9, 'label': 'Great'},
      {'emoji': '🙂', 'value': 7, 'label': 'Good'},
      {'emoji': '😐', 'value': 5, 'label': 'Okay'},
      {'emoji': '😔', 'value': 3, 'label': 'Low'},
      {'emoji': '😰', 'value': 1, 'label': 'Struggling'},
    ];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentTeal.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.smile, color: _accentTeal, size: 20),
              const SizedBox(width: 10),
              Text('How are you feeling?', 
                style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: moods.map((mood) => GestureDetector(
              onTap: () => _logQuickMood(mood['value'] as int, mood['label'] as String),
              child: Column(
                children: [
                  Text(mood['emoji'] as String, style: const TextStyle(fontSize: 32)),
                  const SizedBox(height: 4),
                  Text(mood['label'] as String, 
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 10)),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
  
  /// Log quick mood and show confirmation
  Future<void> _logQuickMood(int value, String label) async {
    try {
      // Find the mood metric
      final moodMetric = _metrics.firstWhere(
        (m) => m.id == 'mood',
        orElse: () => HealthMetric(
          id: 'mood',
          name: 'Mood',
          unit: '/10',
          iconName: 'smile',
        ),
      );
      
      // Log the value
      await VitalBalanceService.addEntry(moodMetric.id, value.toDouble());
      
      // Update last wellness date
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_wellness_update_date', DateTime.now().toIso8601String());
      
      // Refresh metrics display
      await _refreshMetrics();
      
      // Show confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✨ Logged mood: $label ($value/10)'),
            backgroundColor: _accentTeal,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error logging quick mood: $e');
    }
  }

  Widget _buildPrivacySettings() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accentLavender.withOpacity(0.15),
            _cardColor,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentLavender.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: _accentLavender.withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.shieldCheck, color: _accentLavender, size: 20), // Changed from shieldOff to check
              const SizedBox(width: 10),
              Text('Privacy Settings', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Keep wellness chats private', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(
                      _keepConversationsPrivate 
                        ? 'ON: Mental health topics stay here only. Main chat will redirect wellness questions to Vital Balance.' 
                        : 'OFF: Wellness history may be referenced in main chat',
                      style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 11),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              Switch(
                value: _keepConversationsPrivate,
                onChanged: _togglePrivacy,
                activeColor: _accentTeal,
                activeTrackColor: _accentTeal.withOpacity(0.3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
     return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _warningAmber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _warningAmber.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.alertTriangle, color: _warningAmber, size: 20),
              const SizedBox(width: 10),
              Text('Important Disclaimer', style: GoogleFonts.spaceGrotesk(color: _warningAmber, fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'This app and its AI companion are not medical professionals. This tool is for wellness tracking only. If you are in crisis, seek professional care.',
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyScreen())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.shieldAlert, color: Colors.red[300], size: 18),
                        const SizedBox(width: 8),
                        Text('Crisis Resources', style: GoogleFonts.inter(color: Colors.red[300], fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: _cardColor,
      child: const Center(
        child: Icon(LucideIcons.heartPulse, color: _accentTeal, size: 22),
      ),
    );
  }
  Future<void> _showStepsDialog(HealthMetric metric) async {
    // Init permissions
    final hasPerm = await StepTrackingService.instance.init();
    
    // Controller for manual override
    final manualController = TextEditingController();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        bool isDistanceMode = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isWalking = StepTrackingService.instance.isWalking;

            return AlertDialog(
              backgroundColor: const Color(0xFF1A1F2C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         Row(
                           children: [
                             Icon(LucideIcons.footprints, color: _accentTeal),
                             const SizedBox(width: 12),
                             Text('Walk Session', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 18)),
                           ],
                         ),
                         IconButton(
                           icon: const Icon(LucideIcons.x, color: Colors.white38),
                           onPressed: () => Navigator.pop(context),
                         )
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Permission Status
                    if (!hasPerm)
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                       margin: const EdgeInsets.only(bottom: 16),
                       decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                       child: Row(
                         children: [
                           const Icon(LucideIcons.alertTriangle, color: Colors.red, size: 16),
                           const SizedBox(width: 8),
                           Expanded(child: Text('Motion permission required.', style: GoogleFonts.inter(color: Colors.white, fontSize: 12))),
                           TextButton(
                             onPressed: () async {
                                // Check if running on simulator (motion not supported)
                                final isSimulator = Platform.isIOS && 
                                    (Platform.environment['SIMULATOR_DEVICE_NAME'] != null ||
                                     await Permission.activityRecognition.status == PermissionStatus.restricted);
                                
                                // First check current status
                                var status = await Permission.activityRecognition.status;
                                debugPrint('Motion permission status: $status (isSimulator: $isSimulator)');
                                
                                if (status.isGranted || status.isLimited) {
                                  // Already have permission - just reinit
                                  await StepTrackingService.instance.init();
                                  if (mounted) {
                                    Navigator.pop(context);
                                    _showStepsDialog(metric);
                                  }
                                  return;
                                }
                                
                                // On simulator or if restricted, show helpful message
                                if (status.isRestricted) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Step tracking requires a physical device with motion sensors.'),
                                        backgroundColor: Colors.orange,
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                  return;
                                }
                                
                                if (status.isPermanentlyDenied) {
                                  // Must go to settings
                                  debugPrint('Opening app settings for motion permission');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Please enable Motion & Fitness in Settings.'),
                                        backgroundColor: Colors.blue,
                                        action: SnackBarAction(
                                          label: 'OPEN',
                                          textColor: Colors.white,
                                          onPressed: () => openAppSettings(),
                                        ),
                                      ),
                                    );
                                  }
                                  openAppSettings();
                                  return;
                                }
                                
                                // Request permission (status is denied or undetermined)
                                debugPrint('Requesting motion permission...');
                                status = await Permission.activityRecognition.request();
                                debugPrint('Permission result: $status');
                                
                                // iOS fallback to sensors
                                if (!status.isGranted && !status.isLimited) {
                                  final sensorStatus = await Permission.sensors.status;
                                  if (!sensorStatus.isPermanentlyDenied && !sensorStatus.isRestricted) {
                                    status = await Permission.sensors.request();
                                    debugPrint('Sensors permission result: $status');
                                  }
                                }
                                
                                if (status.isGranted || status.isLimited) {
                                  await StepTrackingService.instance.init();
                                  if (mounted) {
                                    Navigator.pop(context);
                                    _showStepsDialog(metric);
                                  }
                                } else if (status.isPermanentlyDenied || status.isRestricted) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Motion permission needed. Open Settings to enable.'),
                                        backgroundColor: Colors.orange,
                                        action: SnackBarAction(
                                          label: 'SETTINGS',
                                          textColor: Colors.white,
                                          onPressed: () => openAppSettings(),
                                        ),
                                      ),
                                    );
                                  }
                                  openAppSettings();
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Motion permission needed for step tracking'), backgroundColor: Colors.black87)
                                    );
                                  }
                                }
                             },
                             style: TextButton.styleFrom(
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                               minimumSize: Size.zero,
                               tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                             ),
                             child: Text('ENABLE', style: GoogleFonts.inter(color: _accentTeal, fontWeight: FontWeight.bold, fontSize: 12)),
                           )
                         ],
                       ),
                     ),

                    // Live Counter
                    StreamBuilder<int>(
                      stream: StepTrackingService.instance.sessionStepsStream,
                      initialData: 0,
                      builder: (context, snapshot) {
                        final steps = snapshot.data ?? 0;
                        return Column(
                          children: [
                             Text(
                               isWalking ? '$steps' : 'Ready',
                               style: GoogleFonts.spaceGrotesk(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
                             ),
                             Text(isWalking ? 'STEPS' : 'Start your walk', style: GoogleFonts.inter(fontSize: 12, color: Colors.white54, letterSpacing: 2)),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    
                    // Action Button
                    GestureDetector(
                      onTap: () {
                         if (isWalking) {
                           final total = StepTrackingService.instance.stopWalk();
                           // Save
                           _submitMetric(metric, total.toDouble());
                           setDialogState(() {}); // Update UI to "Ready"
                           // Maybe verify with user?
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Walk logged: $total steps!'), backgroundColor: Colors.black87));
                           Navigator.pop(context);
                         } else {
                           StepTrackingService.instance.startWalk();
                           setDialogState(() {});
                         }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                        decoration: BoxDecoration(
                          color: isWalking ? Colors.red.withOpacity(0.2) : _accentTeal,
                          borderRadius: BorderRadius.circular(50),
                          border: isWalking ? Border.all(color: Colors.red) : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isWalking ? LucideIcons.square : LucideIcons.play, color: isWalking ? Colors.red : Colors.black87),
                            const SizedBox(width: 8),
                            Text(isWalking ? 'STOP WALK' : 'START WALK', style: GoogleFonts.spaceGrotesk(color: isWalking ? Colors.red : Colors.black87, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 16),
                    
                    // Manual Fallback Header & Toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Manual Entry:', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                        // Toggle
                        Container(
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => setDialogState(() => isDistanceMode = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: !isDistanceMode ? Colors.white.withOpacity(0.1) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text('Steps', style: GoogleFonts.inter(fontSize: 10, color: !isDistanceMode ? Colors.white : Colors.white38, fontWeight: !isDistanceMode ? FontWeight.bold : FontWeight.normal)),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setDialogState(() => isDistanceMode = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDistanceMode ? Colors.white.withOpacity(0.1) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text('Distance', style: GoogleFonts.inter(fontSize: 10, color: isDistanceMode ? Colors.white : Colors.white38, fontWeight: isDistanceMode ? FontWeight.bold : FontWeight.normal)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Input Field
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: manualController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: isDistanceMode ? 'e.g. 1.2 miles' : 'e.g. 2000 steps',
                              hintStyle: const TextStyle(color: Colors.white24),
                              fillColor: Colors.white.withOpacity(0.05),
                              filled: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(LucideIcons.checkCircle, color: _accentTeal),
                          onPressed: () {
                             final input = manualController.text;
                             final val = double.tryParse(input);
                             if (val != null) {
                                final steps = isDistanceMode ? (val * 2000).round().toDouble() : val;
                                _submitMetric(metric, steps);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(isDistanceMode ? 'Logged ${val}mi (~${steps.toInt()} steps)' : 'Logged ${steps.toInt()} steps'),
                                  backgroundColor: Colors.black87
                                ));
                                Navigator.pop(context);
                             }
                          },
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Approx Calculation
                    Text(
                      isDistanceMode ? '~2,000 steps = 1 mile' : '~1 mile = 2,000 steps', 
                      style: GoogleFonts.inter(color: Colors.white30, fontSize: 10, fontStyle: FontStyle.italic)
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    final width = size.width;
    final height = size.height;

    double minV = values.reduce((curr, next) => curr < next ? curr : next);
    double maxV = values.reduce((curr, next) => curr > next ? curr : next);
    // Pad ranges to avoid flat line if all equal
    if (maxV == minV) {
      maxV += 1;
      minV -= 1;
    }
    
    final range = maxV - minV;
    final dx = width / (values.length - 1 > 0 ? values.length - 1 : 1);

    for (int i = 0; i < values.length; i++) {
        // Normalize value to height
        // value - minV / range = 0..1
        // y = height - (norm * height)
        final norm = (values[i] - minV) / range;
        final x = i * dx;
        final y = height - (norm * height);
        
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
    }
    
    canvas.drawPath(path, paint);
    
    // Gradient fill below
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, width, height));
      
    final fillPath = Path.from(path);

    fillPath.lineTo(width, height);
    fillPath.lineTo(0, height);
    fillPath.close();
    
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant SparklinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

class _ProfileDialog extends StatefulWidget {
  final Map<String, String> currentProfile;
  final Function(Map<String, String>) onSave;

  const _ProfileDialog({required this.currentProfile, required this.onSave});

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  DateTime? _dob;
  late TextEditingController _weightController;
  late TextEditingController _heightController;
  late TextEditingController _raceController;
  String? _sex;
  String? _smoking;
  String? _drinking;

  @override
  void initState() {
    super.initState();
    // Parse existing DOB if available
    final dobString = widget.currentProfile['dob'];
    if (dobString != null && dobString.isNotEmpty) {
      try {
        _dob = DateTime.parse(dobString);
      } catch (_) {
        _dob = null;
      }
    }
    _weightController = TextEditingController(text: widget.currentProfile['weight']);
    _heightController = TextEditingController(text: widget.currentProfile['height']);
    _raceController = TextEditingController(text: widget.currentProfile['race']);
    _sex = widget.currentProfile['sex'];
    _smoking = widget.currentProfile['smoking'];
    _drinking = widget.currentProfile['drinking'];
  }
  
  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _raceController.dispose();
    super.dispose();
  }
  
  int? _calculateAge() {
    if (_dob == null) return null;
    final now = DateTime.now();
    int age = now.year - _dob!.year;
    if (now.month < _dob!.month || (now.month == _dob!.month && now.day < _dob!.day)) {
      age--;
    }
    return age;
  }
  
  Future<void> _selectDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Select your date of birth',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF5DD9C1),
              surface: Color(0xFF1E2D3D),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _dob = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final age = _calculateAge();
    
    return Dialog(
      backgroundColor: const Color(0xFF1E2D3D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.sparkles, color: Color(0xFF5DD9C1), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Setup Health Profile', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              "I'd love to get to know you better. To provide personalized wellness insights, I need a few details. This stays strictly on your device.",
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            
            // Date of Birth picker
            _buildDateField('Date of Birth', _dob, age, _selectDob),
            const SizedBox(height: 16),
            
            _buildDropdown('Sex', ['Female', 'Male', 'Other'], _sex, (v) => setState(() => _sex = v)),
            const SizedBox(height: 16),
            
            _buildTextField('Weight', _weightController, TextInputType.text, 'e.g. 150 lbs or 68 kg'),
            const SizedBox(height: 16),
            
            _buildTextField('Height', _heightController, TextInputType.text, "e.g. 5'7\" or 170cm"),
            const SizedBox(height: 16),
            
            _buildDropdown('Race/Ethnicity', ['White/Caucasian', 'Black/African American', 'Asian', 'Hispanic/Latino', 'Native American', 'Pacific Islander', 'Mixed/Multiracial', 'Other', 'Prefer not to say'], _raceController.text.isEmpty ? null : _raceController.text, (v) => setState(() => _raceController.text = v ?? '')),
            const SizedBox(height: 16),
            
            _buildDropdown('Smoking', ['Never', 'Occasional', 'Regular', 'Quit'], _smoking, (v) => setState(() => _smoking = v)),
            const SizedBox(height: 16),
            
            _buildDropdown('Drinking', ['Never', 'Socially', 'Regularly'], _drinking, (v) => setState(() => _drinking = v)),
            
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5DD9C1),
                    foregroundColor: const Color(0xFF0D1B2A),
                  ),
                  child: const Text('Save Profile'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDateField(String label, DateTime? date, int? age, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF5DD9C1).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.calendar, color: Color(0xFF5DD9C1), size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    date != null 
                      ? '${date.month}/${date.day}/${date.year}${age != null ? ' (Age: $age)' : ''}'
                      : 'Tap to select...',
                    style: TextStyle(color: date != null ? Colors.white : Colors.white24),
                  ),
                ),
                const Icon(LucideIcons.chevronDown, color: Colors.white38, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildTextField(String label, TextEditingController controller, TextInputType type, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: type,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white24),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> options, String? value, Function(String?) onChanged) {
    // Validate that value exists in options, otherwise set to null
    final validatedValue = (value != null && options.contains(value)) ? value : null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<String>(
            value: validatedValue,
            isExpanded: true,
            dropdownColor: const Color(0xFF1E2D3D),
            underline: const SizedBox(),
            hint: const Text('Select...', style: TextStyle(color: Colors.white24)),
            style: const TextStyle(color: Colors.white),
            items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _save() {
    final profile = <String, String>{};
    if (_dob != null) profile['dob'] = _dob!.toIso8601String();
    if (_weightController.text.isNotEmpty) profile['weight'] = _weightController.text;
    if (_heightController.text.isNotEmpty) profile['height'] = _heightController.text;
    if (_raceController.text.isNotEmpty) profile['race'] = _raceController.text;
    if (_sex != null) profile['sex'] = _sex!;
    if (_smoking != null) profile['smoking'] = _smoking!;
    if (_drinking != null) profile['drinking'] = _drinking!;
    
    widget.onSave(profile);
    Navigator.pop(context);
  }
}
