// WristControlPhone/MacConnectionManager.swift
import Foundation
import Network

class MacConnectionManager: ObservableObject {
    static let shared = MacConnectionManager()

    @Published var isConnected: Bool = false
    @Published var macName: String = "Buscando..."

    private var connection: NWConnection?
    private var browser: NWBrowser?
    private var isConnecting: Bool = false

    private let serviceType = "_wristcontrol._tcp"

    func startBrowsing() {
        // Don't browse if already connected or connecting
        guard !isConnected && !isConnecting else { return }

        stopBrowsing()

        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        browser = NWBrowser(
            for: .bonjour(type: serviceType, domain: nil),
            using: parameters
        )

        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            guard let self = self, !self.isConnected, !self.isConnecting else { return }

            if let result = results.first {
                switch result.endpoint {
                case .service(let name, _, _, _):
                    DispatchQueue.main.async {
                        self.macName = name
                    }
                    self.isConnecting = true
                    self.stopBrowsing()
                    self.connectToMac(endpoint: result.endpoint)
                default:
                    break
                }
            }
        }

        browser?.stateUpdateHandler = { state in
            print("[WristControl] Browser state: \(state)")
        }

        browser?.start(queue: .main)
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
    }

    private func connectToMac(endpoint: NWEndpoint) {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        let newConnection = NWConnection(to: endpoint, using: parameters)

        newConnection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch state {
                case .ready:
                    self.isConnecting = false
                    self.isConnected = true
                    self.receiveData()
                    self.requestCurrentStatus()
                case .failed, .cancelled:
                    self.isConnecting = false
                    self.isConnected = false
                    self.connection = nil
                    // Retry after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.startBrowsing()
                    }
                default:
                    break
                }
            }
        }

        connection?.cancel()
        connection = newConnection
        newConnection.start(queue: .global(qos: .userInteractive))
    }

    func send(command: ControlCommand) {
        guard let connection = connection else { return }

        do {
            let data = try JSONEncoder().encode(command)
            var length = UInt32(data.count).bigEndian
            let lengthData = Data(bytes: &length, count: 4)

            connection.send(content: lengthData + data, completion: .contentProcessed { error in
                if let error = error {
                    print("[WristControl] Error sending to Mac: \(error.localizedDescription)")
                }
            })
        } catch {
            print("[WristControl] Error encoding command: \(error)")
        }
    }

    private func receiveData() {
        connection?.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, _, error in
            guard let self = self, let data = data else { return }

            let length = data.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

            self.connection?.receive(
                minimumIncompleteLength: Int(length),
                maximumLength: Int(length)
            ) { payload, _, _, error in
                if let payload = payload,
                   let status = try? JSONDecoder().decode(StatusUpdate.self, from: payload) {
                    DispatchQueue.main.async {
                        PhoneSessionManager.shared.sendStatus(status)
                    }
                }
                self.receiveData()
            }
        }
    }

    private func requestCurrentStatus() {
        let request = ControlCommand(type: .brightness, value: -1)
        send(command: request)
    }
}
