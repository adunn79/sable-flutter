import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sable/core/theme/aeliana_theme.dart';

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value; // Text shown on right, e.g. "On"
  final Widget? trailing; // Custom widget, overrides value/chevron
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool isDestructive;
  final bool showChevron;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.isDestructive = false,
    this.showChevron = true,
  });

  factory SettingsTile.switchTile({
    Key? key,
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? iconColor,
  }) {
    return SettingsTile(
      key: key,
      icon: icon,
      title: title,
      subtitle: subtitle,
      iconColor: iconColor,
      showChevron: false,
      onTap: () => onChanged(!value),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AelianaColors.hyperGold,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (iconColor ?? AelianaColors.hyperGold).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: iconColor ?? AelianaColors.hyperGold,
                ),
              ),
              const SizedBox(width: 16),
              
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDestructive ? Colors.red : AelianaColors.stardust,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AelianaColors.ghost,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Trailing
              if (trailing != null) 
                Flexible(child: trailing!)
              else ...[
                if (value != null)
                  Flexible(
                    child: Text(
                      value!,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: AelianaColors.ghost.withOpacity(0.8),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (showChevron && onTap != null) ...[
                   const SizedBox(width: 8),
                   const Icon(Icons.chevron_right, color: Colors.white24, size: 20),
                ]
              ],
            ],
          ),
        ),
      ),
    );
  }
}
