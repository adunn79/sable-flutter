/// Floating Help Button Widget
/// Provides always-accessible help across the app

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:sable/core/ui/safe_snackbar.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sable/features/safety/screens/emergency_screen.dart';

class FloatingHelpButton extends StatefulWidget {
  const FloatingHelpButton({super.key});

  @override
  State<FloatingHelpButton> createState() => _FloatingHelpButtonState();
}

class _FloatingHelpButtonState extends State<FloatingHelpButton>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Expanded menu
          SizeTransition(
            sizeFactor: _expandAnimation,
            axisAlignment: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildMenuItem(
                  icon: LucideIcons.messageCircle,
                  label: 'Chat with Support',
                  onTap: () {
                    _toggle();
                    // Open support chat or email
                    launchUrl(Uri.parse('mailto:support@aeliana.ai?subject=Help%20Request'));
                  },
                ),
                const SizedBox(height: 8),
                _buildMenuItem(
                  icon: LucideIcons.book,
                  label: 'Help Center',
                  onTap: () {
                    _toggle();
                    context.push('/more/help');
                  },
                ),
                const SizedBox(height: 8),
                _buildMenuItem(
                  icon: LucideIcons.bug,
                  label: 'Report Bug',
                  onTap: () {
                    _toggle();
                    _showBugReportDialog(context);
                  },
                ),
                const SizedBox(height: 8),
                _buildMenuItem(
                  icon: LucideIcons.alertCircle,
                  label: 'Emergency',
                  color: Colors.red,
                  onTap: () {
                    _toggle();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EmergencyScreen()),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          
          // Main FAB
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AelianaColors.plasmaCyan,
                    AelianaColors.plasmaCyan.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AelianaColors.plasmaCyan.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: AnimatedRotation(
                duration: const Duration(milliseconds: 200),
                turns: _isExpanded ? 0.125 : 0,
                child: Icon(
                  _isExpanded ? LucideIcons.x : LucideIcons.helpCircle,
                  color: AelianaColors.obsidian,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AelianaColors.carbon,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color?.withOpacity(0.3) ?? Colors.white10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color ?? AelianaColors.plasmaCyan),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color ?? Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBugReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const BugReportDialog(),
    );
  }
}

/// Bug Report Dialog with reward potential
class BugReportDialog extends StatefulWidget {
  const BugReportDialog({super.key});

  @override
  State<BugReportDialog> createState() => _BugReportDialogState();
}

class _BugReportDialogState extends State<BugReportDialog> {
  final _descriptionController = TextEditingController();
  String _category = 'Bug';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_descriptionController.text.trim().isEmpty) {
      SafeSnackBar.showText(context, 'Please describe the issue');
      return;
    }

    setState(() => _isSubmitting = true);

    // Simulate submission
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      Navigator.pop(context);
      SafeSnackBar.showSuccess(context, '🎉 Thank you! Check your email for a reward code.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
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
              Row(
                children: [
                  Icon(LucideIcons.bug, color: AelianaColors.hyperGold, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Report an Issue',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Help us improve! Valid reports earn rewards.',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Category
              Text('Category', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['Bug', 'Crash', 'UI Issue', 'Suggestion'].map((cat) {
                  final isSelected = _category == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _category = cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AelianaColors.hyperGold.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AelianaColors.hyperGold : Colors.white10,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: GoogleFonts.inter(
                          color: isSelected ? AelianaColors.hyperGold : Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Description
              Text('Description', style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'What happened? Steps to reproduce?',
                  hintStyle: GoogleFonts.inter(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white54,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AelianaColors.hyperGold,
                        foregroundColor: AelianaColors.obsidian,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Submit & Earn Reward'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
