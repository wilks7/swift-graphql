import Foundation

protocol Fragmentable {
    static var fragment: String { get }
}

// MARK: - Default Implementation via Codable Introspection

extension Fragmentable where Self: Decodable {
    static var fragment: String {
        if let cached = FragmentCache.shared.get(for: Self.self) {
            return cached
        }
        let introspector = FragmentIntrospector()
        _ = try? Self.init(from: introspector)
        let result = introspector.buildFragment()
        FragmentCache.shared.set(result, for: Self.self)
        return result
    }
}

// MARK: - Scalar Conformances

extension String: Fragmentable { static var fragment: String { "" } }
extension Int: Fragmentable { static var fragment: String { "" } }
extension Bool: Fragmentable { static var fragment: String { "" } }
extension Double: Fragmentable { static var fragment: String { "" } }
extension URL: Fragmentable { static var fragment: String { "" } }
extension Date: Fragmentable { static var fragment: String { "" } }
extension Decimal: Fragmentable { static var fragment: String { "" } }

extension Array: Fragmentable where Element: Fragmentable {
    static var fragment: String {
        return Element.fragment
    }
}

// MARK: - Fragment Resolver (Public-facing fragment generation for any Decodable)

enum FragmentResolver {
    static func fragment<T: Decodable>(for type: T.Type) -> String {
        if let fragmentable = type as? any Fragmentable.Type {
            return fragmentable.fragment
        }
        // Unwrap Optional<Wrapped> → resolve fragment for Wrapped
        if let optionalType = type as? any DecodableOptionalProtocol.Type {
            return optionalType.wrappedFragment
        }
        // Unwrap Array<Element> → resolve fragment for Element
        if let arrayType = type as? any DecodableArrayProtocol.Type {
            return arrayType.elementFragment
        }
        if let cached = FragmentCache.shared.get(for: type) {
            return cached
        }
        let introspector = FragmentIntrospector()
        _ = try? T.init(from: introspector)
        let result = introspector.buildFragment()
        FragmentCache.shared.set(result, for: type)
        return result
    }
}

/// Helper protocol to unwrap Optional<Wrapped> for fragment resolution.
private protocol DecodableOptionalProtocol {
    static var wrappedFragment: String { get }
}

extension Optional: DecodableOptionalProtocol where Wrapped: Decodable {
    static var wrappedFragment: String {
        FragmentResolver.fragment(for: Wrapped.self)
    }
}

/// Helper protocol to unwrap Array element types for fragment resolution.
private protocol DecodableArrayProtocol {
    static var elementFragment: String { get }
}

extension Array: DecodableArrayProtocol where Element: Decodable {
    static var elementFragment: String {
        FragmentResolver.fragment(for: Element.self)
    }
}

// MARK: - Fragment Cache

final class FragmentCache: @unchecked Sendable {
    static let shared = FragmentCache()
    private var cache: [ObjectIdentifier: String] = [:]
    private let lock = NSLock()

    func get(for type: any Any.Type) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return cache[ObjectIdentifier(type)]
    }

    func set(_ fragment: String, for type: any Any.Type) {
        lock.lock()
        defer { lock.unlock() }
        cache[ObjectIdentifier(type)] = fragment
    }
}

// MARK: - Fragment Introspector (Custom Decoder)

final class FragmentIntrospector: Decoder {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]
    var fields: [(name: String, subFragment: String?)] = []

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        KeyedDecodingContainer(IntrospectionKeyedContainer<Key>(introspector: self))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        IntrospectionUnkeyedContainer()
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        IntrospectionSingleValueContainer()
    }

    func buildFragment() -> String {
        fields.map { field in
            if let sub = field.subFragment {
                return "\(field.name) { \(sub) }"
            }
            return field.name
        }.joined(separator: " ")
    }
}

// MARK: - Keyed Container

private struct IntrospectionKeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let introspector: FragmentIntrospector
    var codingPath: [CodingKey] { introspector.codingPath }
    var allKeys: [Key] { [] }

    func contains(_ key: Key) -> Bool { true }

    func decodeNil(forKey key: Key) throws -> Bool { false }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        introspector.fields.append((name: key.stringValue, subFragment: nil))
        return false
    }
    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        introspector.fields.append((name: key.stringValue, subFragment: nil))
        return ""
    }
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        introspector.fields.append((name: key.stringValue, subFragment: nil))
        return 0
    }
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        introspector.fields.append((name: key.stringValue, subFragment: nil))
        return 0
    }
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        introspector.fields.append((name: key.stringValue, subFragment: nil))
        return 0
    }
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
        introspector.fields.append((name: key.stringValue, subFragment: nil))
        return 0
    }
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
        introspector.fields.append((name: key.stringValue, subFragment: nil))
        return 0
    }
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
        introspector.fields.append((name: key.stringValue, subFragment: nil))
        return 0
    }
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
        introspector.fields.append((name: key.stringValue, subFragment: nil))
        return 0
    }
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
        introspector.fields.append((name: key.stringValue, subFragment: nil))
        return 0
    }
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
        introspector.fields.append((name: key.stringValue, subFragment: nil))
        return 0
    }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
        introspector.fields.append((name: key.stringValue, subFragment: nil))
        return 0
    }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
        introspector.fields.append((name: key.stringValue, subFragment: nil))
        return 0
    }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
        introspector.fields.append((name: key.stringValue, subFragment: nil))
        return 0
    }
    func decode(_ type: Decimal.Type, forKey key: Key) throws -> Decimal {
        introspector.fields.append((name: key.stringValue, subFragment: nil))
        return 0
    }

    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        // Decimal is a struct but GraphQL treats it as a scalar (serialized as string).
        if type == Decimal.self {
            introspector.fields.append((name: key.stringValue, subFragment: nil))
            return Decimal(0) as! T
        }

        // Check if T is CaseIterable (enum with known cases) — before fragment resolution
        if let first = firstCaseIterableValue(of: type) {
            introspector.fields.append((name: key.stringValue, subFragment: nil))
            return first
        }

        // Resolve fragment for any Decodable type (handles nested structs, arrays, etc.)
        let sub = FragmentResolver.fragment(for: T.self)
        introspector.fields.append((
            name: key.stringValue,
            subFragment: sub.isEmpty ? nil : sub
        ))
        return try dummyValue(for: type)
    }

    func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        if type == Decimal.self {
            introspector.fields.append((name: key.stringValue, subFragment: nil))
            return nil
        }
        // For optionals, capture the field but return nil (safe — no dummy value needed)
        let sub = FragmentResolver.fragment(for: T.self)
        introspector.fields.append((
            name: key.stringValue,
            subFragment: sub.isEmpty ? nil : sub
        ))
        return nil
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        KeyedDecodingContainer(IntrospectionKeyedContainer<NestedKey>(introspector: introspector))
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        IntrospectionUnkeyedContainer()
    }

    func superDecoder() throws -> Decoder { introspector }
    func superDecoder(forKey key: Key) throws -> Decoder { introspector }
}

// MARK: - Unkeyed Container (reports empty — used for array dummy values)

private struct IntrospectionUnkeyedContainer: UnkeyedDecodingContainer {
    var codingPath: [CodingKey] { [] }
    var count: Int? { 0 }
    var isAtEnd: Bool { true }
    var currentIndex: Int { 0 }

    mutating func decodeNil() throws -> Bool { true }
    mutating func decode(_ type: Bool.Type) throws -> Bool { throw emptyError(type) }
    mutating func decode(_ type: String.Type) throws -> String { throw emptyError(type) }
    mutating func decode(_ type: Double.Type) throws -> Double { throw emptyError(type) }
    mutating func decode(_ type: Float.Type) throws -> Float { throw emptyError(type) }
    mutating func decode(_ type: Int.Type) throws -> Int { throw emptyError(type) }
    mutating func decode(_ type: Int8.Type) throws -> Int8 { throw emptyError(type) }
    mutating func decode(_ type: Int16.Type) throws -> Int16 { throw emptyError(type) }
    mutating func decode(_ type: Int32.Type) throws -> Int32 { throw emptyError(type) }
    mutating func decode(_ type: Int64.Type) throws -> Int64 { throw emptyError(type) }
    mutating func decode(_ type: UInt.Type) throws -> UInt { throw emptyError(type) }
    mutating func decode(_ type: UInt8.Type) throws -> UInt8 { throw emptyError(type) }
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 { throw emptyError(type) }
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 { throw emptyError(type) }
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 { throw emptyError(type) }
    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T { throw emptyError(type) }
    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> { throw emptyError(type) }
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer { throw emptyError(Int.self) }
    mutating func superDecoder() throws -> Decoder { throw emptyError(Int.self) }

    private func emptyError<T>(_ type: T.Type) -> DecodingError {
        DecodingError.valueNotFound(type, .init(codingPath: [], debugDescription: "Empty introspection container"))
    }
}

// MARK: - Single Value Container (returns dummy scalars — used for enum raw values)

private struct IntrospectionSingleValueContainer: SingleValueDecodingContainer {
    var codingPath: [CodingKey] { [] }

    func decodeNil() -> Bool { false }
    func decode(_ type: Bool.Type) throws -> Bool { false }
    func decode(_ type: String.Type) throws -> String { "" }
    func decode(_ type: Double.Type) throws -> Double { 0 }
    func decode(_ type: Float.Type) throws -> Float { 0 }
    func decode(_ type: Int.Type) throws -> Int { 0 }
    func decode(_ type: Int8.Type) throws -> Int8 { 0 }
    func decode(_ type: Int16.Type) throws -> Int16 { 0 }
    func decode(_ type: Int32.Type) throws -> Int32 { 0 }
    func decode(_ type: Int64.Type) throws -> Int64 { 0 }
    func decode(_ type: UInt.Type) throws -> UInt { 0 }
    func decode(_ type: UInt8.Type) throws -> UInt8 { 0 }
    func decode(_ type: UInt16.Type) throws -> UInt16 { 0 }
    func decode(_ type: UInt32.Type) throws -> UInt32 { 0 }
    func decode(_ type: UInt64.Type) throws -> UInt64 { 0 }
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try dummyValue(for: type)
    }
}

// MARK: - Helpers

/// Produce a dummy value for a Decodable type so the parent's init(from:) can continue.
private func dummyValue<T: Decodable>(for type: T.Type) throws -> T {
    if type == String.self { return "" as! T }
    if type == Int.self { return 0 as! T }
    if type == Double.self { return 0.0 as! T }
    if type == Bool.self { return false as! T }
    if type == Float.self { return Float(0) as! T }
    if type == Int8.self { return Int8(0) as! T }
    if type == Int16.self { return Int16(0) as! T }
    if type == Int32.self { return Int32(0) as! T }
    if type == Int64.self { return Int64(0) as! T }
    if type == UInt.self { return UInt(0) as! T }
    if type == UInt8.self { return UInt8(0) as! T }
    if type == UInt16.self { return UInt16(0) as! T }
    if type == UInt32.self { return UInt32(0) as! T }
    if type == UInt64.self { return UInt64(0) as! T }
    if type == Date.self { return Date(timeIntervalSince1970: 0) as! T }
    if type == URL.self { return URL(string: "https://placeholder.invalid")! as! T }
    if type == Data.self { return Data() as! T }
    if type == Decimal.self { return Decimal(0) as! T }

    // CaseIterable enum — return first case
    if let first = firstCaseIterableValue(of: type) {
        return first
    }

    // Nested Decodable — recurse with a fresh introspector
    return try T.init(from: FragmentIntrospector())
}

/// Extract the first case from a CaseIterable type via existential opening.
private func firstCaseIterableValue<T>(of type: T.Type) -> T? {
    func extract<C: CaseIterable>(_ caseIterableType: C.Type) -> Any? {
        var iter = C.allCases.makeIterator()
        return iter.next()
    }
    guard let caseIterableType = type as? any CaseIterable.Type else { return nil }
    return extract(caseIterableType) as? T
}
