// WristControlMac/TCPServer.swift
import Foundation
import Network

class TCPServer {
    private var listener: NWListener?
    private var connections: [NWConnection] = []

    private let serviceType = "_wristcontrol._tcp"
    private let port: UInt16 = 9876

    func start() {
        do {
            let parameters = NWParameters.tcp
            parameters.includePeerToPeer = true

            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)

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
                    print("[WristControl] Server ready on port \(self.port)")
                case .failed(let error):
                    print("[WristControl] Server failed: \(error)")
                default:
                    break
                }
            }

            listener?.start(queue: .main)
        } catch {
            print("[WristControl] Error creating listener: \(error)")
        }
    }

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

    private let decoder = JSONDecoder()

    private func receiveData(from connection: NWConnection) {
        // Read up to 4KB at once — may contain header + payload in one read
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4096) { [weak self] data, _, _, error in
            guard let self = self, let data = data, error == nil else { return }
            self.processBuffer(data, connection: connection)
            self.receiveData(from: connection)
        }
    }

    private func processBuffer(_ data: Data, connection: NWConnection) {
        guard data.count >= 4 else { return }

        let length = data.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        let payloadStart = 4
        let payloadEnd = payloadStart + Int(length)

        guard data.count >= payloadEnd else {
            // Incomplete — fall back to sequential read
            let remaining = payloadEnd - data.count
            connection.receive(minimumIncompleteLength: remaining, maximumLength: remaining) { [weak self] moreData, _, _, _ in
                guard let self = self, let moreData = moreData else { return }
                let fullPayload = data.suffix(from: payloadStart) + moreData
                if let command = try? self.decoder.decode(ControlCommand.self, from: fullPayload) {
                    self.handleCommand(command, connection: connection)
                }
            }
            return
        }

        let payload = data[payloadStart..<payloadEnd]
        if let command = try? decoder.decode(ControlCommand.self, from: payload) {
            handleCommand(command, connection: connection)
        }

        // Process remaining data in buffer (pipelined commands)
        if data.count > payloadEnd {
            processBuffer(data.suffix(from: payloadEnd), connection: connection)
        }
    }

    private func handleCommand(_ command: ControlCommand, connection: NWConnection) {
        if command.value < 0 && (command.type == .brightness || command.type == .volume) {
            sendCurrentStatus(to: connection)
            return
        }

        // Mouse/scroll: process immediately on current queue (low latency)
        // Brightness/volume: dispatch to main
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
