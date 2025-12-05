import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/theme/aureal_theme.dart';
import 'package:sable/features/onboarding/services/onboarding_state_service.dart';
import 'package:sable/core/theme/aureal_theme.dart';
import 'package:sable/features/onboarding/services/onboarding_state_service.dart';
// import 'package:local_auth/local_auth.dart'; // Determine if we can use this later, or just mock for now

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  bool _isUnlocked = false;
  bool _isAuthenticating = false;
  List<String> _memories = [];
  OnboardingStateService? _stateService;

  @override
  void initState() {
    super.initState();
    _authenticate(); // Auto-auth on load
  }

  Future<void> _authenticate() async {
    setState(() => _isAuthenticating = true);
    
    // Simulate Biometric/FaceID delay
    await Future.delayed(const Duration(seconds: 1));
    
    // In a real implementation:
    // final auth = LocalAuthentication();
    // final didAuthenticate = await auth.authenticate(...);
    
    // For now, we simulate success for the "Privacy Fortress" feel
    if (mounted) {
      setState(() {
        _isUnlocked = true;
        _isAuthenticating = false;
      });
      _loadMemories();
    }
  }
  
  Future<void> _loadMemories() async {
    final service = await OnboardingStateService.create();
    if (mounted) {
      setState(() {
        _stateService = service;
        _memories = service.memoryItems;
      });
    }
  }

  Future<void> _deleteMemory(int index) async {
    await _stateService?.removeMemoryItem(index);
    _loadMemories();
  }

  Future<void> _wipeAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A1010), // Dark Red
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.red.withOpacity(0.5), width: 2),
        ),
        title: Row(
          children: [
            const Icon(LucideIcons.alertTriangle, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'IRREVERSIBLE ACTION',
                style: GoogleFonts.spaceGrotesk(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to wipe everything?',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              'This will permanently delete ALL memories, learned facts, and preferences.\n\nThis action cannot be undone.',
              style: GoogleFonts.inter(color: Colors.white70, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCEL', style: GoogleFonts.inter(color: Colors.white54, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text('YES, DELETE EVERYTHING', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _stateService?.wipeAllMemory();
      if (mounted) {
        Navigator.pop(context); // Close vault
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Memory wiped successfully.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isUnlocked) {
      return Scaffold(
        backgroundColor: AurealColors.obsidian,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.lock, size: 64, color: AurealColors.plasmaCyan),
              const SizedBox(height: 24),
              Text(
                'THE VAULT',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontSize: 24,
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isAuthenticating ? 'Verifying Credentials...' : 'Biometric Auth Required',
                style: GoogleFonts.inter(color: AurealColors.stardust, fontSize: 14),
              ),
              if (_isAuthenticating)
                const Padding(
                  padding: EdgeInsets.only(top: 32),
                  child: CircularProgressIndicator(color: AurealColors.plasmaCyan),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AurealColors.obsidian,
      appBar: AppBar(
        backgroundColor: AurealColors.obsidian,
        title: Text(
          'THE VAULT',
          style: GoogleFonts.spaceGrotesk(
            color: AurealColors.plasmaCyan,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.trash2, color: Colors.red),
            onPressed: _wipeAll,
            tooltip: 'Wipe All Memory',
          )
        ],
      ),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AurealColors.plasmaCyan.withOpacity(0.1), Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                const Icon(LucideIcons.brainCircuit, color: AurealColors.plasmaCyan, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Zero-Knowledge Zone',
                  style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Structured data and memories stored locally. Not accessible by native apps unless exported.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          
          // Memory List
          Expanded(
            child: _memories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.fileX, color: Colors.white24, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'No memories stored yet.',
                          style: GoogleFonts.inter(color: Colors.white30),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _memories.length,
                    itemBuilder: (context, index) {
                      final item = _memories[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AurealColors.carbon,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: ListTile(
                          leading: const Icon(LucideIcons.database, color: AurealColors.plasmaCyan, size: 20),
                          title: Text(
                            item,
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                          ),
                          trailing: IconButton(
                            icon: const Icon(LucideIcons.x, color: Colors.white54, size: 18),
                            onPressed: () => _deleteMemory(index),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // Big Delete Button for the list (redundant with AppBar but requested)
          if (_memories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _wipeAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.1),
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.alertOctagon, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'WIPE ALL MEMORY',
                        style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
