import Foundation

// MARK: - Cached Date Formatters

private let iso8601WithFractional: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

private let iso8601Standard: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

private let iso8601FullDateTimeZone: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withFullDate, .withTime, .withTimeZone]
    return f
}()

private let iso8601NoTimezoneFractional: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withFullDate, .withTime, .withFractionalSeconds]
    return f
}()

private let iso8601NoTimezone: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withFullDate, .withTime]
    return f
}()

private let microsecondFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
    f.timeZone = TimeZone(secondsFromGMT: 0)
    return f
}()

private let noFractionFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    f.timeZone = TimeZone(secondsFromGMT: 0)
    return f
}()

// MARK: - Flexible Date Decoding

public extension JSONDecoder.DateDecodingStrategy {
    /// A date decoding strategy that handles multiple ISO 8601 formats.
    ///
    /// This strategy tries several common ISO 8601 variants in order, including
    /// formats with and without fractional seconds, timezones, and microsecond precision.
    /// It is applied automatically when you create a ``Client``.
    static let flexibleDateDecoding = JSONDecoder.DateDecodingStrategy.custom { decoder in
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)

        if let d = iso8601WithFractional.date(from: dateString) { return d }
        if let d = iso8601Standard.date(from: dateString) { return d }
        if let d = iso8601FullDateTimeZone.date(from: dateString) { return d }
        if let d = iso8601NoTimezoneFractional.date(from: dateString) { return d }
        if let d = iso8601NoTimezone.date(from: dateString) { return d }
        if let d = microsecondFormatter.date(from: dateString) { return d }
        if let d = noFractionFormatter.date(from: dateString) { return d }

        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected date string to be ISO8601-formatted, but found '\(dateString)'"
            )
        )
    }
}

// MARK: - Decimal from String

/// GraphQL `Decimal` scalars are serialized as JSON strings (e.g. `"0.3713"`)
/// by Strawberry and many other servers. These overloads let synthesized
/// `Codable` decode `Decimal` properties transparently — no custom
/// `init(from:)` needed on your model structs.
extension KeyedDecodingContainer {
    public func decode(_ type: Decimal.Type, forKey key: Key) throws -> Decimal {
        if let value = try decodeIfPresent(Decimal.self, forKey: key) {
            return value
        }
        throw DecodingError.valueNotFound(Decimal.self, .init(
            codingPath: codingPath + [key],
            debugDescription: "Expected Decimal but found null or missing value."
        ))
    }

    public func decodeIfPresent(_ type: Decimal.Type, forKey key: Key) throws -> Decimal? {
        guard contains(key) else { return nil }
        if try decodeNil(forKey: key) { return nil }

        if let stringValue = try? decode(String.self, forKey: key),
           let decimalValue = Decimal(string: stringValue) {
            return decimalValue
        }
        if let doubleValue = try? decode(Double.self, forKey: key) {
            return Decimal(doubleValue)
        }
        if let intValue = try? decode(Int.self, forKey: key) {
            return Decimal(intValue)
        }

        throw DecodingError.typeMismatch(Decimal.self, .init(
            codingPath: codingPath + [key],
            debugDescription: "Value for key '\(key.stringValue)' could not be converted to Decimal."
        ))
    }
}

extension SingleValueDecodingContainer {
    public func decode(_ type: Decimal.Type) throws -> Decimal {
        if let stringValue = try? decode(String.self),
           let decimalValue = Decimal(string: stringValue) {
            return decimalValue
        }
        if let doubleValue = try? decode(Double.self) {
            return Decimal(doubleValue)
        }
        if let intValue = try? decode(Int.self) {
            return Decimal(intValue)
        }
        throw DecodingError.typeMismatch(Decimal.self, .init(
            codingPath: codingPath,
            debugDescription: "Value could not be converted to Decimal."
        ))
    }
}

// MARK: - Response Types

struct Response<D: Decodable>: Decodable {
    let data: KeyedDataWrapper<D>?
    let errors: [ErrorResponse]?
    var value: D? { data?.value }
}

struct ErrorResponse: Decodable {
    let message: String
    let locations: [Location]?
    let path: [String]?

    struct Location: Decodable {
        let line: Int
        let column: Int
    }
}

struct KeyedDataWrapper<D: Decodable>: Decodable {
    let value: D

    struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int?
        init?(intValue: Int) { return nil }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        guard let key = decoder.userInfo[.functionNameKey] as? String else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Missing functionNameKey in userInfo"))
        }
        let dynamicKey = DynamicCodingKeys(stringValue: key)!
        value = try container.decode(D.self, forKey: dynamicKey)
    }
}

extension CodingUserInfoKey {
    static let functionNameKey = CodingUserInfoKey(rawValue: "functionNameKey")!
}
