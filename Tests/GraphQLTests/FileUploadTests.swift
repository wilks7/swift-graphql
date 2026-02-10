import Testing
import Foundation
@testable import GraphQL

@Suite("File Upload Tests")
struct FileUploadTests {

    let client = Client(
        endpoint: URL(string: "https://example.com/graphql")!,
        apiKey: "test-key"
    )

    struct UploadResult: Codable, Sendable {
        let url: String
    }

    struct UploadInput: Encodable {
        let name: String
        let files: [FileUpload]
    }

    @Test func multipartContentType() throws {
        let file = FileUpload(data: Data("test".utf8), filename: "test.txt", mimeType: "text/plain")
        let request = try client.graphQLRequest(
            kind: .mutation,
            operation: "upload()",
            input: UploadInput(name: "doc", files: [file]),
            files: [file],
            as: UploadResult.self
        )
        let contentType = request.value(forHTTPHeaderField: "Content-Type")!
        #expect(contentType.contains("multipart/form-data"))
        #expect(contentType.contains("boundary="))
    }

    @Test func multipartBodyContainsOperations() throws {
        let file = FileUpload(data: Data("hello".utf8), filename: "hello.txt", mimeType: "text/plain")
        let request = try client.graphQLRequest(
            kind: .mutation,
            operation: "upload()",
            input: UploadInput(name: "doc", files: [file]),
            files: [file],
            as: UploadResult.self
        )
        let bodyString = String(data: request.httpBody!, encoding: .utf8)!
        #expect(bodyString.contains("operations"))
        #expect(bodyString.contains("map"))
    }

    @Test func multipartBodyContainsFilename() throws {
        let file = FileUpload(data: Data("content".utf8), filename: "report.pdf", mimeType: "application/pdf")
        let request = try client.graphQLRequest(
            kind: .mutation,
            operation: "upload()",
            input: UploadInput(name: "report", files: [file]),
            files: [file],
            as: UploadResult.self
        )
        let bodyString = String(data: request.httpBody!, encoding: .utf8)!
        #expect(bodyString.contains("report.pdf"))
    }

    @Test func multipleFilesInRequest() throws {
        let file1 = FileUpload(data: Data("a".utf8), filename: "a.txt", mimeType: "text/plain")
        let file2 = FileUpload(data: Data("b".utf8), filename: "b.txt", mimeType: "text/plain")
        let request = try client.graphQLRequest(
            kind: .mutation,
            operation: "upload()",
            input: UploadInput(name: "batch", files: [file1, file2]),
            files: [file1, file2],
            as: UploadResult.self
        )
        let bodyString = String(data: request.httpBody!, encoding: .utf8)!
        #expect(bodyString.contains("a.txt"))
        #expect(bodyString.contains("b.txt"))
    }

    @Test func fileUploadEncodesAsNull() throws {
        let file = FileUpload(data: Data("test".utf8), filename: "test.txt", mimeType: "text/plain")
        let encoded = try JSONEncoder().encode(file)
        let decoded = try JSONSerialization.jsonObject(with: encoded, options: .fragmentsAllowed)
        #expect(decoded is NSNull)
    }

    @Test func pdfConvenience() {
        let file = FileUpload.pdf(data: Data("pdf".utf8), filename: "doc.pdf")
        #expect(file.filename == "doc.pdf")
        #expect(file.mimeType == "application/pdf")
    }
}
