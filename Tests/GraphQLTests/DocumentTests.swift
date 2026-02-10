import Testing
import Foundation
@testable import GraphQL

@Suite("Document Generation Tests")
struct DocumentTests {

    let client = Client(
        endpoint: URL(string: "https://example.com/graphql")!,
        apiKey: "test-key"
    )

    struct SimpleResult: Codable, Sendable {
        let name: String
    }

    struct DetailResult: Codable, Sendable {
        let id: String
        let value: Int
    }

    struct CreateInput: Encodable {
        let name: String
    }

    @Test func queryWithoutInput() throws {
        let request = try client.graphQLRequest(
            kind: .query,
            operation: "getUsers()",
            input: Optional<EmptyVariables>.none,
            as: SimpleResult.self
        )
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let query = body["query"] as! String
        #expect(query.contains("query GetUsers"))
        #expect(query.contains("getUsers"))
        #expect(query.contains("{ name }"))
    }

    @Test func queryWithInput() throws {
        let request = try client.graphQLRequest(
            kind: .query,
            operation: "getUser()",
            input: CreateInput(name: "test"),
            as: DetailResult.self
        )
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let query = body["query"] as! String
        #expect(query.contains("$input: CreateInput!"))
        #expect(query.contains("getUser(input: $input)"))
        #expect(query.contains("{ id value }"))
    }

    @Test func mutationWithoutInput() throws {
        let request = try client.graphQLRequest(
            kind: .mutation,
            operation: "resetData()",
            input: Optional<EmptyVariables>.none,
            as: SimpleResult.self
        )
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let query = body["query"] as! String
        #expect(query.contains("mutation ResetData"))
        #expect(query.contains("resetData"))
    }

    @Test func mutationWithInput() throws {
        let request = try client.graphQLRequest(
            kind: .mutation,
            operation: "createItem()",
            input: CreateInput(name: "new"),
            as: DetailResult.self
        )
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let query = body["query"] as! String
        #expect(query.contains("mutation CreateItem"))
        #expect(query.contains("$input: CreateInput!"))
        #expect(query.contains("createItem(input: $input)"))
    }

    @Test func operationNameConversion() {
        #expect("getUsers()".toGraphQLOperationName() == "GetUsers")
        #expect("createItem()".toGraphQLOperationName() == "CreateItem")
        #expect("simpleOp".toGraphQLOperationName() == "SimpleOp")
        #expect("a".toGraphQLOperationName() == "A")
    }

    @Test func reverseOperationNameConversion() {
        #expect("GetUsers".fromGraphQLOperationName() == "getUsers")
        #expect("CreateItem".fromGraphQLOperationName() == "createItem")
    }

    @Test func requestVariablesIncluded() throws {
        let request = try client.graphQLRequest(
            kind: .query,
            operation: "getUser()",
            input: CreateInput(name: "alice"),
            as: SimpleResult.self
        )
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let variables = body["variables"] as! [String: Any]
        let input = variables["input"] as! [String: Any]
        #expect(input["name"] as? String == "alice")
    }
}
