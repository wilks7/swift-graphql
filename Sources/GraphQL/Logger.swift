import Foundation
import os

/// Controls the verbosity of GraphQL request and response logging.
///
/// Used when initializing ``Client`` to set the desired log output level.
public enum LoggerLevel: Int, Sendable {
    /// No logging output.
    case none
    /// Logs operation names and basic request info.
    case info
    /// Logs full request bodies and response data.
    case debug
}

/// A logger for GraphQL operations that formats requests and responses for readability.
///
/// `GraphQLLogger` uses Apple's unified logging system (`os.Logger`) and is used
/// internally by ``Client`` to log operations based on the configured ``LoggerLevel``.
public class GraphQLLogger {

    /// The underlying `os.Logger` instance for GraphQL client operations.
    public static let client = Logger(subsystem: "GraphQL", category: "Client")

    // MARK: - Request Logging

    /// Logs an outgoing GraphQL request.
    ///
    /// - Parameters:
    ///   - request: The URL request being sent.
    ///   - operation: The GraphQL operation name.
    ///   - type: The expected response type.
    ///   - token: The bearer token, if any (logged with privacy redaction).
    ///   - debug: The current logging level.
    public static func request<T: Decodable>(
        _ request: URLRequest,
        _ operation: String,
        _ type: T.Type,
        _ token: String?,
        _ debug: LoggerLevel
    ) {
        guard debug.rawValue > 0 else { return }
        client.info("📀 \(operation) -> \(String(describing: T.self))")
        
        if debug == .debug, let httpBody = request.httpBody {
            if let token {
                client.debug("🔐 Added Authorization header with token: \(token.prefix(20), privacy: .private)...")
            } else {
                client.info("🔓 No authentication token provided")
            }
            client.debug("📤 Request:\n\(formatRequestBody(httpBody))")
        }
    }
    
    
    /// Logs a formatted GraphQL response.
    ///
    /// - Parameters:
    ///   - data: The response data.
    ///   - debug: The current logging level.
    public static func response(data: Data, _ debug: LoggerLevel) {
        guard debug == .debug else { return }
        client.debug("📦 Response:\n\(formatResponseData(data))")
    }
}

private extension GraphQLLogger {
    
    // MARK: - Private Formatting Methods
    
    /// Formats the GraphQL request body for cleaner logging
    /// - Parameter data: The request body data
    /// - Returns: A formatted string representation of the request
    static func formatRequestBody(_ data: Data) -> String {
        guard let bodyString = String(data: data, encoding: .utf8) else {
            return "Unable to decode request body"
        }
        
        // Try to parse as JSON to extract and format the GraphQL query
        guard let jsonData = bodyString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return bodyString
        }
        
        var formattedOutput = ""
        
        // Format the GraphQL query
        if let query = json["query"] as? String {
            let formattedQuery = formatGraphQLQuery(query)
            formattedOutput += "\(formattedQuery)"
        } else if let mutation = json["mutation"] as? String {
            let formattedQuery = formatGraphQLQuery(mutation)
            formattedOutput += "\(formattedQuery)"
        }
        
        // Format the variables
        if let variables = json["variables"] {
            if let variablesData = try? JSONSerialization.data(withJSONObject: variables, options: [.prettyPrinted]),
               let variablesString = String(data: variablesData, encoding: .utf8) {
                formattedOutput += "\nInput\n\(variablesString)"
            }
        }
        
        return formattedOutput.isEmpty ? bodyString : formattedOutput
    }
    
    /// Formats a GraphQL query string for better readability
    /// - Parameter query: The raw GraphQL query string
    /// - Returns: A formatted GraphQL query string
    static func formatGraphQLQuery(_ query: String) -> String {
        var formatted = query
        
        // Add newlines after common GraphQL keywords and punctuation
        formatted = formatted.replacingOccurrences(of: " { ", with: " {\n  ")
        formatted = formatted.replacingOccurrences(of: "{ ", with: "{\n  ")
        formatted = formatted.replacingOccurrences(of: " }", with: "\n}")
        formatted = formatted.replacingOccurrences(of: "} ", with: "}\n")
        
        // Add proper indentation
        let lines = formatted.components(separatedBy: "\n")
        var indentLevel = 0
        var formattedLines: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Decrease indent for closing braces
            if trimmedLine.contains("}") {
                indentLevel = max(0, indentLevel - 1)
            }
            
            // Add the indented line
            let indent = String(repeating: "  ", count: indentLevel)
            formattedLines.append(indent + trimmedLine)
            
            // Increase indent for opening braces
            if trimmedLine.contains("{") {
                indentLevel += 1
            }
        }
        
        return formattedLines.joined(separator: "\n")
    }
    
    /// Formats the GraphQL response data for cleaner logging
    /// - Parameter data: The response data
    /// - Returns: A formatted string representation of the response
    static func formatResponseData(_ data: Data) -> String {
        guard let responseString = String(data: data, encoding: .utf8) else {
            return "Unable to decode response data"
        }
        
        // Try to parse as JSON and pretty print it
        guard let jsonData = responseString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) else {
            return responseString
        }
        
        // Pretty print the JSON without escaping slashes
        guard let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return responseString
        }
        
        return prettyString
    }
}

extension DecodingError {
    var prettyDescription: String {
        switch self {
        case .typeMismatch(let type, let context):
            return """
            Type mismatch for \(type)
            Path: \(context.codingPath.prettyPath)
            Debug: \(context.debugDescription)
            """

        case .valueNotFound(let type, let context):
            return """
            Value not found for \(type)
            Path: \(context.codingPath.prettyPath)
            Debug: \(context.debugDescription)
            """

        case .keyNotFound(let key, let context):
            return """
            Key not found: \(key.stringValue)
            Path: \(context.codingPath.prettyPath)
            Debug: \(context.debugDescription)
            """

        case .dataCorrupted(let context):
            return """
            Data corrupted
            Path: \(context.codingPath.prettyPath)
            Debug: \(context.debugDescription)
            """
        @unknown default:
            return "Unknown DecodingError"
        }
    }
}

extension Array where Element == CodingKey {
    var prettyPath: String {
        map { $0.stringValue }.joined(separator: ".")
    }
}
