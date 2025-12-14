import Flutter
import UIKit
import EventKit
import AppIntents
import MediaPlayer

@main
@objc class AppDelegate: FlutterAppDelegate {
  let eventStore = EKEventStore()
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let remindersChannel = FlutterMethodChannel(name: "com.sable.reminders",
                                                 binaryMessenger: controller.binaryMessenger)
    
    remindersChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard let self = self else { return }
      
      switch call.method {
      case "requestPermission":
        self.requestRemindersPermission(result: result)
      case "hasPermission":
        self.hasRemindersPermission(result: result)
      case "getReminders":
        self.getReminders(result: result)
      case "createReminder":
        if let args = call.arguments as? [String: Any] {
          self.createReminder(args: args, result: result)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
        }
      case "completeReminder":
        if let reminderId = call.arguments as? String {
          self.completeReminder(reminderId: reminderId, result: result)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    })
    
    // Apple Intelligence Channel
    let intelligenceChannel = FlutterMethodChannel(name: "com.aeliana.app/apple_intelligence",
                                                 binaryMessenger: controller.binaryMessenger)
    
    intelligenceChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard let self = self else { return }
      
      switch call.method {
      case "isAvailable":
        if #available(iOS 18.0, *) {
          result(true)
        } else {
          result(false)
        }
      case "rewrite":
        // Placeholder for Writing Tools integration
        // Actual API requires UITextView interaction which is complex for Flutter
        if #available(iOS 18.0, *) {
          result(nil) // Return null to indicate "handled by system UI" or not implemented
        } else {
          result(FlutterError(code: "UNSUPPORTED", message: "Requires iOS 18+", details: nil))
        }
      case "summarize":
        if #available(iOS 18.0, *) {
          result(nil)
        } else {
          result(FlutterError(code: "UNSUPPORTED", message: "Requires iOS 18+", details: nil))
        }
      case "launchSiri":
        // Open Shortcuts app as a proxy for Siri interactions
        if let url = URL(string: "shortcuts://") {
          if application.canOpenURL(url) {
            application.open(url, options: [:], completionHandler: nil)
            result(true)
          } else {
            result(false)
          }
        } else {
          result(false)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    })
    
    // iCloud CloudKit Channel
    let cloudKitChannel = FlutterMethodChannel(name: "com.sable.cloudkit",
                                               binaryMessenger: controller.binaryMessenger)
    
    cloudKitChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      
      switch call.method {
      case "isAvailable":
        CloudKitManager.shared.isAvailable { available in
          result(available)
        }
        
      case "checkAccountStatus":
        CloudKitManager.shared.checkAccountStatus { status, error in
          if let error = error {
            result(FlutterError(code: "CLOUDKIT_ERROR", message: error.localizedDescription, details: nil))
          } else {
            result(status.rawValue) // 0=couldNotDetermine, 1=available, 2=restricted, 3=noAccount, 4=temporarilyUnavailable
          }
        }
        
      case "backupJournalEntries":
        guard let entries = call.arguments as? [[String: Any]] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Expected array of entries", details: nil))
          return
        }
        CloudKitManager.shared.backupJournalEntries(entries) { backupResult in
          switch backupResult {
          case .success(let count):
            result(count)
          case .failure(let error):
            result(FlutterError(code: "BACKUP_ERROR", message: error.localizedDescription, details: nil))
          }
        }
        
      case "fetchAllJournalEntries":
        CloudKitManager.shared.fetchAllJournalEntries { fetchResult in
          switch fetchResult {
          case .success(let entries):
            result(entries)
          case .failure(let error):
            result(FlutterError(code: "FETCH_ERROR", message: error.localizedDescription, details: nil))
          }
        }
        
      case "backupGoals":
        guard let goals = call.arguments as? [[String: Any]] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Expected array of goals", details: nil))
          return
        }
        CloudKitManager.shared.backupGoals(goals) { backupResult in
          switch backupResult {
          case .success(let count):
            result(count)
          case .failure(let error):
            result(FlutterError(code: "BACKUP_ERROR", message: error.localizedDescription, details: nil))
          }
        }
        
      case "fetchAllGoals":
        CloudKitManager.shared.fetchAllGoals { fetchResult in
          switch fetchResult {
          case .success(let goals):
            result(goals)
          case .failure(let error):
            result(FlutterError(code: "FETCH_ERROR", message: error.localizedDescription, details: nil))
          }
        }
        
      case "backupChatMessages":
        guard let messages = call.arguments as? [[String: Any]] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Expected array of messages", details: nil))
          return
        }
        CloudKitManager.shared.backupChatMessages(messages) { backupResult in
          switch backupResult {
          case .success(let count):
            result(count)
          case .failure(let error):
            result(FlutterError(code: "BACKUP_ERROR", message: error.localizedDescription, details: nil))
          }
        }
        
      case "fetchAllChatMessages":
        CloudKitManager.shared.fetchAllChatMessages { fetchResult in
          switch fetchResult {
          case .success(let messages):
            result(messages)
          case .failure(let error):
            result(FlutterError(code: "FETCH_ERROR", message: error.localizedDescription, details: nil))
          }
        }
        
      case "savePreference":
        guard let args = call.arguments as? [String: String],
              let key = args["key"],
              let value = args["value"] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Expected key and value", details: nil))
          return
        }
        CloudKitManager.shared.savePreference(key: key, value: value) { saveResult in
          switch saveResult {
          case .success:
            result(true)
          case .failure(let error):
            result(FlutterError(code: "SAVE_ERROR", message: error.localizedDescription, details: nil))
          }
        }
        
      case "fetchAllPreferences":
        CloudKitManager.shared.fetchAllPreferences { fetchResult in
          switch fetchResult {
          case .success(let prefs):
            result(prefs)
          case .failure(let error):
            result(FlutterError(code: "FETCH_ERROR", message: error.localizedDescription, details: nil))
          }
        }
        
      default:
        result(FlutterMethodNotImplemented)
      }
    })
    
    // Now Playing Music Channel - Detection AND Playback Control
    let nowPlayingChannel = FlutterMethodChannel(name: "com.sable.nowplaying",
                                                 binaryMessenger: controller.binaryMessenger)
    
    nowPlayingChannel.setMethodCallHandler({
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard let self = self else { return }
      
      switch call.method {
      case "getNowPlaying":
        self.getNowPlayingInfo(result: result)
      case "play":
        self.playMusic(result: result)
      case "pause":
        self.pauseMusic(result: result)
      case "togglePlayPause":
        self.togglePlayPause(result: result)
      case "next":
        self.nextTrack(result: result)
      case "previous":
        self.previousTrack(result: result)
      case "seekTo":
        if let args = call.arguments as? [String: Any],
           let position = args["position"] as? Double {
          self.seekToPosition(seconds: position, result: result)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Position required", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    })
    
    // Notes Channel (placeholder - Apple Notes doesn't have a public API)
    // This provides a stub that can be enhanced with macOS AppleScript in the future
    let notesChannel = FlutterMethodChannel(name: "com.sable.notes",
                                            binaryMessenger: controller.binaryMessenger)
    
    notesChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      
      switch call.method {
      case "isAvailable":
        // Notes integration not yet implemented on iOS
        // Would require macOS AppleScript or third-party solution
        result(false)
        
      case "hasPermission":
        result(false)
        
      case "requestPermission":
        // No permission model for Notes on iOS
        result(false)
        
      case "getRecentNotes":
        // Placeholder - would require native implementation
        result([])
        
      case "searchNotes":
        result([])
        
      case "createNote":
        // Could open Notes app with URL scheme: mobilenotes://
        if let url = URL(string: "mobilenotes://") {
          UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        result(nil)
        
      default:
        result(FlutterMethodNotImplemented)
      }
    })
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // MARK: - Reminders Methods
  
  private func requestRemindersPermission(result: @escaping FlutterResult) {
    eventStore.requestAccess(to: .reminder) { granted, error in
      DispatchQueue.main.async {
        if let error = error {
          result(FlutterError(code: "PERMISSION_ERROR", message: error.localizedDescription, details: nil))
        } else {
          result(granted)
        }
      }
    }
  }
  
  private func hasRemindersPermission(result: @escaping FlutterResult) {
    let status = EKEventStore.authorizationStatus(for: .reminder)
    result(status == .authorized)
  }
  
  private func getReminders(result: @escaping FlutterResult) {
    let status = EKEventStore.authorizationStatus(for: .reminder)
    guard status == .authorized else {
      result(FlutterError(code: "NO_PERMISSION", message: "Reminders permission not granted", details: nil))
      return
    }
    
    let predicate = eventStore.predicateForReminders(in: nil)
    eventStore.fetchReminders(matching: predicate) { reminders in
      guard let reminders = reminders else {
        result([])
        return
      }
      
      let remindersList = reminders.filter { !$0.isCompleted }.map { reminder -> [String: Any?] in
        return [
          "id": reminder.calendarItemIdentifier,
          "title": reminder.title,
          "notes": reminder.notes,
          "dueDate": reminder.dueDateComponents?.date?.timeIntervalSince1970,
          "isCompleted": reminder.isCompleted,
          "priority": reminder.priority
        ]
      }
      
      result(remindersList)
    }
  }
  
  private func createReminder(args: [String: Any], result: @escaping FlutterResult) {
    let status = EKEventStore.authorizationStatus(for: .reminder)
    guard status == .authorized else {
      result(FlutterError(code: "NO_PERMISSION", message: "Reminders permission not granted", details: nil))
      return
    }
    
    let reminder = EKReminder(eventStore: eventStore)
    reminder.title = args["title"] as? String ?? "Untitled"
    reminder.notes = args["notes"] as? String
    reminder.calendar = eventStore.defaultCalendarForNewReminders()
    
    if let dueDateTimestamp = args["dueDate"] as? Double {
      let dueDate = Date(timeIntervalSince1970: dueDateTimestamp)
      var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
      reminder.dueDateComponents = components
    }
    
    if let priority = args["priority"] as? Int {
      reminder.priority = priority
    }
    
    do {
      try eventStore.save(reminder, commit: true)
      result([
        "id": reminder.calendarItemIdentifier,
        "title": reminder.title,
        "success": true
      ])
    } catch {
      result(FlutterError(code: "CREATE_ERROR", message: error.localizedDescription, details: nil))
    }
  }
  
  private func completeReminder(reminderId: String, result: @escaping FlutterResult) {
    let status = EKEventStore.authorizationStatus(for: .reminder)
    guard status == .authorized else {
      result(FlutterError(code: "NO_PERMISSION", message: "Reminders permission not granted", details: nil))
      return
    }
    
    if let reminder = eventStore.calendarItem(withIdentifier: reminderId) as? EKReminder {
      reminder.isCompleted = true
      
      do {
        try eventStore.save(reminder, commit: true)
        result(true)
      } catch {
        result(FlutterError(code: "COMPLETE_ERROR", message: error.localizedDescription, details: nil))
      }
    } else {
      result(FlutterError(code: "NOT_FOUND", message: "Reminder not found", details: nil))
    }
  }
  
  // MARK: - Now Playing Methods
  
  private func getNowPlayingInfo(result: @escaping FlutterResult) {
    // Access the system-wide now playing info
    // Note: This works for music apps that properly set MPNowPlayingInfoCenter
    let nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo
    
    if let info = nowPlayingInfo, 
       let title = info[MPMediaItemPropertyTitle] as? String {
      let artist = info[MPMediaItemPropertyArtist] as? String
      let album = info[MPMediaItemPropertyAlbumTitle] as? String
      
      // Try to get artwork URL (if available)
      var artworkUrlString: String? = nil
      if let artwork = info[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork {
        // For now, we don't have a URL. Artwork is an image.
        // Could save to temp file if needed in future
        artworkUrlString = nil
      }
      
      result([
        "title": title,
        "artist": artist ?? "Unknown Artist",
        "album": album,
        "artworkUrl": artworkUrlString,
        "bundleId": "unknown" // Can't easily determine source app from MPNowPlayingInfoCenter
      ])
    } else {
      result(nil)
    }
  }
  
  // MARK: - Playback Control Methods (Works with Apple Music and other music apps)
  
  private func playMusic(result: @escaping FlutterResult) {
    let player = MPMusicPlayerController.systemMusicPlayer
    player.play()
    result(true)
  }
  
  private func pauseMusic(result: @escaping FlutterResult) {
    let player = MPMusicPlayerController.systemMusicPlayer
    player.pause()
    result(true)
  }
  
  private func togglePlayPause(result: @escaping FlutterResult) {
    let player = MPMusicPlayerController.systemMusicPlayer
    if player.playbackState == .playing {
      player.pause()
    } else {
      player.play()
    }
    result(true)
  }
  
  private func nextTrack(result: @escaping FlutterResult) {
    let player = MPMusicPlayerController.systemMusicPlayer
    player.skipToNextItem()
    result(true)
  }
  
  private func previousTrack(result: @escaping FlutterResult) {
    let player = MPMusicPlayerController.systemMusicPlayer
    player.skipToPreviousItem()
    result(true)
  }
  
  private func seekToPosition(seconds: Double, result: @escaping FlutterResult) {
    let player = MPMusicPlayerController.systemMusicPlayer
    player.currentPlaybackTime = seconds
    result(true)
  }
}
