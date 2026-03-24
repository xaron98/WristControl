// WristControlMac/VolumeController.swift
import Foundation
import CoreAudio
import AudioToolbox

class VolumeController {

    private init() {}

    private static func defaultOutputDeviceID() -> AudioDeviceID {
        var deviceID = AudioDeviceID(0)
        var deviceIDSize = UInt32(MemoryLayout.size(ofValue: deviceID))
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0, nil,
            &deviceIDSize,
            &deviceID
        )
        if status != noErr {
            #if DEBUG
            print("[WristControl] Error getting default output device: \(status)")
            #endif
        }
        return deviceID
    }

    static func setVolume(_ value: Float) {
        let clamped = min(max(value, 0.0), 1.0)

        let defaultOutputDeviceID = defaultOutputDeviceID()

        var volume = Float32(clamped)
        let volumeSize = UInt32(MemoryLayout.size(ofValue: volume))

        var volumePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectSetPropertyData(
            defaultOutputDeviceID,
            &volumePropertyAddress,
            0, nil,
            volumeSize,
            &volume
        )
        if status != noErr {
            #if DEBUG
            print("[WristControl] Error setting volume: \(status)")
            #endif
        }
    }

    static func getVolume() -> Float {
        let defaultOutputDeviceID = defaultOutputDeviceID()

        var volume = Float32(0.0)
        var volumeSize = UInt32(MemoryLayout.size(ofValue: volume))

        var volumePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            defaultOutputDeviceID,
            &volumePropertyAddress,
            0, nil,
            &volumeSize,
            &volume
        )
        if status != noErr {
            #if DEBUG
            print("[WristControl] Error getting volume: \(status)")
            #endif
        }

        return volume
    }
}
