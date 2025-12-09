import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/theme/aeliana_theme.dart';

class LegalViewerScreen extends StatelessWidget {
  final String title;
  final String content;

  const LegalViewerScreen({
    super.key,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AelianaColors.obsidian,
      appBar: AppBar(
        backgroundColor: AelianaColors.obsidian,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            color: AelianaColors.hyperGold,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Markdown(
        data: content,
        styleSheet: MarkdownStyleSheet(
          h1: GoogleFonts.spaceGrotesk(
            color: AelianaColors.hyperGold,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          h2: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          h3: GoogleFonts.spaceGrotesk(
            color: Colors.white70,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          p: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 15,
            height: 1.6,
          ),
          strong: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          listBullet: const TextStyle(color: AelianaColors.plasmaCyan),
          blockSpacing: 16,
        ),
        padding: const EdgeInsets.all(24),
      ),
    );
  }
}
