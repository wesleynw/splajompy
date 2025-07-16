import Foundation

struct Poll: Identifiable, Codable, Equatable {
    let id: String
    let question: String
    let options: [PollOption]
    let totalVotes: Int
    let createdAt: Date
    let expiresAt: Date?
    
    init(id: String = UUID().uuidString, question: String, options: [PollOption], totalVotes: Int, createdAt: Date = Date(), expiresAt: Date? = nil) {
        self.id = id
        self.question = question
        self.options = options
        self.totalVotes = totalVotes
        self.createdAt = createdAt
        self.expiresAt = expiresAt
    }
}

struct PollOption: Identifiable, Codable, Equatable {
    let id: String
    let text: String
    let voteCount: Int
    
    init(id: String = UUID().uuidString, text: String, voteCount: Int = 0) {
        self.id = id
        self.text = text
        self.voteCount = voteCount
    }
    
    func percentage(of totalVotes: Int) -> Double {
        guard totalVotes > 0 else { return 0.0 }
        return Double(voteCount) / Double(totalVotes) * 100.0
    }
}