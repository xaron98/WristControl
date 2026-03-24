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
                    print("[WristControl] TCP ready on port \(self.tcpPort)")
                case .failed(let error):
                    print("[WristControl] TCP failed: \(error)")
                default:
                    break
                }
            }

            listener?.start(queue: .main)
        } catch {
            print("[WristControl] Error creating TCP listener: \(error)")
        }
    }

    // MARK: - UDP (mouse movement, scroll — low latency)

    private func startUDP() {
        do {
            let parameters = NWParameters.udp
            parameters.includePeerToPeer = true

            udpListener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: udpPort)!)

            udpListener?.newConnectionHandler = { [weak self] connection in
                connection.start(queue: .global(qos: .userInteractive))
                self?.receiveUDP(from: connection)
            }

            udpListener?.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }
                if case .ready = state {
                    print("[WristControl] UDP ready on port \(self.udpPort)")
                }
            }

            udpListener?.start(queue: .global(qos: .userInteractive))
        } catch {
            print("[WristControl] Error creating UDP listener: \(error)")
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
        print("[WristControl] New connection from iPhone")
        connections.append(connection)

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.receiveData(from: connection)
            case .failed, .cancelled:
                self?.connections.removeAll { $0 === connection }
            default:
                break
            }
        }

        connection.start(queue: .global(qos: .userInteractive))
    }

    private func receiveData(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, _, error in
            guard let self = self, let data = data, error == nil else { return }

            var length: UInt32 = 0
            _ = withUnsafeMutableBytes(of: &length) { data.copyBytes(to: $0) }
            length = UInt32(bigEndian: length)

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
        if command.value < 0 && (command.type == .brightness || command.type == .volume) {
            sendCurrentStatus(to: connection)
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
        }
    }

    private func sendCurrentStatus(to connection: NWConnection) {
        let status = StatusUpdate(
            brightness: BrightnessController.getBrightness(),
            volume: VolumeController.getVolume(),
            connected: true
        )

        guard let data = try? JSONEncoder().encode(status) else { return }

        var length = UInt32(data.count).bigEndian
        let lengthData = Data(bytes: &length, count: 4)

        connection.send(content: lengthData + data, completion: .contentProcessed { error in
            if let error = error {
                print("[WristControl] Error sending status: \(error)")
            }
        })
    }
}
