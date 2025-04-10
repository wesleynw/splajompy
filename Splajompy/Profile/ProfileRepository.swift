import Foundation

struct UserProfile: Decodable {
    let userId: Int
    let email: String
    let username: String
    let createdAt: String
    let name: String
    let bio: String
    let isFollower: Bool
    var isFollowing: Bool
}

struct ProfileService {
    static func getUserProfile(userId: Int) async -> APIResult<UserProfile> {
        return await APIService.performRequest(
            endpoint: "user/\(userId)",
            method: "GET"
        )
    }
    
    static func toggleFollowing(userId: Int, isFollowing: Bool) async -> APIResult<Void> {
        let method = isFollowing ? "DELETE" : "POST"
        
        let result: APIResult<EmptyResponse> = await APIService.performRequest(
            endpoint: "follow/\(userId)",
            method: method
        )
        
        switch result {
        case .success:
            return .success(())
        case .failure(let error):
            return .failure(error)
        }
    }
}
