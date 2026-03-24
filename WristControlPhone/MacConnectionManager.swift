// WristControlPhone/MacConnectionManager.swift
import Foundation
import Network

class MacConnectionManager: ObservableObject {
    static let shared = MacConnectionManager()

    @Published var isConnected: Bool = false
    @Published var macName: String = "Buscando..."

    private var connection: NWConnection?
    private var udpConnection: NWConnection?
    private var browser: NWBrowser?
    private var isConnecting: Bool = false
    private var macHost: NWEndpoint.Host?

    private let serviceType = "_wristcontrol._tcp"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func startBrowsing() {
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
            #if DEBUG
            print("[WristControl] Browser state: \(state)")
            #endif
        }

        browser?.start(queue: .main)
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
    }

    private func connectToMac(endpoint: NWEndpoint) {
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.noDelay = true
        let parameters = NWParameters(tls: nil, tcp: tcpOptions)
        parameters.includePeerToPeer = true

        let newConnection = NWConnection(to: endpoint, using: parameters)

        newConnection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch state {
                case .ready:
                    self.isConnecting = false
                    self.isConnected = true
                    // Resolve the Mac's IP for UDP
                    if let path = newConnection.currentPath,
                       let endpoint = path.remoteEndpoint,
                       case .hostPort(let host, _) = endpoint {
                        self.macHost = host
                        self.setupUDP(host: host)
                    }
                    self.receiveData()
                    self.requestCurrentStatus()
                case .failed, .cancelled:
                    self.isConnecting = false
                    self.isConnected = false
                    self.connection = nil
                    self.udpConnection?.cancel()
                    self.udpConnection = nil
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

    // MARK: - UDP for mouse/scroll (low latency)

    private func setupUDP(host: NWEndpoint.Host) {
        let udp = NWConnection(
            host: host,
            port: 9877,
            using: .udp
        )
        udp.start(queue: .global(qos: .userInteractive))
        udpConnection = udp
    }

    /// Send mouse/scroll via UDP binary (9 bytes, no JSON overhead)
    func sendFast(type: UInt8, deltaX: Float, deltaY: Float) {
        guard let udp = udpConnection else { return }

        var packet = Data(count: 9)
        packet[0] = type
        withUnsafeBytes(of: deltaX) { packet.replaceSubrange(1..<5, with: $0) }
        withUnsafeBytes(of: deltaY) { packet.replaceSubrange(5..<9, with: $0) }

        udp.send(content: packet, completion: .idempotent)
    }

    // MARK: - TCP for commands (reliable)

    func send(command: ControlCommand) {
        guard let connection = connection else { return }

        do {
            let data = try encoder.encode(command)
            var length = UInt32(data.count).bigEndian
            let lengthData = Data(bytes: &length, count: 4)

            connection.send(content: lengthData + data, completion: .contentProcessed { error in
                if let error = error {
                    #if DEBUG
                    print("[WristControl] Error sending to Mac: \(error.localizedDescription)")
                    #endif
                }
            })
        } catch {
            #if DEBUG
            print("[WristControl] Error encoding command: \(error)")
            #endif
        }
    }

    private func receiveData() {
        connection?.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, _, error in
            guard let self = self else { return }
            guard let data = data, error == nil else {
                // Connection lost or error — will be handled by stateUpdateHandler
                return
            }

            var length: UInt32 = 0
            _ = withUnsafeMutableBytes(of: &length) { data.copyBytes(to: $0) }
            length = UInt32(bigEndian: length)

            guard length > 0 && length < 65536 else { self.receiveData(); return }

            self.connection?.receive(
                minimumIncompleteLength: Int(length),
                maximumLength: Int(length)
            ) { payload, _, _, error in
                if let payload = payload,
                   let status = try? decoder.decode(StatusUpdate.self, from: payload) {
                    DispatchQueue.main.async {
                        PhoneSessionManager.shared.sendStatus(status)
                    }
                }
                self.receiveData()
            }
        }
    }

    private func requestCurrentStatus() {
        send(command: ControlCommand(type: .statusRequest, value: 0))
    }
}
