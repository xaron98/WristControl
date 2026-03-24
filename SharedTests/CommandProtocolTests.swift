// SharedTests/CommandProtocolTests.swift
import XCTest
@testable import WristControlPhone // Will import Shared via target membership

final class CommandProtocolTests: XCTestCase {

    func testControlCommandEncodeDecode() throws {
        let command = ControlCommand(type: .brightness, value: 0.75)
        let data = try JSONEncoder().encode(command)
        let decoded = try JSONDecoder().decode(ControlCommand.self, from: data)
        XCTAssertEqual(decoded.type, .brightness)
        XCTAssertEqual(decoded.value, 0.75, accuracy: 0.001)
    }

    func testControlCommandDictionaryRoundTrip() {
        let command = ControlCommand(type: .volume, value: 0.5)
        let dict = command.dictionaryRepresentation
        let restored = ControlCommand.from(dictionary: dict)
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.type, .volume)
        XCTAssertEqual(restored?.value ?? 0, 0.5, accuracy: 0.001)
    }

    func testControlCommandFromInvalidDictionary() {
        let bad: [String: Any] = ["type": "invalid", "value": 0.5]
        XCTAssertNil(ControlCommand.from(dictionary: bad))

        let missing: [String: Any] = ["type": "brightness"]
        XCTAssertNil(ControlCommand.from(dictionary: missing))
    }

    func testStatusUpdateEncodeDecode() throws {
        let status = StatusUpdate(brightness: 0.8, volume: 0.3, connected: true)
        let data = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(StatusUpdate.self, from: data)
        XCTAssertEqual(decoded.brightness, 0.8, accuracy: 0.001)
        XCTAssertEqual(decoded.volume, 0.3, accuracy: 0.001)
        XCTAssertTrue(decoded.connected)
    }
}
