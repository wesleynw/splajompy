import Foundation

class MockNotificationService: @unchecked Sendable, NotificationServiceProtocol {
    enum Behavior {
        case success([Notification])
        case failure(Error)
        case delayed([Notification], TimeInterval)
        case unreadNotifications(Bool)
        case markReadSuccess
        case markReadFailure(Error)
    }
    
    struct MockError: Error, LocalizedError {
        var errorDescription: String?
        
        init(_ description: String) {
            self.errorDescription = description
        }
    }
    
    var behavior: Behavior
    
    private(set) var callHistory: [(offset: Int, limit: Int)] = []
    private(set) var markedAsReadIds: [Int] = []
    private(set) var markedAllAsReadCalls: Int = 0
    private(set) var hasUnreadCalls: Int = 0
    
    init(behavior: Behavior = .success([])) {
        self.behavior = behavior
    }
    
    static func createSampleNotifications(count: Int, startingId: Int = 1) -> [Notification] {
        return (startingId..<(startingId + count)).map { id in
            Notification(
                notificationId: id,
                userId: 100 + id,
                postId: 200 + id,
                commentId: id % 3 == 0 ? 300 + id : nil,
                message: "Test notification #\(id)",
                link: id % 2 == 0 ? "/posts/\(200 + id)" : nil,
                viewed: id % 4 == 0,
                createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-Double(id * 3600)))
            )
        }
    }
    
    func getAllNotifications(offset: Int, limit: Int) async -> APIResult<[Notification]> {
        callHistory.append((offset, limit))
        
        switch behavior {
        case .success(let notifications):
            return .success(Array(notifications.dropFirst(offset).prefix(limit)))
            
        case .failure(let error):
            return .failure(error)
            
        case .delayed(let notifications, let delay):
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return .success(Array(notifications.dropFirst(offset).prefix(limit)))
            
        default:
            return .failure(MockError("Unexpected behavior set for getAllNotifications"))
        }
    }
    
    func markNotificationAsRead(notificationId: Int) async -> APIResult<EmptyResponse> {
        markedAsReadIds.append(notificationId)
        
        switch behavior {
        case .markReadSuccess:
            return .success(EmptyResponse())
            
        case .markReadFailure(let error):
            return .failure(error)
            
        case .delayed(_, let delay):
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return .success(EmptyResponse())
            
        default:
            return .success(EmptyResponse())
        }
    }
    
    func markAllNotificationsAsRead() async -> APIResult<EmptyResponse> {
        markedAllAsReadCalls += 1
        
        switch behavior {
        case .markReadSuccess:
            return .success(EmptyResponse())
            
        case .markReadFailure(let error):
            return .failure(error)
            
        case .delayed(_, let delay):
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return .success(EmptyResponse())
            
        default:
            return .success(EmptyResponse())
        }
    }
    
    func hasUnreadNotifications() async -> APIResult<Bool> {
        hasUnreadCalls += 1
        
        switch behavior {
        case .unreadNotifications(let hasUnread):
            return .success(hasUnread)
            
        case .failure(let error):
            return .failure(error)
            
        case .delayed(_, let delay):
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return .success(false)
            
        default:
            return .success(false)
        }
    }
    
    func resetCallHistory() {
        callHistory = []
        markedAsReadIds = []
        markedAllAsReadCalls = 0
        hasUnreadCalls = 0
    }
}
