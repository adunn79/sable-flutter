import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service to detect currently playing music on the device
/// Works with Spotify, Apple Music, and other music apps via system APIs
class NowPlayingService {
  static const MethodChannel _channel = MethodChannel('com.sable.nowplaying');
  
  /// Get the currently playing track info
  /// Returns null if nothing is playing or not available
  static Future<NowPlayingInfo?> getCurrentTrack() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS || 
          defaultTargetPlatform == TargetPlatform.macOS) {
        final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getNowPlaying');
        if (result != null && result['title'] != null) {
          return NowPlayingInfo(
            title: result['title'] as String,
            artist: result['artist'] as String? ?? 'Unknown Artist',
            album: result['album'] as String?,
            artworkUrl: result['artworkUrl'] as String?,
            source: result['bundleId']?.toString().contains('spotify') == true 
                ? 'spotify' 
                : 'apple_music',
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint('🎵 Now Playing error: $e');
      return null;
    }
  }
  
  /// Get formatted string for storage: "Track - Artist"
  static Future<String?> getFormattedNowPlaying() async {
    final info = await getCurrentTrack();
    if (info == null) return null;
    return '${info.title} - ${info.artist}';
  }
}

/// Data class for now playing information
class NowPlayingInfo {
  final String title;
  final String artist;
  final String? album;
  final String? artworkUrl;
  final String source; // 'spotify' or 'apple_music'
  
  NowPlayingInfo({
    required this.title,
    required this.artist,
    this.album,
    this.artworkUrl,
    required this.source,
  });
  
  @override
  String toString() => '$title - $artist';
}
