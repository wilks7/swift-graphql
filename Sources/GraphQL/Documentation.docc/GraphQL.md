# ``GraphQL``

A lightweight Swift GraphQL client that automatically generates queries from your Decodable types.

## Overview

The GraphQL package provides a type-safe client for executing GraphQL queries and mutations over HTTP. Instead of writing raw GraphQL query strings, you define standard Swift `Codable` types and the library generates selection sets automatically via runtime introspection.

```swift
// Define your response type
struct User: Codable {
    let id: String
    let name: String
    let email: String
}

// The client generates the query for you
let client = Client(
    endpoint: URL(string: "https://api.example.com/graphql")!,
    apiKey: "your-api-key"
)

let user: User = try await client.query(token: authToken)
// Sends: query GetUser { getUser { id name email } }
```

### Key Features

- **Automatic selection sets** — response types conforming to `Decodable` are introspected at runtime to build GraphQL fragments, so you never write raw query strings.
- **File uploads** — supports the [GraphQL multipart request spec](https://github.com/jaydenseric/graphql-multipart-request-spec) for uploading files alongside mutations.
- **Flexible date decoding** — handles multiple ISO 8601 date formats out of the box.
- **Structured logging** — configurable logging of requests and responses using Apple's unified logging system.

## Topics

### Client

- ``Client``
- ``GraphQLError``

### File Uploads

- ``FileUpload``

### Logging

- ``LoggerLevel``
- ``GraphQLLogger``
