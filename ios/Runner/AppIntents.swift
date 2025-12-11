import AppIntents
import UIKit

// MARK: - App Shortcut Provider for Siri Integration
@available(iOS 16.0, *)
struct AelianaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartChatIntent(),
            phrases: [
                "Start chat in \(.applicationName)",
                "Open \(.applicationName)",
                "Talk to \(.applicationName)",
                "Chat with Aeliana"
            ],
            shortTitle: "Start Chat",
            systemImageName: "bubble.left.and.bubble.right.fill"
        )
        
        AppShortcut(
            intent: OpenJournalIntent(),
            phrases: [
                "Open journal in \(.applicationName)",
                "Show my journal",
                "Open \(.applicationName) journal"
            ],
            shortTitle: "Open Journal",
            systemImageName: "book.fill"
        )
        
        AppShortcut(
            intent: OpenClockModeIntent(),
            phrases: [
                "Start clock mode in \(.applicationName)",
                "Show \(.applicationName) clock",
                "Bedside clock"
            ],
            shortTitle: "Clock Mode",
            systemImageName: "clock.fill"
        )
        
        AppShortcut(
            intent: CheckMoodIntent(),
            phrases: [
                "Check my mood with \(.applicationName)",
                "How am I feeling \(.applicationName)",
                "Mood check"
            ],
            shortTitle: "Check Mood",
            systemImageName: "heart.fill"
        )
        
        AppShortcut(
            intent: NowPlayingIntent(),
            phrases: [
                "What am I listening to in \(.applicationName)",
                "Now playing \(.applicationName)"
            ],
            shortTitle: "Now Playing",
            systemImageName: "music.note"
        )
    }
}

// MARK: - Start Chat Intent
@available(iOS 16.0, *)
struct StartChatIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Chat"
    static var description = IntentDescription("Opens Aeliana and starts a new chat conversation")
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // Navigate to chat screen via deep link
        if let url = URL(string: "aeliana://chat") {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}

// MARK: - Open Journal Intent
@available(iOS 16.0, *)
struct OpenJournalIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Journal"
    static var description = IntentDescription("Opens your private journal in Aeliana")
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        if let url = URL(string: "aeliana://journal") {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}

// MARK: - Open Clock Mode Intent
@available(iOS 16.0, *)
struct OpenClockModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Clock Mode"
    static var description = IntentDescription("Starts the beautiful bedside clock display")
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        if let url = URL(string: "aeliana://clock") {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}

// MARK: - Check Mood Intent
@available(iOS 16.0, *)
struct CheckMoodIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Mood"
    static var description = IntentDescription("Opens Vital Balance for a mood check-in")
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        if let url = URL(string: "aeliana://vital-balance") {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}

// MARK: - Now Playing Intent
@available(iOS 16.0, *)
struct NowPlayingIntent: AppIntent {
    static var title: LocalizedStringResource = "Now Playing"
    static var description = IntentDescription("Shows what music is currently playing")
    static var openAppWhenRun: Bool = true
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // Open app to show mini-player
        if let url = URL(string: "aeliana://chat?showPlayer=true") {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}

// MARK: - Add Memory Intent (for Journal)
@available(iOS 16.0, *)
struct AddMemoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Memory"
    static var description = IntentDescription("Quickly add a memory to your journal")
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: "Memory Text")
    var memoryText: String?
    
    @MainActor
    func perform() async throws -> some IntentResult {
        var urlString = "aeliana://journal/add"
        if let text = memoryText, !text.isEmpty {
            let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            urlString += "?text=\(encoded)"
        }
        if let url = URL(string: urlString) {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}
