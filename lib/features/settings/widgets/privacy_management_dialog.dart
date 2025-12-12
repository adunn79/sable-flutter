/// Privacy Management Dialog
/// Account deletion and data export with GDPR/CCPA compliant flows

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:sable/core/services/user_data_service.dart';
import 'package:sable/core/widgets/restart_widget.dart';

class PrivacyManagementDialog extends StatefulWidget {
  const PrivacyManagementDialog({super.key});
  
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const PrivacyManagementDialog(),
    );
  }

  @override
  State<PrivacyManagementDialog> createState() => _PrivacyManagementDialogState();
}

class _PrivacyManagementDialogState extends State<PrivacyManagementDialog> {
  bool _isExporting = false;
  bool _isDeleting = false;
  Map<String, int> _stats = {};
  String? _exportPath;
  
  @override
  void initState() {
    super.initState();
    _loadStats();
  }
  
  Future<void> _loadStats() async {
    final stats = await UserDataService.instance.getDataStatistics();
    if (mounted) {
      setState(() => _stats = stats);
    }
  }
  
  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    
    await UserDataService.instance.shareExportedData();
    
    if (mounted) {
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📦 Data export ready for sharing'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  
  Future<void> _confirmDeleteAccount() async {
    // First confirmation
    final confirm1 = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AelianaColors.carbon,
        title: Row(
          children: [
            Icon(LucideIcons.alertTriangle, color: Colors.red, size: 24),
            const SizedBox(width: 12),
            Text('Delete Account?', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete:',
              style: GoogleFonts.inter(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            _buildDeleteItem('${_stats['chat_messages'] ?? 0} chat messages'),
            _buildDeleteItem('${_stats['memories'] ?? 0} memories'),
            _buildDeleteItem('${_stats['journal_entries'] ?? 0} journal entries'),
            _buildDeleteItem('All settings and preferences'),
            _buildDeleteItem('Private Space data'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Text(
                '⚠️ This action cannot be undone. We recommend exporting your data first.',
                style: GoogleFonts.inter(color: Colors.red[300], fontSize: 13),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('I Understand', style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirm1 != true) return;
    
    // Second confirmation - type to confirm
    final confirm2 = await showDialog<bool>(
      context: context,
      builder: (context) => _TypeToConfirmDialog(),
    );
    
    if (confirm2 != true) return;
    
    // Execute deletion
    setState(() => _isDeleting = true);
    
    final success = await UserDataService.instance.deleteAllUserData(confirmDeletion: true);
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted. Goodbye! 👋'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Restart app to onboarding
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          RestartWidget.restartApp(context);
        }
      } else {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deletion failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Widget _buildDeleteItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(LucideIcons.trash2, size: 14, color: Colors.red),
          const SizedBox(width: 8),
          Text(text, style: GoogleFonts.inter(color: Colors.white60, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: AelianaColors.carbon,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Padding(
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
                    decoration: BoxDecoration(
                      color: AelianaColors.plasmaCyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(LucideIcons.shield, color: AelianaColors.plasmaCyan, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR DATA',
                          style: GoogleFonts.spaceGrotesk(
                            color: AelianaColors.plasmaCyan,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          'Export or delete your data',
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Data Statistics
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR DATA INCLUDES',
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 10,
                        letterSpacing: 1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStatItem('Messages', _stats['chat_messages'] ?? 0, LucideIcons.messageSquare),
                        _buildStatItem('Memories', _stats['memories'] ?? 0, LucideIcons.brain),
                        _buildStatItem('Journal', _stats['journal_entries'] ?? 0, LucideIcons.book),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Export Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isExporting ? null : _exportData,
                  icon: _isExporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(LucideIcons.download),
                  label: Text(_isExporting ? 'Preparing...' : 'Export My Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AelianaColors.plasmaCyan,
                    foregroundColor: AelianaColors.obsidian,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Delete Account Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isDeleting ? null : _confirmDeleteAccount,
                  icon: _isDeleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                        )
                      : const Icon(LucideIcons.trash2),
                  label: Text(_isDeleting ? 'Deleting...' : 'Delete My Account'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              Center(
                child: Text(
                  'GDPR & CCPA Compliant',
                  style: GoogleFonts.inter(color: Colors.white24, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatItem(String label, int count, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white38, size: 18),
          const SizedBox(height: 6),
          Text(
            count.toString(),
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

/// Type-to-confirm dialog for account deletion
class _TypeToConfirmDialog extends StatefulWidget {
  @override
  State<_TypeToConfirmDialog> createState() => _TypeToConfirmDialogState();
}

class _TypeToConfirmDialogState extends State<_TypeToConfirmDialog> {
  final _controller = TextEditingController();
  static const _confirmText = 'DELETE';
  bool _canConfirm = false;
  
  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _canConfirm = _controller.text.toUpperCase() == _confirmText;
      });
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AelianaColors.carbon,
      title: Text(
        'Type DELETE to confirm',
        style: GoogleFonts.spaceGrotesk(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'This is your final chance to cancel. Type DELETE below to permanently remove your account.',
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.red,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
            decoration: InputDecoration(
              hintText: 'DELETE',
              hintStyle: GoogleFonts.spaceGrotesk(
                color: Colors.white24,
                fontSize: 20,
                letterSpacing: 4,
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
        ),
        TextButton(
          onPressed: _canConfirm ? () => Navigator.pop(context, true) : null,
          child: Text(
            'Delete Forever',
            style: GoogleFonts.inter(
              color: _canConfirm ? Colors.red : Colors.red.withOpacity(0.3),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
