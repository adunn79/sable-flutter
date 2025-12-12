import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:uuid/uuid.dart';
import '../../../core/ai/character_personality.dart';
import '../models/avatar_config.dart';

class Screen45OriginRitual extends StatefulWidget {
  final AvatarConfig config;
  final String avatarImageUrl;
  final VoidCallback onComplete;

  const Screen45OriginRitual({
    super.key,
    required this.config,
    required this.avatarImageUrl,
    required this.onComplete,
  });

  @override
  State<Screen45OriginRitual> createState() => _Screen45OriginRitualState();
}

class _Screen45OriginRitualState extends State<Screen45OriginRitual> with SingleTickerProviderStateMixin {
  late final AnimationController _holdController;
  final String _uuid = const Uuid().v4().substring(0, 13).toUpperCase();
  bool _isAwakened = false;
  final GlobalKey _cardKey = GlobalKey();
  
  /// Get pronunciation for the current archetype
  String get _pronunciation {
    final personality = CharacterPersonality.all.firstWhere(
      (p) => p.id.toLowerCase() == widget.config.archetype.toLowerCase(),
      orElse: () => CharacterPersonality.aeliana,
    );
    return personality.pronunciation;
  }

  /// Get personality style for the current archetype
  String get _personalityStyle {
    final personality = CharacterPersonality.all.firstWhere(
      (p) => p.id.toLowerCase() == widget.config.archetype.toLowerCase(),
      orElse: () => CharacterPersonality.aeliana,
    );
    return personality.style;
  }

  /// Get personality tone for the current archetype
  String get _personalityTone {
    final personality = CharacterPersonality.all.firstWhere(
      (p) => p.id.toLowerCase() == widget.config.archetype.toLowerCase(),
      orElse: () => CharacterPersonality.aeliana,
    );
    return personality.tone;
  }

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2), // 2 seconds to hold
    );

    _holdController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _handleAwakening();
      }
    });
  }

  @override
  void dispose() {
    _holdController.dispose();
    super.dispose();
  }

  void _handleAwakening() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isAwakened = true;
    });

    // Flash effect and proceed
    Future.delayed(const Duration(milliseconds: 1500), () {
      widget.onComplete();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AelianaColors.obsidian,
      body: Stack(
        children: [
          // Background - subtle gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: [
                    AelianaColors.plasmaCyan.withOpacity(0.05),
                    AelianaColors.obsidian,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'YOUR COMPANION AWAITS',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                      color: AelianaColors.plasmaCyan,
                    ),
                  ).animate().fadeIn(duration: 800.ms),

                  const SizedBox(height: 20),

                  // The "Soul Bond" Card - Shareable
                  RepaintBoundary(
                    key: _cardKey,
                    child: _buildIdentityCard(),
                  ),

                  const SizedBox(height: 30),

                  // Interaction Prompt
                  if (!_isAwakened) ...[
                    Text(
                      'HOLD FINGERPRINT TO AWAKEN',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        letterSpacing: 1.5,
                        color: AelianaColors.ghost.withOpacity(0.7),
                      ),
                    ).animate(delay: 1000.ms).fadeIn(),
                    
                    const SizedBox(height: 16),
                    
                    _buildFingerprintButton(),
                  ] else ...[
                    Text(
                      'SOUL BOND COMPLETE',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: AelianaColors.hyperGold,
                      ),
                    ).animate().fadeIn().shimmer(duration: 1000.ms),
                    const SizedBox(height: 16),
                    // Share and Print buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildShareButton(),
                        const SizedBox(width: 12),
                        _buildPrintButton(),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          
          // Full screen flash overlay
          if (_isAwakened)
            IgnorePointer(
              child: Container(
                color: Colors.white,
              ).animate().fadeIn(duration: 100.ms).fadeOut(delay: 100.ms, duration: 1000.ms),
            ),
        ],
      ),
    );
  }

  Widget _buildIdentityCard() {
    // Determine if avatarImageUrl is an asset path or network URL
    final isAssetPath = widget.avatarImageUrl.startsWith('assets/');
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AelianaColors.carbon.withOpacity(0.95),
            AelianaColors.obsidian.withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: _isAwakened ? AelianaColors.hyperGold : AelianaColors.plasmaCyan.withOpacity(0.3),
          width: _isAwakened ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (_isAwakened ? AelianaColors.hyperGold : AelianaColors.plasmaCyan).withOpacity(0.3),
            blurRadius: 40,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _isAwakened ? AelianaColors.hyperGold : AelianaColors.plasmaCyan,
                width: 3,
              ),
              image: DecorationImage(
                image: isAssetPath 
                    ? AssetImage(widget.avatarImageUrl) as ImageProvider
                    : NetworkImage(widget.avatarImageUrl),
                fit: BoxFit.cover,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isAwakened ? AelianaColors.hyperGold : AelianaColors.plasmaCyan).withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // Name
          Text(
            widget.config.archetype.toUpperCase(),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          // Pronunciation - for names that are hard to pronounce
          Text(
            _pronunciation,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: AelianaColors.plasmaCyan.withOpacity(0.8),
              letterSpacing: 1,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Personality Style
          Text(
            _personalityStyle,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AelianaColors.hyperGold,
              letterSpacing: 0.5,
            ),
          ),
          
          const SizedBox(height: 6),
          
          // Personality Tone
          Text(
            _personalityTone,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AelianaColors.ghost.withOpacity(0.9),
              height: 1.4,
            ),
          ),
          
          const SizedBox(height: 24),
          
          _buildDetailRow('ORIGIN', widget.config.origin),
          _buildDetailRow('AWAKENED', DateFormat.yMMMd().format(DateTime.now()).toUpperCase()),
          _buildDetailRow('BOND ID', _uuid),
          
          const SizedBox(height: 24),
          
          // Soul Bond Seal
          Divider(color: AelianaColors.plasmaCyan.withOpacity(0.3)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.sparkles, color: AelianaColors.plasmaCyan.withOpacity(0.6), size: 12),
                  const SizedBox(width: 6),
                  Text(
                    'SOUL BOND',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10, 
                      color: AelianaColors.ghost,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              if (_isAwakened)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AelianaColors.hyperGold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.heart, color: AelianaColors.hyperGold, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'SEALED',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AelianaColors.hyperGold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ).animate().scale(duration: 300.ms, curve: Curves.elasticOut),
            ],
          ),
        ],
      ),
    ).animate(delay: 200.ms).fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0)
     .animate(target: _isAwakened ? 1 : 0).shimmer(duration: 1000.ms, color: AelianaColors.hyperGold);
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AelianaColors.ghost,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.spaceMono(
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareButton() {
    return GestureDetector(
      onTap: _shareCard,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AelianaColors.hyperGold.withOpacity(0.3),
              AelianaColors.plasmaCyan.withOpacity(0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AelianaColors.hyperGold.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.share2, color: AelianaColors.hyperGold, size: 18),
            const SizedBox(width: 10),
            Text(
              'Share Your Companion',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0);
  }

  Future<void> _shareCard() async {
    try {
      HapticFeedback.mediumImpact();
      
      // Capture the identity card as an image
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      
      final pngBytes = byteData.buffer.asUint8List();
      
      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/aeliana_companion_${widget.config.archetype.toLowerCase()}.png');
      await file.writeAsBytes(pngBytes);
      
      // Share
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'I just awakened my AI companion ${widget.config.archetype} on Aeliana! ✨',
        subject: 'My Aeliana Companion',
      );
    } catch (e) {
      debugPrint('Error sharing card: $e');
    }
  }

  Widget _buildPrintButton() {
    return GestureDetector(
      onTap: _printCard,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AelianaColors.plasmaCyan.withOpacity(0.3),
              AelianaColors.plasmaCyan.withOpacity(0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AelianaColors.plasmaCyan.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.printer, color: AelianaColors.plasmaCyan, size: 18),
            const SizedBox(width: 10),
            Text(
              'Print',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0);
  }

  Future<void> _printCard() async {
    try {
      HapticFeedback.mediumImpact();
      
      // Capture the identity card as an image
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      
      final pngBytes = byteData.buffer.asUint8List();
      
      // Create PDF with the image
      final pdf = pw.Document();
      final pdfImage = pw.MemoryImage(pngBytes);
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Center(
            child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
          ),
        ),
      );
      
      // Print
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Aeliana Companion - ${widget.config.archetype}',
      );
    } catch (e) {
      debugPrint('Error printing card: $e');
    }
  }

  Widget _buildFingerprintButton() {
    return GestureDetector(
      onTapDown: (_) {
         _holdController.forward();
         HapticFeedback.lightImpact();
      },
      onTapUp: (_) {
        if (!_isAwakened) _holdController.reverse();
      },
      onTapCancel: () {
        if (!_isAwakened) _holdController.reverse();
      },
      child: AnimatedBuilder(
        animation: _holdController,
        builder: (context, child) {
          return Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AelianaColors.carbon,
              border: Border.all(
                color: Color.lerp(AelianaColors.ghost.withOpacity(0.3), AelianaColors.hyperGold, _holdController.value)!,
                width: 2,
              ),
              boxShadow: [
                 BoxShadow(
                  color: AelianaColors.hyperGold.withOpacity(_holdController.value * 0.6),
                  blurRadius: 20 * _holdController.value,
                  spreadRadius: 2 * _holdController.value,
                 )
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Fill effect
                Container(
                  width: 80 * _holdController.value,
                  height: 80 * _holdController.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AelianaColors.hyperGold.withOpacity(0.2),
                  ),
                ),
                Icon(
                  LucideIcons.fingerprint,
                  size: 40,
                  color: Color.lerp(AelianaColors.ghost, AelianaColors.hyperGold, _holdController.value),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
