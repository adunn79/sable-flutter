import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'spotify_service.dart';

/// Enum for music source identification
enum MusicSource {
  spotify,
  appleMusic,
  systemMedia, // Other apps detected via now playing
  none,
}

/// Unified track info model that works with any source
class TrackInfo {
  final String name;
  final String artist;
  final String? album;
  final String? artworkUrl;
  final Uint8List? artworkBytes;
  final MusicSource source;
  final int? durationMs;
  final int? positionMs;
  final bool isPlaying;
  
  TrackInfo({
    required this.name,
    required this.artist,
    this.album,
    this.artworkUrl,
    this.artworkBytes,
    required this.source,
    this.durationMs,
    this.positionMs,
    this.isPlaying = false,
  });
  
  double get progress {
    if (durationMs == null || durationMs == 0) return 0.0;
    return (positionMs ?? 0) / durationMs!;
  }
  
  String get formattedDuration {
    if (durationMs == null) return '--:--';
    final duration = Duration(milliseconds: durationMs!);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  
  String get formattedPosition {
    if (positionMs == null) return '--:--';
    final position = Duration(milliseconds: positionMs!);
    final minutes = position.inMinutes;
    final seconds = position.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  
  @override
  String toString() => '$name - $artist';
  
  TrackInfo copyWith({
    String? name,
    String? artist,
    String? album,
    String? artworkUrl,
    Uint8List? artworkBytes,
    MusicSource? source,
    int? durationMs,
    int? positionMs,
    bool? isPlaying,
  }) {
    return TrackInfo(
      name: name ?? this.name,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      artworkBytes: artworkBytes ?? this.artworkBytes,
      source: source ?? this.source,
      durationMs: durationMs ?? this.durationMs,
      positionMs: positionMs ?? this.positionMs,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}

/// Unified music service that abstracts Spotify and Apple Music
/// Provides a single interface for the entire app to interact with music
class UnifiedMusicService extends ChangeNotifier {
  static UnifiedMusicService? _instance;
  static UnifiedMusicService get instance => _instance ??= UnifiedMusicService._();
  
  UnifiedMusicService._() {
    _initialize();
  }
  
  final SpotifyService _spotify = SpotifyService.instance;
  
  MusicSource _activeSource = MusicSource.none;
  TrackInfo? _currentTrack;
  bool _isPlaying = false;
  bool _isSpotifyConnected = false;
  bool _isAppleMusicConnected = false;
  Uint8List? _currentArtwork;
  
  StreamSubscription? _spotifyStateSubscription;
  Timer? _pollingTimer;
  
  // Getters
  MusicSource get activeSource => _activeSource;
  TrackInfo? get currentTrack => _currentTrack;
  bool get isPlaying => _isPlaying;
  bool get isSpotifyConnected => _isSpotifyConnected;
  bool get isAppleMusicConnected => _isAppleMusicConnected;
  bool get hasMusicPlaying => _currentTrack != null && _isPlaying;
  Uint8List? get currentArtwork => _currentArtwork;
  
  /// Check if any music service is connected
  bool get hasActiveConnection => _isSpotifyConnected || _isAppleMusicConnected;
  
  void _initialize() {
    // Listen to Spotify connection changes
    _spotify.connectionStream.listen((connected) {
      _isSpotifyConnected = connected;
      if (connected) {
        _activeSource = MusicSource.spotify;
        _subscribeToSpotify();
      }
      notifyListeners();
    });
    
    // Start polling for system media if no direct connection
    _startSystemMediaPolling();
  }
  
  void _subscribeToSpotify() {
    _spotifyStateSubscription?.cancel();
    _spotifyStateSubscription = _spotify.playerStateStream.listen((state) async {
      if (state != null && state.track != null) {
        _activeSource = MusicSource.spotify;
        _isPlaying = !state.isPaused;
        
        // Get artwork bytes
        final artwork = await _spotify.getAlbumArt();
        _currentArtwork = artwork;
        
        _currentTrack = TrackInfo(
          name: state.track!.name,
          artist: state.track!.artist.name ?? 'Unknown Artist',
          album: state.track!.album.name,
          artworkBytes: artwork,
          source: MusicSource.spotify,
          durationMs: state.track!.duration,
          positionMs: state.playbackPosition,
          isPlaying: !state.isPaused,
        );
        notifyListeners();
      }
    });
  }
  
  void _startSystemMediaPolling() {
    // Poll for system media every 3 seconds if no active connection
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!_isSpotifyConnected && !_isAppleMusicConnected) {
        // TODO: Use nowplaying package to detect system media
        // For now, this is a placeholder
      }
    });
  }
  
  // ==================== CONNECTION METHODS ====================
  
  /// Connect to Spotify
  Future<bool> connectSpotify() async {
    final result = await _spotify.connect();
    _isSpotifyConnected = result;
    if (result) {
      _activeSource = MusicSource.spotify;
    }
    notifyListeners();
    return result;
  }
  
  /// Disconnect from Spotify
  Future<void> disconnectSpotify() async {
    await _spotify.disconnect();
    _isSpotifyConnected = false;
    if (_activeSource == MusicSource.spotify) {
      _activeSource = MusicSource.none;
      _currentTrack = null;
      _isPlaying = false;
    }
    notifyListeners();
  }
  
  /// Connect to Apple Music (placeholder - requires MusicKit)
  Future<bool> connectAppleMusic() async {
    // TODO: Implement MusicKit authorization
    // For now, return false as not implemented yet
    debugPrint('🎵 Apple Music: Not implemented yet');
    return false;
  }
  
  /// Disconnect from Apple Music (placeholder - requires MusicKit)
  Future<void> disconnectAppleMusic() async {
    _isAppleMusicConnected = false;
    if (_activeSource == MusicSource.appleMusic) {
      _activeSource = MusicSource.none;
      _currentTrack = null;
      _isPlaying = false;
    }
    notifyListeners();
  }
  
  // ==================== PLAYBACK CONTROLS ====================
  
  /// Play or resume
  Future<bool> play({String? uri}) async {
    switch (_activeSource) {
      case MusicSource.spotify:
        return await _spotify.play(spotifyUri: uri);
      case MusicSource.appleMusic:
        // TODO: Implement Apple Music play
        return false;
      default:
        return false;
    }
  }
  
  /// Pause playback
  Future<bool> pause() async {
    switch (_activeSource) {
      case MusicSource.spotify:
        return await _spotify.pause();
      case MusicSource.appleMusic:
        // TODO: Implement Apple Music pause
        return false;
      default:
        return false;
    }
  }
  
  /// Toggle play/pause
  Future<bool> togglePlayPause() async {
    if (_isPlaying) {
      return await pause();
    } else {
      return await play();
    }
  }
  
  /// Skip to next track
  Future<bool> skipNext() async {
    switch (_activeSource) {
      case MusicSource.spotify:
        return await _spotify.skipNext();
      case MusicSource.appleMusic:
        // TODO: Implement Apple Music skip next
        return false;
      default:
        return false;
    }
  }
  
  /// Skip to previous track
  Future<bool> skipPrevious() async {
    switch (_activeSource) {
      case MusicSource.spotify:
        return await _spotify.skipPrevious();
      case MusicSource.appleMusic:
        // TODO: Implement Apple Music skip previous
        return false;
      default:
        return false;
    }
  }
  
  /// Seek to position in current track
  Future<bool> seekTo(int positionMs) async {
    switch (_activeSource) {
      case MusicSource.spotify:
        return await _spotify.seekTo(positionMs);
      case MusicSource.appleMusic:
        // TODO: Implement Apple Music seek
        return false;
      default:
        return false;
    }
  }
  
  /// Seek by percentage (0.0 - 1.0)
  Future<bool> seekToPercent(double percent) async {
    if (_currentTrack?.durationMs == null) return false;
    final positionMs = (_currentTrack!.durationMs! * percent).toInt();
    return await seekTo(positionMs);
  }
  
  @override
  void dispose() {
    _spotifyStateSubscription?.cancel();
    _pollingTimer?.cancel();
    _spotify.dispose();
    super.dispose();
  }
}

/// Riverpod provider for UnifiedMusicService
final unifiedMusicServiceProvider = ChangeNotifierProvider<UnifiedMusicService>((ref) {
  return UnifiedMusicService.instance;
});
