import Foundation
import UIKit

struct CreatePostRequest: Encodable {
    let content: String
    let imageIds: [String]
}

struct PostCreationService {
    static func createPost(text: String) async -> APIResult<Void> {
        do {
            let bodyData: [String: String] = ["text": text]
            let jsonData = try JSONEncoder().encode(bodyData)
            
            let result: APIResult<EmptyResponse> = await APIService.performRequest(
                endpoint: "post/new",
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
    
//    static func createPostWithImage(text: String, image: UIImage) async -> APIResult<Void> {
//        do {
//            // Note: This implementation assumes your APIService has an uploadImage method
//            // You might need to implement this method based on your API requirements
//            let result: APIResult<EmptyResponse> = await APIService.uploadImage(
//                endpoint: "post/new",
//                method: "POST",
//                image: image,
//                bodyFields: ["text": text]
//            )
//            
//            switch result {
//            case .success:
//                return .success(())
//            case .failure(let error):
//                return .failure(error)
//            }
//        } catch {
//            return .failure(error)
//        }
//    }
    
    static func validatePostText(text: String) -> (isValid: Bool, errorMessage: String?) {
        if text.count > 5000 {
            return (false, "This post is \(text.count - 5000) characters too long.")
        }
        return (true, nil)
    }
}
