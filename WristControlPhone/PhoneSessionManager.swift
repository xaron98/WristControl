// WristControlPhone/PhoneSessionManager.swift
import Foundation
import WatchConnectivity

class PhoneSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = PhoneSessionManager()

    @Published var watchReachable: Bool = false

    var onCommandReceived: ((ControlCommand) -> Void)?

    private var session: WCSession?

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    func sendStatus(_ status: StatusUpdate) {
        guard let session = session, session.isReachable else { return }

        let message: [String: Any] = [
            "brightness": status.brightness,
            "volume": status.volume,
            "connected": status.connected
        ]

        session.sendMessage(message, replyHandler: nil) { error in
            #if DEBUG
            print("[WristControl] Error sending status to Watch: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.watchReachable = session.isReachable
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.watchReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let command = ControlCommand.from(dictionary: message) {
            DispatchQueue.main.async {
                self.onCommandReceived?(command)
            }
        }
    }
}
