import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:markdown/markdown.dart' as md;

/// Full-screen deep dive view for news, briefings, and detailed explanations
/// Emulates ChatGPT's article view with rich formatting
class DeepDiveScreen extends StatefulWidget {
  final String title;
  final String content;
  final List<SourceReference> sources;
  final List<ArticlePreview> articles;
  final VoidCallback? onDismiss;

  const DeepDiveScreen({
    super.key,
    required this.title,
    required this.content,
    this.sources = const [],
    this.articles = const [],
    this.onDismiss,
  });

  /// Show as a modal overlay from chat
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String content,
    List<SourceReference> sources = const [],
    List<ArticlePreview> articles = const [],
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DeepDiveScreen(
        title: title,
        content: content,
        sources: sources,
        articles: articles,
        onDismiss: () => Navigator.of(context).pop(),
      ),
    );
  }

  @override
  State<DeepDiveScreen> createState() => _DeepDiveScreenState();
}

class _DeepDiveScreenState extends State<DeepDiveScreen> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;
  bool _sourcesExpanded = false;
  
  // Thinking timer
  late DateTime _startTime;
  int _thinkingSeconds = 0;
  late AnimationController _thinkingPulse;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _startTime = DateTime.now();
    _thinkingSeconds = DateTime.now().difference(_startTime).inSeconds.clamp(1, 30);
    
    // Pulse animation for thinking indicator
    _thinkingPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  void _onScroll() {
    final showButton = _scrollController.offset > 300;
    if (showButton != _showBackToTop) {
      setState(() => _showBackToTop = showButton);
    }
  }

  @override
  void dispose() {
    _thinkingPulse.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D), // ChatGPT-style dark
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thinking indicator (like ChatGPT)
                  _buildThinkingIndicator(),
                  const SizedBox(height: 20),
                  
                  // Rich markdown content
                  _buildMarkdownContent(),
                  
                  // Article cards if available
                  if (widget.articles.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _buildArticleSection(),
                  ],
                  
                  // Sources section
                  if (widget.sources.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _buildSourcesSection(),
                  ],
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          // Handle bar
          Expanded(
            child: Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Close button
          IconButton(
            icon: const Icon(LucideIcons.x, color: Colors.white54),
            onPressed: widget.onDismiss ?? () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingIndicator() {
    return AnimatedBuilder(
      animation: _thinkingPulse,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03 + _thinkingPulse.value * 0.02),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.sparkles, 
                size: 14, 
                color: Color.lerp(Colors.white24, AelianaColors.plasmaCyan, _thinkingPulse.value),
              ),
              const SizedBox(width: 8),
              Text(
                'Thought for ${_thinkingSeconds}s',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white38,
                ),
              ),
              const SizedBox(width: 6),
              Icon(LucideIcons.chevronRight, size: 12, color: Colors.white24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMarkdownContent() {
    return MarkdownBody(
      data: widget.content,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        // Headers - clean, bold, white
        h1: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.3,
        ),
        h2: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.4,
        ),
        h3: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.4,
        ),
        // Body text
        p: GoogleFonts.inter(
          fontSize: 15,
          color: Colors.white.withOpacity(0.9),
          height: 1.6,
        ),
        // Lists
        listBullet: GoogleFonts.inter(
          fontSize: 15,
          color: Colors.white.withOpacity(0.9),
        ),
        // Bold text
        strong: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        // Italic
        em: GoogleFonts.inter(
          fontStyle: FontStyle.italic,
          color: Colors.white.withOpacity(0.85),
        ),
        // Code blocks
        code: GoogleFonts.firaCode(
          fontSize: 13,
          color: AelianaColors.plasmaCyan,
          backgroundColor: Colors.white.withOpacity(0.05),
        ),
        // Block quotes
        blockquote: GoogleFonts.inter(
          fontSize: 15,
          color: Colors.white70,
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: AelianaColors.plasmaCyan.withOpacity(0.5),
              width: 3,
            ),
          ),
        ),
        blockquotePadding: const EdgeInsets.only(left: 16),
        // Spacing
        h1Padding: const EdgeInsets.only(top: 24, bottom: 12),
        h2Padding: const EdgeInsets.only(top: 20, bottom: 10),
        h3Padding: const EdgeInsets.only(top: 16, bottom: 8),
        pPadding: const EdgeInsets.only(bottom: 12),
        listIndent: 24,
        listBulletPadding: const EdgeInsets.only(right: 8),
      ),
      builders: {
        'sourceChip': SourceChipBuilder(),
      },
      inlineSyntaxes: [
        SourceChipSyntax(),
      ],
    );
  }

  Widget _buildArticleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key reporting used',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.articles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final article = widget.articles[index];
              return _buildArticleCard(article);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildArticleCard(ArticlePreview article) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: article.imageUrl != null
                ? Image.network(
                    article.imageUrl!,
                    height: 110,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                  )
                : _buildPlaceholderImage(),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Source
                Row(
                  children: [
                    Icon(LucideIcons.globe, size: 12, color: Colors.white54),
                    const SizedBox(width: 4),
                    Text(
                      article.source,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Headline
                Text(
                  article.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                // Date
                Text(
                  article.date ?? 'Today',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 110,
      color: Colors.white.withOpacity(0.05),
      child: Center(
        child: Icon(LucideIcons.image, size: 32, color: Colors.white24),
      ),
    );
  }

  Widget _buildSourcesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _sourcesExpanded = !_sourcesExpanded),
          child: Row(
            children: [
              // Source logos (stacked circles)
              SizedBox(
                width: 60,
                height: 24,
                child: Stack(
                  children: [
                    for (var i = 0; i < widget.sources.take(3).length; i++)
                      Positioned(
                        left: i * 18.0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _getSourceColor(widget.sources[i].name),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF0D0D0D), width: 2),
                          ),
                          child: Center(
                            child: Text(
                              widget.sources[i].name[0],
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Sources',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white54,
                ),
              ),
              const Spacer(),
              Icon(
                _sourcesExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                size: 16,
                color: Colors.white38,
              ),
            ],
          ),
        ),
        // Collapsible source details
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.sources.map((source) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _getSourceColor(source.name).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _getSourceColor(source.name).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _getSourceColor(source.name),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          source.name[0],
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      source.name,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    if (source.additionalCount > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '+${source.additionalCount}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ],
                ),
              )).toList(),
            ),
          ),
          crossFadeState: _sourcesExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Color _getSourceColor(String source) {
    switch (source.toLowerCase()) {
      case 'reuters':
        return const Color(0xFFFF6B00);
      case 'ap news':
      case 'ap':
        return const Color(0xFFE31B23);
      case 'bbc':
        return const Color(0xFFBB1919);
      case 'abc news':
        return const Color(0xFF0066B3);
      case 'al jazeera':
        return const Color(0xFF8B5A2B);
      default:
        return AelianaColors.plasmaCyan;
    }
  }
}

/// Source reference model
class SourceReference {
  final String name;
  final String? url;
  final int additionalCount;

  const SourceReference({
    required this.name,
    this.url,
    this.additionalCount = 0,
  });
}

/// Article preview model
class ArticlePreview {
  final String title;
  final String source;
  final String? imageUrl;
  final String? date;
  final String? url;

  const ArticlePreview({
    required this.title,
    required this.source,
    this.imageUrl,
    this.date,
    this.url,
  });
}

/// Custom inline syntax for source chips like [Reuters +2]
class SourceChipSyntax extends md.InlineSyntax {
  SourceChipSyntax() : super(r'\{([^}]+)\s*(\+\d+)?\}');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final sourceName = match.group(1)?.trim() ?? '';
    final count = match.group(2) ?? '';
    
    final element = md.Element.text('sourceChip', '$sourceName$count');
    parser.addNode(element);
    return true;
  }
}

/// Builder for source chip elements
class SourceChipBuilder extends MarkdownElementBuilder {
  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final text = element.textContent;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: Colors.white60,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
