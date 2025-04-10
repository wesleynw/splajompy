import Foundation

enum FeedType {
    case home
    case all
    case profile
}

struct FeedService {
    private let fetchLimit = 10
    
    static func getFeedPosts(
        feedType: FeedType,
        userId: Int? = nil,
        offset: Int,
        limit: Int
    ) async -> APIResult<[DetailedPost]> {
        let urlBase: String
        switch feedType {
        case .home:
            urlBase = "posts/following"
        case .all:
            urlBase = "posts/all"
        case .profile:
            guard let userId = userId else {
                return .failure(URLError(.badURL))
            }
            urlBase = "user/\(userId)/posts"
        }
        
        let queryItems = [
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        return await APIService.performRequest(
            endpoint: urlBase,
            queryItems: queryItems
        )
    }
    
    static func toggleLike(postId: Int, isLiked: Bool) async -> APIResult<Void> {
        let method = isLiked ? "DELETE" : "POST"
        
        let result: APIResult<EmptyResponse> = await APIService.performRequest(
            endpoint: "post/\(postId)/liked",
            method: method
        )
        
        switch result {
        case .success:
            return .success(())
        case .failure(let error):
            return .failure(error)
        }
    }
    
    static func addComment(postId: Int, content: String) async -> APIResult<Void> {
        let bodyData: [String: String] = ["Text": content]
        
        do {
            let jsonData = try JSONEncoder().encode(bodyData)
            
            let result: APIResult<EmptyResponse> = await APIService.performRequest(
                endpoint: "post/\(postId)/comment",
                method: "POST",
                body: jsonData
            )
            
            switch result {
            case .success:
                return .success(())
            case .failure(let error):
                return .failure(error)
            }
        } catch {
            return .failure(error)
        }
    }
}
