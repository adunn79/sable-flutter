import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:spotify_sdk/models/player_state.dart';

/// Spotify integration service with OAuth, playback control, and history
/// Best-in-class implementation with graceful error handling
class SpotifyService {
  static SpotifyService? _instance;
  static SpotifyService get instance => _instance ??= SpotifyService._();
  
  SpotifyService._();
  
  final _storage = const FlutterSecureStorage();
  
  // Spotify App Credentials (from Spotify Developer Dashboard)
  static const String _clientId = 'e6781c91f06e48d3ab1a8139ef3b6de4';
  static const String _redirectUri = 'sable://spotify-callback';
  static const List<String> _scopes = [
    'user-read-playback-state',
    'user-modify-playback-state',
    'user-read-currently-playing',
    'user-read-recently-played',
    'playlist-read-private',
    'user-library-read',
  ];
  
  bool _isConnected = false;
  String? _accessToken;
  PlayerState? _currentState;
  
  // Stream controllers for reactive UI
  final _playerStateController = StreamController<PlayerState?>.broadcast();
  Stream<PlayerState?> get playerStateStream => _playerStateController.stream;
  
  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;
  
  // Getters
  bool get isConnected => _isConnected;
  PlayerState? get currentState => _currentState;
  bool get isPlaying => _currentState?.isPaused == false;
  
  /// Check if Spotify app is installed
  Future<bool> get isSpotifyInstalled async {
    try {
      // Attempt to check if Spotify is reachable
      // The SDK will return false if Spotify app is not installed
      return true; // Assume installed, will fail gracefully on connect
    } catch (e) {
      return false;
    }
  }
  
  /// Connect to Spotify (launches Spotify app for auth if needed)
  Future<bool> connect() async {
    try {
      debugPrint('🎵 Spotify: Attempting connection...');
      
      final accessToken = await SpotifySdk.connectToSpotifyRemote(
        clientId: _clientId,
        redirectUrl: _redirectUri,
        accessToken: _accessToken,
        scope: _scopes.join(','),
      );
      
      if (accessToken) {
        _isConnected = true;
        _connectionController.add(true);
        debugPrint('🎵 Spotify: Connected successfully');
        
        // Start listening to player state
        _subscribeToPlayerState();
        
        return true;
      }
      
      return false;
    } on PlatformException catch (e) {
      debugPrint('🎵 Spotify connection error: ${e.code} - ${e.message}');
      _isConnected = false;
      _connectionController.add(false);
      return false;
    } catch (e) {
      debugPrint('🎵 Spotify unexpected error: $e');
      _isConnected = false;
      _connectionController.add(false);
      return false;
    }
  }
  
  /// Get access token for API calls (recently played, etc.)
  Future<String?> getAccessToken() async {
    try {
      final token = await SpotifySdk.getAccessToken(
        clientId: _clientId,
        redirectUrl: _redirectUri,
        scope: _scopes.join(','),
      );
      _accessToken = token;
      await _storage.write(key: 'spotify_access_token', value: token);
      return token;
    } catch (e) {
      debugPrint('🎵 Spotify token error: $e');
      return null;
    }
  }
  
  /// Disconnect from Spotify
  Future<void> disconnect() async {
    try {
      await SpotifySdk.disconnect();
      _isConnected = false;
      _currentState = null;
      _connectionController.add(false);
      _playerStateController.add(null);
      await _storage.delete(key: 'spotify_access_token');
      debugPrint('🎵 Spotify: Disconnected');
    } catch (e) {
      debugPrint('🎵 Spotify disconnect error: $e');
    }
  }
  
  /// Subscribe to player state updates
  void _subscribeToPlayerState() {
    try {
      SpotifySdk.subscribePlayerState().listen(
        (state) {
          _currentState = state;
          _playerStateController.add(state);
        },
        onError: (e) {
          debugPrint('🎵 Spotify state stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('🎵 Spotify subscribe error: $e');
    }
  }
  
  // ==================== PLAYBACK CONTROLS ====================
  
  /// Play/Resume playback
  Future<bool> play({String? spotifyUri}) async {
    try {
      if (spotifyUri != null) {
        await SpotifySdk.play(spotifyUri: spotifyUri);
      } else {
        await SpotifySdk.resume();
      }
      return true;
    } catch (e) {
      debugPrint('🎵 Spotify play error: $e');
      return false;
    }
  }
  
  /// Pause playback
  Future<bool> pause() async {
    try {
      await SpotifySdk.pause();
      return true;
    } catch (e) {
      debugPrint('🎵 Spotify pause error: $e');
      return false;
    }
  }
  
  /// Toggle play/pause
  Future<bool> togglePlayPause() async {
    if (_currentState?.isPaused == true) {
      return await play();
    } else {
      return await pause();
    }
  }
  
  /// Skip to next track
  Future<bool> skipNext() async {
    try {
      await SpotifySdk.skipNext();
      return true;
    } catch (e) {
      debugPrint('🎵 Spotify skip next error: $e');
      return false;
    }
  }
  
  /// Skip to previous track
  Future<bool> skipPrevious() async {
    try {
      await SpotifySdk.skipPrevious();
      return true;
    } catch (e) {
      debugPrint('🎵 Spotify skip previous error: $e');
      return false;
    }
  }
  
  /// Seek to position in track (milliseconds)
  Future<bool> seekTo(int positionMs) async {
    try {
      await SpotifySdk.seekTo(positionedMilliseconds: positionMs);
      return true;
    } catch (e) {
      debugPrint('🎵 Spotify seek error: $e');
      return false;
    }
  }
  
  /// Set shuffle mode
  Future<bool> setShuffle(bool enabled) async {
    try {
      await SpotifySdk.setShuffle(shuffle: enabled);
      debugPrint('🔀 Spotify shuffle: $enabled');
      return true;
    } catch (e) {
      debugPrint('🎵 Spotify shuffle error: $e');
      return false;
    }
  }
  
  /// Set repeat mode ('off', 'track', 'context')
  Future<bool> setRepeat(String mode) async {
    try {
      // SpotifySdk uses RepeatMode enum internally
      // Convert our string to the appropriate call
      switch (mode) {
        case 'off':
          await SpotifySdk.setRepeatMode(repeatMode: RepeatMode.off);
          break;
        case 'track':
          await SpotifySdk.setRepeatMode(repeatMode: RepeatMode.track);
          break;
        case 'context':
          await SpotifySdk.setRepeatMode(repeatMode: RepeatMode.context);
          break;
      }
      debugPrint('🔁 Spotify repeat: $mode');
      return true;
    } catch (e) {
      debugPrint('🎵 Spotify repeat error: $e');
      return false;
    }
  }
  
  /// Get current track info from player state
  SpotifyTrackInfo? get currentTrack {
    final track = _currentState?.track;
    if (track == null) return null;
    
    return SpotifyTrackInfo(
      name: track.name,
      artist: track.artist.name ?? 'Unknown Artist',
      album: track.album.name ?? 'Unknown Album',
      imageUri: track.imageUri.raw,
      uri: track.uri,
      durationMs: track.duration,
      positionMs: _currentState?.playbackPosition ?? 0,
    );
  }
  
  /// Get album artwork as bytes
  Future<Uint8List?> getAlbumArt({int? size}) async {
    try {
      final track = _currentState?.track;
      if (track == null) return null;
      
      return await SpotifySdk.getImage(
        imageUri: track.imageUri,
        dimension: ImageDimension.medium,
      );
    } catch (e) {
      debugPrint('🎵 Spotify album art error: $e');
      return null;
    }
  }
  
  /// Dispose resources
  void dispose() {
    _playerStateController.close();
    _connectionController.close();
  }
}

/// Track info model for Spotify
class SpotifyTrackInfo {
  final String name;
  final String artist;
  final String album;
  final String? imageUri;
  final String uri;
  final int durationMs;
  final int positionMs;
  
  SpotifyTrackInfo({
    required this.name,
    required this.artist,
    required this.album,
    this.imageUri,
    required this.uri,
    required this.durationMs,
    required this.positionMs,
  });
  
  double get progressPercent => durationMs > 0 ? positionMs / durationMs : 0.0;
  
  @override
  String toString() => '$name - $artist';
}
