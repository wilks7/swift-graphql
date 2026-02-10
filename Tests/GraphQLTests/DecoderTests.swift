import Testing
import Foundation
@testable import GraphQL

@Suite("Response Decoding Tests")
struct ResponseDecodingTests {

    let client = Client(
        endpoint: URL(string: "https://example.com/graphql")!,
        apiKey: "test-key"
    )

    struct User: Codable {
        let id: String
        let name: String
    }

    struct NestedResponse: Codable {
        let title: String
        let author: Author

        struct Author: Codable {
            let name: String
        }
    }

    @Test func successfulDecode() throws {
        let json = """
        {"data":{"getUser":{"id":"1","name":"Alice"}}}
        """.data(using: .utf8)!
        let user: User = try client.decode(json, operation: "getUser()")
        #expect(user.id == "1")
        #expect(user.name == "Alice")
    }

    @Test func graphQLErrorThrows() {
        let json = """
        {"errors":[{"message":"Not found"}],"data":null}
        """.data(using: .utf8)!
        #expect(throws: GraphQLError.self) {
            let _: User = try client.decode(json, operation: "getUser()")
        }
    }

    @Test func graphQLErrorMessage() {
        let json = """
        {"errors":[{"message":"User not found"}],"data":null}
        """.data(using: .utf8)!
        do {
            let _: User = try client.decode(json, operation: "getUser()")
            Issue.record("Expected GraphQLError to be thrown")
        } catch let error as GraphQLError {
            #expect(error.message == "User not found")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test func missingDataThrows() {
        let json = """
        {"data":null}
        """.data(using: .utf8)!
        #expect(throws: GraphQLError.self) {
            let _: User = try client.decode(json, operation: "getUser()")
        }
    }

    @Test func nestedObjectDecode() throws {
        let json = """
        {"data":{"getPost":{"title":"Hello","author":{"name":"Bob"}}}}
        """.data(using: .utf8)!
        let post: NestedResponse = try client.decode(json, operation: "getPost()")
        #expect(post.title == "Hello")
        #expect(post.author.name == "Bob")
    }

    @Test func errorWithDataPrefersError() {
        let json = """
        {"errors":[{"message":"Partial failure"}],"data":{"getUser":{"id":"1","name":"X"}}}
        """.data(using: .utf8)!
        #expect(throws: GraphQLError.self) {
            let _: User = try client.decode(json, operation: "getUser()")
        }
    }
}

// MARK: - Date Decoding Tests

@Suite("Date Decoding Tests")
struct DateDecodingTests {

    let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .flexibleDateDecoding
        return d
    }()

    struct DateWrapper: Codable {
        let date: Date
    }

    @Test func iso8601WithFractionalSeconds() throws {
        let json = """
        {"date":"2025-01-15T10:30:00.123Z"}
        """.data(using: .utf8)!
        let wrapper = try decoder.decode(DateWrapper.self, from: json)
        #expect(wrapper.date.timeIntervalSince1970 > 0)
    }

    @Test func iso8601WithoutFractionalSeconds() throws {
        let json = """
        {"date":"2025-01-15T10:30:00Z"}
        """.data(using: .utf8)!
        let wrapper = try decoder.decode(DateWrapper.self, from: json)
        #expect(wrapper.date.timeIntervalSince1970 > 0)
    }

    @Test func dateWithTimezone() throws {
        let json = """
        {"date":"2025-01-15T10:30:00+05:00"}
        """.data(using: .utf8)!
        let wrapper = try decoder.decode(DateWrapper.self, from: json)
        #expect(wrapper.date.timeIntervalSince1970 > 0)
    }

    @Test func dateWithoutTimezone() throws {
        let json = """
        {"date":"2025-01-15T10:30:00"}
        """.data(using: .utf8)!
        let wrapper = try decoder.decode(DateWrapper.self, from: json)
        #expect(wrapper.date.timeIntervalSince1970 > 0)
    }

    @Test func dateWithMicroseconds() throws {
        let json = """
        {"date":"2025-09-16T16:32:54.188511"}
        """.data(using: .utf8)!
        let wrapper = try decoder.decode(DateWrapper.self, from: json)
        #expect(wrapper.date.timeIntervalSince1970 > 0)
    }

    @Test func invalidDateThrows() {
        let json = """
        {"date":"not-a-date"}
        """.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(DateWrapper.self, from: json)
        }
    }
}
