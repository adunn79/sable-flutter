import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sable/core/theme/aeliana_theme.dart';
import 'package:sable/features/inspiration/daily_quote_service.dart';

/// Shareable Quote Card Widget
/// 
/// Displays a daily quote with share functionality to all social platforms.
/// Used in Vital Balance screen and can be reused elsewhere.
class ShareableQuoteCard extends StatefulWidget {
  final bool showSableObservation; // True = dark humor, False = motivational
  final String? mood; // Optional mood for quote selection
  
  const ShareableQuoteCard({
    super.key,
    this.showSableObservation = false,
    this.mood,
  });

  @override
  State<ShareableQuoteCard> createState() => _ShareableQuoteCardState();
}

class _ShareableQuoteCardState extends State<ShareableQuoteCard> {
  late Quote _currentQuote;
  bool _isSharing = false;
  
  @override
  void initState() {
    super.initState();
    _refreshQuote();
  }
  
  void _refreshQuote() {
    setState(() {
      if (widget.showSableObservation) {
        _currentQuote = DailyQuoteService.getSableObservation();
      } else {
        _currentQuote = DailyQuoteService.getDailyQuote(mood: widget.mood);
      }
    });
  }

  Future<void> _shareQuote() async {
    setState(() => _isSharing = true);
    
    final shareText = widget.showSableObservation
        ? '''"${_currentQuote.text}"

— Sable's Observation ✨
Shared from Aeliana AI
aeliana.ai'''
        : '''"${_currentQuote.text}"

— ${_currentQuote.author ?? 'Aeliana'} ✨
Shared from Aeliana AI
aeliana.ai''';
    
    await Share.share(
      shareText,
      subject: 'A thought from Aeliana',
    );
    
    setState(() => _isSharing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.showSableObservation
              ? [
                  Colors.purple.withOpacity(0.15),
                  AelianaColors.obsidian.withOpacity(0.8),
                ]
              : [
                  AelianaColors.plasmaCyan.withOpacity(0.1),
                  Colors.purple.withOpacity(0.2),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.showSableObservation
              ? Colors.purple.withOpacity(0.3)
              : AelianaColors.plasmaCyan.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                widget.showSableObservation 
                    ? LucideIcons.sparkle
                    : LucideIcons.quote,
                size: 16,
                color: widget.showSableObservation 
                    ? Colors.purple.shade200
                    : AelianaColors.plasmaCyan,
              ),
              const SizedBox(width: 8),
              Text(
                widget.showSableObservation 
                    ? 'Sable\'s Observation' 
                    : 'Daily Inspiration',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              // Refresh button
              GestureDetector(
                onTap: _refreshQuote,
                child: Icon(
                  LucideIcons.refreshCw,
                  size: 16,
                  color: Colors.white38,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Quote text
          Text(
            '"${_currentQuote.text}"',
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: Colors.white,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
          
          // Author (if not Sable observation)
          if (!widget.showSableObservation && _currentQuote.author != null) ...[
            const SizedBox(height: 12),
            Text(
              '— ${_currentQuote.author}',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white54,
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Share buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Share button
              GestureDetector(
                onTap: _isSharing ? null : _shareQuote,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AelianaColors.plasmaCyan.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AelianaColors.plasmaCyan.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.share2,
                        size: 14,
                        color: _isSharing ? Colors.white38 : Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isSharing ? 'Sharing...' : 'Share',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _isSharing ? Colors.white38 : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
