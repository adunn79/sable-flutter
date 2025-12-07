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
import 'package:sable/features/journal/widgets/avatar_journal_overlay.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sable/src/pages/chat/chat_page.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sable/core/memory/unified_memory_service.dart';
import 'package:sable/core/ai/model_orchestrator.dart';
import 'package:sable/core/ai/providers/openai_provider.dart';
import 'package:sable/features/journal/services/journal_storage_service.dart';

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
  bool _keepConversationsPrivate = true; // Default: private
  
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
  
  // Dynamic AI-Generated Focus Items
  List<Map<String, dynamic>> _aiFocusItems = []; // {title, description, icon, metricId, enabled}
  bool _isLoadingFocus = true;
  int _daysSinceUpdate = 0; // Days since last wellness metric update
  Set<String> _disabledFocusItems = {}; // User-disabled items by metricId
  
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
      _keepConversationsPrivate = prefs.getBool(_keyPrivateConversations) ?? true;
      _metrics = metrics;
      _latestValues = values;
      _profile = profile;
      _weatherTemp = weatherTemp;
      _weatherHighLow = weatherHighLow;
      _daysSinceUpdate = daysSince;
      _isLoadingMetrics = false;
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
      {'id': 'sleep', 'title': 'Rest', 'description': 'Log your sleep', 'icon': LucideIcons.moon},
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
    
    setState(() {
      _chatMessages.add({'role': 'user', 'text': text});
      _isAiThinking = true;
    });
    
    try {
      // Get user identity and preferences
      final prefs = await SharedPreferences.getInstance();
      final avatarName = prefs.getString('selectedArchetypeName') ?? 'Sable';
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
      
      final wellnessPrompt = '''User asks: "$text"

CURRENT HEALTH METRICS: $metricsContext

HEALTH PROFILE:
- Name: $userName
- Age: ${age.isEmpty ? 'Not specified' : age}
- Sex: ${sex.isEmpty ? 'Not specified' : sex}  
- Height: ${height.isEmpty ? 'Not specified' : height}

${memoryContext.isNotEmpty ? 'KEY MEMORIES ABOUT $userName:\n$memoryContext\n' : ''}
${recentChats.isNotEmpty ? 'RECENT CONVERSATIONS:\n$recentChats\n' : ''}
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

Keep responses to 2-3 sentences. Be warm, personal, and draw from what you know about them.''';

      // Use OpenAI provider directly for reliable wellness chat
      final openAiProvider = OpenAiProvider();
      final response = await openAiProvider.generateResponse(
        prompt: wellnessPrompt,
        systemPrompt: systemPrompt,
        modelId: 'gpt-4o-mini', // Fast, reliable model for wellness chat
      );
      
      debugPrint('✅ Wellness AI response received: ${response.substring(0, response.length.clamp(0, 100))}...');
      
      if (_disposed || !mounted) return;
      
      setState(() {
        _chatMessages.add({'role': 'ai', 'text': response.trim()});
        _isAiThinking = false;
      });
      
      // Scroll to bottom after adding message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
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
                      
                      // 3. Privacy Settings (moved up)
                      _buildPrivacySettings(),
                      
                      const SizedBox(height: 24),

                      // 4. Metrics Section Header & Grid
                      _buildMetricsSection(),
                      
                      const SizedBox(height: 24),
                      
                      // 5. Health Profile Card
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

  Widget _buildProfileCard() {
    // If profile is empty/loading, show skeleton or CTA?
    // We'll show a summary card.
    final age = _profile['age'] ?? '-';
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
    // If age or sex is missing, assume first time setup needed
    if (profile['age'] == null || profile['sex'] == null) {
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
    showDialog(
      context: context,
      barrierDismissible: !isFirstTime, // Force setup if first time? Maybe let them cancel.
      builder: (context) => _ProfileDialog(
        currentProfile: _profile,
        onSave: (newProfile) async {
          await VitalBalanceService.updateProfile(newProfile);
          if (mounted) {
            setState(() => _profile = newProfile);
            _refreshMetrics();
            ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Profile Updated', style: TextStyle(color: Colors.white)), backgroundColor: Colors.black87),
            );
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
            tooltipBgColor: const Color(0xFF1A2A35),
            tooltipRoundedRadius: 8,
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
            pw.Footer(title: pw.Text('Generated by Sable AI')),
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
              SizedBox(
                width: 140, // Significantly larger avatar
                height: 140,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: AvatarJournalOverlay(
                    isPrivate: _keepConversationsPrivate,
                    archetype: _archetypeId,
                    onSparkTap: null,
                    onAvatarTap: () {
                      if (_keepConversationsPrivate) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vital Balance is currently Private.', style: TextStyle(color: Colors.white)),
                            backgroundColor: Colors.black87,
                          ),
                        );
                      } else {
                        // Just show a tooltip/snackbar since chat is below
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sable is observing your wellness.', style: TextStyle(color: Colors.white)),
                              backgroundColor: Colors.black87,
                              duration: Duration(seconds: 1),
                            ),
                          );
                      }
                    },
                  ),
                ),
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
                else
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
                    textInputAction: TextInputAction.send, // Enter sends message
                    decoration: const InputDecoration(
                      hintText: "What's on your mind?",
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24), // 100% increase
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
            constraints: const BoxConstraints(minHeight: 120, maxHeight: 750), // 50% increase from 500
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _accentTeal.withOpacity(0.2)),
            ),
            child: (_chatMessages.isEmpty && !_isAiThinking) || _hideChatMessages
                ? const SizedBox(height: 60) // Empty placeholder
                : ListView.builder(
                    controller: _chatScrollController,
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _chatMessages.length + (_isAiThinking ? 1 : 0),
                    itemBuilder: (context, index) {
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
    final dailyQuotes = [
      "Every small step counts. Your wellness journey is uniquely yours.",
      "You are stronger than you know.",
      "Rest is productive.",
      "Healing isn't linear. Be patient with yourself.",
    ];
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    final todaysQuote = dailyQuotes[dayOfYear % dailyQuotes.length];
    
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
          Text('"$todaysQuote"', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontStyle: FontStyle.italic, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildPrivacySettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentLavender.withOpacity(0.3)),
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
                                // Request motion/activity permission - use activityRecognition for iOS
                                var status = await Permission.activityRecognition.request();
                                // Fallback to sensors if activityRecognition not available
                                if (!status.isGranted && !status.isLimited) {
                                  status = await Permission.sensors.request();
                                }
                                if (status.isGranted || status.isLimited) {
                                  // Permission granted - reinit and refresh dialog
                                  await StepTrackingService.instance.init();
                                  if (mounted) {
                                    Navigator.pop(context);
                                    _showStepsDialog(metric); // Reopen with permission
                                  }
                                } else if (status.isPermanentlyDenied) {
                                  // Only open settings if permanently denied
                                  openAppSettings();
                                } else {
                                  // Show snackbar for denied
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
  late TextEditingController _ageController;
  late TextEditingController _heightController;
  late TextEditingController _raceController;
  String? _sex;
  String? _smoking;
  String? _drinking;

  @override
  void initState() {
    super.initState();
    _ageController = TextEditingController(text: widget.currentProfile['age']);
    _heightController = TextEditingController(text: widget.currentProfile['height']);
    _raceController = TextEditingController(text: widget.currentProfile['race']);
    _sex = widget.currentProfile['sex'];
    _smoking = widget.currentProfile['smoking'];
    _drinking = widget.currentProfile['drinking'];
  }
  
  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _raceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            
            _buildTextField('Age', _ageController, TextInputType.number, 'e.g. 32'),
            const SizedBox(height: 16),
            
            _buildDropdown('Sex', ['Female', 'Male', 'Other'], _sex, (v) => setState(() => _sex = v)),
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
    if (_ageController.text.isNotEmpty) profile['age'] = _ageController.text;
    if (_heightController.text.isNotEmpty) profile['height'] = _heightController.text;
    if (_raceController.text.isNotEmpty) profile['race'] = _raceController.text;
    if (_sex != null) profile['sex'] = _sex!;
    if (_smoking != null) profile['smoking'] = _smoking!;
    if (_drinking != null) profile['drinking'] = _drinking!;
    
    widget.onSave(profile);
    Navigator.pop(context);
  }
}
