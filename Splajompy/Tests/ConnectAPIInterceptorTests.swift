import Connect
import Foundation
import Testing

@testable import Splajompy

@MainActor
struct ConnectAPIInterceptorTests {
  @MainActor private final class Session {
    var token: String? = "original-token"
    var invalidatedTokens: [String] = []
  }

  @Test(arguments: [false, true])
  func authenticationErrorChecksRequestSession(replaceSession: Bool) async throws {
    let session = Session()
    let interceptor = ConnectAPIInterceptor(
      baseUrl: APIService.baseUrl,
      tokenProvider: { await session.token },
      onUnauthenticated: { session.invalidatedTokens.append($0) },
      onUpgradeRequired: {}
    )
    let request = HTTPRequest(
      url: try #require(URL(string: "\(APIService.baseUrl)/count")),
      headers: [:], message: Splajompy_V1_GetUnreadNotificationCountRequest(),
      method: .post, trailers: nil, idempotencyLevel: .unknown
    )
    let outgoing = await withCheckedContinuation { continuation in
      interceptor.handleUnaryRequest(request) { continuation.resume(returning: $0) }
    }
    #expect(try outgoing.get().headers["Authorization"] == ["Bearer original-token"])

    if replaceSession { session.token = "new-token" }
    let response = ResponseMessage<Splajompy_V1_GetUnreadNotificationCountResponse>(
      code: .unauthenticated,
      result: .failure(ConnectError(code: .unauthenticated, message: "Session expired"))
    )
    let incoming = await withCheckedContinuation { continuation in
      interceptor.handleUnaryResponse(response) { continuation.resume(returning: $0) }
    }
    #expect(incoming.code == (replaceSession ? .canceled : .unauthenticated))
    #expect(session.invalidatedTokens == (replaceSession ? [] : ["original-token"]))
  }
}
