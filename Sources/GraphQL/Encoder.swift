import Foundation
import os


/// A GraphQL request builder for creating URLRequests and decoding responses
/// Does not perform network requests - that's left to the consuming code
extension Client {
    enum GraphQLOperation: String { case query, mutation }
    
    /// Build a GraphQL mutation URLRequest with input
    /// - Parameters:
    ///   - operation: The operation name
    ///   - input: The input parameters
    ///   - type: The expected return type
    /// - Returns: URLRequest ready for execution
    /// - Throws: An error if the request cannot be built
    internal func graphQLRequest<T: Codable & Sendable, Input: Encodable>(
        kind: GraphQLOperation,
        operation: String,
        input: Input?,
        files: [FileUpload] = [],
        as type: T.Type = T.self
    ) throws -> URLRequest {
        let document = makeDocument(kind: kind, operation: operation, input: input, as: type)

        if !files.isEmpty {
            if let input {
                return try buildMultipartRequest(query: document, variables: ["input": input], files: files)
            } else {
                 return try buildMultipartRequest(query: document, variables: EmptyVariables(), files: files)
            }
        }
        
        if let input {
            return try buildRequest(query: document, variables: ["input": input])
        } else {
            return try buildRequest(query: document, variables: EmptyVariables())
        }
    }


    private func makeDocument<T: Decodable, Input: Encodable>(
        kind: GraphQLOperation,
        operation: String,
        input: Input?,
        as type: T.Type = T.self
    ) -> String {
        let operationName = operation.toGraphQLOperationName()
        let camelCaseOperation = operationName.prefix(1).lowercased() + operationName.dropFirst()
        let fragment = FragmentResolver.fragment(for: T.self)
        let selectionSet = fragment.isEmpty ? "" : " { \(fragment) }"
        
        if let input {
            let inputTypeName: String
            if let named = input as? GraphQLNamed {
                inputTypeName = named.graphQLTypeName
            } else {
                inputTypeName = String(describing: Input.self)
            }
            return """
            \(kind.rawValue) \(operationName)($input: \(inputTypeName)!) {
                \(camelCaseOperation)(input: $input)\(selectionSet)
            }
            """
        } else {
            return """
            \(kind.rawValue) \(operationName) {
                \(camelCaseOperation)\(selectionSet)
            }
            """
        }
    }
    
    /// Builds a GraphQL request
    /// - Parameters:
    ///   - query: The GraphQL query string
    ///   - variables: Optional variables to include with the query
    /// - Returns: URLRequest ready for execution
    /// - Throws: An error if the request cannot be built
    private func buildRequest<V: Encodable>(
        query: String,
        variables: V
    ) throws -> URLRequest {
        let body = try encode(query: query, variables: variables)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = body
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        return request
    }

    
    /// Encodes a GraphQL request into JSON data
    private func encode<E: Encodable>(query: String, variables: E?) throws -> Data {
        let request = Request(query: query, variables: variables)
        return try encoder.encode(request)
    }


}

extension String {
    /// Converts a Swift function name to a GraphQL operation name
    /// Example: "getStoreGiftCards()" -> "GetStoreGiftCards"
    func toGraphQLOperationName() -> String {
        // Remove parameter list if present
        let functionName = self.prefix(while: { $0 != "(" })
        
        // Convert camelCase to PascalCase for GraphQL
        return String(functionName).prefix(1).uppercased() + String(functionName).dropFirst()
    }
    
    func fromGraphQLOperationName() -> String {
        let operation = self
        return operation.toGraphQLOperationName().prefix(1).lowercased() + operation.toGraphQLOperationName().dropFirst()
    }
}

/// Conform to this protocol to override the GraphQL input type name
/// derived from `String(describing:)`. Useful when the Swift type name
/// doesn't match the backend schema (e.g. generic wrappers).
public protocol GraphQLNamed {
    var graphQLTypeName: String { get }
}

/// GraphQL request structure
private struct Request<V: Encodable>: Encodable {
    let query: String
    let variables: V?
}


internal struct EmptyVariables: Encodable {
    // Empty struct for operations without variables
}
