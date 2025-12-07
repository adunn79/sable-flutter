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

import 'package:sable/features/safety/screens/emergency_screen.dart';
import 'package:sable/features/onboarding/services/onboarding_state_service.dart';
import 'package:sable/features/vital_balance/services/vital_balance_service.dart';
import 'package:sable/features/vital_balance/services/step_tracking_service.dart';
import 'package:sable/features/journal/widgets/avatar_journal_overlay.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sable/src/pages/chat/chat_page.dart';
import 'package:permission_handler/permission_handler.dart';

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
  
  static const _keyPrivateConversations = 'vital_balance_private_conversations';

  final TextEditingController _chatInputController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadAllData();
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
                        onTap: () => context.go('/home'),
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
                
              // AI Daily Focus Section
              _buildDailyFocus(),
              // Main content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Wellness Coach Chat (Moved UP)
                      _buildWellnessChat(),
                      
                      const SizedBox(height: 16),
                      // 2. Health Profile Card
                      _buildProfileCard(),
                      
                      const SizedBox(height: 24),

                      // 2. Metrics Section Header & Grid
                      _buildMetricsSection(),
                      
                      const SizedBox(height: 24),
                      
                      // 3. Daily Quote (Moved down)
                      _buildWellnessCard(),
                      
                      const SizedBox(height: 20),
                      
                      // 4. Privacy Settings
                      _buildPrivacySettings(),
                      
                      const SizedBox(height: 40),
                      
                      // 5. Disclaimer & Emergency
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('Your Vitals', LucideIcons.activity),
            Row(
              children: [
                // Print/Export Button
                IconButton(
                  icon: const Icon(LucideIcons.printer, color: Colors.white70, size: 20),
                  onPressed: _generateReport,
                  tooltip: 'Print Report',
                ),
                // Export Button (Share/Email)
                Builder(
                  builder: (context) {
                    return IconButton(
                      icon: const Icon(LucideIcons.mail, color: Colors.white70, size: 20),
                      onPressed: () => _shareReport(context),
                      tooltip: 'Export to Email',
                    );
                  }
                ),
                // Add Metric Button
                IconButton(
                  icon: const Icon(LucideIcons.plusCircle, color: _accentTeal, size: 22),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('Add New Metric', style: TextStyle(color: Colors.white)), backgroundColor: Colors.black87, duration: Duration(milliseconds: 500))
                    );
                    _showAddMetricDialog();
                  },
                  tooltip: 'Add Metric',
                ),
              ],
            ),
          ],
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
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.2,
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
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accentTeal.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(VitalBalanceService.getIconData(metric.iconName), color: _accentTeal, size: 24),
                Icon(LucideIcons.plus, color: Colors.white24, size: 16),
              ],
            ),
            const Spacer(),
            Text(
              _latestValues[metric.id] ?? '--',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              metric.name.toUpperCase(),
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
                _buildFaceSelector((val) => _submitMetric(metric, val))
              else if (useWaterSelector)
                _buildWaterSelector((val) => _submitMetric(metric, val))
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
              
              // Recent History with Chart Placeholder
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text('Recent History', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
                   Text('Last 7 Days', style: GoogleFonts.inter(color: _accentTeal, fontSize: 10)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 80, 
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: history.isEmpty 
                  ? Center(child: Text('No data yet', style: GoogleFonts.inter(color: Colors.white24)))
                  : CustomPaint(
                      painter: SparklinePainter(
                        values: history.take(7).map((e) => e.value).toList().reversed.toList(),
                        color: _accentTeal,
                      ),
                      size: Size.infinite,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitMetric(HealthMetric metric, double val) async {
     await VitalBalanceService.addEntry(metric.id, val);
     if (!mounted) return;
     Navigator.pop(context);
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
                width: 90, // Increased size again
                height: 90,
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
          const SizedBox(height: 16),
          // Quick prompts
          Text('Quick check-in:', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickPrompt('How\'s my energy?', LucideIcons.zap),
              _buildQuickPrompt('Sleep tips', LucideIcons.moon),
              _buildQuickPrompt('Stress relief', LucideIcons.heart),
              _buildQuickPrompt('Mood boost', LucideIcons.smile),
            ],
          ),
          const SizedBox(height: 16),
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
                    decoration: const InputDecoration(
                      hintText: 'Ask about your wellness...',
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (text) {
                      if (text.isNotEmpty) {
                        _startWellnessChat(text);
                        _chatInputController.clear();
                      }
                    },
                  ),
                ),
                IconButton(
                  onPressed: () {
                     final text = _chatInputController.text;
                     if (text.isNotEmpty) {
                       _startWellnessChat(text);
                       _chatInputController.clear();
                     } else {
                       _startWellnessChat('General wellness check');
                     }
                  },
                  icon: const Icon(LucideIcons.send, color: _accentTeal),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

    Widget _buildQuickPrompt(String label, IconData icon) {
    return GestureDetector(
      onTap: () => _startWellnessChat(label),
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
                    Text('Keep conversations private', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(
                      _keepConversationsPrivate ? 'Health chats stay in this tab only' : 'May be referenced in main chat',
                      style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 12),
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
                             onPressed: () => openAppSettings(),
                             style: TextButton.styleFrom(
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                               minimumSize: Size.zero,
                               tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                             ),
                             child: Text('ENABLE', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
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
            
            _buildDropdown('Race/Ethnicity', ['White', 'Black/African American', 'Asian', 'Hispanic/Latino', 'Native American', 'Other', 'Prefer not to say'], _raceController.text.isEmpty ? null : _raceController.text, (v) => setState(() => _raceController.text = v ?? '')),
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
            value: value,
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
