//  Zetara
//
//  Created by xxtx on 2022/12/3.
//

import Foundation
import CoreBluetooth
import RxSwift
import RxBluetoothKit2
import RxCocoa
import UIKit

public class ZetaraManager: NSObject {

    public enum Error: Swift.Error {
        case connectionError
        case notZetaraPeripheralError
        case writeControlDataError
        case stalePeripheralError  // iOS returned cached peripheral with invalid state
        case peripheralNotFound  // Failed to retrieve peripheral from CoreBluetooth
    }

    public typealias ConnectedPeripheral = Peripheral

    private let manager = CentralManager(queue: DispatchQueue(label: "com.zetara.radar"))

    private var scanningDisposable: Disposable?
    public var scannedPeripheralsSubject = BehaviorSubject<[ScannedPeripheral]>(value: [])

    private var connectionDisposable: Disposable?
    public var connectedPeripheralSubject = BehaviorSubject<ConnectedPeripheral?>(value: nil)

    public var observableState: Observable<BluetoothState> {
        manager.observeStateWithInitialValue().observeOn(MainScheduler.instance)
    }

    public var bmsDataSubject = BehaviorSubject<Data.BMS>(value: Data.BMS())
    private var refreshBMSDataDisposable: Disposable?
    private var disposeBag = DisposeBag()


    private var identifier: Identifier?
    private var writeCharacteristic: Characteristic?
    private var notifyCharacteristic: Characteristic?
    
    // Имя устройства для мок-данных
    private var mockDeviceName: String?

    private static var configuration: Configuration = .default
    
    // MARK: - Request Queue (Этап 2.1)
    // Очередь для последовательного выполнения Bluetooth запросов
    private var requestQueue: DispatchQueue = DispatchQueue(
        label: "com.zetara.requests",
        qos: .userInitiated,
        attributes: []
    )
    
    // Время последнего выполненного запроса
    private var lastRequestTime: Date?
    
    // Минимальный интервал между запросами (500ms)
    private let minimumRequestInterval: TimeInterval = 0.5
    
    // MARK: - Connection Monitor (Этап 2.2)
    // Таймер для периодической проверки подключения
    private var connectionMonitorTimer: Timer?

    // Интервал проверки подключения (2 секунды)
    private let connectionCheckInterval: TimeInterval = 2.0

    // Флаг для предотвращения множественных вызовов cleanConnection
    private var isCleaningConnection = false

    // Serial queue для атомарного доступа к isCleaningConnection
    private let cleanConnectionQueue = DispatchQueue(label: "com.zetara.cleanConnection")

    // Shared DisposeBag для queuedRequest
    private let requestQueueDisposeBag = DisposeBag()

    // MARK: - Protocol Data Manager
    /// Менеджер для управления протокольными данными (Module ID, CAN, RS485)
    public let protocolDataManager = ProtocolDataManager()

    // UUID текущего подключенного устройства (для проверки валидности)
    public var cachedDeviceUUID: String?

    // MARK: - Build 38: Persistent Storage for Auto-Reconnect
    // Persistent storage keys for auto-reconnection feature
    private let lastConnectedUUIDKey = "com.zetara.lastConnectedPeripheralUUID"
    private let autoReconnectEnabledKey = "com.zetara.autoReconnectEnabled"

    // Auto-reconnect configuration (default: enabled)
    // User can disable this in Settings if they don't want automatic reconnection
    public var autoReconnectEnabled: Bool {
        get {
            // Default to true if not set (first launch or after update)
            return UserDefaults.standard.object(forKey: autoReconnectEnabledKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: autoReconnectEnabledKey)
            protocolDataManager.logProtocolEvent("[CONFIG] Auto-reconnect \(newValue ? "enabled" : "disabled")")
        }
    }

    public static let shared = ZetaraManager()

    private override init() {
        super.init()

        // Устанавливаем ссылку на себя в protocolDataManager
        protocolDataManager.setZetaraManager(self)

        manager.observeState()
            .observeOn(MainScheduler.instance)
            .subscribeOn(MainScheduler.instance)
            .subscribe { [weak self] (state: BluetoothState) in
            switch state {
                case .poweredOn:
                    return
                default:
                    self?.cleanData()
                    self?.cleanScanning()
                    self?.cleanConnection()
            }
        }.disposed(by: disposeBag)

        // Global disconnect handler (NOT tied to any ViewController lifecycle)
        // Follows Apple CoreBluetooth best practices for peripheral lifecycle management
        // Build 38: Modified to enable auto-reconnect using persistent connection requests
        manager.observeDisconnect()
            .subscribe(onNext: { [weak self] (peripheral, error) in
                guard let self = self else { return }

                let peripheralName = peripheral.name ?? "Unknown"
                let peripheralUUID = peripheral.identifier.uuidString

                self.protocolDataManager.logProtocolEvent("[DISCONNECT] 🔌 Device disconnected: \(peripheralName)")
                self.protocolDataManager.logProtocolEvent("[DISCONNECT] UUID: \(peripheralUUID)")

                if let error = error {
                    self.protocolDataManager.logProtocolEvent("[DISCONNECT] Reason: \(error.localizedDescription)")
                } else {
                    self.protocolDataManager.logProtocolEvent("[DISCONNECT] Reason: User disconnect or peripheral powered off")
                }

                // Build 38: CRITICAL CHANGE - Partial cleanup instead of full
                // This preserves UUID for auto-reconnect capability
                self.cleanConnectionPartial()

                // Attempt auto-reconnect if enabled (default: true)
                if self.autoReconnectEnabled {
                    self.protocolDataManager.logProtocolEvent("[RECONNECT] Auto-reconnect enabled - attempting reconnection")
                    self.attemptAutoReconnect(peripheralUUID: peripheralUUID)
                } else {
                    self.protocolDataManager.logProtocolEvent("[RECONNECT] Auto-reconnect disabled - manual reconnection required")
                }
            })
            .disposed(by: disposeBag)

        // Layer 3: Periodic connection health monitor
        // iOS CoreBluetooth doesn't always generate disconnect events for physical power off,
        // so we actively check peripheral.state every 3 seconds to detect disconnections
        Observable<Int>.interval(.seconds(3), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] tick in
                guard let self = self else { return }
                guard let peripheral = try? self.connectedPeripheralSubject.value() else { return }

                let currentState = peripheral.state

                // Log periodic health check every 30 seconds (tick % 10 == 0)
                if tick % 10 == 0 {
                    self.protocolDataManager.logProtocolEvent("[HEALTH] Periodic check (tick \(tick)) - Peripheral state: \(currentState.rawValue)")
                    print("[HEALTH] Periodic check (tick \(tick)) - Peripheral state: \(currentState.rawValue)")  // Console debug
                }

                // If peripheral.state != .connected, connection was lost without disconnect event!
                if currentState != .connected {
                    self.protocolDataManager.logProtocolEvent("[HEALTH] ⚠️ DETECTED: Peripheral state changed to \(currentState.rawValue)")
                    self.protocolDataManager.logProtocolEvent("[HEALTH] Connection lost without disconnect event - triggering auto-reconnect")
                    print("[HEALTH] ⚠️ DETECTED: Peripheral state changed to \(currentState.rawValue)")  // Console debug

                    // Build 40 FIX: Use partial cleanup + auto-reconnect instead of full cleanup
                    // This preserves UUID for automatic reconnection (Build 38 feature)
                    self.cleanConnectionPartial()

                    // Attempt auto-reconnect if enabled and UUID available
                    if self.autoReconnectEnabled {
                        if let uuid = self.cachedDeviceUUID {
                            self.protocolDataManager.logProtocolEvent("[HEALTH] Triggering auto-reconnect with UUID: \(uuid)")
                            self.attemptAutoReconnect(peripheralUUID: uuid)
                        } else {
                            self.protocolDataManager.logProtocolEvent("[HEALTH] ⚠️ Cannot auto-reconnect: No cached UUID")
                        }
                    } else {
                        self.protocolDataManager.logProtocolEvent("[HEALTH] Auto-reconnect disabled - manual scan required")
                    }
                }
            })
            .disposed(by: disposeBag)

        // Log that health monitor started
        // Using both logProtocolEvent (for diagnostics export) and print (for Xcode console debugging)
        protocolDataManager.logProtocolEvent("[INIT] ✅ Connection health monitor started (3s interval)")
        print("[INIT] ✅ Connection health monitor started (3s interval)")  // Console debug

        NotificationCenter.default.rx.notification(UIApplication.didEnterBackgroundNotification)
            .subscribe { [weak self] (noti: Notification) in
                self?.pauseRefreshBMSData()
            }.disposed(by: disposeBag)

        NotificationCenter.default.rx.notification(UIApplication.willEnterForegroundNotification)
            .subscribe { [weak self] (_ : Notification) in
                self?.resumeRefreshBMSData()
            }.disposed(by: disposeBag)
    }

    deinit {
        shutDown()
    }

    public static func setup(_ configuration: Configuration) {
        ZetaraManager.configuration = configuration
        
        if let mockDeviceName = configuration.mockDeviceName {
            shared.mockDeviceName = mockDeviceName
        }
        
        // Если установлены мок-данные, запускаем обновление данных сразу
        if configuration.mockData != nil {
            shared.startRefreshBMSData()
        }
    }

    public func connectedPeripheral() -> ConnectedPeripheral? {
        // Если есть реальное подключенное устройство, возвращаем его
        if let peripheral = try? connectedPeripheralSubject.value() {
            return peripheral
        }
        
        return nil
    }
    
    /// Возвращает имя подключенного устройства или имя мок-устройства, если используются мок-данные
    public func getDeviceName() -> String {
        // Если есть реальное подключенное устройство, возвращаем его имя
        if let peripheral = try? connectedPeripheralSubject.value() {
            return peripheral.name ?? "Unknown device"
        }
        
        // Если используются мок-данные и задано имя устройства, возвращаем его
        if Self.configuration.mockData != nil && mockDeviceName != nil {
            return mockDeviceName!
        }
        
        return "No device connected"
    }

    public func startScan() -> Observable<[ScannedPeripheral]> {
        print("start scan")
        let managerIsOn = manager.observeStateWithInitialValue()
            .filter { $0 == .poweredOn }
            .compactMap { [weak self] _ in self?.manager }

        scannedPeripheralsSubject.dispose()
        scannedPeripheralsSubject = BehaviorSubject<[ScannedPeripheral]>(value: [])

        scanningDisposable?.dispose()
        scanningDisposable = managerIsOn
            .flatMap { $0.scanForPeripherals(withServices: nil) }
            .filter { $0.peripheral.name != nil }
            .timeout(.seconds(7), scheduler: MainScheduler.instance)
            .subscribe { [weak self] (scannedPeripheral: ScannedPeripheral) in
                if var current = try? self?.scannedPeripheralsSubject.value(),
                   !current.contains(scannedPeripheral) {
                    current.append(scannedPeripheral)
                    self?.scannedPeripheralsSubject.onNext(current)
                }
            } onError: { [weak self] _ in
                self?.scannedPeripheralsSubject.onNext([])
            } onDisposed: { [weak self] in
                self?.scannedPeripheralsSubject.onNext([])
            }

        return scannedPeripheralsSubject.asObservable().observeOn(MainScheduler.instance)
    }

    public func shutDown() {
        print("stop scan")
        scanningDisposable?.dispose()
    }

    public func connect(_ peripheral: Peripheral) -> Observable<ConnectedPeripheral> {

        print("try to connect peripheral: \(peripheral.name ?? "") identifier: \(peripheral.identifier.uuidString)")

        // Детальное логирование процесса подключения
        protocolDataManager.logProtocolEvent("[CONNECT] Attempting connection")
        protocolDataManager.logProtocolEvent("[CONNECT] Device name: \(peripheral.name ?? "Unknown")")
        protocolDataManager.logProtocolEvent("[CONNECT] Device UUID: \(peripheral.identifier.uuidString)")
        protocolDataManager.logProtocolEvent("[CONNECT] Cached UUID: \(cachedDeviceUUID ?? "none")")

        // Layer 2: Pre-flight check - verify peripheral is from current scan
        // iOS CoreBluetooth caches peripheral instances across scans
        // We must verify this peripheral came from the current scan session, not a stale cached reference
        // Note: peripheral.state is NOT reliable (always .disconnected after scan, before connection)
        if let scannedPeripherals = try? scannedPeripheralsSubject.value() {
            let isInCurrentScan = scannedPeripherals.contains { scanned in
                scanned.peripheral.identifier == peripheral.identifier
            }

            protocolDataManager.logProtocolEvent("[CONNECT] Pre-flight check: Peripheral in current scan list: \(isInCurrentScan)")

            if !isInCurrentScan {
                // Peripheral NOT in scan list = stale cached reference from previous session
                // This happens when battery disconnects → cleanConnection() clears scan list →
                // but UI still shows old peripheral from cache
                protocolDataManager.logProtocolEvent("[CONNECT] ❌ ABORT: Peripheral not found in current scan list")
                protocolDataManager.logProtocolEvent("[CONNECT] This peripheral is from a previous scan session (UUID: \(peripheral.identifier.uuidString))")
                protocolDataManager.logProtocolEvent("[CONNECT] Scan list was cleared during disconnect - this is a stale reference")
                protocolDataManager.logProtocolEvent("[CONNECT] User must scan again to get fresh peripheral from current session")

                // ABORT connection attempt - return error with user-friendly message
                return Observable.error(Error.stalePeripheralError)
            } else {
                protocolDataManager.logProtocolEvent("[CONNECT] ✅ Peripheral verified from current scan session")
            }
        }

        // Build 37 Fix: Force cached peripheral release before fresh retrieval
        // Problem: retrievePeripherals() may return iOS cached stale peripheral instance
        // even after battery restart (within same app session)
        // Solution: Explicitly cancel connection to force iOS CoreBluetooth to release cache
        if let cachedPeripheral = try? connectedPeripheralSubject.value() {
            protocolDataManager.logProtocolEvent("[CONNECT] Build 37: Forcing release of cached peripheral")
            protocolDataManager.logProtocolEvent("[CONNECT] Cached peripheral state: \(cachedPeripheral.state.rawValue)")

            // Cancel connection to force iOS to release cached references
            manager.manager.cancelPeripheralConnection(cachedPeripheral.peripheral)

            // Brief delay to allow iOS to process cancellation
            Thread.sleep(forTimeInterval: 0.1)

            protocolDataManager.logProtocolEvent("[CONNECT] Build 37: Cached peripheral released, proceeding with fresh retrieval")
        }

        // Build 33 Fix: Retrieve fresh peripheral instance to avoid iOS cached stale characteristics
        // Research: iOS caches services/characteristics at the peripheral object level
        // After disconnect, these cached references become invalid (error 4: invalidHandle)
        // Solution: Use retrievePeripherals(withIdentifiers:) to get fresh peripheral instance
        // Source: Apple docs + Stack Overflow (CoreBluetooth doesn't discover services on reconnect)
        let peripheralUUID = peripheral.identifier
        let freshPeripherals = manager.retrievePeripherals(withIdentifiers: [peripheralUUID])

        guard let freshPeripheral = freshPeripherals.first else {
            protocolDataManager.logProtocolEvent("[CONNECT] ❌ Failed to retrieve fresh peripheral instance")
            return Observable.error(Error.peripheralNotFound)
        }

        protocolDataManager.logProtocolEvent("[CONNECT] ✅ Retrieved fresh peripheral instance (prevents stale characteristic caches)")
        protocolDataManager.logProtocolEvent("[CONNECT] Fresh peripheral UUID: \(freshPeripheral.identifier.uuidString)")

        // 先释放之前的
        cleanConnection()

        let serviceUUIDs = ZetaraManager.configuration.identifiers.map { $0.service.uuid }

        self.connectionDisposable = freshPeripheral.establishConnection()
            .flatMap { $0.discoverServices(serviceUUIDs) }
            .do(onNext: { [weak self] services in
                // Логируем найденные services
                self?.protocolDataManager.logProtocolEvent("[CONNECT] Services discovered: \(services.count)")
                services.forEach { service in
                    self?.protocolDataManager.logProtocolEvent("[CONNECT] Service UUID: \(service.uuid.uuidString)")
                }
            })
            .flatMap { Observable.from($0) }
            .flatMap { Identifier.asSingle(service: $0) }
            .flatMap {
                $0.service.discoverCharacteristics([$0.identifer.writeCharacteristic.uuid,
                                                    $0.identifer.notifyCharacteristic.uuid])
                    .observeOn(MainScheduler.instance)
            }
            .subscribeOn(MainScheduler.instance)
            .subscribe { [weak self] event in
                let observer = self!.connectedPeripheralSubject.asObserver()
                switch event {
                    case .error(let error):
                        // Детальное логирование ошибки подключения
                        if case ZetaraManager.Error.notZetaraPeripheralError = error {
                            self?.protocolDataManager.logProtocolEvent("[CONNECT] ❌ Service UUID not recognized (not a valid BigBattery device)")
                        } else {
                            self?.protocolDataManager.logProtocolEvent("[CONNECT] ❌ Connection error: \(error.localizedDescription)")
                        }
                        observer.onError(error)
                    case .next(let characteristics):
                        if let identifier = Identifier.identifier(of: characteristics.first!),
                           let writeCharacteristic = characteristics[characteristicOf: identifier.writeCharacteristic],
                           let notifyCharacteristic = characteristics[characteristicOf: identifier.notifyCharacteristic]
                            {
                            self?.writeCharacteristic = writeCharacteristic
                            self?.notifyCharacteristic = notifyCharacteristic
                            self?.identifier = identifier

                            // Логируем успешное установление characteristics
                            self?.protocolDataManager.logProtocolEvent("[CONNECTION] ✅ Characteristics configured")
                            self?.protocolDataManager.logProtocolEvent("[CONNECTION] Write UUID: \(writeCharacteristic.uuid.uuidString)")
                            self?.protocolDataManager.logProtocolEvent("[CONNECTION] Notify UUID: \(notifyCharacteristic.uuid.uuidString)")

                            // Сохраняем UUID подключенного устройства (using fresh peripheral)
                            // Build 38: Save BOTH in memory AND persistent storage for auto-reconnect
                            self?.cachedDeviceUUID = freshPeripheral.identifier.uuidString
                            UserDefaults.standard.set(freshPeripheral.identifier.uuidString, forKey: self!.lastConnectedUUIDKey)
                            print("[CONNECTION] Saved device UUID: \(freshPeripheral.identifier.uuidString)")
                            self?.protocolDataManager.logProtocolEvent("[CONNECTION] Device UUID saved (memory + persistent storage)")
                            self?.protocolDataManager.logProtocolEvent("[CONNECTION] UUID: \(freshPeripheral.identifier.uuidString)")

                            observer.onNext(freshPeripheral)

                            // Запускаем мониторинг подключения
                            self?.startConnectionMonitor()

                            // NOTE: startRefreshBMSData() НЕ вызывается здесь!
                            // BMS timer запускается ПОСЛЕ protocol loading в ConnectivityViewController
                            // чтобы избежать смешивания BMS requests с protocol queries
                        } else {
                            // Identifier or characteristics not found
                            self?.protocolDataManager.logProtocolEvent("[CONNECT] ❌ Failed to configure characteristics (identifier not recognized)")
                            observer.onError(ZetaraManager.Error.notZetaraPeripheralError)
                        }
                    case .completed:
                        observer.onCompleted()
                }
            }

        return self.connectedPeripheralSubject
            .compactMap { $0 }
            .asObservable()
            .observeOn(MainScheduler.instance)
    }

    public func disconnect(_ peripheral: Peripheral) {
        print("disconnect peripheral: \(peripheral.name ?? "") identifier: \(peripheral.identifier.uuidString)")
    }

    func cleanData() {
        self.bmsDataSubject.onNext(Data.BMS())
    }

    func cleanScanning() {
        self.scannedPeripheralsSubject.onNext([])
        self.scanningDisposable?.dispose()
    }

    public func cleanConnection() {
        // Атомарная проверка и установка флага через serial queue
        let shouldProceed = cleanConnectionQueue.sync { () -> Bool in
            guard !isCleaningConnection else {
                return false
            }
            isCleaningConnection = true
            return true
        }

        guard shouldProceed else {
            protocolDataManager.logProtocolEvent("[CONNECTION] ⚠️ Skipping duplicate cleanConnection call")
            return
        }

        defer {
            cleanConnectionQueue.sync {
                isCleaningConnection = false
            }
        }

        // Build 38: Full cleanup is MANUAL disconnect (not auto-reconnect)
        protocolDataManager.logProtocolEvent("[CLEANUP] 🔴 Full cleanup requested (MANUAL disconnect)")
        protocolDataManager.logProtocolEvent("[CLEANUP] This will clear ALL connection data including persistent UUID")

        // Останавливаем мониторинг подключения
        stopConnectionMonitor()

        // Очищаем Request Queue
        lastRequestTime = nil
        protocolDataManager.logProtocolEvent("[QUEUE] Request queue cleared")

        connectionDisposable?.dispose()

        // Останавливаем BMS timer явно
        if timer != nil {
            timer?.invalidate()
            timer = nil
            protocolDataManager.logProtocolEvent("[CONNECTION] 🛑 BMS timer stopped")
        }

        // Очищаем BMS данные
        cleanData()
        protocolDataManager.logProtocolEvent("[CONNECTION] BMS data cleared")

        // Очищаем протокольные данные через ProtocolDataManager
        protocolDataManager.clearProtocols()

        // Очищаем список сканированных устройств (stale peripherals)
        cleanScanning()
        protocolDataManager.logProtocolEvent("[CONNECTION] Scanned peripherals cleared")

        // Сбрасываем ВСЕ Bluetooth состояния для чистого переподключения
        writeCharacteristic = nil
        notifyCharacteristic = nil
        identifier = nil

        // Build 38: Clear persistent UUID (prevent auto-reconnect after manual disconnect)
        UserDefaults.standard.removeObject(forKey: lastConnectedUUIDKey)
        protocolDataManager.logProtocolEvent("[CLEANUP] Cleared persistent UUID from storage (auto-reconnect disabled)")

        cachedDeviceUUID = nil
        protocolDataManager.logProtocolEvent("[CONNECTION] All Bluetooth characteristics cleared")
        protocolDataManager.logProtocolEvent("[CONNECTION] Cached device UUID cleared (memory)")

        connectedPeripheralSubject.onNext(nil)

        protocolDataManager.logProtocolEvent("[CONNECTION] Connection state cleaned")
    }

    // Build 38: Partial cleanup for auto-reconnect
    /// Partial cleanup - clears ONLY invalidated data (characteristics/services)
    /// KEEPS peripheral UUID and connection state for auto-reconnect capability
    /// Used during disconnect to preserve reconnection foundation
    /// Apple docs: "All services, characteristics become invalidated after disconnect"
    public func cleanConnectionPartial() {
        protocolDataManager.logProtocolEvent("[CLEANUP] Partial cleanup - preserving UUID for auto-reconnect")

        // Останавливаем мониторинг подключения
        stopConnectionMonitor()

        // Останавливаем BMS timer
        if timer != nil {
            timer?.invalidate()
            timer = nil
            protocolDataManager.logProtocolEvent("[CLEANUP] 🛑 BMS timer stopped")
        }

        // Очищаем Request Queue
        lastRequestTime = nil
        protocolDataManager.logProtocolEvent("[CLEANUP] Request queue cleared")

        // Очищаем BMS data
        cleanData()
        protocolDataManager.logProtocolEvent("[CLEANUP] BMS data cleared")

        // Очищаем протокольные данные
        protocolDataManager.clearProtocols()

        // Очищаем ТОЛЬКО characteristics (invalid after disconnect per Apple docs)
        // Apple: "All services, characteristics, and characteristic descriptors
        // become invalidated after it disconnects"
        writeCharacteristic = nil
        notifyCharacteristic = nil
        identifier = nil
        protocolDataManager.logProtocolEvent("[CLEANUP] Characteristics cleared (invalidated by disconnect)")

        // CRITICAL: DO NOT clear these (needed for auto-reconnect):
        // - cachedDeviceUUID (keep for auto-reconnect attempt)
        // - connectedPeripheralSubject (will be updated by auto-reconnect)
        // - scannedPeripheralsSubject (not needed for retrievePeripherals)
        // - persistent UUID in UserDefaults (keep for cross-session reconnect)

        protocolDataManager.logProtocolEvent("[CLEANUP] Partial cleanup complete - ready for auto-reconnect")
        protocolDataManager.logProtocolEvent("[CLEANUP] UUID preserved: \(cachedDeviceUUID ?? "none")")
    }

    // Build 38: Auto-reconnect implementation
    /// Attempts automatic reconnection to previously connected peripheral
    /// Uses retrievePeripherals(withIdentifiers:) to get fresh peripheral instance
    /// Establishes persistent connection request that survives battery power cycles
    /// - Parameter peripheralUUID: UUID string of peripheral to reconnect
    public func attemptAutoReconnect(peripheralUUID: String) {
        protocolDataManager.logProtocolEvent("[RECONNECT] ⚡ Starting auto-reconnect sequence")
        protocolDataManager.logProtocolEvent("[RECONNECT] Target UUID: \(peripheralUUID)")

        // Build 40: Prevent duplicate auto-reconnect attempts
        // If iOS didDisconnect fires after health monitor, this prevents second attempt
        if let peripheral = try? connectedPeripheralSubject.value(),
           peripheral.state == .connecting {
            protocolDataManager.logProtocolEvent("[RECONNECT] ⚠️ Auto-reconnect already in progress - skipping duplicate")
            return
        }

        guard let uuid = UUID(uuidString: peripheralUUID) else {
            protocolDataManager.logProtocolEvent("[RECONNECT] ❌ Invalid UUID format")
            return
        }

        // Step 1: Retrieve fresh peripheral instance from iOS CoreBluetooth
        // This is KEY - we don't scan, we retrieve by known UUID
        // Apple: "If peripheral disconnects and reconnects at iOS level, app needs to
        // retrieve the peripheral object and explicitly connect through CBCentralManager"
        let retrievedPeripherals = manager.retrievePeripherals(withIdentifiers: [uuid])

        guard let freshPeripheral = retrievedPeripherals.first else {
            protocolDataManager.logProtocolEvent("[RECONNECT] ❌ Peripheral not found by UUID")
            protocolDataManager.logProtocolEvent("[RECONNECT] iOS may have forgotten this peripheral")
            protocolDataManager.logProtocolEvent("[RECONNECT] Manual scan required")
            // Fallback: require manual scan
            connectedPeripheralSubject.onNext(nil)
            return
        }

        protocolDataManager.logProtocolEvent("[RECONNECT] ✅ Retrieved fresh peripheral instance")
        protocolDataManager.logProtocolEvent("[RECONNECT] Peripheral state: \(freshPeripheral.state.rawValue)")
        protocolDataManager.logProtocolEvent("[RECONNECT] Peripheral name: \(freshPeripheral.name ?? "Unknown")")

        // Step 2: Check if peripheral is already connected at iOS level
        // (can happen with bonded peripherals or HID devices)
        if freshPeripheral.state == .connected {
            protocolDataManager.logProtocolEvent("[RECONNECT] ⚡ Peripheral already connected at iOS level!")
            protocolDataManager.logProtocolEvent("[RECONNECT] Proceeding directly to service/characteristic discovery")

            // Already connected at iOS level - just rediscover services
            rediscoverServicesAndCharacteristics(peripheral: freshPeripheral)
            return
        }

        // Step 3: Establish PERSISTENT connection request
        // Apple: "Connection requests do not time out - iOS will auto-connect when peripheral in range"
        // This is THE KEY to auto-reconnect - the connection request persists until peripheral appears
        protocolDataManager.logProtocolEvent("[RECONNECT] 🔌 Establishing persistent connection request")
        protocolDataManager.logProtocolEvent("[RECONNECT] iOS will auto-connect when peripheral comes in range")
        protocolDataManager.logProtocolEvent("[RECONNECT] This request will NOT timeout")

        // Update UI state to show disconnected (will be updated on successful reconnect)
        connectedPeripheralSubject.onNext(nil)

        // THIS IS THE KEY: calling establishConnection() creates a persistent request
        // It will NOT timeout - iOS will connect automatically when peripheral appears
        // Even after battery power cycle, when battery powers on, iOS will auto-connect
        connectionDisposable?.dispose()
        connectionDisposable = freshPeripheral.establishConnection()
            .subscribe(onNext: { [weak self] connectedPeripheral in
                guard let self = self else { return }

                self.protocolDataManager.logProtocolEvent("[RECONNECT] ✅ ✅ ✅ AUTO-RECONNECT SUCCESSFUL!")
                self.protocolDataManager.logProtocolEvent("[RECONNECT] Peripheral reconnected: \(connectedPeripheral.name ?? "Unknown")")
                self.protocolDataManager.logProtocolEvent("[RECONNECT] Connection state: \(connectedPeripheral.state.rawValue)")

                // Rediscover services and characteristics with fresh peripheral
                // This is necessary because all characteristics become invalid after disconnect
                self.rediscoverServicesAndCharacteristics(peripheral: connectedPeripheral)

            }, onError: { [weak self] error in
                self?.protocolDataManager.logProtocolEvent("[RECONNECT] ❌ Auto-reconnect failed: \(error.localizedDescription)")
                self?.protocolDataManager.logProtocolEvent("[RECONNECT] Connection request still active - waiting for peripheral")
                // Note: Don't give up - connection request stays active
                // iOS will continue trying when peripheral comes in range
                // User can manually scan if needed
            })

        protocolDataManager.logProtocolEvent("[RECONNECT] Persistent connection request established ✅")
        protocolDataManager.logProtocolEvent("[RECONNECT] Waiting for peripheral to come back in range...")
        protocolDataManager.logProtocolEvent("[RECONNECT] User will be notified when connection succeeds")
    }

    // Build 38: Service/Characteristic rediscovery after reconnection
    /// Rediscovers services and characteristics for reconnected peripheral
    /// Apple: "All services, characteristics become invalidated after disconnect"
    /// Must rediscover to get fresh, valid characteristic handles
    /// - Parameter peripheral: Freshly connected peripheral
    private func rediscoverServicesAndCharacteristics(peripheral: Peripheral) {
        protocolDataManager.logProtocolEvent("[RECONNECT] 🔍 Rediscovering services and characteristics")
        protocolDataManager.logProtocolEvent("[RECONNECT] This is required because characteristics invalidated after disconnect")

        let serviceUUIDs = ZetaraManager.configuration.identifiers.map { $0.service.uuid }

        Observable.just(peripheral)
            .flatMap { $0.discoverServices(serviceUUIDs).asObservable() }
            .flatMap { Observable.from($0) }
            .flatMap { Identifier.asSingle(service: $0).asObservable() }
            .flatMap { tuple -> Observable<[Characteristic]> in
                tuple.service.discoverCharacteristics([tuple.identifer.writeCharacteristic.uuid,
                                                       tuple.identifer.notifyCharacteristic.uuid])
                    .asObservable()
                    .observeOn(MainScheduler.instance)
            }
            .subscribeOn(MainScheduler.instance)
            .subscribe { [weak self] event in
                guard let self = self else { return }

                switch event {
                case .next(let characteristics):
                    if let identifier = Identifier.identifier(of: characteristics.first!),
                       let writeCharacteristic = characteristics[characteristicOf: identifier.writeCharacteristic],
                       let notifyCharacteristic = characteristics[characteristicOf: identifier.notifyCharacteristic] {

                        // Configure characteristics with fresh handles
                        self.writeCharacteristic = writeCharacteristic
                        self.notifyCharacteristic = notifyCharacteristic
                        self.identifier = identifier

                        // Build 44: Save UUID to memory for mid-session auto-reconnect
                        // This was missing - rediscover path never saved cachedDeviceUUID!
                        self.cachedDeviceUUID = peripheral.identifier.uuidString
                        self.protocolDataManager.logProtocolEvent("[RECONNECT] UUID saved to memory: \(peripheral.identifier.uuidString)")

                        // Also ensure UserDefaults is up to date
                        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: self.lastConnectedUUIDKey)

                        self.protocolDataManager.logProtocolEvent("[RECONNECT] ✅ Characteristics rediscovered successfully")
                        self.protocolDataManager.logProtocolEvent("[RECONNECT] Write UUID: \(writeCharacteristic.uuid.uuidString)")
                        self.protocolDataManager.logProtocolEvent("[RECONNECT] Notify UUID: \(notifyCharacteristic.uuid.uuidString)")

                        // Update connected peripheral subject - this triggers UI update
                        self.connectedPeripheralSubject.onNext(peripheral)
                        self.protocolDataManager.logProtocolEvent("[RECONNECT] connectedPeripheralSubject updated")

                        // Start connection monitor to detect future disconnects
                        self.startConnectionMonitor()
                        self.protocolDataManager.logProtocolEvent("[RECONNECT] Connection monitor started")

                        // Auto-load protocols after reconnection (with delay for stability)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.protocolDataManager.logProtocolEvent("[RECONNECT] 🔄 Auto-loading protocols after reconnection")
                            self.protocolDataManager.loadAllProtocols(afterDelay: 0)
                        }

                        // Start BMS timer after protocol loading (with delay)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            self.protocolDataManager.logProtocolEvent("[RECONNECT] ⏱️ Starting BMS timer after reconnection")
                            self.startRefreshBMSData()
                        }

                        self.protocolDataManager.logProtocolEvent("[RECONNECT] 🎉 🎉 🎉 AUTO-RECONNECTION COMPLETE!")
                        self.protocolDataManager.logProtocolEvent("[RECONNECT] Battery data will resume automatically")

                    } else {
                        self.protocolDataManager.logProtocolEvent("[RECONNECT] ❌ Failed to configure characteristics")
                        self.protocolDataManager.logProtocolEvent("[RECONNECT] Identifier or characteristics not recognized")
                        // Connection request stays active - iOS will retry
                    }

                case .error(let error):
                    self.protocolDataManager.logProtocolEvent("[RECONNECT] ❌ Service discovery error: \(error.localizedDescription)")
                    self.protocolDataManager.logProtocolEvent("[RECONNECT] Connection request still active - will retry")
                    // Don't give up - connection request persists
                    // User can try manual reconnect if needed

                case .completed:
                    break
                }
            }
            .disposed(by: disposeBag)
    }

    // Build 34: Launch-time fresh peripheral retrieval
    // Called from AppDelegate on app launch and foreground to prevent stale characteristics
    public func refreshPeripheralInstanceIfNeeded() {
        protocolDataManager.logProtocolEvent("[LAUNCH] Checking for cached peripheral to refresh")

        // Build 35: Guard against refresh during disconnect to prevent crash
        // Skip refresh if peripheral is currently disconnecting
        if let currentPeripheral = try? connectedPeripheralSubject.value(),
           currentPeripheral.state == .disconnecting {
            protocolDataManager.logProtocolEvent("[LAUNCH] ⚠️ Skip refresh - peripheral disconnecting")
            return
        }

        guard let cachedUUID = cachedDeviceUUID,
              let uuidObj = UUID(uuidString: cachedUUID) else {
            protocolDataManager.logProtocolEvent("[LAUNCH] No cached peripheral UUID found")
            return
        }

        protocolDataManager.logProtocolEvent("[LAUNCH] Found cached UUID: \(cachedUUID)")

        // Retrieve fresh peripheral instance from iOS CoreBluetooth
        // This prevents error 4 (invalidHandle) from stale characteristic references
        let freshPeripherals = manager.retrievePeripherals(withIdentifiers: [uuidObj])

        guard let freshPeripheral = freshPeripherals.first else {
            // Peripheral no longer available - clear stale state
            protocolDataManager.logProtocolEvent("[LAUNCH] ⚠️ Peripheral no longer available, clearing state")
            cleanConnection()
            return
        }

        protocolDataManager.logProtocolEvent("[LAUNCH] ✅ Retrieved fresh peripheral instance")
        protocolDataManager.logProtocolEvent("[LAUNCH] Fresh peripheral state: \(freshPeripheral.state.rawValue)")

        // Update subject with fresh instance (replaces stale one in memory)
        connectedPeripheralSubject.onNext(freshPeripheral)
        protocolDataManager.logProtocolEvent("[LAUNCH] Updated peripheral reference with fresh instance")
    }

    // Build 39: Startup auto-reconnect
    /// Initiates auto-reconnect at app startup if UUID exists in UserDefaults
    /// Called from AppDelegate.didFinishLaunchingWithOptions after setup()
    /// Handles both "Bluetooth already on" and "Bluetooth off at launch" scenarios
    public func initiateStartupAutoReconnect() {
        protocolDataManager.logProtocolEvent("[STARTUP] Checking for stored UUID to auto-reconnect")

        // Get stored UUID from persistent storage
        guard let storedUUIDString = UserDefaults.standard.string(forKey: lastConnectedUUIDKey) else {
            protocolDataManager.logProtocolEvent("[STARTUP] No stored UUID found - manual scan required")
            return
        }

        guard autoReconnectEnabled else {
            protocolDataManager.logProtocolEvent("[STARTUP] Auto-reconnect disabled by user")
            return
        }

        protocolDataManager.logProtocolEvent("[STARTUP] Found stored UUID: \(storedUUIDString)")
        protocolDataManager.logProtocolEvent("[STARTUP] Auto-reconnect enabled - checking Bluetooth state")

        // Check if already attempting reconnection to avoid duplicates
        if let currentPeripheral = try? connectedPeripheralSubject.value(),
           currentPeripheral.state == .connecting {
            protocolDataManager.logProtocolEvent("[STARTUP] Auto-reconnect already in progress - skipping duplicate")
            return
        }

        // Check current Bluetooth state synchronously
        // observeStateWithInitialValue() emits current state immediately
        let stateDisposable = manager.observeStateWithInitialValue()
            .take(1)
            .subscribe(onNext: { [weak self] currentState in
                guard let self = self else { return }

                self.protocolDataManager.logProtocolEvent("[STARTUP] Current Bluetooth state: \(currentState)")

                if currentState == .poweredOn {
                    // Bluetooth already powered on - proceed immediately
                    self.protocolDataManager.logProtocolEvent("[STARTUP] Bluetooth already powered on - initiating auto-reconnect immediately")
                    self.attemptAutoReconnect(peripheralUUID: storedUUIDString)
                } else {
                    // Bluetooth not ready - wait for .poweredOn state
                    self.protocolDataManager.logProtocolEvent("[STARTUP] Bluetooth not ready (\(currentState)) - will auto-reconnect when Bluetooth powers on")

                    // Set up one-time listener for Bluetooth ready
                    // This will trigger auto-reconnect when user enables Bluetooth
                    self.observableState
                        .filter { $0 == .poweredOn }
                        .take(1)  // Fire only once
                        .subscribe(onNext: { [weak self] _ in
                            self?.protocolDataManager.logProtocolEvent("[STARTUP] Bluetooth now powered on - initiating auto-reconnect")
                            self?.attemptAutoReconnect(peripheralUUID: storedUUIDString)
                        })
                        .disposed(by: self.disposeBag)
                }
            })

        stateDisposable.dispose()
    }

    public func observeDisconect() -> Observable<Peripheral> {
        return manager.observeDisconnect()
            .do(onNext: { [weak self] (peripheral, error) in
                let peripheralName = peripheral.name ?? "Unknown"
                print("[CONNECTION] 🔌 Device disconnected: \(peripheralName)")
                if let error = error {
                    print("[CONNECTION] Disconnect reason: \(error)")
                }
                
                // Автоматическая очистка при отключении
                self?.cleanConnection()
            })
            .flatMap { (peripheral, _) in Observable.of(peripheral) }
            .observeOn(MainScheduler.instance)
    }
    
    // MARK: - Request Queue Methods (Этап 2.1)
    
    /// Выполняет Bluetooth запрос через очередь с минимальным интервалом между запросами
    /// - Parameters:
    ///   - requestName: Имя запроса для логирования
    ///   - request: Замыкание, возвращающее Maybe с результатом
    /// - Returns: Maybe с результатом запроса
    public func queuedRequest<T>(_ requestName: String,
                                 _ request: @escaping () -> Maybe<T>) -> Maybe<T> {
        return Maybe.create { observer in
            let startTime = Date()

            print("[QUEUE] 📥 Request queued: \(requestName)")
            self.protocolDataManager.logProtocolEvent("[QUEUE] 📥 Request queued: \(requestName)")

            self.requestQueue.async {
                // Ждем если прошло < 500ms с последнего запроса
                if let lastTime = self.lastRequestTime {
                    let elapsed = Date().timeIntervalSince(lastTime)
                    if elapsed < self.minimumRequestInterval {
                        let waitTime = self.minimumRequestInterval - elapsed

                        print("[QUEUE] ⏳ Waiting \(Int(waitTime * 1000))ms before \(requestName)")
                        self.protocolDataManager.logProtocolEvent("[QUEUE] ⏳ Waiting \(Int(waitTime * 1000))ms before \(requestName)")

                        Thread.sleep(forTimeInterval: waitTime)
                    }
                }

                // Обновляем время последнего запроса
                self.lastRequestTime = Date()

                print("[QUEUE] 🚀 Executing \(requestName)")
                self.protocolDataManager.logProtocolEvent("[QUEUE] 🚀 Executing \(requestName)")

                // Выполняем запрос
                request()
                    .subscribe(onSuccess: { value in
                        let duration = Date().timeIntervalSince(startTime) * 1000
                        print("[QUEUE] ✅ \(requestName) completed in \(Int(duration))ms")
                        self.protocolDataManager.logProtocolEvent("[QUEUE] ✅ \(requestName) completed in \(Int(duration))ms")

                        observer(.success(value))

                    }, onError: { error in
                        let duration = Date().timeIntervalSince(startTime) * 1000
                        print("[QUEUE] ❌ \(requestName) failed in \(Int(duration))ms: \(error)")
                        self.protocolDataManager.logProtocolEvent("[QUEUE] ❌ \(requestName) failed in \(Int(duration))ms: \(error)")

                        observer(.error(error))
                    })
                    .disposed(by: self.requestQueueDisposeBag)
            }

            return Disposables.create()
        }
    }
    
    // MARK: - Connection Monitor Methods (Этап 2.2)
    
    /// Запускает периодическую проверку реального состояния подключения
    public func startConnectionMonitor() {
        // Останавливаем предыдущий таймер если есть
        stopConnectionMonitor()
        
        print("[CONNECTION] 🔍 Starting connection monitor (check every \(connectionCheckInterval)s)")
        
        connectionMonitorTimer = Timer.scheduledTimer(
            withTimeInterval: connectionCheckInterval,
            repeats: true
        ) { [weak self] _ in
            self?.verifyConnectionState()
        }
        
        // Первая проверка сразу
        verifyConnectionState()
    }
    
    /// Останавливает мониторинг подключения
    public func stopConnectionMonitor() {
        guard connectionMonitorTimer != nil else { return }
        
        connectionMonitorTimer?.invalidate()
        connectionMonitorTimer = nil
        
        print("[CONNECTION] Connection monitor stopped")
    }
    
    /// Проверяет реальное состояние периферии через CoreBluetooth
    public func verifyConnectionState() {
        let peripheral = try? connectedPeripheralSubject.value()
        let bmsTimerActive = (timer != nil)

        // КРИТИЧЕСКАЯ ПРОВЕРКА: Phantom connection если нет peripheral НО BMS timer активен
        if peripheral == nil && bmsTimerActive {
            print("[CONNECTION] ⚠️ PHANTOM CONNECTION: No peripheral but BMS timer is running!")
            protocolDataManager.logProtocolEvent("[CONNECTION] ⚠️ PHANTOM: No peripheral but BMS timer running!")

            // Build 43: Use partial cleanup to preserve UUID for auto-reconnect
            cleanConnectionPartial()

            // Trigger auto-reconnect if UUID available
            if autoReconnectEnabled, let uuid = cachedDeviceUUID {
                protocolDataManager.logProtocolEvent("[PHANTOM] Triggering auto-reconnect with UUID: \(uuid)")
                attemptAutoReconnect(peripheralUUID: uuid)
            }
            return
        }

        // Обычная проверка если peripheral существует
        guard let peripheral = peripheral else {
            // Нет подключенного устройства и нет BMS timer - это нормально
            return
        }

        let peripheralName = peripheral.name ?? "Unknown"
        let currentState = peripheral.state

        // Проверяем РЕАЛЬНОЕ состояние через CoreBluetooth
        if currentState != .connected {
            print("[CONNECTION] ⚠️ Phantom connection detected!")
            print("[CONNECTION] Device: \(peripheralName)")
            print("[CONNECTION] Expected state: connected")
            print("[CONNECTION] Actual state: \(currentState)")
            print("[CONNECTION] Action: Using partial cleanup for auto-reconnect")

            protocolDataManager.logProtocolEvent("[CONNECTION] ⚠️ Phantom connection detected! Device: \(peripheralName), State: \(currentState)")

            // Build 43: Use partial cleanup to preserve UUID for auto-reconnect
            cleanConnectionPartial()

            // Trigger auto-reconnect if UUID available
            if autoReconnectEnabled, let uuid = cachedDeviceUUID {
                protocolDataManager.logProtocolEvent("[PHANTOM] Triggering auto-reconnect with UUID: \(uuid)")
                attemptAutoReconnect(peripheralUUID: uuid)
            }
        }
    }

    /// Проверяет, актуален ли кэш для текущего подключенного устройства
    public func isCacheValidForCurrentDevice() -> Bool {
        guard let peripheral = try? connectedPeripheralSubject.value() else {
            return false
        }

        let currentUUID = peripheral.identifier.uuidString
        return cachedDeviceUUID == currentUUID
    }

    let bmsDataHandler = Data.BMSDataHandler()

    var timer: Timer?
    public func startRefreshBMSData() {
        protocolDataManager.logProtocolEvent("[BMS] 🚀 Starting BMS data refresh timer (interval: \(Self.configuration.refreshBMSTimeInterval)s)")
        print("[BMS] 🚀 Starting BMS data refresh timer (interval: \(Self.configuration.refreshBMSTimeInterval)s)")

        self.timer = Timer.scheduledTimer(withTimeInterval: Self.configuration.refreshBMSTimeInterval, repeats: true) { [weak self] _ in
            self?.getBMSData()
                .subscribeOn(MainScheduler.instance)
                .subscribe(onSuccess: { [weak self] _data in
                    self?.bmsDataSubject.asObserver().onNext(_data)
                }, onError: { _ in
                    // Ошибка при получении данных BMS
                }, onCompleted: {
                    // Получение данных завершено
                }).disposed(by: self!.disposeBag)
        }
        self.timer?.fire()
    }

    public func pauseRefreshBMSData() {
        print("stop refresh bms data")
        self.timer?.invalidate()
    }

    public func resumeRefreshBMSData() {
        print("resume refresh bms data")
        self.timer?.invalidate()
        self.timer = nil
        self.startRefreshBMSData()
    }

    var getBMSDataDisposeBag: DisposeBag?
    func getBMSData() -> Maybe<Data.BMS> {
        print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
        print("!!! МЕТОД getBMSData() ВЫЗВАН !!!")
        print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")

        protocolDataManager.logProtocolEvent("[BMS] 📡 getBMSData() called")

        // Проверяем наличие подключенного устройства
        let isDeviceConnected = (try? connectedPeripheralSubject.value()) != nil &&
                                writeCharacteristic != nil &&
                                notifyCharacteristic != nil

        protocolDataManager.logProtocolEvent("[BMS] Device connected: \(isDeviceConnected)")
        
        // Используем мок-данные только если нет подключенного устройства
        if !isDeviceConnected, let mockBMSData = Self.configuration.mockData {
            protocolDataManager.logProtocolEvent("[BMS] 🧪 Using mock data (no device connected)")
            print("!!! Нет подключенного устройства, используем мок-данные: \(mockBMSData.toHexString()) !!!")
            return Maybe.create { [weak self] observer in
                let bytes = [UInt8](mockBMSData)
                print("!!! Длина мок-данных: \(bytes.count) байт !!!")
                
                // Проверяем, является ли первый байт нормальным
                let isNormal = Data.BMS.FunctionCode.isNormal(of: bytes)
                print("!!! Является ли первый байт нормальным: \(isNormal) !!!")
                
                // Проверяем cellCount
                let cellCount = bytes.cellCount()
                print("!!! Количество ячеек: \(cellCount) !!!")
                
                // Пробуем обработать текущие мок-данные
                if let data = self?.bmsDataHandler.append(bytes) {
                    print("!!! Мок-данные успешно обработаны !!!")
                    observer(.success(data))
                } else {
                    print("!!! Ошибка при обработке мок-данных, пробуем другой набор !!!")
                    
                    // Пробуем использовать другой готовый набор мок-данных
                    print("!!! Пробуем использовать mockInChargingBMSData !!!")
                    let inChargingBytes = [UInt8](Foundation.Data.mockInChargingBMSData)
                    
                    if let data = self?.bmsDataHandler.append(inChargingBytes) {
                        print("!!! mockInChargingBMSData успешно обработан !!!")
                        observer(.success(data))
                    } else {
                        print("!!! Пробуем использовать mockNormalBMSData !!!")
                        let normalBytes = [UInt8](Foundation.Data.mockNormalBMSData)
                        
                        if let data = self?.bmsDataHandler.append(normalBytes) {
                            print("!!! mockNormalBMSData успешно обработан !!!")
                            observer(.success(data))
                        } else {
                            print("!!! Все наборы мок-данных не удалось обработать !!!")
                            observer(.completed)
                        }
                    }
                }

                return Disposables.create {}
            }
        }
        
        // Если есть подключенное устройство, используем реальные данные
        guard let peripheral = try? connectedPeripheralSubject.value(),
              let writeCharacteristic = writeCharacteristic,
              let notifyCharacteristic = notifyCharacteristic else {
            protocolDataManager.logProtocolEvent("[BMS] ❌ No peripheral/characteristics available")
            print("!!! ОШИБКА: Нет подключенного устройства !!!")
            // Build 42: Don't call cleanConnection() here - let health monitor handle auto-reconnect
            return Maybe.error(ZetaraManager.Error.connectionError)
        }

        protocolDataManager.logProtocolEvent("[BMS] ✅ Using real device data")
        print("!!! Используем реальные данные от подключенного устройства !!!")

        getBMSDataDisposeBag = nil
        getBMSDataDisposeBag = DisposeBag()

        let data = Foundation.Data.getBMSData
        protocolDataManager.logProtocolEvent("[BMS] 📤 Writing BMS request: \(data.toHexString())")
        print("getting bms data write data: \(data.toHexString())")
        peripheral.writeValue(data, for: writeCharacteristic, type: writeCharacteristic.writeType)
            .subscribe()
            .disposed(by: getBMSDataDisposeBag!)

        return Maybe.create { observer in
            peripheral.observeValueUpdateAndSetNotification(for: notifyCharacteristic)
                .compactMap { $0.value }
                .do { [weak self] data in
                    self?.protocolDataManager.logProtocolEvent("[BMS] 📥 Received BMS response: \(data.toHexString())")
                    print("recevie bms data: \(data.toHexString())")
                }
                .map { [UInt8]($0) }
                .filter { [weak self] bytes in
                    let crcValid = bytes.crc16Verify()
                    let isBMS = Data.BMS.isBMSData(bytes)
                    self?.protocolDataManager.logProtocolEvent("[BMS] Validation - CRC: \(crcValid), isBMSData: \(isBMS)")
                    return crcValid && isBMS
                }
                .compactMap { [weak self] _bytes in
                    let result = self?.bmsDataHandler.append(_bytes)
                    if result != nil {
                        self?.protocolDataManager.logProtocolEvent("[BMS] ✅ BMS data parsed successfully")
                    } else {
                        self?.protocolDataManager.logProtocolEvent("[BMS] ⚠️ Failed to parse BMS data")
                    }
                    return result
                }
                .flatMap { Observable.of($0) }
                .observeOn(MainScheduler.instance)
                .subscribeOn(MainScheduler.instance)
                .subscribe { bmsEvent in
                    switch bmsEvent {
                        case .next(let data):
                            observer(.success(data))
                        default:
                            return
                    }
                }.disposed(by: self.getBMSDataDisposeBag!)

            return Disposables.create { [weak self] in
                self?.getBMSDataDisposeBag = nil
            }
        }
    }

    public func getModuleId() -> Maybe<Data.ModuleIdControlData> {
        writeControlData(.getModuleId).compactMap { Data.ModuleIdControlData($0) }
    }

    public func setModuleId(_ number: Int) -> Maybe<Bool> {
        let data = [0x10, 0x07, 0x01, UInt8(number)]
        let hexString = data.crc16().toHexString()
        return writeControlData(.init(hex: hexString)).compactMap { Data.ResponseData($0)?.success ?? false }
    }

    public func getRS485() -> Maybe<Data.RS485ControlData> {
        writeControlData(.getRS485).compactMap { Data.RS485ControlData($0) }
    }

    public func setRS485(_ number: Int) -> Maybe<Bool> {
        let data = [0x10, 0x05, 0x01, UInt8(number)].crc16().toHexString()
        return writeControlData(.init(hex: data)).compactMap { Data.ResponseData($0)?.success ?? false }
    }

    public func getCAN() -> Maybe<Data.CANControlData> {
        writeControlData(.getCAN).compactMap {
            if let data = Data.CANControlData($0) {
                return data
            } else {
                return nil
            }
        }
    }

    public func setCAN(_ number: Int) -> Maybe<Bool> {
        let data = [0x10, 0x06, 0x01, UInt8(number)].crc16().toHexString()
        return writeControlData(.init(hex: data)).compactMap { Data.ResponseData($0)?.success ?? false }
    }

    // Build 45: Dictionary of DisposeBags to prevent request cancellation
    // Build 46: Fixed observation-before-write timing issue
    var controlDataDisposeBags: [UUID: DisposeBag] = [:]

    func writeControlData(_ data: Foundation.Data) -> Maybe<[UInt8]> {
        guard let peripheral = try? connectedPeripheralSubject.value(),
              let writeCharacteristic = writeCharacteristic,
              let notifyCharacteristic = notifyCharacteristic else {
            print("send data error. no connected peripheral")
            protocolDataManager.logProtocolEvent("[BLUETOOTH] ❌ No peripheral for writeControlData")
            // Build 42: Don't call cleanConnection() here - let health monitor handle auto-reconnect
            return Maybe.error(Error.writeControlDataError)
        }

        // Build 45: Each request gets its own DisposeBag that lives independently
        let requestId = UUID()
        let disposeBag = DisposeBag()
        controlDataDisposeBags[requestId] = disposeBag

        protocolDataManager.logProtocolEvent("[BLUETOOTH] 📤 Preparing control data: \(data.toHexString())")
        print("write control data: \(data.toHexString())")

        return Maybe.create { [weak self] observer in
            guard let self = self else {
                observer(.error(Error.writeControlDataError))
                return Disposables.create()
            }

            // Build 46: Set up observation FIRST, then write
            // This ensures we don't miss fast responses from the device
            self.protocolDataManager.logProtocolEvent("[BLUETOOTH] 📡 Setting up notification observation...")

            peripheral.observeValueUpdateAndSetNotification(for: notifyCharacteristic)
                .do(onNext: { characteristic in
                    // Логируем ВСЕ приходящие данные
                    if let value = characteristic.value {
                        let hexString = [UInt8](value).toHexString()
                        self.protocolDataManager.logProtocolEvent("[BLUETOOTH] 📥 Received notification: \(hexString)")
                    }
                })
                .compactMap { $0.value }
                .map { [UInt8]($0) }
                .do(onNext: { bytes in
                    let isControl = Data.isControlData(bytes)
                    self.protocolDataManager.logProtocolEvent("[BLUETOOTH] Is control data: \(isControl)")
                })
                .filter { Data.isControlData($0) }
                .do { print("receive control data: \($0.toHexString())") }
                .take(1)
                .timeout(.seconds(10), scheduler: MainScheduler.instance)
                .observeOn(MainScheduler.instance)
                .subscribeOn(MainScheduler.instance)
                .subscribe { event in
                    switch event {
                        case .next(let _data):
                            self.protocolDataManager.logProtocolEvent("[BLUETOOTH] ✅ Got control data response")
                            observer(.success(_data))
                        case .error(let error):
                            if case RxError.timeout = error {
                                self.protocolDataManager.logProtocolEvent("[BLUETOOTH] ⏱️ Timeout waiting for response")
                            } else {
                                self.protocolDataManager.logProtocolEvent("[BLUETOOTH] ❌ Error: \(error)")
                            }
                            observer(.error(error))
                        default:
                            self.protocolDataManager.logProtocolEvent("[BLUETOOTH] ❌ Unexpected completion")
                            observer(.error(ZetaraManager.Error.writeControlDataError))
                    }
                }
                .disposed(by: disposeBag)

            // Build 46: Write AFTER observation is set up to catch fast responses
            self.protocolDataManager.logProtocolEvent("[BLUETOOTH] 📤 Now writing request...")
            peripheral.writeValue(data, for: writeCharacteristic, type: writeCharacteristic.writeType)
                .subscribe()
                .disposed(by: disposeBag)

            // Build 45: Cleanup this request's DisposeBag when Maybe completes or is disposed
            return Disposables.create { [weak self] in
                self?.controlDataDisposeBags.removeValue(forKey: requestId)
            }
        }
    }
}

extension Characteristic {
    var writeType: CBCharacteristicWriteType {
        if properties.contains(.write) {
            return .withResponse
        } else {
            return .withoutResponse
        }
    }
}

extension RxBluetoothKit2.ScannedPeripheral: Hashable {
    public static func == (lhs: RxBluetoothKit2.ScannedPeripheral, rhs: RxBluetoothKit2.ScannedPeripheral) -> Bool {
        return lhs.peripheral.identifier.uuidString == rhs.peripheral.identifier.uuidString
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.peripheral.identifier.uuidString)
    }
}
