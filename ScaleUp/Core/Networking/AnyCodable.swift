//
// AnyCodable.swift
//
// Used by generated schemas (under ScaleUp/Generated/OpenAPI/) that
// expose opaque `data` fields like the success-envelope payload. Lives
// outside the generated dir so scripts/regenerate-openapi-types.sh
// (which wipes the dir) doesn't delete it.
//
import Foundation

public struct AnyCodable: Codable, Hashable, @unchecked Sendable {
    public let value: Any?

    public init(_ value: Any? = nil) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = nil
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues { $0.value }
        } else {
            self.value = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case nil:
            try container.encodeNil()
        case let v as Bool:
            try container.encode(v)
        case let v as Int:
            try container.encode(v)
        case let v as Double:
            try container.encode(v)
        case let v as String:
            try container.encode(v)
        case let v as [Any?]:
            try container.encode(v.map { AnyCodable($0) })
        case let v as [String: Any?]:
            try container.encode(v.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }

    public func hash(into hasher: inout Hasher) {
        if let data = try? JSONEncoder().encode(self),
           let s = String(data: data, encoding: .utf8) {
            hasher.combine(s)
        } else {
            hasher.combine(0)
        }
    }

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        let l = (try? JSONEncoder().encode(lhs)) ?? Data()
        let r = (try? JSONEncoder().encode(rhs)) ?? Data()
        return l == r
    }
}
