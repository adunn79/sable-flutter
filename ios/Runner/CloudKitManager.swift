import CloudKit
import Foundation

/// CloudKit Manager for full app backup to iCloud
/// Handles journal entries, goals, chat messages, memories, and preferences
class CloudKitManager {
    static let shared = CloudKitManager()
    
    private let containerIdentifier = "iCloud.com.aureal.sable"
    private lazy var container = CKContainer(identifier: containerIdentifier)
    private var privateDatabase: CKDatabase { container.privateCloudDatabase }
    
    // Record type constants
    private enum RecordType {
        static let journalEntry = "JournalEntry"
        static let goal = "Goal"
        static let chatMessage = "ChatMessage"
        static let memory = "ExtractedMemory"
        static let preference = "UserPreference"
    }
    
    private init() {}
    
    // MARK: - Account Status
    
    /// Check if iCloud is available and user is signed in
    func checkAccountStatus(completion: @escaping (CKAccountStatus, Error?) -> Void) {
        container.accountStatus { status, error in
            DispatchQueue.main.async {
                completion(status, error)
            }
        }
    }
    
    /// Returns true if iCloud is available
    func isAvailable(completion: @escaping (Bool) -> Void) {
        checkAccountStatus { status, _ in
            completion(status == .available)
        }
    }
    
    // MARK: - Generic CRUD Operations
    
    /// Save a record to CloudKit
    func save(record: CKRecord, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        privateDatabase.save(record) { savedRecord, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                } else if let savedRecord = savedRecord {
                    completion(.success(savedRecord))
                } else {
                    completion(.failure(CloudKitError.unknownError))
                }
            }
        }
    }
    
    /// Fetch records by type
    func fetchAll(recordType: String, completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        
        privateDatabase.perform(query, inZoneID: nil) { records, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(records ?? []))
                }
            }
        }
    }
    
    /// Delete a record by ID
    func delete(recordID: CKRecord.ID, completion: @escaping (Result<Void, Error>) -> Void) {
        privateDatabase.delete(withRecordID: recordID) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
    
    // MARK: - Journal Entries
    
    /// Convert journal entry dictionary to CloudKit record
    func createJournalRecord(from data: [String: Any]) -> CKRecord {
        let recordID = CKRecord.ID(recordName: data["id"] as? String ?? UUID().uuidString)
        let record = CKRecord(recordType: RecordType.journalEntry, recordID: recordID)
        
        record["id"] = data["id"] as? String
        record["content"] = data["content"] as? String
        record["plainText"] = data["plainText"] as? String
        record["timestamp"] = data["timestamp"] as? Date
        record["updatedAt"] = data["updatedAt"] as? Date
        record["bucketId"] = data["bucketId"] as? String
        record["tags"] = data["tags"] as? [String]
        record["moodScore"] = data["moodScore"] as? Int
        record["isPrivate"] = data["isPrivate"] as? Bool ?? false
        record["location"] = data["location"] as? String
        record["weather"] = data["weather"] as? String
        record["stepCount"] = data["stepCount"] as? Int
        record["nowPlayingTrack"] = data["nowPlayingTrack"] as? String
        record["nowPlayingArtist"] = data["nowPlayingArtist"] as? String
        
        return record
    }
    
    /// Convert CloudKit record to journal entry dictionary
    func journalEntryFromRecord(_ record: CKRecord) -> [String: Any] {
        return [
            "id": record["id"] as? String ?? record.recordID.recordName,
            "content": record["content"] as? String ?? "",
            "plainText": record["plainText"] as? String ?? "",
            "timestamp": (record["timestamp"] as? Date)?.timeIntervalSince1970 ?? 0,
            "updatedAt": (record["updatedAt"] as? Date)?.timeIntervalSince1970,
            "bucketId": record["bucketId"] as? String ?? "default",
            "tags": record["tags"] as? [String] ?? [],
            "moodScore": record["moodScore"] as? Int,
            "isPrivate": record["isPrivate"] as? Bool ?? false,
            "location": record["location"] as? String,
            "weather": record["weather"] as? String,
            "stepCount": record["stepCount"] as? Int,
            "nowPlayingTrack": record["nowPlayingTrack"] as? String,
            "nowPlayingArtist": record["nowPlayingArtist"] as? String,
        ]
    }
    
    func saveJournalEntry(_ data: [String: Any], completion: @escaping (Result<String, Error>) -> Void) {
        let record = createJournalRecord(from: data)
        save(record: record) { result in
            switch result {
            case .success(let savedRecord):
                completion(.success(savedRecord.recordID.recordName))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func fetchAllJournalEntries(completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        fetchAll(recordType: RecordType.journalEntry) { [weak self] result in
            switch result {
            case .success(let records):
                let entries = records.compactMap { self?.journalEntryFromRecord($0) }
                completion(.success(entries))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Goals
    
    func createGoalRecord(from data: [String: Any]) -> CKRecord {
        let recordID = CKRecord.ID(recordName: data["id"] as? String ?? UUID().uuidString)
        let record = CKRecord(recordType: RecordType.goal, recordID: recordID)
        
        record["id"] = data["id"] as? String
        record["title"] = data["title"] as? String
        record["description"] = data["description"] as? String
        record["targetDate"] = data["targetDate"] as? Date
        record["createdAt"] = data["createdAt"] as? Date
        record["progress"] = data["progress"] as? Double
        record["isCompleted"] = data["isCompleted"] as? Bool ?? false
        record["checkInFrequencyDays"] = data["checkInFrequencyDays"] as? Int
        
        return record
    }
    
    func goalFromRecord(_ record: CKRecord) -> [String: Any] {
        return [
            "id": record["id"] as? String ?? record.recordID.recordName,
            "title": record["title"] as? String ?? "",
            "description": record["description"] as? String ?? "",
            "targetDate": (record["targetDate"] as? Date)?.timeIntervalSince1970,
            "createdAt": (record["createdAt"] as? Date)?.timeIntervalSince1970,
            "progress": record["progress"] as? Double ?? 0,
            "isCompleted": record["isCompleted"] as? Bool ?? false,
            "checkInFrequencyDays": record["checkInFrequencyDays"] as? Int ?? 7,
        ]
    }
    
    func saveGoal(_ data: [String: Any], completion: @escaping (Result<String, Error>) -> Void) {
        let record = createGoalRecord(from: data)
        save(record: record) { result in
            switch result {
            case .success(let savedRecord):
                completion(.success(savedRecord.recordID.recordName))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func fetchAllGoals(completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        fetchAll(recordType: RecordType.goal) { [weak self] result in
            switch result {
            case .success(let records):
                let goals = records.compactMap { self?.goalFromRecord($0) }
                completion(.success(goals))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Chat Messages
    
    func createChatMessageRecord(from data: [String: Any]) -> CKRecord {
        let recordID = CKRecord.ID(recordName: data["id"] as? String ?? UUID().uuidString)
        let record = CKRecord(recordType: RecordType.chatMessage, recordID: recordID)
        
        record["id"] = data["id"] as? String
        record["role"] = data["role"] as? String
        record["content"] = data["content"] as? String
        record["timestamp"] = data["timestamp"] as? Date
        record["contextType"] = data["contextType"] as? String
        
        return record
    }
    
    func chatMessageFromRecord(_ record: CKRecord) -> [String: Any] {
        return [
            "id": record["id"] as? String ?? record.recordID.recordName,
            "role": record["role"] as? String ?? "user",
            "content": record["content"] as? String ?? "",
            "timestamp": (record["timestamp"] as? Date)?.timeIntervalSince1970 ?? 0,
            "contextType": record["contextType"] as? String,
        ]
    }
    
    func saveChatMessage(_ data: [String: Any], completion: @escaping (Result<String, Error>) -> Void) {
        let record = createChatMessageRecord(from: data)
        save(record: record) { result in
            switch result {
            case .success(let savedRecord):
                completion(.success(savedRecord.recordID.recordName))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func fetchAllChatMessages(completion: @escaping (Result<[[String: Any]], Error>) -> Void) {
        fetchAll(recordType: RecordType.chatMessage) { [weak self] result in
            switch result {
            case .success(let records):
                let messages = records.compactMap { self?.chatMessageFromRecord($0) }
                completion(.success(messages))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Batch Operations for Full Backup
    
    /// Backup all journal entries at once
    func backupJournalEntries(_ entries: [[String: Any]], completion: @escaping (Result<Int, Error>) -> Void) {
        let records = entries.map { createJournalRecord(from: $0) }
        
        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.savePolicy = .allKeys
        operation.qualityOfService = .userInitiated
        
        operation.modifyRecordsCompletionBlock = { savedRecords, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(savedRecords?.count ?? 0))
                }
            }
        }
        
        privateDatabase.add(operation)
    }
    
    /// Backup all goals at once
    func backupGoals(_ goals: [[String: Any]], completion: @escaping (Result<Int, Error>) -> Void) {
        let records = goals.map { createGoalRecord(from: $0) }
        
        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.savePolicy = .allKeys
        operation.qualityOfService = .userInitiated
        
        operation.modifyRecordsCompletionBlock = { savedRecords, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(savedRecords?.count ?? 0))
                }
            }
        }
        
        privateDatabase.add(operation)
    }
    
    /// Backup all chat messages at once
    func backupChatMessages(_ messages: [[String: Any]], completion: @escaping (Result<Int, Error>) -> Void) {
        let records = messages.map { createChatMessageRecord(from: $0) }
        
        let operation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: nil)
        operation.savePolicy = .allKeys
        operation.qualityOfService = .userInitiated
        
        operation.modifyRecordsCompletionBlock = { savedRecords, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(savedRecords?.count ?? 0))
                }
            }
        }
        
        privateDatabase.add(operation)
    }
    
    // MARK: - User Preferences
    
    func savePreference(key: String, value: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let recordID = CKRecord.ID(recordName: "pref_\(key)")
        let record = CKRecord(recordType: RecordType.preference, recordID: recordID)
        
        record["key"] = key
        record["value"] = value
        record["updatedAt"] = Date()
        
        save(record: record) { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func fetchAllPreferences(completion: @escaping (Result<[String: String], Error>) -> Void) {
        fetchAll(recordType: RecordType.preference) { result in
            switch result {
            case .success(let records):
                var prefs: [String: String] = [:]
                for record in records {
                    if let key = record["key"] as? String,
                       let value = record["value"] as? String {
                        prefs[key] = value
                    }
                }
                completion(.success(prefs))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Error Types

enum CloudKitError: Error, LocalizedError {
    case notAvailable
    case notSignedIn
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "iCloud is not available on this device"
        case .notSignedIn:
            return "Please sign in to iCloud in Settings"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}
