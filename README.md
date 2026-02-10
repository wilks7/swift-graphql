# GraphQL

A lightweight Swift GraphQL client that automatically generates queries from your `Decodable` types.

## Overview

Instead of writing raw GraphQL query strings, you define standard Swift `Codable` types and the library generates selection sets automatically. The client handles request construction, execution, and response decoding.

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/daylight-energy/swift-graphql.git", from: "0.1.0"),
]
```

Then add it as a dependency to your target:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "GraphQL", package: "swift-graphql"),
    ]
)
```

## Usage

### Creating a Client

```swift
import GraphQL

let client = Client(
    endpoint: URL(string: "https://api.example.com/graphql")!,
    apiKey: "your-api-key"
)
```

### Defining Response Types

Define your response types as regular `Codable` structs. The library introspects the `Decodable` conformance at runtime to build the GraphQL selection set automatically.

```swift
struct User: Codable, Sendable {
    let id: String
    let name: String
    let email: String
}

struct Address: Codable, Sendable {
    let street: String
    let city: String
    let state: String
}

// Nested types are supported — the selection set includes sub-fields automatically
struct UserProfile: Codable, Sendable {
    let user: User
    let address: Address?
}
```

For `UserProfile`, the generated selection set would be:

```graphql
user { id name email } address { street city state }
```

### Queries

The operation name is derived from the calling function name by default. Define thin wrapper methods on your API client:

```swift
extension MyAPIClient {
    func getUser(token: String) async throws -> User {
        // Generates: query GetUser { getUser { id name email } }
        try await client.query(token: token)
    }

    func getUserProfile(input: GetUserInput, token: String) async throws -> UserProfile {
        // Generates: query GetUserProfile($input: GetUserInput!) { getUserProfile(input: $input) { user { id name email } address { street city state } } }
        try await client.query(input: input, token: token)
    }
}
```

### Mutations

```swift
struct CreateUserInput: Encodable {
    let name: String
    let email: String
}

extension MyAPIClient {
    func createUser(input: CreateUserInput, token: String) async throws -> User {
        // Generates: mutation CreateUser($input: CreateUserInput!) { createUser(input: $input) { id name email } }
        try await client.mutation(input: input, token: token)
    }
}
```

### File Uploads

File uploads use the [GraphQL multipart request spec](https://github.com/jaydenseric/graphql-multipart-request-spec):

```swift
let upload = FileUpload(
    data: imageData,
    filename: "photo.heic",
    mimeType: "image/heic"
)

let result: Photo = try await client.mutation(
    input: UploadPhotoInput(title: "My Photo"),
    files: [upload],
    token: token
)
```

Convenience initializers are available for common file types:

```swift
// PDF
let pdf = FileUpload.pdf(data: pdfData, filename: "document.pdf")

// HEIC image (iOS only)
let image = FileUpload.fromHEIC(image: uiImage, filename: "photo.heic")
```

### Error Handling

The client throws `GraphQLError` when the server returns an error:

```swift
do {
    let user: User = try await client.query(token: token)
} catch let error as GraphQLError {
    print(error.message)    // Server error message
    print(error.data)       // Raw response data for debugging
}
```

### Logging

Control log verbosity when creating the client:

```swift
// No logging
let client = Client(endpoint: url, apiKey: key, debug: .none)

// Operation names only (default)
let client = Client(endpoint: url, apiKey: key, debug: .info)

// Full request/response bodies
let client = Client(endpoint: url, apiKey: key, debug: .debug)
```

## Documentation

Full API documentation is available at [daylight-energy.github.io/swift-graphql](https://daylight-energy.github.io/swift-graphql/documentation/graphql/).

To preview documentation locally:

```bash
swift package --disable-sandbox preview-documentation --target GraphQL
# Open http://localhost:8080/documentation/graphql
```

## License

Copyright Daylight Energy. All rights reserved.
