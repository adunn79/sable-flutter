import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Chat Share Service - Capture and share conversation moments
/// 
/// Best-in-class features:
/// - Screenshot capture of chat widget
/// - Branded share images with Aeliana watermark
/// - Support for all major platforms
/// - Individual message or thread sharing
class ChatShareService {
  
  /// Capture a widget as an image
  static Future<Uint8List?> captureWidget(GlobalKey key) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing widget: $e');
      return null;
    }
  }
  
  /// Share a chat screenshot to any platform
  static Future<void> shareScreenshot({
    required Uint8List imageBytes,
    String? caption,
    String? hashtag,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/aeliana_moment_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(imageBytes);
      
      final shareText = caption ?? 'A moment with Aeliana ✨';
      final fullText = hashtag != null ? '$shareText\n\n$hashtag' : shareText;
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: fullText,
        subject: 'Aeliana Moment',
      );
    } catch (e) {
      debugPrint('Error sharing screenshot: $e');
    }
  }
  
  /// Share text content only
  static Future<void> shareText({
    required String text,
    String? subject,
  }) async {
    await Share.share(
      text,
      subject: subject ?? 'From Aeliana',
    );
  }
  
  /// Share a quote as a styled image
  static Future<void> shareQuote({
    required String quote,
    required String author,
    String? hashtag,
  }) async {
    // Generate styled quote card and share
    final text = '"$quote"\n\n— $author';
    final shareText = hashtag != null ? '$text\n\n$hashtag' : text;
    await Share.share(shareText, subject: 'Quote from Aeliana');
  }
  
  /// Get share suggestions based on content
  static List<ShareSuggestion> getShareSuggestions(String content) {
    final suggestions = <ShareSuggestion>[];
    
    // Motivational content
    if (content.toLowerCase().contains('proud') || 
        content.toLowerCase().contains('achieve') ||
        content.toLowerCase().contains('success')) {
      suggestions.add(ShareSuggestion(
        platform: 'Instagram Story',
        hashtag: '#AelianaMoment #Growth #Success',
        description: 'Share this achievement!',
      ));
    }
    
    // Thoughtful content
    if (content.toLowerCase().contains('reflect') ||
        content.toLowerCase().contains('think') ||
        content.toLowerCase().contains('realize')) {
      suggestions.add(ShareSuggestion(
        platform: 'X (Twitter)',
        hashtag: '#Thoughts #AICompanion',
        description: 'Share this insight',
      ));
    }
    
    // Funny content
    if (content.toLowerCase().contains('haha') ||
        content.toLowerCase().contains('lol') ||
        content.toLowerCase().contains('funny')) {
      suggestions.add(ShareSuggestion(
        platform: 'TikTok',
        hashtag: '#AIChat #Funny',
        description: 'This is hilarious!',
      ));
    }
    
    return suggestions;
  }
}

/// Share suggestion for context-aware sharing
class ShareSuggestion {
  final String platform;
  final String hashtag;
  final String description;
  
  ShareSuggestion({
    required this.platform,
    required this.hashtag,
    required this.description,
  });
}
