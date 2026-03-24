// WristControlMac/BrightnessController.swift
import Foundation
import CoreGraphics

class BrightnessController {

    // Load CoreDisplay private framework at runtime to avoid linker errors
    private static let coreDisplayHandle: UnsafeMutableRawPointer? = {
        dlopen("/System/Library/Frameworks/CoreDisplay.framework/CoreDisplay", RTLD_LAZY)
    }()

    private static let _setBrightness: (@convention(c) (CGDirectDisplayID, Double) -> Void)? = {
        guard let handle = coreDisplayHandle,
              let sym = dlsym(handle, "CoreDisplay_Display_SetUserBrightness") else { return nil }
        return unsafeBitCast(sym, to: (@convention(c) (CGDirectDisplayID, Double) -> Void).self)
    }()

    private static let _getBrightness: (@convention(c) (CGDirectDisplayID) -> Double)? = {
        guard let handle = coreDisplayHandle,
              let sym = dlsym(handle, "CoreDisplay_Display_GetUserBrightness") else { return nil }
        return unsafeBitCast(sym, to: (@convention(c) (CGDirectDisplayID) -> Double).self)
    }()

    static func setBrightness(_ value: Float) {
        let clamped = min(max(value, 0.0), 1.0)
        _setBrightness?(CGMainDisplayID(), Double(clamped))
    }

    static func getBrightness() -> Float {
        guard let fn = _getBrightness else { return 0.5 }
        return Float(fn(CGMainDisplayID()))
    }
}
