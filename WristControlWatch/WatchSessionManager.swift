// WristControlWatch/WatchSessionManager.swift
import Foundation
import WatchConnectivity

class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    var onStatusUpdate: ((StatusUpdate) -> Void)?

    private var session: WCSession?

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    func send(command: ControlCommand) {
        guard let session = session, session.isReachable else {
            print("[WristControl] iPhone not reachable")
            return
        }

        session.sendMessage(
            command.dictionaryRepresentation,
            replyHandler: nil,
            errorHandler: { error in
                print("[WristControl] Error sending command: \(error.localizedDescription)")
            }
        )
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error = error {
            print("[WristControl] WCSession activation error: \(error.localizedDescription)")
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let brightnessVal = message["brightness"] as? Float,
           let volumeVal = message["volume"] as? Float,
           let connected = message["connected"] as? Bool {
            let status = StatusUpdate(
                brightness: brightnessVal,
                volume: volumeVal,
                connected: connected
            )
            DispatchQueue.main.async {
                self.onStatusUpdate?(status)
            }
        }
    }
}
