import Foundation
import os

/// A lightweight GraphQL client that executes queries and mutations over HTTP.
///
/// `Client` handles request construction, execution, and response decoding for
/// GraphQL operations. It automatically generates selection sets from your `Decodable`
/// response types using `FragmentResolver`, so you don't need to write raw GraphQL strings.
///
/// ```swift
/// let client = Client(
///     endpoint: URL(string: "https://api.example.com/graphql")!,
///     apiKey: "your-api-key"
/// )
///
/// let user: User = try await client.query(token: authToken)
/// ```
///
/// ## Topics
///
/// ### Creating a Client
/// - ``init(endpoint:apiKey:urlSession:encoder:decoder:debug:)``
///
/// ### Queries
/// - ``query(operation:input:as:token:)``
/// - ``query(operation:as:token:)``
///
/// ### Mutations
/// - ``mutation(operation:input:files:token:as:)``
/// - ``mutation(operation:files:token:as:)``
///
/// ### Decoding
/// - ``decode(_:operation:as:)``
public struct Client: Sendable {
    let endpoint: URL
    let apiKey: String

    let urlSession: URLSession
    let encoder: JSONEncoder
    let decoder: JSONDecoder

    let debug: LoggerLevel

    /// Creates a new GraphQL client.
    ///
    /// - Parameters:
    ///   - endpoint: The URL of the GraphQL server.
    ///   - apiKey: The API key sent in the `X-API-Key` header with every request.
    ///   - urlSession: The URL session to use for network requests. Defaults to `.shared`.
    ///   - encoder: The JSON encoder for serializing request variables. Defaults to `JSONEncoder()`.
    ///   - decoder: The JSON decoder for deserializing responses. Configured with flexible ISO 8601 date decoding automatically.
    ///   - debug: The logging verbosity level. Defaults to ``LoggerLevel/info``.
    public init(
        endpoint: URL,
        apiKey: String,
        urlSession: URLSession = .shared,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder(),
        debug: LoggerLevel = .info
    ) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        
        self.urlSession = urlSession
        decoder.dateDecodingStrategy = .flexibleDateDecoding
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        self.decoder = decoder
        
        self.debug = debug
    }
    
    // MARK: - Private Network Execution
    
    func execute<T: Decodable>(
        _ request: URLRequest,
        operation: String,
        as type: T.Type,
        token: String?
    ) async throws -> T {
        var request = request
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            GraphQLLogger.request(request, operation, type, token, debug)
            let (data, _) = try await urlSession.data(for: request)
            GraphQLLogger.response(data: data, debug)
            return try decode(data, operation: operation, as: type)
        } catch {
            GraphQLLogger.client.error("🚨 GraphQL Error: \(error.localizedDescription)")

            throw error
        }
    }
    
    /// Decodes raw GraphQL response data into the specified type.
    ///
    /// This is called automatically by ``query(operation:as:token:)`` and
    /// ``mutation(operation:files:token:as:)``, but is also available for manual decoding
    /// when you have raw response data.
    ///
    /// - Parameters:
    ///   - data: The raw JSON response data from the GraphQL server.
    ///   - operation: The operation name, used to locate the data key in the response.
    ///   - type: The expected `Decodable` type.
    /// - Returns: The decoded value.
    /// - Throws: ``GraphQLError`` if the server returned an error, or `DecodingError` if decoding fails.
    public func decode<D: Decodable>(_ data: Data, operation: String, as type: D.Type = D.self) throws -> D {
        let functionName = operation.fromGraphQLOperationName()
        decoder.userInfo[.functionNameKey] = String(functionName)

        let wrappedResponse = try decoder.decode(Response<D>.self, from: data)
        let error = wrappedResponse.errors?.first
        let object = wrappedResponse.data?.value
        
        if let error {
            throw GraphQLError(message: error.message, data: data)
        } else if let object{
            return object
        } else {
            throw GraphQLError(
                message: "The GraphQL response did not contain any data, expected: \(D.self).",
                data: data
            )
        }
    }
    
}

public extension Client {
    
    /// Executes a GraphQL mutation that takes input variables.
    ///
    /// The operation name is derived from the calling function name by default.
    /// The selection set is generated automatically from the response type `T`.
    ///
    /// - Parameters:
    ///   - operation: The GraphQL operation name. Defaults to the calling function name.
    ///   - input: The input variables to send with the mutation.
    ///   - files: Files to upload via the GraphQL multipart request spec. Defaults to `[]`.
    ///   - token: An optional bearer token for authorization.
    ///   - type: The expected response type.
    /// - Returns: The decoded response value.
    /// - Throws: ``GraphQLError`` if the server returned an error.
    func mutation<T: Codable & Sendable, Input: Encodable>(
        operation: String = #function,
        input: Input,
        files: [FileUpload] = [],
        token: String?,
        as type: T.Type = T.self
    ) async throws -> T {
        let request = try graphQLRequest(kind: .mutation, operation: operation, input: input, files: files, as: type)
        return try await execute(request, operation: operation, as: type, token: token)
    }

    /// Executes a GraphQL mutation without input variables.
    ///
    /// - Parameters:
    ///   - operation: The GraphQL operation name. Defaults to the calling function name.
    ///   - files: Files to upload via the GraphQL multipart request spec. Defaults to `[]`.
    ///   - token: An optional bearer token for authorization.
    ///   - type: The expected response type.
    /// - Returns: The decoded response value.
    /// - Throws: ``GraphQLError`` if the server returned an error.
    func mutation<T: Codable & Sendable>(
        operation: String = #function,
        files: [FileUpload] = [],
        token: String?,
        as type: T.Type = T.self
    ) async throws -> T {
        let request = try graphQLRequest(kind: .mutation, operation: operation, input: Optional<EmptyVariables>.none, files: files, as: type)
        return try await execute(request, operation: operation, as: type, token: token)
    }

    /// Executes a GraphQL query with input variables.
    ///
    /// The operation name is derived from the calling function name by default.
    /// The selection set is generated automatically from the response type `T`.
    ///
    /// - Parameters:
    ///   - operation: The GraphQL operation name. Defaults to the calling function name.
    ///   - input: The input variables to send with the query.
    ///   - type: The expected response type.
    ///   - token: An optional bearer token for authorization.
    /// - Returns: The decoded response value.
    /// - Throws: ``GraphQLError`` if the server returned an error.
    func query<T: Codable & Sendable, Input: Encodable>(
        operation: String = #function,
        input: Input,
        as type: T.Type = T.self,
        token: String?
    ) async throws -> T {
        let request = try graphQLRequest(kind: .query, operation: operation, input: input, as: type)
        return try await execute(request, operation: operation, as: type, token: token)
    }

    /// Executes a GraphQL query without input variables.
    ///
    /// - Parameters:
    ///   - operation: The GraphQL operation name. Defaults to the calling function name.
    ///   - type: The expected response type.
    ///   - token: An optional bearer token for authorization.
    /// - Returns: The decoded response value.
    /// - Throws: ``GraphQLError`` if the server returned an error.
    func query<T: Codable & Sendable>(
        operation: String = #function,
        as type: T.Type = T.self,
        token: String?
    ) async throws -> T {
        let request = try graphQLRequest(kind: .query, operation: operation, input: Optional<EmptyVariables>.none, as: type)
        return try await execute(request, operation: operation, as: type, token: token)
    }
}


enum RequestAuthorization: Int, Sendable {
    case none, api, token
}

/// An error returned by the GraphQL server.
///
/// Contains the error message from the server response and optionally
/// the raw response data for debugging.
public struct GraphQLError: Error, LocalizedError {
    /// The error message from the GraphQL response.
    public let message: String
    /// The raw response data, useful for debugging.
    public let data: Data?

    public var errorDescription: String? { message }
}
