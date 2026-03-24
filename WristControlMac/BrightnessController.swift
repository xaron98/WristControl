// WristControlMac/BrightnessController.swift
import Foundation
import CoreGraphics

class BrightnessController {

    // Current software brightness level (0.0 = black, 1.0 = full)
    private static var currentBrightness: Float = 1.0

    // Original gamma tables to scale from
    private static var originalRed = [CGGammaValue](repeating: 0, count: 256)
    private static var originalGreen = [CGGammaValue](repeating: 0, count: 256)
    private static var originalBlue = [CGGammaValue](repeating: 0, count: 256)
    private static var originalSampleCount: UInt32 = 0
    private static var hasOriginal = false

    private static func captureOriginalGamma() {
        guard !hasOriginal else { return }
        let display = CGMainDisplayID()
        var count: UInt32 = 0
        let err = CGGetDisplayTransferByTable(
            display, 256,
            &originalRed, &originalGreen, &originalBlue,
            &count
        )
        if err == .success && count > 0 {
            originalSampleCount = count
            hasOriginal = true
        }
    }

    static func setBrightness(_ value: Float) {
        captureOriginalGamma()

        let clamped = min(max(value, 0.0), 1.0)
        currentBrightness = clamped

        let display = CGMainDisplayID()
        let count = hasOriginal ? Int(originalSampleCount) : 256

        var red = [CGGammaValue](repeating: 0, count: count)
        var green = [CGGammaValue](repeating: 0, count: count)
        var blue = [CGGammaValue](repeating: 0, count: count)

        for i in 0..<count {
            if hasOriginal {
                red[i] = originalRed[i] * clamped
                green[i] = originalGreen[i] * clamped
                blue[i] = originalBlue[i] * clamped
            } else {
                let v = (Float(i) / Float(count - 1)) * clamped
                red[i] = v
                green[i] = v
                blue[i] = v
            }
        }

        CGSetDisplayTransferByTable(display, UInt32(count), red, green, blue)
    }

    static func getBrightness() -> Float {
        return currentBrightness
    }
}
