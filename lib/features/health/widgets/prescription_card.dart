import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import '../models/prescription.dart';

/// Card widget for displaying a prescription in the list
class PrescriptionCard extends StatelessWidget {
  final Prescription prescription;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const PrescriptionCard({
    super.key,
    required this.prescription,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isLowRefills = (prescription.refillsRemaining ?? 0) <= 1;
    final isExpiringSoon = _isExpiringSoon();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AelianaColors.obsidian,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLowRefills || isExpiringSoon
                ? Colors.orange.withValues(alpha: 0.5)
                : Colors.white12,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Medication icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AelianaColors.plasmaCyan.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    LucideIcons.pill,
                    color: AelianaColors.plasmaCyan,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Name and strength
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prescription.displayName,
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (prescription.strength.isNotEmpty)
                        Text(
                          prescription.strength,
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                // More options
                PopupMenuButton<String>(
                  icon: const Icon(LucideIcons.moreVertical, color: Colors.white54, size: 20),
                  color: AelianaColors.carbon,
                  onSelected: (value) {
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(LucideIcons.trash2, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Text('Delete', style: GoogleFonts.inter(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Directions
            if (prescription.directions.isNotEmpty) ...[
              Text(
                prescription.directions,
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
            ],
            
            // Info chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (prescription.refillsRemaining != null)
                  _buildChip(
                    '${prescription.refillsRemaining} refills',
                    isLowRefills ? Colors.orange : Colors.white54,
                    LucideIcons.refreshCw,
                  ),
                if (prescription.pharmacyName != null)
                  _buildChip(
                    prescription.pharmacyName!,
                    Colors.white54,
                    LucideIcons.building2,
                  ),
                if (prescription.dateFilled != null)
                  _buildChip(
                    'Filled ${_formatDate(prescription.dateFilled!)}',
                    Colors.white54,
                    LucideIcons.calendar,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  bool _isExpiringSoon() {
    if (prescription.daysSupply == null || prescription.dateFilled == null) {
      return false;
    }
    final expiryDate = prescription.dateFilled!.add(
      Duration(days: prescription.daysSupply!),
    );
    final daysUntilExpiry = expiryDate.difference(DateTime.now()).inDays;
    return daysUntilExpiry <= 7 && daysUntilExpiry > 0;
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }
}
