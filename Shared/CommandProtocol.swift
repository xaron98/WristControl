// Shared/CommandProtocol.swift
import Foundation

enum ControlType: String, Codable {
    case brightness
    case volume
}

struct ControlCommand: Codable {
    let type: ControlType
    let value: Float  // 0.0 ... 1.0

    var dictionaryRepresentation: [String: Any] {
        return [
            "type": type.rawValue,
            "value": value
        ]
    }

    static func from(dictionary: [String: Any]) -> ControlCommand? {
        guard
            let typeRaw = dictionary["type"] as? String,
            let type = ControlType(rawValue: typeRaw),
            let value = dictionary["value"] as? Float
        else { return nil }
        return ControlCommand(type: type, value: value)
    }
}

struct StatusUpdate: Codable {
    let brightness: Float
    let volume: Float
    let connected: Bool
}
