import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:sable/features/web/services/web_search_service.dart';
import 'package:sable/core/ai/model_orchestrator.dart';

/// Full-screen news detail viewer for expanded news stories
/// Provides a beautiful, readable layout for detailed news coverage
class NewsDetailScreen extends StatefulWidget {
  final String topic;
  final String? initialContent; // Optional pre-loaded content
  
  const NewsDetailScreen({
    super.key,
    required this.topic,
    this.initialContent,
  });
  
  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  String? _content;
  bool _isLoading = true;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    if (widget.initialContent != null) {
      _content = widget.initialContent;
      _isLoading = false;
    } else {
      _loadDetailedNews();
    }
  }
  
  Future<void> _loadDetailedNews() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      
      // Use WebSearchService for balanced news report
      final orchestrator = ModelOrchestrator();
      final webSearchService = WebSearchService(orchestrator: orchestrator);
      
      final report = await webSearchService.getBalancedNewsReport(widget.topic);
      
      if (mounted) {
        setState(() {
          _content = report;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load news: $e';
          _isLoading = false;
        });
      }
    }
  }
  
  void _shareNews() {
    if (_content != null) {
      Share.share(
        '📰 ${widget.topic}\n\n$_content\n\n— Shared from Aeliana',
        subject: widget.topic,
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AelianaColors.deepSpace : Colors.grey[100],
      appBar: AppBar(
        backgroundColor: isDark ? AelianaColors.carbon : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.x, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'NEWS DETAIL',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_content != null)
            IconButton(
              icon: Icon(LucideIcons.share2, color: AelianaColors.plasmaCyan),
              onPressed: _shareNews,
            ),
          IconButton(
            icon: Icon(LucideIcons.refreshCw, color: isDark ? Colors.white54 : Colors.black54),
            onPressed: _loadDetailedNews,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState(isDark)
            : _error != null
                ? _buildErrorState(isDark)
                : _buildContent(isDark),
      ),
    );
  }
  
  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(AelianaColors.plasmaCyan),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Researching...',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.topic,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.alertTriangle,
              size: 48,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load news',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadDetailedNews,
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AelianaColors.plasmaCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildContent(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Topic Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AelianaColors.plasmaCyan.withOpacity(0.15),
                  AelianaColors.hyperGold.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AelianaColors.plasmaCyan.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.newspaper,
                      color: AelianaColors.plasmaCyan,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'DETAILED ANALYSIS',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: AelianaColors.plasmaCyan,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.topic,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Content
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AelianaColors.carbon : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: MarkdownBody(
              data: _content ?? '',
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                h1: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                h2: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                h3: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AelianaColors.plasmaCyan,
                ),
                p: GoogleFonts.inter(
                  fontSize: 15,
                  height: 1.6,
                  color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                ),
                listBullet: GoogleFonts.inter(
                  fontSize: 15,
                  color: AelianaColors.plasmaCyan,
                ),
                blockquote: GoogleFonts.inter(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                blockquoteDecoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: AelianaColors.hyperGold,
                      width: 3,
                    ),
                  ),
                ),
                strong: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                em: GoogleFonts.inter(
                  fontStyle: FontStyle.italic,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                horizontalRuleDecoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.white24 : Colors.black12,
                    ),
                  ),
                ),
              ),
              onTapLink: (text, href, title) async {
                if (href == null) return;
                final uri = Uri.tryParse(href);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Footer
          Center(
            child: Text(
              'Powered by Aeliana AI',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
