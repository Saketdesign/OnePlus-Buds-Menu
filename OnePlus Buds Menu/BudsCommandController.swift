//
//  BudsCommandController.swift
//  OnePlus Buds Menu
//
//  Created by Saket Joshi on 19/07/26.
//

import Combine
import CoreBluetooth
import Foundation

enum NoiseControlMode: CaseIterable, Identifiable {
    case noiseCancellation
    case transparency
    case off

    var id: Self { self }

    var title: String {
        switch self {
        case .noiseCancellation:
            return "Noise Cancellation"
        case .transparency:
            return "Transparency"
        case .off:
            return "Off"
        }
    }

    fileprivate var modeByte: UInt8 {
        switch self {
        case .noiseCancellation:
            return 0x02
        case .transparency:
            return 0x04
        case .off:
            return 0x01
        }
    }
}

final class BudsCommandController: NSObject, ObservableObject {
    @Published var status: String = "Ready"
    @Published var selectedMode: NoiseControlMode = .off
    @Published var isConnectionEnabled: Bool = true
    @Published var isConnected: Bool = false
    @Published var isConnecting: Bool = false
    @Published var isCommandReady: Bool = false
    @Published var deviceName: String?
    @Published private(set) var pendingMode: NoiseControlMode?

    var isChangingNoiseControl: Bool {
        pendingMode != nil
    }

    private let service079A = CBUUID(string: "0000079A-D102-11E1-9B23-00025B00A5A5")
    private let write079AUUID = "0100079A-D102-11E1-9B23-00025B00A5A5"
    private let notify079AUUID = "0200079A-D102-11E1-9B23-00025B00A5A5"
    private let fe2cCommandUUID = "FE2C123A-8366-4814-8EB0-01DE32100BEA"

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var write079A: CBCharacteristic?
    private var notify079A: CBCharacteristic?
    private var fe2cCommand: CBCharacteristic?
    private var commandSequenceID = 0
    private var hasStartedProtocolSetup = false

    private let helloPacket: [UInt8] = [
        0xAA, 0x07, 0x00, 0x00, 0x00, 0x01, 0x23, 0x00, 0x00, 0x12
    ]
    private let registrationPacket: [UInt8] = [
        0xAA, 0x0C, 0x00, 0x00, 0x00, 0x85, 0x41, 0x05, 0x00, 0x00, 0xB5, 0x50, 0xA0, 0x69
    ]
    private let noiseControlQueryPacket: [UInt8] = [
        0xAA, 0x09, 0x00, 0x00, 0x04, 0x82, 0x44, 0x02, 0x00, 0x00, 0xF2
    ]

    override init() {
        super.init()
        connect()
    }

    var connectionAccessibilityStatus: String {
        if isCommandReady {
            return "Connected"
        }

        if isConnecting {
            return status
        }

        if isConnected {
            return "Preparing controls"
        }

        return "Disconnected"
    }

    func select(_ mode: NoiseControlMode) {
        guard isCommandReady else {
            status = "Preparing controls..."
            return
        }

        let sequenceID = nextCommandSequenceID()
        pendingMode = mode
        status = "Changing noise control..."

        guard sendPacket(
            [0xAA, 0x0A, 0x00, 0x00, 0x04, 0x04, 0x42, 0x03, 0x00, 0x01, 0x01, mode.modeByte],
            name: "ANC_SET"
        ) else {
            pendingMode = nil
            status = "Control unavailable"
            return
        }

        // Firmware normally acknowledges with command 0x8404. If it does not,
        // query the actual mode before deciding whether the change succeeded.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            guard let self else { return }
            guard sequenceID == self.commandSequenceID, self.pendingMode == mode else { return }
            print("[RX] ANC acknowledgement delayed; querying current mode")
            self.sendPacket(self.noiseControlQueryPacket, name: "ANC_QUERY_FALLBACK")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            guard sequenceID == self.commandSequenceID, self.pendingMode == mode else { return }
            self.pendingMode = nil
            self.status = "Earbuds did not respond"
        }
    }

    func toggleConnection() {
        if isConnectionEnabled {
            disconnect()
        } else {
            connect()
        }
    }

    func connect() {
        isConnectionEnabled = true
        status = "Connecting..."
        isConnecting = true
        isCommandReady = false

        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
        } else if central?.state == .poweredOn {
            startConnection()
        }
    }

    func disconnect() {
        isConnectionEnabled = false
        status = "Disconnected"
        isConnected = false
        isConnecting = false
        isCommandReady = false
        invalidateCommandSequences()

        if let peripheral {
            central?.cancelPeripheralConnection(peripheral)
        }

        central?.stopScan()
        peripheral = nil
        write079A = nil
        notify079A = nil
        fe2cCommand = nil
        hasStartedProtocolSetup = false
    }

    private func startConnection() {
        guard let central else { return }

        let connected = central.retrieveConnectedPeripherals(withServices: [service079A])
        if let buds = connected.first {
            attachAndConnect(buds)
            return
        }

        status = "Scanning..."
        central.scanForPeripherals(withServices: nil, options: nil)
    }

    private func attachAndConnect(_ buds: CBPeripheral) {
        invalidateCommandSequences()
        peripheral = buds
        buds.delegate = self
        deviceName = buds.name ?? deviceName
        status = "Connecting..."
        isCommandReady = false
        hasStartedProtocolSetup = false
        central?.connect(buds, options: nil)
    }

    @discardableResult
    private func sendPacket(_ bytes: [UInt8], name: String) -> Bool {
        guard isConnected, let peripheral, let write079A else { return false }

        let hex = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        print("[TX] \(name): \(hex)")
        peripheral.writeValue(Data(bytes), for: write079A, type: .withoutResponse)
        return true
    }

    @discardableResult
    private func sendPacketIfCurrent(_ bytes: [UInt8], name: String, sequenceID: Int) -> Bool {
        guard sequenceID == commandSequenceID else { return false }
        return sendPacket(bytes, name: name)
    }

    @discardableResult
    private func nextCommandSequenceID() -> Int {
        commandSequenceID += 1
        return commandSequenceID
    }

    private func invalidateCommandSequences() {
        commandSequenceID += 1
        pendingMode = nil
    }

    private func beginProtocolSetup() {
        guard !hasStartedProtocolSetup, write079A != nil else { return }

        hasStartedProtocolSetup = true
        isCommandReady = false
        status = "Preparing controls..."
        let sequenceID = nextCommandSequenceID()

        sendPacket(helloPacket, name: "HELLO")

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self else { return }
            self.sendPacketIfCurrent(
                self.registrationPacket,
                name: "REGISTER",
                sequenceID: sequenceID
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            guard let self, sequenceID == self.commandSequenceID else { return }
            self.sendPacket(self.noiseControlQueryPacket, name: "ANC_QUERY")
            self.isCommandReady = true
            self.status = "Ready"
        }
    }

    private func finishModeChange(_ mode: NoiseControlMode) {
        selectedMode = mode
        pendingMode = nil
        status = "Ready"
    }

    private func reportedNoiseControlMode(from bytes: [UInt8]) -> NoiseControlMode? {
        guard bytes.count >= 12, bytes[4] == 0x04 else { return nil }
        guard [0x02, 0x82, 0x84].contains(bytes[5]) else { return nil }
        guard bytes[9] == 0x01, bytes[10] == 0x01 else { return nil }

        return NoiseControlMode.allCases.first { $0.modeByte == bytes[11] }
    }
}

extension BudsCommandController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard isConnectionEnabled || isConnecting else { return }

        switch central.state {
        case .poweredOn:
            startConnection()
        case .poweredOff:
            status = "Bluetooth off"
            isConnecting = false
        case .unauthorized:
            status = "Bluetooth unauthorized"
            isConnecting = false
        case .unsupported:
            status = "Bluetooth unsupported"
            isConnecting = false
        case .resetting:
            status = "Bluetooth resetting..."
        case .unknown:
            status = "Bluetooth unavailable"
            isConnecting = false
        @unknown default:
            status = "Bluetooth unavailable"
            isConnecting = false
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String else { return }
        guard name.contains("Nord Buds") || name.contains("OnePlus") else { return }

        central.stopScan()
        attachAndConnect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        isConnecting = false
        isCommandReady = false
        deviceName = peripheral.name ?? deviceName
        status = "Discovering..."
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        isConnecting = false
        isCommandReady = false
        invalidateCommandSequences()
        write079A = nil
        notify079A = nil
        fe2cCommand = nil
        hasStartedProtocolSetup = false
        status = "Disconnected"

        if isConnectionEnabled {
            startConnection()
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        isConnecting = false
        isCommandReady = false
        status = error?.localizedDescription ?? "Connection failed"
    }
}

extension BudsCommandController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics ?? [] {
            let uuid = characteristic.uuid.uuidString.uppercased()
            let props = characteristic.properties

            if uuid == write079AUUID {
                write079A = characteristic
            }

            if uuid == notify079AUUID {
                notify079A = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }

            if uuid == fe2cCommandUUID {
                fe2cCommand = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }

            if props.contains(.notify) || props.contains(.indicate) {
                peripheral.setNotifyValue(true, for: characteristic)
            }

            if props.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
        }

        beginProtocolSetup()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }

        let bytes = [UInt8](data)
        let hex = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        print("[RX] \(characteristic.uuid.uuidString): \(hex)")

        if let reportedMode = reportedNoiseControlMode(from: bytes) {
            if pendingMode == nil || pendingMode == reportedMode {
                finishModeChange(reportedMode)
            }
        }

        if bytes.count >= 6, bytes[4] == 0x04, bytes[5] == 0x84,
           let pendingMode {
            print("[RX] Noise control acknowledged")
            finishModeChange(pendingMode)
        }
    }
}
