import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/theme/aureal_theme.dart';
import 'package:sable/features/subscription/services/subscription_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  SubscriptionService? _service;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    final service = await SubscriptionService.create();
    service.addListener(_onServiceUpdate);
    if (mounted) {
      setState(() {
        _service = service;
        _isLoading = false;
      });
    }
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _service?.removeListener(_onServiceUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _service == null) {
      return const Scaffold(
        backgroundColor: AurealColors.obsidian,
        body: Center(child: CircularProgressIndicator(color: AurealColors.plasmaCyan)),
      );
    }

    return Scaffold(
      backgroundColor: AurealColors.obsidian,
      appBar: AppBar(
        backgroundColor: AurealColors.obsidian,
        elevation: 0,
        title: Text(
          'SUBSCRIPTION & STORE',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCurrentStatus(),
            const SizedBox(height: 32),
            _buildSectionHeader('MEMBERSHIP TIERS'),
            const SizedBox(height: 16),
            _buildTiersList(),
            const SizedBox(height: 32),
            _buildSectionHeader('CREDIT STORE'),
            const SizedBox(height: 16),
            _buildCreditStore(),
            const SizedBox(height: 32),
            _buildSectionHeader('SMART FEATURES'),
            const SizedBox(height: 16),
            _buildSmartAdjustments(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.spaceGrotesk(
        color: AurealColors.plasmaCyan,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildCurrentStatus() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AurealColors.plasmaCyan.withOpacity(0.2),
            AurealColors.obsidian,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AurealColors.plasmaCyan.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CURRENT PLAN', style: GoogleFonts.inter(color: Colors.white70, fontSize: 10, letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(
                    _service!.getTierName(_service!.currentTier).toUpperCase(),
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Icon(LucideIcons.crown, color: AurealColors.hyperGold, size: 32),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildBalanceItem('Voice Credits', _service!.voiceCredits.toString(), LucideIcons.mic)),
              Container(width: 1, height: 40, color: Colors.white10),
              Expanded(child: _buildBalanceItem('Video Credits', _service!.videoCredits.toString(), LucideIcons.video)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white54, size: 16),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
      ],
    );
  }

  Widget _buildTiersList() {
    return SizedBox(
      height: 320,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: SubscriptionTier.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final tier = SubscriptionTier.values[index];
          final isCurrent = _service!.currentTier == tier;
          return _buildTierCard(tier, isCurrent);
        },
      ),
    );
  }

  Widget _buildTierCard(SubscriptionTier tier, bool isCurrent) {
    final price = _service!.getTierPrice(tier);
    final features = _service!.getTierFeatures(tier);
    
    return Container(
      width: 240,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCurrent ? AurealColors.plasmaCyan.withOpacity(0.1) : AurealColors.carbon,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? AurealColors.plasmaCyan : Colors.white10,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _service!.getTierName(tier).toUpperCase(),
                style: GoogleFonts.spaceGrotesk(
                  color: isCurrent ? AurealColors.plasmaCyan : Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Tooltip(
                message: 'Tap to see feature details',
                triggerMode: TooltipTriggerMode.tap,
                child: Icon(LucideIcons.info, size: 16, color: Colors.white24),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            price == 0 ? 'Free' : '\$${price.toStringAsFixed(2)}/mo',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView( // Fix Overflow
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(LucideIcons.check, size: 14, color: AurealColors.hyperGold),
                      const SizedBox(width: 8),
                      Expanded(child: Text(f, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12))),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isCurrent ? null : () => _service!.setTier(tier),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCurrent ? Colors.white10 : AurealColors.plasmaCyan,
                foregroundColor: isCurrent ? Colors.white : AurealColors.obsidian,
                disabledBackgroundColor: Colors.white10,
                disabledForegroundColor: Colors.white30,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(isCurrent ? 'CURRENT PLAN' : 'UPGRADE'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditStore() {
    return Column(
      children: [
        _buildCreditPack('Voice Pack S', '100 Credits', '\$4.99', () => _service!.addVoiceCredits(100), LucideIcons.mic),
        const SizedBox(height: 12),
        _buildCreditPack('Voice Pack L', '500 Credits', '\$19.99', () => _service!.addVoiceCredits(500), LucideIcons.mic),
        const SizedBox(height: 12),
        _buildCreditPack('Video Pack S', '50 Credits', '\$9.99', () => _service!.addVideoCredits(50), LucideIcons.video),
        const SizedBox(height: 12),
        _buildCreditPack('Video Pack L', '200 Credits', '\$29.99', () => _service!.addVideoCredits(200), LucideIcons.video),
      ],
    );
  }

  Widget _buildCreditPack(String name, String amount, String price, VoidCallback onTap, IconData icon) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AurealColors.carbon,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text(amount, style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AurealColors.plasmaCyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AurealColors.plasmaCyan.withOpacity(0.5)),
              ),
              child: Text(price, style: GoogleFonts.inter(color: AurealColors.plasmaCyan, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartAdjustments() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AurealColors.carbon,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AurealColors.hyperGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.sparkles, color: AurealColors.hyperGold, size: 20),
                  const SizedBox(width: 12),
                  Text('Smart Adjustments', style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              Switch(
                value: _service!.smartAdjustmentsEnabled,
                activeColor: AurealColors.hyperGold,
                onChanged: (val) => _service!.toggleSmartAdjustments(val),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Automatically adapts generated content based on your mood, local weather, and time of day. Uses your selected AI model.',
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 12),
          if (_service!.smartAdjustmentsEnabled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AurealColors.hyperGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.checkCircle, size: 14, color: AurealColors.hyperGold),
                  const SizedBox(width: 8),
                  Text('Active', style: GoogleFonts.inter(color: AurealColors.hyperGold, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
