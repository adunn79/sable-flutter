import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'spotify_service.dart';
import 'now_playing_service.dart';

/// Enum for music source identification
enum MusicSource {
  spotify,
  appleMusic,
  systemMedia, // Other apps detected via now playing
  none,
}

/// Repeat mode for playback
enum RepeatMode {
  off,    // No repeat
  track,  // Repeat current track
  context // Repeat playlist/album
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
  
  // Shuffle & Repeat state
  bool _shuffleEnabled = false;
  RepeatMode _repeatMode = RepeatMode.off;
  
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
  bool get shuffleEnabled => _shuffleEnabled;
  RepeatMode get repeatMode => _repeatMode;
  
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
  
  static const _nowPlayingChannel = MethodChannel('com.sable.nowplaying');
  
  void _startSystemMediaPolling() {
    // Poll for system media every 3 seconds if no active connection
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!_isSpotifyConnected && !_isAppleMusicConnected) {
        await _detectSystemMedia();
      }
    });
  }
  
  Future<void> _detectSystemMedia() async {
    try {
      final result = await _nowPlayingChannel.invokeMethod<Map>('getNowPlaying');
      if (result != null && result['title'] != null) {
        _activeSource = MusicSource.systemMedia;
        _currentTrack = TrackInfo(
          name: result['title'] as String? ?? '',
          artist: result['artist'] as String? ?? 'Unknown Artist',
          album: result['album'] as String?,
          source: MusicSource.systemMedia,
          isPlaying: true, // Assume playing if data is returned
        );
        _isPlaying = true;
        notifyListeners();
        debugPrint('🎵 Now Playing detected: ${_currentTrack?.name} - ${_currentTrack?.artist}');
      }
    } catch (e) {
      // Silent fail - native channel may not be available in test/web
      if (e is! MissingPluginException) {
        debugPrint('⚠️ Now Playing detection failed: $e');
      }
    }
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
  
  /// Connect to Apple Music (uses native iOS MediaPlayer APIs)
  Future<bool> connectAppleMusic() async {
    // Apple Music works via system MediaPlayer without explicit connection
    // We just set connected = true and start detecting now playing
    _isAppleMusicConnected = true;
    _activeSource = MusicSource.appleMusic;
    debugPrint('🎵 Apple Music: Connected via native iOS');
    notifyListeners();
    return true;
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
        return await NowPlayingService.play();
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
        return await NowPlayingService.pause();
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
        return await NowPlayingService.next();
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
        return await NowPlayingService.previous();
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
      case MusicSource.systemMedia:
        return await NowPlayingService.seekTo(positionMs);
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
  
  /// Toggle shuffle mode
  Future<void> toggleShuffle() async {
    _shuffleEnabled = !_shuffleEnabled;
    notifyListeners();
    
    // Apply to active source
    switch (_activeSource) {
      case MusicSource.spotify:
        try {
          await _spotify.setShuffle(_shuffleEnabled);
          debugPrint('🔀 Shuffle ${_shuffleEnabled ? "enabled" : "disabled"}');
        } catch (e) {
          debugPrint('⚠️ Shuffle toggle failed: $e');
        }
        break;
      default:
        // For other sources, we just track the state locally
        debugPrint('🔀 Shuffle ${_shuffleEnabled ? "enabled" : "disabled"} (local only)');
    }
  }
  
  /// Cycle through repeat modes: off → track → context → off
  Future<void> toggleRepeat() async {
    switch (_repeatMode) {
      case RepeatMode.off:
        _repeatMode = RepeatMode.track;
        break;
      case RepeatMode.track:
        _repeatMode = RepeatMode.context;
        break;
      case RepeatMode.context:
        _repeatMode = RepeatMode.off;
        break;
    }
    notifyListeners();
    
    // Apply to active source
    switch (_activeSource) {
      case MusicSource.spotify:
        try {
          String spotifyMode;
          switch (_repeatMode) {
            case RepeatMode.off:
              spotifyMode = 'off';
              break;
            case RepeatMode.track:
              spotifyMode = 'track';
              break;
            case RepeatMode.context:
              spotifyMode = 'context';
              break;
          }
          await _spotify.setRepeat(spotifyMode);
          debugPrint('🔁 Repeat mode: ${_repeatMode.name}');
        } catch (e) {
          debugPrint('⚠️ Repeat toggle failed: $e');
        }
        break;
      default:
        debugPrint('🔁 Repeat mode: ${_repeatMode.name} (local only)');
    }
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
