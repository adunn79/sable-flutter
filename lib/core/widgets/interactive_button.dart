import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sable/src/theme/colors.dart';
import 'package:sable/core/ui/feedback_service.dart';
import 'package:sable/core/audio/button_sound_service.dart';

/// A reusable button widget with built-in haptic feedback, sound effects,
/// and optional info dialog on long-press
class InteractiveButton extends ConsumerWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? infoTitle;
  final String? infoDescription;
  final String? infoDetails;
  final String? actionLabel;
  final Color? iconColor;
  final Color? backgroundColor;
  final bool isDestructive;

  const InteractiveButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.onLongPress,
    this.infoTitle,
    this.infoDescription,
    this.infoDetails,
    this.actionLabel,
    this.iconColor,
    this.backgroundColor,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasInfo = infoTitle != null && infoDescription != null;

    return GestureDetector(
      onTap: () {
        // Play appropriate sound based on button type
        if (isDestructive) {
          ref.read(buttonSoundServiceProvider).playHeavyTap();
        } else {
          ref.read(buttonSoundServiceProvider).playMediumTap();
        }
        
        // Haptic feedback
        ref.read(feedbackServiceProvider).medium();
        
        // Execute action
        onTap();
      },
      onLongPress: hasInfo
          ? () {
              ref.read(buttonSoundServiceProvider).playLightTap();
              ref.read(feedbackServiceProvider).light();
              _showInfoDialog(context, ref);
            }
          : onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDestructive
                    ? Colors.red.withOpacity(0.3)
                    : Colors.white.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: iconColor ?? (isDestructive ? Colors.red : Colors.white),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: isDestructive ? Colors.red : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AurealColors.carbon,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Colors.red : AurealColors.plasmaCyan,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                infoTitle!,
                style: GoogleFonts.spaceGrotesk(
                  color: isDestructive ? Colors.red : AurealColors.plasmaCyan,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              infoDescription!,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            ),
            if (infoDetails != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isDestructive ? Colors.red : AurealColors.plasmaCyan)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (isDestructive ? Colors.red : AurealColors.plasmaCyan)
                        .withOpacity(0.3),
                  ),
                ),
                child: Text(
                  infoDetails!,
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'GOT IT',
              style: GoogleFonts.inter(color: Colors.white54),
            ),
          ),
          if (actionLabel != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onTap();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDestructive ? Colors.red : AurealColors.plasmaCyan,
                foregroundColor: AurealColors.obsidian,
              ),
              child: Text(
                actionLabel!,
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}
