// WristControlMac/TCPServer.swift
import Foundation
import Network

class TCPServer {
    private var listener: NWListener?
    private var udpListener: NWListener?
    private var connections: [NWConnection] = []

    private let serviceType = "_wristcontrol._tcp"
    private let tcpPort: UInt16 = 9876
    private let udpPort: UInt16 = 9877
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var allowedHost: NWEndpoint.Host?

    func start() {
        startTCP()
        startUDP()
    }

    // MARK: - TCP (brightness, volume, clicks, status)

    private func startTCP() {
        do {
            let tcpOptions = NWProtocolTCP.Options()
            tcpOptions.noDelay = true
            let parameters = NWParameters(tls: nil, tcp: tcpOptions)
            parameters.includePeerToPeer = true

            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: tcpPort)!)

            listener?.service = NWListener.Service(
                name: Host.current().localizedName ?? "Mac",
                type: serviceType
            )

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }

            listener?.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }
                switch state {
                case .ready:
                    #if DEBUG
                    print("[WristControl] TCP ready on port \(self.tcpPort)")
                    #endif
                case .failed(let error):
                    #if DEBUG
                    print("[WristControl] TCP failed: \(error)")
                    #endif
                default:
                    break
                }
            }

            listener?.start(queue: .main)
        } catch {
            #if DEBUG
            print("[WristControl] Error creating TCP listener: \(error)")
            #endif
        }
    }

    // MARK: - UDP (mouse movement, scroll — low latency)

    private func startUDP() {
        do {
            let parameters = NWParameters.udp
            parameters.includePeerToPeer = true

            udpListener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: udpPort)!)

            udpListener?.newConnectionHandler = { [weak self] connection in
                // Verify source matches connected iPhone
                if let self = self, let allowed = self.allowedHost {
                    if let path = connection.currentPath,
                       let remote = path.remoteEndpoint,
                       case .hostPort(let host, _) = remote,
                       host != allowed {
                        connection.cancel()
                        return
                    }
                }
                connection.start(queue: .global(qos: .userInteractive))
                self?.receiveUDP(from: connection)
            }

            udpListener?.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }
                if case .ready = state {
                    #if DEBUG
                    print("[WristControl] UDP ready on port \(self.udpPort)")
                    #endif
                }
            }

            udpListener?.start(queue: .global(qos: .userInteractive))
        } catch {
            #if DEBUG
            print("[WristControl] Error creating UDP listener: \(error)")
            #endif
        }
    }

    private func receiveUDP(from connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self = self else { return }

            if let data = data, data.count == 9 {
                // Binary format: [1 byte type] [4 bytes float deltaX] [4 bytes float deltaY]
                let typeByte = data[0]
                var dx: Float = 0
                var dy: Float = 0
                _ = withUnsafeMutableBytes(of: &dx) { data[1..<5].copyBytes(to: $0) }
                _ = withUnsafeMutableBytes(of: &dy) { data[5..<9].copyBytes(to: $0) }

                guard dx.isFinite && dy.isFinite else {
                    self.receiveUDP(from: connection)
                    return
                }

                switch typeByte {
                case 0: // mouseMove
                    MouseController.moveMouse(deltaX: dx, deltaY: dy)
                case 1: // scroll
                    MouseController.scroll(deltaY: dy)
                default:
                    break
                }
            }

            self.receiveUDP(from: connection)
        }
    }

    // MARK: - TCP connection handling

    private func handleNewConnection(_ connection: NWConnection) {
        #if DEBUG
        print("[WristControl] New connection from iPhone")
        #endif
        // Cancel old connections (single-client system)
        for old in connections {
            old.cancel()
        }
        connections.removeAll()
        connections.append(connection)

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                if let path = connection.currentPath,
                   let remote = path.remoteEndpoint,
                   case .hostPort(let host, _) = remote {
                    self?.allowedHost = host
                }
                self?.receiveData(from: connection)
            case .failed, .cancelled:
                self?.connections.removeAll { $0 === connection }
            default:
                break
            }
        }

        connection.start(queue: .main)
    }

    private func receiveData(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, _, error in
            guard let self = self, let data = data, error == nil else { return }

            var length: UInt32 = 0
            _ = withUnsafeMutableBytes(of: &length) { data.copyBytes(to: $0) }
            length = UInt32(bigEndian: length)

            guard length > 0 && length < 65536 else { self.receiveData(from: connection); return }

            connection.receive(
                minimumIncompleteLength: Int(length),
                maximumLength: Int(length)
            ) { payload, _, _, error in
                if let payload = payload,
                   let command = try? self.decoder.decode(ControlCommand.self, from: payload) {
                    self.handleCommand(command, connection: connection)
                }
                self.receiveData(from: connection)
            }
        }
    }

    private func handleCommand(_ command: ControlCommand, connection: NWConnection) {
        guard command.value.isFinite,
              (command.deltaX ?? 0).isFinite,
              (command.deltaY ?? 0).isFinite else { return }

        if command.type == .statusRequest {
            DispatchQueue.main.async {
                self.sendCurrentStatus(to: connection)
            }
            return
        }

        switch command.type {
        case .mouseMove:
            MouseController.moveMouse(deltaX: command.deltaX ?? 0, deltaY: command.deltaY ?? 0)
        case .mouseClick:
            MouseController.click()
        case .rightClick:
            MouseController.rightClick()
        case .scroll:
            MouseController.scroll(deltaY: command.deltaY ?? command.value)
        case .brightness:
            DispatchQueue.main.async {
                BrightnessController.setBrightness(command.value)
                self.sendCurrentStatus(to: connection)
            }
        case .volume:
            DispatchQueue.main.async {
                VolumeController.setVolume(command.value)
                self.sendCurrentStatus(to: connection)
            }
        case .mediaPlayPause:
            SystemActionController.mediaPlayPause()
        case .mediaNext:
            SystemActionController.mediaNext()
        case .mediaPrevious:
            SystemActionController.mediaPrevious()
        case .mute:
            SystemActionController.toggleMute()
        case .sleep:
            SystemActionController.sleepDisplay()
        case .lockScreen:
            SystemActionController.lockScreen()
        case .screenshot:
            SystemActionController.takeScreenshot()
        case .darkMode:
            SystemActionController.toggleDarkMode()
        case .statusRequest:
            break // handled above before the switch
        }
    }

    @MainActor private func sendCurrentStatus(to connection: NWConnection) {
        let status = StatusUpdate(
            brightness: BrightnessController.getBrightness(),
            volume: VolumeController.getVolume(),
            connected: true
        )

        guard let data = try? encoder.encode(status) else { return }

        var length = UInt32(data.count).bigEndian
        let lengthData = Data(bytes: &length, count: 4)

        connection.send(content: lengthData + data, completion: .contentProcessed { error in
            if let error = error {
                #if DEBUG
                print("[WristControl] Error sending status: \(error)")
                #endif
            }
        })
    }
}
