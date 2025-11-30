import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sable/core/theme/aureal_theme.dart';
import 'package:sable/core/identity/bond_engine.dart';
import 'package:sable/features/settings/widgets/settings_tile.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _newsEnabled = true;
  bool _gpsEnabled = false;

  @override
  Widget build(BuildContext context) {
    final bondState = ref.watch(bondEngineProvider);

    return Scaffold(
      backgroundColor: AurealColors.obsidian,
      appBar: AppBar(
        backgroundColor: AurealColors.obsidian,
        title: Text(
          'SETTINGS',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        children: [
          // Emergency Services (Prominent)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              border: Border.all(color: Colors.red.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SettingsTile(
              title: 'Emergency Services',
              subtitle: 'Get help immediately',
              icon: Icons.emergency,
              iconColor: Colors.red,
              onTap: () {
                // TODO: Implement emergency call/info
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Emergency protocols activated.')),
                );
              },
            ),
          ),

          _buildSectionHeader('ACCOUNT'),
          const SettingsTile(
            title: 'Profile',
            subtitle: 'Manage your identity',
            icon: Icons.person_outline,
          ),
          const SettingsTile(
            title: 'Subscription',
            subtitle: 'Aureal Pro Active',
            icon: Icons.diamond_outlined,
          ),

          _buildSectionHeader('PRIVACY FORTRESS'),
          const SettingsTile(
            title: 'The Vault',
            subtitle: 'Zero-Knowledge Zone',
            icon: Icons.lock_outline,
          ),
          SettingsTile(
            title: 'How we use your info',
            subtitle: 'Data usage & protection policy',
            icon: Icons.shield_outlined,
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AurealColors.carbon,
                  title: Text('Data Privacy', style: GoogleFonts.spaceGrotesk(color: Colors.white)),
                  content: Text(
                    'Your data is encrypted locally. We do not sell your personal information. '
                    'Conversations are processed for response generation only and are not stored permanently on our servers without your consent.',
                    style: GoogleFonts.inter(color: AurealColors.stardust),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
          SettingsTile(
            title: 'Forget Last Interaction',
            subtitle: 'Remove from short-term memory',
            icon: Icons.history,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Memory shredded.')),
              );
            },
          ),
          SettingsTile(
            title: 'Wipe Memory',
            subtitle: 'Reset Bond Graph completely',
            icon: Icons.delete_forever,
            isDestructive: true,
            onTap: () {
              // TODO: Implement nuclear wipe
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Nuclear wipe initiated...')),
              );
            },
          ),

          _buildSectionHeader('REAL-WORLD AWARENESS'),
          SettingsTile(
            title: 'Daily Briefing',
            subtitle: 'News injection (max 1/24h)',
            icon: Icons.newspaper,
            trailing: Switch(
              value: _newsEnabled,
              activeColor: AurealColors.hyperGold,
              onChanged: (val) => setState(() => _newsEnabled = val),
            ),
          ),
          SettingsTile(
            title: 'Local Guide',
            subtitle: 'GPS suggestions',
            icon: Icons.location_on_outlined,
            trailing: Switch(
              value: _gpsEnabled,
              activeColor: AurealColors.hyperGold,
              onChanged: (val) => setState(() => _gpsEnabled = val),
            ),
          ),

          _buildSectionHeader('BOND ENGINE'),
          SettingsTile(
            title: 'Connection Status',
            subtitle: bondState.name.toUpperCase(),
            icon: Icons.favorite_border,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getBondColor(bondState).withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _getBondColor(bondState)),
              ),
              child: Text(
                bondState.name.toUpperCase(),
                style: GoogleFonts.inter(
                  color: _getBondColor(bondState),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SettingsTile(
            title: 'Reset Bond',
            subtitle: 'Return to Neutral state',
            icon: Icons.refresh,
            onTap: () {
              ref.read(bondEngineProvider.notifier).resetToNeutral();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bond reset to Neutral.')),
              );
            },
          ),

          _buildSectionHeader('SUPPORT'),
          const SettingsTile(
            title: 'Contact Us',
            subtitle: 'support@aureal.ai',
            icon: Icons.mail_outline,
          ),
          const SettingsTile(
            title: 'Help Center',
            subtitle: 'FAQ & Guides',
            icon: Icons.help_outline,
          ),

          _buildSectionHeader('ABOUT'),
          const SettingsTile(
            title: 'Version',
            subtitle: '1.0.0 (Build 102)',
            icon: Icons.info_outline,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
      child: Text(
        title,
        style: GoogleFonts.spaceGrotesk(
          color: AurealColors.plasmaCyan,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Color _getBondColor(BondState state) {
    switch (state) {
      case BondState.warm:
        return AurealColors.hyperGold;
      case BondState.neutral:
        return Colors.blue;
      case BondState.cooled:
        return Colors.cyan;
    }
  }
}
