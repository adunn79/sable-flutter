import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }
  
  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Setup Now Playing channel
    if let flutterViewController = mainFlutterWindow?.contentViewController as? FlutterViewController {
      let nowPlayingChannel = FlutterMethodChannel(
        name: "com.sable.nowplaying",
        binaryMessenger: flutterViewController.engine.binaryMessenger
      )
      
      nowPlayingChannel.setMethodCallHandler { (call, result) in
        switch call.method {
        case "getNowPlaying":
          // macOS uses MRMediaRemote (private framework) or AppleScript
          // For now, return nil since it requires entitlements
          // Could use AppleScript to query Music.app/Spotify in future
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}
