import Testing
import Foundation
@testable import GraphQL

@Suite("Request Encoding Tests")
struct RequestEncodingTests {

    let client = Client(
        endpoint: URL(string: "https://example.com/graphql")!,
        apiKey: "test-key"
    )

    struct Dummy: Codable, Sendable {
        let id: String
    }

    @Test func jsonContentType() throws {
        let request = try client.graphQLRequest(
            kind: .query,
            operation: "test()",
            input: Optional<EmptyVariables>.none,
            as: Dummy.self
        )
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test func httpMethodIsPOST() throws {
        let request = try client.graphQLRequest(
            kind: .query,
            operation: "test()",
            input: Optional<EmptyVariables>.none,
            as: Dummy.self
        )
        #expect(request.httpMethod == "POST")
    }

    @Test func bodyHasQueryAndVariables() throws {
        let request = try client.graphQLRequest(
            kind: .query,
            operation: "test()",
            input: Optional<EmptyVariables>.none,
            as: Dummy.self
        )
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        #expect(body["query"] != nil)
        #expect(body["variables"] != nil)
    }

    @Test func endpointMatchesClientURL() throws {
        let request = try client.graphQLRequest(
            kind: .query,
            operation: "test()",
            input: Optional<EmptyVariables>.none,
            as: Dummy.self
        )
        #expect(request.url == URL(string: "https://example.com/graphql"))
    }
}
