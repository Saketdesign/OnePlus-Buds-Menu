import Combine
import CoreBluetooth
import Foundation
import OSLog

@MainActor
final class BudsCommandController: NSObject, ObservableObject {
    @Published private(set) var phase: BudsConnectionPhase = .disabled
    @Published private(set) var selectedMode: NoiseControlMode = .off
    @Published private(set) var isConnectionEnabled = true
    @Published private(set) var deviceName: String?
    @Published private(set) var battery: BudsBatteryStatus?
    @Published private(set) var pendingMode: NoiseControlMode?

    var isCommandReady: Bool { phase == .ready }
    var isConnected: Bool { peripheral?.state == .connected }
    var isChangingNoiseControl: Bool { pendingMode != nil }
    var connectionAccessibilityStatus: String { phase.statusText }
    var canRetry: Bool {
        if case .failed = phase { return isConnectionEnabled }
        return false
    }

    var displayBattery: BudsBatteryStatus? {
        guard var current = battery else { return nil }
        guard current.case == nil, let cached = batteryCache.currentCaseBattery() else { return current }
        current.case = cached.percentage
        return current
    }

    private let serviceUUID = CBUUID(string: "0000079A-D102-11E1-9B23-00025B00A5A5")
    private let writeUUID = CBUUID(string: "0100079A-D102-11E1-9B23-00025B00A5A5")
    private let notifyUUID = CBUUID(string: "0200079A-D102-11E1-9B23-00025B00A5A5")
    private let persistedPeripheralKey = "buds.peripheralIdentifier"
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "OnePlusBudsMenu", category: "Bluetooth")
    private let batteryCache: BatteryCache
    private let defaults: UserDefaults

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private var queuedWrites: [(data: Data, name: String)] = []
    private var writeInFlight = false
    private var operationGeneration = 0
    private var retryAttempt = 0
    private var didTryPersistedPeripheral = false
    private var timeoutWorkItem: DispatchWorkItem?
    private var retryWorkItem: DispatchWorkItem?
    private var lastBatteryQueryAt: Date?

    private let reconnectPolicy = ReconnectPolicy()

    init(batteryCache: BatteryCache? = nil, defaults: UserDefaults? = nil) {
        self.batteryCache = batteryCache ?? BatteryCache()
        self.defaults = defaults ?? .standard
        super.init()
        connect()
    }

    func select(_ mode: NoiseControlMode) {
        guard isCommandReady else { return }

        let generation = nextGeneration()
        let previousMode = selectedMode
        selectedMode = mode
        pendingMode = mode

        guard enqueue(BudsProtocolCodec.noiseControlCommand(mode), name: "ANC_SET") else {
            selectedMode = previousMode
            pendingMode = nil
            phase = .failed("Noise control is unavailable")
            return
        }

        schedule(after: 0.75, generation: generation) { controller in
            guard controller.pendingMode == mode else { return }
            _ = controller.enqueue(BudsProtocolCodec.noiseControlQuery, name: "ANC_QUERY_CONFIRMATION")
        }
        schedule(after: 2.5, generation: generation) { controller in
            guard controller.pendingMode == mode else { return }
            controller.selectedMode = previousMode
            controller.pendingMode = nil
            controller.phase = .failed("Earbuds did not confirm the change")
        }
    }

    func toggleConnection() {
        isConnectionEnabled ? disconnect() : connect()
    }

    func retry() {
        guard isConnectionEnabled else { return }
        retryAttempt = 0
        didTryPersistedPeripheral = false
        startConnectionIfPossible()
    }

    func refreshBatteryIfNeeded(force: Bool = false) {
        guard isCommandReady else { return }
        let now = Date()
        if !force, let lastUpdated = battery?.lastUpdated,
           now.timeIntervalSince(lastUpdated) < 5 * 60 {
            return
        }
        if let lastBatteryQueryAt, now.timeIntervalSince(lastBatteryQueryAt) < 20 {
            return
        }

        guard enqueue(BudsProtocolCodec.batteryQuery, name: "BATTERY_QUERY") else { return }
        lastBatteryQueryAt = now
    }

    func connect() {
        isConnectionEnabled = true
        retryAttempt = 0
        didTryPersistedPeripheral = false
        if central == nil {
            phase = .waitingForBluetooth("Checking Bluetooth…")
            central = CBCentralManager(delegate: self, queue: .main)
        } else {
            startConnectionIfPossible()
        }
    }

    func disconnect() {
        isConnectionEnabled = false
        cancelScheduledWork()
        invalidateOperations()
        central?.stopScan()
        if let peripheral {
            central?.cancelPeripheralConnection(peripheral)
        }
        resetPeripheralState(clearDeviceName: false)
        phase = .disabled
    }

    private func startConnectionIfPossible() {
        guard isConnectionEnabled, let central else { return }
        cancelScheduledWork()
        invalidateOperations()

        switch central.state {
        case .poweredOn:
            startConnection(using: central)
        case .poweredOff:
            phase = .waitingForBluetooth("Bluetooth is turned off")
        case .unauthorized:
            phase = .failed("Bluetooth access is not allowed")
        case .unsupported:
            phase = .failed("Bluetooth is not supported on this Mac")
        case .resetting:
            phase = .waitingForBluetooth("Bluetooth is restarting…")
        case .unknown:
            phase = .waitingForBluetooth("Checking Bluetooth…")
        @unknown default:
            phase = .failed("Bluetooth is unavailable")
        }
    }

    private func startConnection(using central: CBCentralManager) {
        central.stopScan()
        resetPeripheralState(clearDeviceName: false)

        if !didTryPersistedPeripheral,
           let storedID = defaults.string(forKey: persistedPeripheralKey),
           let identifier = UUID(uuidString: storedID),
           let savedPeripheral = central.retrievePeripherals(withIdentifiers: [identifier]).first {
            didTryPersistedPeripheral = true
            attachAndConnect(savedPeripheral)
            return
        }

        if let connected = central.retrieveConnectedPeripherals(withServices: [serviceUUID]).first {
            attachAndConnect(connected)
            return
        }

        phase = .scanning
        central.scanForPeripherals(withServices: [serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        setTimeout(after: 12, message: "No compatible earbuds were found", shouldRetry: true)
    }

    private func attachAndConnect(_ candidate: CBPeripheral) {
        guard let central else { return }
        cancelTimeout()
        central.stopScan()
        peripheral = candidate
        candidate.delegate = self
        deviceName = candidate.name ?? deviceName
        phase = .connecting
        central.connect(candidate, options: nil)
        setTimeout(after: 10, message: "Connection timed out", shouldRetry: true)
    }

    private func beginProtocolSetup() {
        guard notifyCharacteristic?.isNotifying == true else { return }
        phase = .registering
        let generation = nextGeneration()
        guard enqueue(BudsProtocolCodec.hello, name: "HELLO") else {
            fail("The earbuds do not support commands", shouldRetry: false)
            return
        }

        schedule(after: 0.6, generation: generation) { controller in
            _ = controller.enqueue(BudsProtocolCodec.registration, name: "REGISTER")
        }
        for delay in [1.2, 2.4, 3.6] {
            schedule(after: delay, generation: generation) { controller in
                guard controller.phase == .registering else { return }
                _ = controller.enqueue(BudsProtocolCodec.noiseControlQuery, name: "ANC_QUERY")
            }
        }
        setTimeout(after: 5, message: "The earbuds did not complete setup", shouldRetry: true)
    }

    private func markReady(mode: NoiseControlMode) {
        cancelTimeout()
        retryAttempt = 0
        selectedMode = mode
        pendingMode = nil
        phase = .ready
        if let identifier = peripheral?.identifier.uuidString {
            defaults.set(identifier, forKey: persistedPeripheralKey)
        }
        refreshBatteryIfNeeded(force: true)
    }

    @discardableResult
    private func enqueue(_ data: Data, name: String) -> Bool {
        guard peripheral?.state == .connected, writeCharacteristic != nil else { return false }
        queuedWrites.append((data, name))
        drainWriteQueue()
        return true
    }

    private func drainWriteQueue() {
        guard
            !queuedWrites.isEmpty,
            !writeInFlight,
            let peripheral,
            peripheral.state == .connected,
            let characteristic = writeCharacteristic
        else { return }

        let supportsWithoutResponse = characteristic.properties.contains(.writeWithoutResponse)
        let supportsResponse = characteristic.properties.contains(.write)
        guard supportsWithoutResponse || supportsResponse else {
            fail("The command characteristic is not writable", shouldRetry: false)
            return
        }

        let writeType: CBCharacteristicWriteType = supportsWithoutResponse ? .withoutResponse : .withResponse
        let maximumLength = peripheral.maximumWriteValueLength(for: writeType)
        guard queuedWrites[0].data.count <= maximumLength else {
            logger.error("Command exceeds the peripheral write limit")
            queuedWrites.removeFirst()
            drainWriteQueue()
            return
        }

        if writeType == .withoutResponse, !peripheral.canSendWriteWithoutResponse { return }

        let command = queuedWrites.removeFirst()
        logger.debug("Sending command: \(command.name, privacy: .public)")
        writeInFlight = writeType == .withResponse
        peripheral.writeValue(command.data, for: characteristic, type: writeType)
        if !writeInFlight { drainWriteQueue() }
    }

    private func handle(_ event: BudsProtocolCodec.Event) {
        switch event {
        case .noiseControlMode(let mode):
            if phase == .registering {
                markReady(mode: mode)
            } else if pendingMode == nil || pendingMode == mode {
                selectedMode = mode
                pendingMode = nil
                phase = .ready
            }
        case .noiseControlAcknowledged:
            if let pendingMode {
                selectedMode = pendingMode
                self.pendingMode = nil
                phase = .ready
            }
        case .battery(let value, let isTelemetry):
            updateBattery(value, fromTelemetry: isTelemetry)
        }
    }

    private func updateBattery(_ newValue: BudsBatteryStatus, fromTelemetry: Bool) {
        if fromTelemetry, let current = battery {
            if let old = current.left, let new = newValue.left, abs(old - new) > 30 { return }
            if let old = current.right, let new = newValue.right, abs(old - new) > 30 { return }
            if let old = current.case, let new = newValue.case, abs(old - new) > 40 { return }
        }

        var merged = newValue
        if fromTelemetry, let current = battery {
            merged.left = merged.left ?? current.left
            merged.right = merged.right ?? current.right
            merged.case = merged.case ?? current.case
        }
        merged.lastUpdated = Date()
        battery = merged
        if let casePercentage = merged.case {
            batteryCache.store(casePercentage: casePercentage)
        }
    }

    private func fail(_ message: String, shouldRetry: Bool) {
        cancelTimeout()
        invalidateOperations()
        central?.stopScan()
        phase = .failed(message)
        logger.error("Bluetooth session failed: \(message, privacy: .public)")
        if let peripheral, peripheral.state != .disconnected {
            central?.cancelPeripheralConnection(peripheral)
        }
        if shouldRetry { scheduleReconnect() }
    }

    private func scheduleReconnect() {
        guard isConnectionEnabled, let delay = reconnectPolicy.delay(forAttempt: retryAttempt) else { return }
        guard retryWorkItem == nil else { return }
        retryAttempt += 1
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.isConnectionEnabled else { return }
            self.startConnectionIfPossible()
        }
        retryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func setTimeout(after delay: TimeInterval, message: String, shouldRetry: Bool) {
        cancelTimeout()
        let generation = operationGeneration
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, generation == self.operationGeneration else { return }
            self.fail(message, shouldRetry: shouldRetry)
        }
        timeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func schedule(
        after delay: TimeInterval,
        generation: Int,
        action: @escaping @MainActor (BudsCommandController) -> Void
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, generation == self.operationGeneration else { return }
            action(self)
        }
    }

    @discardableResult
    private func nextGeneration() -> Int {
        operationGeneration += 1
        return operationGeneration
    }

    private func invalidateOperations() {
        operationGeneration += 1
        pendingMode = nil
    }

    private func cancelTimeout() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
    }

    private func cancelScheduledWork() {
        cancelTimeout()
        retryWorkItem?.cancel()
        retryWorkItem = nil
    }

    private func resetPeripheralState(clearDeviceName: Bool) {
        peripheral?.delegate = nil
        peripheral = nil
        writeCharacteristic = nil
        notifyCharacteristic = nil
        queuedWrites.removeAll()
        writeInFlight = false
        lastBatteryQueryAt = nil
        battery = nil
        if clearDeviceName { deviceName = nil }
    }
}

extension BudsCommandController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard isConnectionEnabled else { return }
        startConnectionIfPossible()
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
        guard let name, name.localizedCaseInsensitiveContains("OnePlus") || name.localizedCaseInsensitiveContains("Nord Buds") else {
            return
        }
        attachAndConnect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        cancelTimeout()
        deviceName = peripheral.name ?? deviceName
        phase = .discovering
        peripheral.discoverServices([serviceUUID])
        setTimeout(after: 8, message: "The earbuds did not expose their controls", shouldRetry: true)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let message = error?.localizedDescription ?? "The earbuds disconnected"
        resetPeripheralState(clearDeviceName: false)
        guard isConnectionEnabled else {
            phase = .disabled
            return
        }
        fail(message, shouldRetry: true)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        resetPeripheralState(clearDeviceName: false)
        fail(error?.localizedDescription ?? "Could not connect to the earbuds", shouldRetry: true)
    }
}

extension BudsCommandController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            fail("Service discovery failed: \(error.localizedDescription)", shouldRetry: true)
            return
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
            fail("This device is not compatible", shouldRetry: false)
            return
        }
        peripheral.discoverCharacteristics([writeUUID, notifyUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            fail("Control discovery failed: \(error.localizedDescription)", shouldRetry: true)
            return
        }
        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid {
            case writeUUID: writeCharacteristic = characteristic
            case notifyUUID: notifyCharacteristic = characteristic
            default: break
            }
        }

        guard let writeCharacteristic, let notifyCharacteristic else {
            fail("Required controls are missing on this device", shouldRetry: false)
            return
        }
        guard writeCharacteristic.properties.contains(.writeWithoutResponse) || writeCharacteristic.properties.contains(.write) else {
            fail("The device control is not writable", shouldRetry: false)
            return
        }
        guard notifyCharacteristic.properties.contains(.notify) || notifyCharacteristic.properties.contains(.indicate) else {
            fail("The device cannot report control changes", shouldRetry: false)
            return
        }

        phase = .subscribing
        peripheral.setNotifyValue(true, for: notifyCharacteristic)
        setTimeout(after: 5, message: "Could not enable earbud notifications", shouldRetry: true)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == notifyUUID else { return }
        if let error {
            fail("Notification setup failed: \(error.localizedDescription)", shouldRetry: true)
            return
        }
        guard characteristic.isNotifying else {
            fail("Earbud notifications are unavailable", shouldRetry: true)
            return
        }
        cancelTimeout()
        beginProtocolSetup()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == notifyUUID else { return }
        if let error {
            logger.error("Notification read failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard let data = characteristic.value else { return }
        let events = BudsProtocolCodec.decode(data)
        if events.isEmpty {
            logger.debug("Ignored an unrecognized earbud packet")
        }
        events.forEach(handle)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == writeUUID else { return }
        writeInFlight = false
        if let error {
            fail("A command could not be sent: \(error.localizedDescription)", shouldRetry: true)
            return
        }
        drainWriteQueue()
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        drainWriteQueue()
    }
}
