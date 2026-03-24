// WristControlMac/BrightnessController.swift
import Foundation
import CoreGraphics

class BrightnessController {

    static func setBrightness(_ value: Float) {
        let clamped = min(max(value, 0.0), 1.0)
        CoreDisplay_Display_SetUserBrightness(CGMainDisplayID(), Double(clamped))
    }

    static func getBrightness() -> Float {
        let brightness = CoreDisplay_Display_GetUserBrightness(CGMainDisplayID())
        return Float(brightness)
    }
}

// CoreDisplay private framework declarations
@_silgen_name("CoreDisplay_Display_SetUserBrightness")
func CoreDisplay_Display_SetUserBrightness(_ display: CGDirectDisplayID, _ brightness: Double)

@_silgen_name("CoreDisplay_Display_GetUserBrightness")
func CoreDisplay_Display_GetUserBrightness(_ display: CGDirectDisplayID) -> Double
