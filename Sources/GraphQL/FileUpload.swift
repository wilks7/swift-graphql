import Foundation
import os

/// A file to be uploaded via the
/// [GraphQL multipart request specification](https://github.com/jaydenseric/graphql-multipart-request-spec).
///
/// Files are sent as multipart form data alongside the GraphQL operation.
/// In the JSON variables, file positions are encoded as `null` and a separate
/// `map` field tells the server where each file belongs.
///
/// ```swift
/// let upload = FileUpload(
///     data: imageData,
///     filename: "photo.heic",
///     mimeType: "image/heic"
/// )
/// let result: Photo = try await client.mutation(
///     input: UploadInput(),
///     files: [upload],
///     token: token
/// )
/// ```
///
/// ## Topics
///
/// ### Creating Uploads
/// - ``init(data:filename:mimeType:)``
/// - ``pdf(data:filename:)``
public struct FileUpload: Codable, Sendable {
    /// The raw file data.
    public var data: Data
    /// The filename to report to the server.
    public let filename: String
    /// The MIME type of the file (e.g. `"image/heic"`, `"application/pdf"`).
    public let mimeType: String
    /// The JSON path in the variables where this file should be mapped
    /// (e.g. `"variables.input.file"`). When `nil`, defaults to
    /// `"variables.input.files.{index}"` for backward compatibility.
    public let variablePath: String?

    /// Creates a file upload with the given data, filename, and MIME type.
    ///
    /// - Parameters:
    ///   - data: The raw file data.
    ///   - filename: The filename to report to the server.
    ///   - mimeType: The MIME type of the file.
    ///   - variablePath: The JSON path in the variables for this file. Defaults to `nil`.
    public init(data: Data, filename: String, mimeType: String, variablePath: String? = nil) {
        self.data = data
        self.filename = filename
        self.mimeType = mimeType
        self.variablePath = variablePath
    }

    public func encode(to encoder: Encoder) throws {
        // Files are encoded as null in the variables JSON
        // The actual file data is sent in the multipart form
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }
}

#if canImport(UIKit)
import UIKit

// MARK: - UIImage Extensions

extension FileUpload {
    /// Creates a FileUpload from a UIImage with HEIC compression
    ///
    /// - Parameters:
    ///   - image: The UIImage to upload
    ///   - filename: The filename for the upload
    /// - Returns: A FileUpload instance, or nil if the image couldn't be converted
    public static func fromHEIC(
        image: UIImage,
        filename: String
    ) -> FileUpload? {
        guard let data = image.heicData() else {
            return nil
        }
        return FileUpload(data: data, filename: filename, mimeType: "image/heic")
    }
}
#endif

// MARK: - Common File Types

extension FileUpload {
    /// Creates a FileUpload for a PDF document
    ///
    /// - Parameters:
    ///   - data: The PDF data
    ///   - filename: The filename for the upload
    /// - Returns: A FileUpload instance
    public static func pdf(data: Data, filename: String) -> FileUpload {
        FileUpload(data: data, filename: filename, mimeType: "application/pdf")
    }
}

extension Client {
    
    /// Builds a multipart/form-data request with explicit files
    func buildMultipartRequest<V: Encodable>(
        query: String,
        variables: V,
        files: [FileUpload]
    ) throws -> URLRequest {

        // Build the variable map — each file's variablePath controls where
        // the server injects the upload. Falls back to the legacy array pattern.
        var map: [String: [String]] = [:]
        for (index, file) in files.enumerated() {
            let path = file.variablePath ?? "variables.input.files.\(index)"
            map[String(index)] = [path]
        }

        // FileUpload.encode(to:) writes null, so the encoded JSON already
        // has null placeholders at the correct positions.
        let variablesData = try encoder.encode(variables)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"

        let boundary = "GraphQL-Upload-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let body = try buildMultipartBody(
            boundary: boundary,
            query: query,
            variables: variablesData,
            map: map,
            files: files
        )

        request.httpBody = body

        return request
    }
    
    /// Builds the multipart form data body
    private func buildMultipartBody(
        boundary: String,
        query: String,
        variables: Data,
        map: [String: [String]],
        files: [FileUpload]
    ) throws -> Data {
        var body = Data()
        
        // Add operations (query + variables)
        let operations = [
            "query": query,
            "variables": try JSONSerialization.jsonObject(with: variables) as Any
        ]
        let operationsData = try JSONSerialization.data(withJSONObject: operations)
        body.append(multipartField(name: "operations", data: operationsData, boundary: boundary))
        
        // Add map
        let mapData = try JSONSerialization.data(withJSONObject: map)
        body.append(multipartField(name: "map", data: mapData, boundary: boundary))
        
        // Add files
        for (index, file) in files.enumerated() {
            body.append(multipartFile(
                name: String(index),
                filename: file.filename,
                data: file.data,
                mimeType: file.mimeType,
                boundary: boundary
            ))
        }
        
        // Add closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
    
    /// Creates a multipart field for regular form data
    private func multipartField(name: String, data: Data, boundary: String) -> Data {
        var fieldData = Data()
        fieldData.append("--\(boundary)\r\n".data(using: .utf8)!)
        fieldData.append("Content-Disposition: form-data; name=\"\(name)\"\r\n".data(using: .utf8)!)
        fieldData.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
        fieldData.append(data)
        fieldData.append("\r\n".data(using: .utf8)!)
        return fieldData
    }
    
    /// Creates a multipart field for file data
    private func multipartFile(
        name: String,
        filename: String,
        data: Data,
        mimeType: String,
        boundary: String
    ) -> Data {
        var fileData = Data()
        fileData.append("--\(boundary)\r\n".data(using: .utf8)!)
        fileData.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        fileData.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        fileData.append(data)
        fileData.append("\r\n".data(using: .utf8)!)
        return fileData
    }
}
