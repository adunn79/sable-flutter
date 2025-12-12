import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../health/models/prescription.dart';
import '../../health/services/prescription_service.dart';
import '../services/drug_interaction_service.dart';

/// Medication Manager Screen - Track medications and check interactions
/// 
/// Best-in-class features from Medisafe:
/// - Drug interaction checking
/// - Refill reminders
/// - Dosage schedules
/// - Pharmacy info
class MedicationManagerScreen extends StatefulWidget {
  const MedicationManagerScreen({super.key});

  @override
  State<MedicationManagerScreen> createState() => _MedicationManagerScreenState();
}

class _MedicationManagerScreenState extends State<MedicationManagerScreen> {
  List<Prescription> _medications = [];
  List<DrugInteraction> _interactions = [];
  bool _isLoading = true;
  bool _checkingInteractions = false;
  
  @override
  void initState() {
    super.initState();
    _loadMedications();
  }
  
  Future<void> _loadMedications() async {
    setState(() => _isLoading = true);
    
    try {
      await PrescriptionService.init();
      final meds = await PrescriptionService.getActivePrescriptions();
      
      setState(() {
        _medications = meds;
        _isLoading = false;
      });
      
      if (meds.length >= 2) {
        _checkInteractions();
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _checkInteractions() async {
    if (_medications.length < 2) return;
    
    setState(() => _checkingInteractions = true);
    
    try {
      // Get RxCUIs for all medications
      final rxcuis = <String>[];
      for (final med in _medications) {
        final rxcui = await DrugInteractionService.getRxCui(med.medicationName);
        if (rxcui != null) rxcuis.add(rxcui);
      }
      
      if (rxcuis.length >= 2) {
        final interactions = await DrugInteractionService.checkInteractions(rxcuis);
        setState(() {
          _interactions = interactions;
          _checkingInteractions = false;
        });
      } else {
        setState(() => _checkingInteractions = false);
      }
    } catch (e) {
      setState(() => _checkingInteractions = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Medications',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_medications.length >= 2)
            IconButton(
              icon: _checkingInteractions 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.shieldAlert),
              tooltip: 'Check Interactions',
              onPressed: _checkInteractions,
            ),
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: _showAddMedication,
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }
  
  Widget _buildContent() {
    return CustomScrollView(
      slivers: [
        // Interaction Alerts
        if (_interactions.isNotEmpty)
          SliverToBoxAdapter(
            child: _buildInteractionAlerts(),
          ),
        
        // Privacy Notice
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildPrivacyNotice(),
          ),
        ),
        
        // Medications List
        _medications.isEmpty
            ? SliverFillRemaining(child: _buildEmptyState())
            : SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildMedicationCard(_medications[index]),
                    childCount: _medications.length,
                  ),
                ),
              ),
      ],
    );
  }
  
  Widget _buildInteractionAlerts() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.withOpacity(0.2),
            Colors.red.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.alertTriangle, color: Colors.orange),
              const SizedBox(width: 10),
              Text(
                '${_interactions.length} Drug Interaction${_interactions.length > 1 ? 's' : ''} Found',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._interactions.map((interaction) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getSeverityColor(interaction.severity).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        interaction.severityLabel,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _getSeverityColor(interaction.severity),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${interaction.drug1} + ${interaction.drug2}',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  interaction.description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          )),
          const Divider(color: Colors.white24),
          Text(
            '⚕️ Discuss these interactions with your healthcare provider',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white54,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getSeverityColor(InteractionSeverity severity) {
    switch (severity) {
      case InteractionSeverity.high: return Colors.red;
      case InteractionSeverity.moderate: return Colors.orange;
      case InteractionSeverity.low: return Colors.yellow;
      case InteractionSeverity.unknown: return Colors.grey;
    }
  }
  
  Widget _buildPrivacyNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.shieldCheck, color: Colors.green, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your medications are stored securely on-device only',
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
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.pill, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            'No medications added',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your medications to track refills and check interactions',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.white38),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddMedication,
            icon: const Icon(LucideIcons.plus),
            label: const Text('Add Medication'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.withOpacity(0.2),
              foregroundColor: Colors.orange[200],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMedicationCard(Prescription med) {
    final needsRefill = med.needsRefillSoon;
    final isExpired = med.isExpired;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpired 
              ? Colors.red.withOpacity(0.5)
              : needsRefill 
                  ? Colors.orange.withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text('💊', style: TextStyle(fontSize: 24)),
          ),
        ),
        title: Text(
          med.displayName,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (med.strength != null)
              Text(
                '${med.strength} ${med.dosageForm ?? ""}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white60,
                ),
              ),
            if (med.directions != null)
              Text(
                med.directions!,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white38,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (needsRefill || isExpired)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isExpired ? Colors.red : Colors.orange).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isExpired ? '⚠️ Expired' : '🔔 Refill Soon',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isExpired ? Colors.red[300] : Colors.orange[300],
                    ),
                  ),
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(LucideIcons.moreVertical, color: Colors.white54),
          color: const Color(0xFF2A2A34),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(LucideIcons.edit, size: 16),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'refill',
              child: Row(
                children: [
                  Icon(LucideIcons.refreshCw, size: 16),
                  SizedBox(width: 8),
                  Text('Log Refill'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'info',
              child: Row(
                children: [
                  Icon(LucideIcons.info, size: 16),
                  SizedBox(width: 8),
                  Text('Drug Info'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(LucideIcons.trash2, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) => _handleMenuAction(value, med),
        ),
      ),
    );
  }
  
  void _handleMenuAction(String action, Prescription med) async {
    switch (action) {
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A24),
            title: const Text('Delete Medication?', style: TextStyle(color: Colors.white)),
            content: Text(
              'Remove ${med.displayName}?',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await PrescriptionService.deletePrescription(med.id);
          _loadMedications();
        }
        break;
      case 'info':
        _showDrugInfo(med);
        break;
    }
  }
  
  void _showDrugInfo(Prescription med) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24),
        title: Text(
          med.displayName,
          style: const TextStyle(color: Colors.white),
        ),
        content: FutureBuilder<DrugInfo?>(
          future: _getDrugInfo(med.medicationName),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            
            final info = snapshot.data;
            if (info == null) {
              return const Text(
                'Drug information not available',
                style: TextStyle(color: Colors.white70),
              );
            }
            
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (info.genericName != null)
                    _infoRow('Generic Name', info.genericName!),
                  if (info.manufacturer != null)
                    _infoRow('Manufacturer', info.manufacturer!),
                  if (info.dosageForm != null)
                    _infoRow('Form', info.dosageForm!),
                  if (info.warnings != null)
                    _infoSection('⚠️ Warnings', info.warnings!),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.white54)),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  Widget _infoSection(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            value.length > 500 ? '${value.substring(0, 500)}...' : value,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
  
  Future<DrugInfo?> _getDrugInfo(String drugName) async {
    final rxcui = await DrugInteractionService.getRxCui(drugName);
    if (rxcui != null) {
      return DrugInteractionService.getDrugInfo(rxcui);
    }
    return null;
  }
  
  void _showAddMedication() {
    // Navigate to prescription list/add screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add medication feature - navigate to Prescription screens')),
    );
  }
}
