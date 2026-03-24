// WristControlMac/MouseController.swift
import Foundation
import CoreGraphics

class MouseController {

    private init() {}

    static func moveMouse(deltaX: Float, deltaY: Float) {
        guard let event = CGEvent(source: nil) else { return }
        let currentPos = event.location
        let newX = currentPos.x + CGFloat(deltaX)
        let newY = currentPos.y + CGFloat(deltaY)

        // Clamp to screen bounds (CGDisplayBounds is thread-safe, unlike NSScreen.main)
        let screenBounds = CGDisplayBounds(CGMainDisplayID())
        let clampedX = min(max(newX, 0), screenBounds.width - 1)
        let clampedY = min(max(newY, 0), screenBounds.height - 1)

        let point = CGPoint(x: clampedX, y: clampedY)
        if let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                                    mouseCursorPosition: point, mouseButton: .left) {
            moveEvent.post(tap: .cghidEventTap)
        }
    }

    static func click() {
        guard let event = CGEvent(source: nil) else { return }
        let pos = event.location

        if let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                               mouseCursorPosition: pos, mouseButton: .left) {
            down.post(tap: .cghidEventTap)
        }
        if let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                             mouseCursorPosition: pos, mouseButton: .left) {
            up.post(tap: .cghidEventTap)
        }
    }

    static func rightClick() {
        guard let event = CGEvent(source: nil) else { return }
        let pos = event.location

        if let down = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown,
                               mouseCursorPosition: pos, mouseButton: .right) {
            down.post(tap: .cghidEventTap)
        }
        if let up = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp,
                             mouseCursorPosition: pos, mouseButton: .right) {
            up.post(tap: .cghidEventTap)
        }
    }

    static func scroll(deltaY: Float) {
        if let scrollEvent = CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                                      wheelCount: 1, wheel1: Int32(deltaY * 10),
                                      wheel2: 0, wheel3: 0) {
            scrollEvent.post(tap: .cghidEventTap)
        }
    }
}
