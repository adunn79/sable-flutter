import Flutter
import UIKit
import EventKit

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
}
