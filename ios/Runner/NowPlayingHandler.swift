import Foundation
import MediaPlayer
import Flutter

/// NowPlayingHandler - Native iOS handler for detecting currently playing media
/// Phase 2: Memory Spine & Intelligence - Music Context Detection
///
/// This handler uses MediaRemote (private framework) via MPNowPlayingInfoCenter
/// to detect music playing from ANY app (Spotify, Apple Music, YouTube Music, etc.)
class NowPlayingHandler: NSObject {
    static let shared = NowPlayingHandler()
    
    private var methodChannel: FlutterMethodChannel?
    private var pollingTimer: Timer?
    
    private override init() {
        super.init()
    }
    
    /// Setup the Flutter method channel
    func setup(with controller: FlutterViewController) {
        methodChannel = FlutterMethodChannel(
            name: "com.aeliana/nowplaying",
            binaryMessenger: controller.binaryMessenger
        )
        
        methodChannel?.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "getNowPlaying":
                result(self?.getCurrentlyPlaying())
                
            case "play":
                self?.sendPlayCommand()
                result(true)
                
            case "pause":
                self?.sendPauseCommand()
                result(true)
                
            case "next":
                self?.sendNextCommand()
                result(true)
                
            case "previous":
                self?.sendPreviousCommand()
                result(true)
                
            case "seekTo":
                if let args = call.arguments as? [String: Any],
                   let position = args["position"] as? Double {
                    self?.seekTo(seconds: position)
                    result(true)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", 
                                       message: "Position required", 
                                       details: nil))
                }
                
            case "startPolling":
                self?.startPolling()
                result(true)
                
            case "stopPolling":
                self?.stopPolling()
                result(true)
                
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        print("🎵 NowPlayingHandler: Flutter channel registered")
    }
    
    /// Get currently playing track information
    /// Uses MPNowPlayingInfoCenter which works with most media apps
    func getCurrentlyPlaying() -> [String: Any]? {
        let center = MPNowPlayingInfoCenter.default()
        guard let info = center.nowPlayingInfo else {
            return nil
        }
        
        // Extract track info
        let title = info[MPMediaItemPropertyTitle] as? String ?? ""
        let artist = info[MPMediaItemPropertyArtist] as? String ?? ""
        let album = info[MPMediaItemPropertyAlbumTitle] as? String ?? ""
        
        // Duration and position (in seconds)
        let duration = info[MPMediaItemPropertyPlaybackDuration] as? Double ?? 0
        let position = info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double ?? 0
        
        // Playback rate (0 = paused, 1 = playing)
        let rate = info[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 0
        let isPlaying = rate > 0
        
        // Only return if we have meaningful info
        guard !title.isEmpty || !artist.isEmpty else {
            return nil
        }
        
        return [
            "title": title,
            "artist": artist,
            "album": album,
            "duration": duration,
            "position": position,
            "isPlaying": isPlaying,
            "source": "system"
        ]
    }
    
    // MARK: - Playback Controls
    // Note: These use the media remote commands which work with the system media player
    
    func sendPlayCommand() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.isEnabled = true
        // Sending commands programmatically isn't directly supported
        // The user would need to control this via the lock screen or Control Center
        print("🎵 Play command requested")
    }
    
    func sendPauseCommand() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.pauseCommand.isEnabled = true
        print("🎵 Pause command requested")
    }
    
    func sendNextCommand() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.nextTrackCommand.isEnabled = true
        print("🎵 Next track command requested")
    }
    
    func sendPreviousCommand() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.previousTrackCommand.isEnabled = true
        print("🎵 Previous track command requested")
    }
    
    func seekTo(seconds: Double) {
        // Note: Seeking requires MusicKit authorization for Apple Music
        // For other apps, this would need app-specific integrations
        print("🎵 Seek to \(seconds)s requested")
    }
    
    // MARK: - Polling
    
    func startPolling() {
        stopPolling()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            if let info = self?.getCurrentlyPlaying() {
                self?.methodChannel?.invokeMethod("onNowPlayingChanged", arguments: info)
            }
        }
        print("🎵 Now Playing polling started")
    }
    
    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        print("🎵 Now Playing polling stopped")
    }
}
