import 'package:flutter/foundation.dart';

class MusicService {
  /// Get the currently playing track
  /// Returns a map with 'track' and 'artist' keys if successful, or null if nothing playing/detected
  static Future<Map<String, String>?> getNowPlaying() async {
    // TODO: Implement native platform channel or use a plugin like 'flutter_media_metadata'
    // For now, we'll simulate a delay and return null (or mock data for testing if needed)
    
    // In a real implementation, you would uses:
    // try {
    //   final metadata = await FlutterMediaMetadata.extractMetadata();
    //   return {
    //     'track': metadata.trackName ?? 'Unknown Track',
    //     'artist': metadata.artistName ?? 'Unknown Artist',
    //   };
    // } catch (e) { ... }
    
    await Future.delayed(const Duration(milliseconds: 500));
    return null; 
  }

  /// Search for a track (Manual entry support)
  /// This would ideally connect to Spotify/Apple Music API
  static Future<List<Map<String, String>>> searchTrack(String query) async {
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Mock results for demonstration/testing
    if (query.toLowerCase().contains('sky')) {
      return [
        {'track': 'A Sky Full of Stars', 'artist': 'Coldplay'},
        {'track': 'Blue Sky', 'artist': 'Electric Light Orchestra'},
      ];
    }
    
    return [
      {'track': query, 'artist': 'Unknown Artist'},
    ];
  }
}
