import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/lab_result.dart';
import '../models/vital_reading.dart';
import '../services/health_data_service.dart';
import '../services/health_kit_service.dart';
import 'lab_results_screen.dart';
import 'medication_manager_screen.dart';
import 'document_scan_screen.dart';

/// Main Health Dashboard - Central hub for medical data
/// 
/// Best-in-class features:
/// - Latest vitals at a glance
/// - Lab result summaries with trends
/// - Quick access to medications
/// - Provider sync status
/// - Document import options
class HealthDashboardScreen extends StatefulWidget {
  const HealthDashboardScreen({super.key});

  @override
  State<HealthDashboardScreen> createState() => _HealthDashboardScreenState();
}

class _HealthDashboardScreenState extends State<HealthDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _summary = {};
  List<VitalReading> _recentVitals = [];
  List<LabResult> _recentLabs = [];
  List<HealthProvider> _providers = [];
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      await HealthDataService.init();
      
      final summary = await HealthDataService.getHealthSummary();
      final vitals = await HealthDataService.getTodaysVitals();
      final labs = await HealthDataService.getAllLabResults();
      final providers = await HealthKitService.getConnectedProviders();
      
      setState(() {
        _summary = summary;
        _recentVitals = vitals;
        _recentLabs = labs.take(5).toList();
        _providers = providers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            backgroundColor: Colors.transparent,
            expandedHeight: 100,
            floating: true,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Health Dashboard',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
              titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
            ),
            actions: [
              IconButton(
                icon: const Icon(LucideIcons.upload),
                tooltip: 'Import Data',
                onPressed: _showImportOptions,
              ),
              IconButton(
                icon: const Icon(LucideIcons.settings),
                onPressed: () {},
              ),
            ],
          ),
          
          // Content
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Privacy Notice
                _buildPrivacyNotice(),
                const SizedBox(height: 20),
                
                // Quick Actions
                _buildQuickActions(),
                const SizedBox(height: 24),
                
                // Today's Vitals
                _buildSectionHeader('Today\'s Vitals', LucideIcons.heartPulse),
                const SizedBox(height: 12),
                _buildVitalsGrid(),
                const SizedBox(height: 24),
                
                // Recent Lab Results
                _buildSectionHeader('Recent Lab Results', LucideIcons.testTube),
                const SizedBox(height: 12),
                _buildLabResultsPreview(),
                const SizedBox(height: 24),
                
                // Connected Providers
                _buildSectionHeader('Connected Sources', LucideIcons.link),
                const SizedBox(height: 12),
                _buildProvidersCard(),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPrivacyNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withOpacity(0.1),
            Colors.blue.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.shieldCheck, color: Colors.green, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '🔒 Encrypted  •  📱 On-Device Only  •  🚫 Never Shared',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.green[300],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: LucideIcons.camera,
            label: 'Scan Doc',
            color: Colors.purple,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DocumentScanScreen()),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: LucideIcons.pill,
            label: 'Medications',
            color: Colors.orange,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MedicationManagerScreen()),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            icon: LucideIcons.testTube,
            label: 'Lab Results',
            color: Colors.cyan,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LabResultsScreen()),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white70),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () {},
          child: Text(
            'See All',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.blue[300],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildVitalsGrid() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildVitalCard(
          icon: '❤️',
          label: 'Blood Pressure',
          value: _summary['latestBloodPressure'] ?? '--/-- mmHg',
          trend: null,
          color: Colors.red,
        ),
        _buildVitalCard(
          icon: '🩸',
          label: 'Glucose',
          value: _summary['latestGlucose'] ?? '-- mg/dL',
          trend: null,
          color: Colors.purple,
        ),
        _buildVitalCard(
          icon: '⚖️',
          label: 'Weight',
          value: _summary['latestWeight'] ?? '-- lbs',
          trend: null,
          color: Colors.green,
        ),
        _buildVitalCard(
          icon: '💓',
          label: 'Heart Rate',
          value: '-- bpm',
          trend: null,
          color: Colors.pink,
        ),
      ],
    );
  }
  
  Widget _buildVitalCard({
    required String icon,
    required String label,
    required String value,
    String? trend,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          if (trend != null)
            Text(
              trend,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.green[300],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildLabResultsPreview() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_recentLabs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Icon(LucideIcons.fileText, size: 40, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              'No lab results yet',
              style: GoogleFonts.inter(color: Colors.white60),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const DocumentScanScreen()),
              ),
              icon: const Icon(LucideIcons.camera, size: 16),
              label: const Text('Scan a Lab Report'),
            ),
          ],
        ),
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: _recentLabs.map((lab) {
          final isAbnormal = !lab.isNormal;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isAbnormal 
                    ? Colors.orange.withOpacity(0.2)
                    : Colors.green.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isAbnormal ? LucideIcons.alertTriangle : LucideIcons.checkCircle,
                color: isAbnormal ? Colors.orange : Colors.green,
                size: 18,
              ),
            ),
            title: Text(
              lab.testName,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            subtitle: Text(
              lab.referenceRangeDisplay,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white54,
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  lab.displayValue,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: isAbnormal ? Colors.orange : Colors.white,
                  ),
                ),
                Text(
                  _formatDate(lab.testDate),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildProvidersCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ..._providers.map((provider) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: provider.isConnected 
                    ? Colors.green.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(provider.icon, style: const TextStyle(fontSize: 24)),
              ),
            ),
            title: Text(
              provider.name,
              style: GoogleFonts.inter(color: Colors.white),
            ),
            subtitle: Text(
              provider.isConnected 
                  ? 'Connected' 
                  : 'Not connected',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: provider.isConnected ? Colors.green[300] : Colors.white54,
              ),
            ),
            trailing: provider.isConnected 
                ? TextButton(
                    onPressed: _syncHealthKit,
                    child: const Text('Sync'),
                  )
                : OutlinedButton(
                    onPressed: () => HealthKitService.requestAuthorization(),
                    child: const Text('Connect'),
                  ),
          )),
          const Divider(color: Colors.white12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(LucideIcons.plus, color: Colors.blue),
              ),
            ),
            title: Text(
              'Add Provider',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            subtitle: Text(
              'Connect to MyChart or other portals',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white54,
              ),
            ),
            onTap: _showAddProviderSheet,
          ),
        ],
      ),
    );
  }
  
  void _showImportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Import Health Data',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(LucideIcons.camera, color: Colors.purple),
              title: const Text('Scan Document', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Lab report, prescription, or medical record',
                  style: TextStyle(color: Colors.white54)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, 
                    MaterialPageRoute(builder: (_) => const DocumentScanScreen()));
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.fileText, color: Colors.blue),
              title: const Text('Upload PDF', style: TextStyle(color: Colors.white)),
              subtitle: const Text('From Files or Photos',
                  style: TextStyle(color: Colors.white54)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement PDF upload
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.link, color: Colors.green),
              title: const Text('Connect Provider', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Apple Health, MyChart, and more',
                  style: TextStyle(color: Colors.white54)),
              onTap: () {
                Navigator.pop(context);
                _showAddProviderSheet();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  void _showAddProviderSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Connect Health Provider',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.info, color: Colors.blue, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your medical records stay on your device. We never store them on our servers.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.blue[200],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Text('🍎', style: TextStyle(fontSize: 28)),
              title: const Text('Apple Health', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Sync vitals and clinical records',
                  style: TextStyle(color: Colors.white54)),
              trailing: const Icon(LucideIcons.chevronRight, color: Colors.white54),
              onTap: () async {
                Navigator.pop(context);
                await HealthKitService.requestAuthorization();
                _loadData();
              },
            ),
            ListTile(
              leading: Icon(LucideIcons.building2, color: Colors.cyan, size: 28),
              title: const Text('MyChart / Epic', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Coming soon',
                  style: TextStyle(color: Colors.white54)),
              trailing: const Icon(LucideIcons.lock, color: Colors.white24),
              enabled: false,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Future<void> _syncHealthKit() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Syncing with Apple Health...')),
    );
    
    final imported = await HealthKitService.importVitalsToStorage(days: 30);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported $imported readings from Apple Health')),
    );
    
    _loadData();
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    }
    return '${date.month}/${date.day}/${date.year}';
  }
}
