import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prescription.dart';
import '../services/prescription_service.dart';
import 'prescription_scan_screen.dart';
import 'prescription_edit_screen.dart';
import '../widgets/prescription_card.dart';

/// Screen displaying all prescriptions with scan and add options
class PrescriptionListScreen extends StatefulWidget {
  const PrescriptionListScreen({super.key});

  @override
  State<PrescriptionListScreen> createState() => _PrescriptionListScreenState();
}

class _PrescriptionListScreenState extends State<PrescriptionListScreen> {
  List<Prescription> _prescriptions = [];
  bool _isLoading = true;
  bool _showOnlyActive = true;

  @override
  void initState() {
    super.initState();
    _loadPrescriptions();
  }

  Future<void> _loadPrescriptions() async {
    setState(() => _isLoading = true);
    try {
      await PrescriptionService.init();
      final prescriptions = _showOnlyActive
          ? await PrescriptionService.getActivePrescriptions()
          : await PrescriptionService.getAllPrescriptions();
      setState(() {
        _prescriptions = prescriptions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading prescriptions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AelianaColors.obsidian,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Medications',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Toggle active/all
          IconButton(
            icon: Icon(
              _showOnlyActive ? LucideIcons.eye : LucideIcons.eyeOff,
              color: Colors.white54,
            ),
            onPressed: () {
              setState(() => _showOnlyActive = !_showOnlyActive);
              _loadPrescriptions();
            },
            tooltip: _showOnlyActive ? 'Show all' : 'Show active only',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOptions,
        backgroundColor: AelianaColors.plasmaCyan,
        icon: const Icon(LucideIcons.plus, color: Colors.black),
        label: Text(
          'Add Medication',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_prescriptions.isEmpty) {
      return _buildEmptyState();
    }
    
    return RefreshIndicator(
      onRefresh: _loadPrescriptions,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: _prescriptions.length + 1, // +1 for privacy notice
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildPrivacyNotice();
          }
          final prescription = _prescriptions[index - 1];
          return PrescriptionCard(
            prescription: prescription,
            onTap: () => _editPrescription(prescription),
            onDelete: () => _deletePrescription(prescription),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AelianaColors.plasmaCyan.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.pill,
                size: 48,
                color: AelianaColors.plasmaCyan,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Medications Yet',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add your prescriptions to track refills, set reminders, and share with your doctor.',
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Privacy assurance
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.lock, color: AelianaColors.hyperGold, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your data stays 100% on this device. Never uploaded to any server.',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 12,
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

  Widget _buildPrivacyNotice() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AelianaColors.hyperGold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AelianaColors.hyperGold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.shieldCheck, color: AelianaColors.hyperGold, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Encrypted on-device • Never shared • Your control',
              style: GoogleFonts.inter(
                color: AelianaColors.hyperGold,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AelianaColors.obsidian,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Medication',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              
              // Scan option
              _buildOptionTile(
                icon: LucideIcons.camera,
                title: 'Scan Prescription Label',
                subtitle: 'Use your camera to capture label info',
                color: AelianaColors.plasmaCyan,
                onTap: () {
                  Navigator.pop(context);
                  _scanPrescription();
                },
              ),
              
              const SizedBox(height: 12),
              
              // Manual option
              _buildOptionTile(
                icon: LucideIcons.pencil,
                title: 'Enter Manually',
                subtitle: 'Type in the prescription details',
                color: AelianaColors.hyperGold,
                onTap: () {
                  Navigator.pop(context);
                  _addManually();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _scanPrescription() async {
    final result = await Navigator.push<Prescription>(
      context,
      MaterialPageRoute(builder: (_) => const PrescriptionScanScreen()),
    );
    if (result != null) {
      _loadPrescriptions();
    }
  }

  Future<void> _addManually() async {
    final result = await Navigator.push<Prescription>(
      context,
      MaterialPageRoute(builder: (_) => const PrescriptionEditScreen()),
    );
    if (result != null) {
      _loadPrescriptions();
    }
  }

  Future<void> _editPrescription(Prescription prescription) async {
    final result = await Navigator.push<Prescription>(
      context,
      MaterialPageRoute(
        builder: (_) => PrescriptionEditScreen(prescription: prescription),
      ),
    );
    if (result != null) {
      _loadPrescriptions();
    }
  }

  Future<void> _deletePrescription(Prescription prescription) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AelianaColors.obsidian,
        title: Text(
          'Delete Medication?',
          style: GoogleFonts.spaceGrotesk(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete ${prescription.displayName}?',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await PrescriptionService.deletePrescription(prescription.id);
      _loadPrescriptions();
    }
  }
}

/// Settings key for prescription feature visibility
class PrescriptionSettings {
  static const String _keyEnabled = 'prescription_tracking_enabled';
  static const String _keyDismissed = 'prescription_prompt_dismissed';
  
  /// Check if prescription tracking is enabled
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? true; // Default enabled
  }
  
  /// Set prescription tracking enabled state
  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
  }
  
  /// Check if user dismissed the prompt
  static Future<bool> isPromptDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDismissed) ?? false;
  }
  
  /// Dismiss the prompt
  static Future<void> dismissPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDismissed, true);
  }
  
  /// Reset prompt (user wants to see it again)
  static Future<void> resetPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDismissed, false);
  }
}
