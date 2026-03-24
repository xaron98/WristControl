// Shared/CommandProtocol.swift
import Foundation

enum ControlType: String, Codable {
    case brightness
    case volume
    case mouseMove
    case mouseClick
    case rightClick
    case scroll
    case statusRequest
    case mediaPlayPause
    case mediaNext
    case mediaPrevious
    case mute
    case sleep
    case lockScreen
    case screenshot
    case darkMode
}

struct ControlCommand: Codable {
    let type: ControlType
    let value: Float
    let deltaX: Float?
    let deltaY: Float?

    // Existing commands (brightness, volume, click)
    init(type: ControlType, value: Float) {
        self.type = type
        self.value = value
        self.deltaX = nil
        self.deltaY = nil
    }

    // Full init for dictionary deserialization
    init(type: ControlType, value: Float, deltaX: Float?, deltaY: Float?) {
        self.type = type
        self.value = value
        self.deltaX = deltaX
        self.deltaY = deltaY
    }

    // Mouse/scroll commands with deltas
    init(type: ControlType, deltaX: Float, deltaY: Float) {
        self.type = type
        self.value = 0
        self.deltaX = deltaX
        self.deltaY = deltaY
    }

    var dictionaryRepresentation: [String: Any] {
        var dict: [String: Any] = [
            "type": type.rawValue,
            "value": value
        ]
        if let dx = deltaX { dict["deltaX"] = dx }
        if let dy = deltaY { dict["deltaY"] = dy }
        return dict
    }

    static func from(dictionary: [String: Any]) -> ControlCommand? {
        guard
            let typeRaw = dictionary["type"] as? String,
            let type = ControlType(rawValue: typeRaw)
        else { return nil }
        let value = (dictionary["value"] as? NSNumber)?.floatValue ?? 0
        let deltaX = (dictionary["deltaX"] as? NSNumber)?.floatValue
        let deltaY = (dictionary["deltaY"] as? NSNumber)?.floatValue
        return ControlCommand(type: type, value: value, deltaX: deltaX, deltaY: deltaY)
    }
}

struct StatusUpdate: Codable {
    let brightness: Float
    let volume: Float
    let connected: Bool
}
