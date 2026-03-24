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

    private func receiveData(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, _, error in
            guard let self = self, let data = data, error == nil else { return }

            let length = data.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

            connection.receive(
                minimumIncompleteLength: Int(length),
                maximumLength: Int(length)
            ) { payload, _, _, error in
                if let payload = payload,
                   let command = try? JSONDecoder().decode(ControlCommand.self, from: payload) {
                    self.handleCommand(command, connection: connection)
                }
                self.receiveData(from: connection)
            }
        }
    }

    private func handleCommand(_ command: ControlCommand, connection: NWConnection) {
        // value -1 = status request (only for brightness/volume)
        if command.value < 0 && (command.type == .brightness || command.type == .volume) {
            sendCurrentStatus(to: connection)
            return
        }

        DispatchQueue.main.async {
            switch command.type {
            case .brightness:
                BrightnessController.setBrightness(command.value)
                self.sendCurrentStatus(to: connection)
            case .volume:
                VolumeController.setVolume(command.value)
                self.sendCurrentStatus(to: connection)
            case .mouseMove:
                MouseController.moveMouse(deltaX: command.deltaX ?? 0, deltaY: command.deltaY ?? 0)
            case .mouseClick:
                MouseController.click()
            case .rightClick:
                MouseController.rightClick()
            case .scroll:
                MouseController.scroll(deltaY: command.deltaY ?? command.value)
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
