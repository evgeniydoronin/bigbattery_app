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

    // MARK: - Protocol Data Cache
    // Кэш протоколов для избежания Bluetooth конфликтов между экранами
    // ПРОБЛЕМА (02.10.2025): Home и Settings одновременно загружали протоколы → timeout'ы при открытии Settings
    // РЕШЕНИЕ: Settings загружает через Bluetooth и кэширует здесь, Home только читает из кэша БЕЗ Bluetooth запросов
    public var cachedModuleIdData: Data.ModuleIdControlData?
    public var cachedCANData: Data.CANControlData?
    public var cachedRS485Data: Data.RS485ControlData?

    public static let shared = ZetaraManager()

    private override init() {
        super.init()
        
        // Тестовый лог для проверки ZetaraLogger интеграции
        ZetaraLogger.info("🚀 ZetaraManager initialized", details: ["testMessage": "ZetaraLogger integration working"])

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
        print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
        print("!!! МЕТОД setup() ВЫЗВАН !!!")
        print("!!! Конфигурация: \(configuration) !!!")
        if let mockData = configuration.mockData {
            print("!!! Мок-данные установлены: \(mockData.toHexString()) !!!")
            print("!!! Длина мок-данных: \([UInt8](mockData).count) байт !!!")
        } else {
            print("!!! Мок-данные НЕ установлены !!!")
        }
        
        if let mockDeviceName = configuration.mockDeviceName {
            print("!!! Мок-имя устройства установлено: \(mockDeviceName) !!!")
            shared.mockDeviceName = mockDeviceName
        } else {
            print("!!! Мок-имя устройства НЕ установлено !!!")
        }
        print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
        
        ZetaraManager.configuration = configuration
        
        // Если установлены мок-данные, запускаем обновление данных сразу
        if configuration.mockData != nil {
            print("!!! Запускаем обновление данных сразу, так как установлены мок-данные !!!")
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

        // 先释放之前的
        cleanConnection()

        let serviceUUIDs = ZetaraManager.configuration.identifiers.map { $0.service.uuid }

        self.connectionDisposable = peripheral.establishConnection()
            .flatMap { $0.discoverServices(serviceUUIDs) }
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
                        print("Connection failed with error: \(error.localizedDescription)")
                        observer.onError(error)
                    case .next(let characteristics):
                        if let identifier = Identifier.identifier(of: characteristics.first!),
                           let writeCharacteristic = characteristics[characteristicOf: identifier.writeCharacteristic],
                           let notifyCharacteristic = characteristics[characteristicOf: identifier.notifyCharacteristic]
                            {
                            self?.writeCharacteristic = writeCharacteristic
                            self?.notifyCharacteristic = notifyCharacteristic
                            self?.identifier = identifier

                            print("Peripheral connected successfully: \(peripheral.name ?? "")")

                            observer.onNext(peripheral)
                            self?.startRefreshBMSData()
                        } else {
                            // 一般不会走到这里
                            print("Not a Zetara peripheral: \(peripheral.name ?? "")")
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

        // В RxBluetoothKit отключение происходит через dispose() подписки
        // cleanConnection() уже делает это через connectionDisposable?.dispose()
        cleanConnection()

        // Очищаем данные BMS
        cleanData()

        // Очищаем сканированные устройства
        cleanScanning()

        print("Peripheral disconnected successfully")
    }

    func cleanData() {
        self.bmsDataSubject.onNext(Data.BMS())

        // Очищаем кэш протоколов при отключении устройства
        // Важно: при переподключении Settings загрузит свежие данные
        cachedModuleIdData = nil
        cachedCANData = nil
        cachedRS485Data = nil
    }

    func cleanScanning() {
        self.scannedPeripheralsSubject.onNext([])
        self.scanningDisposable?.dispose()
    }

    func cleanConnection() {
        connectionDisposable?.dispose()
        timer?.invalidate()
        timer = nil
        connectedPeripheralSubject.onNext(nil)
    }

    public func observeDisconect() -> Observable<Peripheral> {
        return manager.observeDisconnect()
            .flatMap { (peripheral, _) in Observable.of(peripheral) }
            .observeOn(MainScheduler.instance)
    }

    let bmsDataHandler = Data.BMSDataHandler()

    var timer: Timer?
    func startRefreshBMSData() {
        print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
        print("!!! МЕТОД startRefreshBMSData() ВЫЗВАН !!!")
        print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
        
        self.timer = Timer.scheduledTimer(withTimeInterval: Self.configuration.refreshBMSTimeInterval, repeats: true) { [weak self] _ in
            print("!!! ТАЙМЕР СРАБОТАЛ, ВЫЗЫВАЕМ getBMSData() !!!")
            self?.getBMSData()
                .subscribeOn(MainScheduler.instance)
                .subscribe(onSuccess: { [weak self] _data in
                    print("!!! ПОЛУЧЕНЫ ДАННЫЕ BMS: \(_data) !!!")
                    self?.bmsDataSubject.asObserver().onNext(_data)
                }, onError: { error in
                    print("!!! ОШИБКА ПРИ ПОЛУЧЕНИИ ДАННЫХ BMS: \(error) !!!")
                }, onCompleted: {
                    print("!!! ПОЛУЧЕНИЕ ДАННЫХ BMS ЗАВЕРШЕНО !!!")
                }).disposed(by: self!.disposeBag)
        }
        self.timer?.fire()
        print("!!! ТАЙМЕР ЗАПУЩЕН !!!")
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
        
        // Проверяем наличие подключенного устройства
        let isDeviceConnected = (try? connectedPeripheralSubject.value()) != nil &&
                                writeCharacteristic != nil &&
                                notifyCharacteristic != nil
        
        // Используем мок-данные только если нет подключенного устройства
        if !isDeviceConnected, let mockBMSData = Self.configuration.mockData {
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
            print("!!! ОШИБКА: Нет подключенного устройства !!!")
            // 清理连接状态
            cleanConnection()
            return Maybe.error(ZetaraManager.Error.connectionError)
        }
        
        print("!!! Используем реальные данные от подключенного устройства !!!")

        getBMSDataDisposeBag = nil
        getBMSDataDisposeBag = DisposeBag()

        let data = Foundation.Data.getBMSData
        print("getting bms data write data: \(data.toHexString())")
        peripheral.writeValue(data, for: writeCharacteristic, type: writeCharacteristic.writeType)
            .subscribe()
            .disposed(by: getBMSDataDisposeBag!)

        return Maybe.create { observer in
            peripheral.observeValueUpdateAndSetNotification(for: notifyCharacteristic)
                .compactMap { $0.value }
                .do { print("recevie bms data: \($0.toHexString())") }
                .map { [UInt8]($0) }
                .filter { $0.crc16Verify() && Data.BMS.isBMSData($0) }
                .compactMap { [weak self] _bytes in
                    return self?.bmsDataHandler.append(_bytes)
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
        let startTime = Date()
        let deviceConnected = (try? connectedPeripheralSubject.value()) != nil
        let deviceName = getDeviceName()

        ZetaraLogger.info("📡 getModuleId() called", details: [
            "deviceConnected": deviceConnected,
            "deviceName": deviceName,
            "timestamp": startTime.timeIntervalSince1970
        ])

        // Если устройство не подключено, но есть Mock данные, возвращаем Mock Module ID
        if !deviceConnected && Self.configuration.mockData != nil {
            print("!!! Возвращаем Mock Module ID !!!")
            ZetaraLogger.info("🎭 Returning Mock Module ID data (device not connected)", details: ["mockDataEnabled": true, "mockModuleId": 1])

            // Создаем Mock данные для Module ID = 1 (включает протоколы)
            let mockBytes: [UInt8] = [0x10, 0x02, 0x00, 0x01] // Module ID = 1
            if let mockData = Data.ModuleIdControlData(mockBytes) {
                return Maybe.just(mockData)
            }
        }

        ZetaraLogger.info("📤 Sending Module ID command to real device", details: [
            "command": "getModuleId",
            "commandByte": "0x02",
            "deviceName": deviceName
        ])

        return writeControlData(.getModuleId)
            .do(onNext: { rawData in
                let hexString = rawData.map { String(format: "%02X", $0) }.joined(separator: " ")
                let duration = Date().timeIntervalSince(startTime) * 1000

                ZetaraLogger.debug("📥 Module ID raw response received", details: [
                    "rawBytes": hexString,
                    "bytesCount": rawData.count,
                    "durationMs": duration,
                    "firstByte": String(format: "0x%02X", rawData.first ?? 0)
                ])
            })
            .compactMap { rawData in
                let parsedData = Data.ModuleIdControlData(rawData)
                let duration = Date().timeIntervalSince(startTime) * 1000

                if let data = parsedData {
                    ZetaraLogger.info(
"[PROTOCOL_DEBUG] ✅ Module ID data parsed successfully",
                        details: [
                            "moduleId": data.moduleId,
                            "readableId": data.readableId(),
                            "otherProtocolsEnabled": data.otherProtocolsEnabled(),
                            "totalDurationMs": duration
                        ]
                    )
                } else {
                    ZetaraLogger.error(
"[PROTOCOL_DEBUG] ❌ Failed to parse Module ID response",
                        details: [
                            "rawBytes": rawData.map { String(format: "%02X", $0) }.joined(separator: " "),
                            "bytesCount": rawData.count,
                            "totalDurationMs": duration
                        ]
                    )
                }

                return parsedData
            }
            .do(onError: { error in
                let duration = Date().timeIntervalSince(startTime) * 1000

                ZetaraLogger.error(
"[PROTOCOL_DEBUG] 💥 Module ID request failed",
                    details: [
                        "error": error.localizedDescription,
                        "errorType": String(describing: type(of: error)),
                        "totalDurationMs": duration
                    ]
                )
            })
    }

    public func setModuleId(_ number: Int) -> Maybe<Bool> {
        let data = [0x10, 0x07, 0x01, UInt8(number)]
        let hexString = data.crc16().toHexString()
        return writeControlData(.init(hex: hexString)).compactMap { Data.ResponseData($0)?.success ?? false }
    }

    public func getRS485() -> Maybe<Data.RS485ControlData> {
        let startTime = Date()
        let deviceConnected = (try? connectedPeripheralSubject.value()) != nil
        let deviceName = getDeviceName()

        ZetaraLogger.info(
            "[PROTOCOL_DEBUG] 📡 getRS485() called",
            details: [
                "deviceConnected": deviceConnected,
                "deviceName": deviceName,
                "timestamp": startTime.timeIntervalSince1970
            ]
        )

        // Если устройство не подключено, но есть Mock данные, возвращаем Mock RS485
        if !deviceConnected && Self.configuration.mockData != nil {
            print("!!! Возвращаем Mock RS485 !!!")
            ZetaraLogger.info(
"[PROTOCOL_DEBUG] 🎭 Returning Mock RS485 data (device not connected)",
                details: ["mockDataEnabled": true]
            )

            // Создаем Mock данные для RS485 с несколькими протоколами
            // Формат: [command, subcommand, 0x00, selectedIndex, protocolCount, protocol1_length, protocol1_bytes, protocol2_length, protocol2_bytes, ...]
            let p02lux = "P02-LUX".data(using: .ascii)!.map { $0 }
            let p01lux = "P01-LUX".data(using: .ascii)!.map { $0 }
            let p06lux = "P06-LUX".data(using: .ascii)!.map { $0 }

            var mockBytes: [UInt8] = [0x10, 0x03, 0x00, 0x00, 0x03] // selectedIndex=0, protocolCount=3
            // Добавляем протоколы
            mockBytes.append(UInt8(p02lux.count))
            mockBytes.append(contentsOf: p02lux)
            mockBytes.append(UInt8(p01lux.count))
            mockBytes.append(contentsOf: p01lux)
            mockBytes.append(UInt8(p06lux.count))
            mockBytes.append(contentsOf: p06lux)

            if let mockData = Data.RS485ControlData(mockBytes) {
                return Maybe.just(mockData)
            }
        }

        ZetaraLogger.info(
            "[PROTOCOL_DEBUG] 📤 Sending RS485 command to real device",
            details: [
                "command": "getRS485",
                "commandByte": "0x06",
                "deviceName": deviceName
            ]
        )

        return writeControlData(.getRS485)
            .do(onNext: { rawData in
                let hexString = rawData.map { String(format: "%02X", $0) }.joined(separator: " ")
                let duration = Date().timeIntervalSince(startTime) * 1000 // в миллисекундах

                ZetaraLogger.debug(
"[PROTOCOL_DEBUG] 📥 RS485 raw response received",
                    details: [
                        "rawBytes": hexString,
                        "bytesCount": rawData.count,
                        "durationMs": duration,
                        "firstByte": String(format: "0x%02X", rawData.first ?? 0)
                    ]
                )
            })
            .compactMap { rawData in
                let parsedData = Data.RS485ControlData(rawData)
                let duration = Date().timeIntervalSince(startTime) * 1000

                if let data = parsedData {
                    ZetaraLogger.info(
"[PROTOCOL_DEBUG] ✅ RS485 data parsed successfully",
                        details: [
                            "selectedIndex": data.selectedIndex,
                            "protocolsCount": data.protocols.count,
                            "selectedProtocol": data.readableProtocol(),
                            "allProtocols": data.readableProtocols(),
                            "totalDurationMs": duration
                        ]
                    )
                } else {
                    ZetaraLogger.error(
"[PROTOCOL_DEBUG] ❌ Failed to parse RS485 response",
                        details: [
                            "rawBytes": rawData.map { String(format: "%02X", $0) }.joined(separator: " "),
                            "bytesCount": rawData.count,
                            "totalDurationMs": duration
                        ]
                    )
                }

                return parsedData
            }
            .do(onError: { error in
                let duration = Date().timeIntervalSince(startTime) * 1000
                let isTimeout = error is RxError && error.localizedDescription.contains("timeout")

                ZetaraLogger.error(
"[PROTOCOL_DEBUG] 💥 RS485 request failed",
                    details: [
                        "error": error.localizedDescription,
                        "errorType": String(describing: type(of: error)),
                        "totalDurationMs": duration,
                        "isTimeout": isTimeout,
                        "deviceName": deviceName,
                        "possibleCauses": isTimeout ? "Device not responding, Bluetooth interference, Device in bad state" : "Unknown"
                    ]
                )
            })
    }

    public func setRS485(_ number: Int) -> Maybe<Bool> {
        let data = [0x10, 0x05, 0x01, UInt8(number)].crc16().toHexString()
        return writeControlData(.init(hex: data)).compactMap { Data.ResponseData($0)?.success ?? false }
    }

    public func getCAN() -> Maybe<Data.CANControlData> {
        let startTime = Date()
        let deviceConnected = (try? connectedPeripheralSubject.value()) != nil
        let deviceName = getDeviceName()

        ZetaraLogger.info(
            "[PROTOCOL_DEBUG] 📡 getCAN() called",
            details: [
                "deviceConnected": deviceConnected,
                "deviceName": deviceName,
                "timestamp": startTime.timeIntervalSince1970
            ]
        )

        // Если устройство не подключено, но есть Mock данные, возвращаем Mock CAN
        if !deviceConnected && Self.configuration.mockData != nil {
            print("!!! Возвращаем Mock CAN !!!")
            ZetaraLogger.info(
"[PROTOCOL_DEBUG] 🎭 Returning Mock CAN data (device not connected)",
                details: ["mockDataEnabled": true]
            )

            // Создаем Mock данные для CAN с несколькими протоколами
            let p06lux = "P06-LUX".data(using: .ascii)!.map { $0 }
            let p01lux = "P01-LUX".data(using: .ascii)!.map { $0 }
            let p02lux = "P02-LUX".data(using: .ascii)!.map { $0 }

            var mockBytes: [UInt8] = [0x10, 0x04, 0x00, 0x01, 0x03] // selectedIndex=1, protocolCount=3
            // Добавляем протоколы
            mockBytes.append(UInt8(p06lux.count))
            mockBytes.append(contentsOf: p06lux)
            mockBytes.append(UInt8(p01lux.count))
            mockBytes.append(contentsOf: p01lux)
            mockBytes.append(UInt8(p02lux.count))
            mockBytes.append(contentsOf: p02lux)

            if let mockData = Data.CANControlData(mockBytes) {
                return Maybe.just(mockData)
            }
        }

        ZetaraLogger.info(
            "[PROTOCOL_DEBUG] 📤 Sending CAN command to real device",
            details: [
                "command": "getCAN",
                "commandByte": "0x04",
                "deviceName": deviceName
            ]
        )

        return writeControlData(.getCAN)
            .do(onNext: { rawData in
                let hexString = rawData.map { String(format: "%02X", $0) }.joined(separator: " ")
                let duration = Date().timeIntervalSince(startTime) * 1000 // в миллисекундах

                ZetaraLogger.debug(
"[PROTOCOL_DEBUG] 📥 CAN raw response received",
                    details: [
                        "rawBytes": hexString,
                        "bytesCount": rawData.count,
                        "durationMs": duration,
                        "firstByte": String(format: "0x%02X", rawData.first ?? 0)
                    ]
                )
            })
            .compactMap { rawData in
                let parsedData = Data.CANControlData(rawData)
                let duration = Date().timeIntervalSince(startTime) * 1000

                if let data = parsedData {
                    ZetaraLogger.info(
"[PROTOCOL_DEBUG] ✅ CAN data parsed successfully",
                        details: [
                            "selectedIndex": data.selectedIndex,
                            "protocolsCount": data.protocols.count,
                            "selectedProtocol": data.readableProtocol(),
                            "allProtocols": data.readableProtocols(),
                            "totalDurationMs": duration
                        ]
                    )
                } else {
                    ZetaraLogger.error(
"[PROTOCOL_DEBUG] ❌ Failed to parse CAN response",
                        details: [
                            "rawBytes": rawData.map { String(format: "%02X", $0) }.joined(separator: " "),
                            "bytesCount": rawData.count,
                            "totalDurationMs": duration
                        ]
                    )
                }

                return parsedData
            }
            .do(onError: { error in
                let duration = Date().timeIntervalSince(startTime) * 1000
                let isTimeout = error is RxError && error.localizedDescription.contains("timeout")

                ZetaraLogger.error(
"[PROTOCOL_DEBUG] 💥 CAN request failed",
                    details: [
                        "error": error.localizedDescription,
                        "errorType": String(describing: type(of: error)),
                        "totalDurationMs": duration,
                        "isTimeout": isTimeout,
                        "deviceName": deviceName,
                        "possibleCauses": isTimeout ? "Device not responding, Bluetooth interference, Device in bad state" : "Unknown"
                    ]
                )
            })
    }

    public func setCAN(_ number: Int) -> Maybe<Bool> {
        let data = [0x10, 0x06, 0x01, UInt8(number)].crc16().toHexString()
        return writeControlData(.init(hex: data)).compactMap { Data.ResponseData($0)?.success ?? false }
    }

    var moduleIdDisposeBag: DisposeBag?
    func writeControlData(_ data: Foundation.Data) -> Maybe<[UInt8]> {
        let startTime = Date()
        let hexCommand = data.toHexString()

        ZetaraLogger.debug(
            "[PROTOCOL_DEBUG] 🔄 writeControlData() started",
            details: [
                "commandHex": hexCommand,
                "commandBytes": data.map { String(format: "0x%02X", $0) }.joined(separator: " "),
                "dataLength": data.count,
                "timestamp": startTime.timeIntervalSince1970
            ]
        )

        guard let peripheral = try? connectedPeripheralSubject.value(),
              let writeCharacteristic = writeCharacteristic,
              let notifyCharacteristic = notifyCharacteristic else {
            print("send data error. no connected peripheral")

            ZetaraLogger.error(
"[PROTOCOL_DEBUG] ❌ writeControlData failed - no peripheral or characteristics",
                details: [
                    "commandHex": hexCommand,
                    "hasPeripheral": (try? connectedPeripheralSubject.value()) != nil,
                    "hasWriteChar": writeCharacteristic != nil,
                    "hasNotifyChar": notifyCharacteristic != nil
                ]
            )

            cleanConnection()
            return Maybe.error(Error.writeControlDataError)
        }

        ZetaraLogger.debug(
            "[PROTOCOL_DEBUG] 📡 Bluetooth characteristics ready",
            details: [
                "peripheralName": peripheral.name ?? "Unknown",
                "writeCharUUID": writeCharacteristic.uuid.uuidString,
                "notifyCharUUID": notifyCharacteristic.uuid.uuidString,
                "writeType": writeCharacteristic.writeType == .withResponse ? "withResponse" : "withoutResponse"
            ]
        )

        self.moduleIdDisposeBag = nil
        self.moduleIdDisposeBag = DisposeBag()

        print("write control data: \(data.toHexString())")

        ZetaraLogger.debug(
            "[PROTOCOL_DEBUG] 📤 Sending command via Bluetooth",
            details: [
                "commandHex": hexCommand,
                "peripheralName": peripheral.name ?? "Unknown",
                "writingToCharacteristic": writeCharacteristic.uuid.uuidString
            ]
        )

        peripheral.writeValue(data, for: writeCharacteristic, type: writeCharacteristic.writeType)
            .subscribe()
            // ИСПРАВЛЕНИЕ КРАША (02.10.2025): убран force unwrap чтобы избежать краша когда DisposeBag nil
            .disposed(by: self.moduleIdDisposeBag ?? DisposeBag())

        return Maybe.create { observer in
            ZetaraLogger.debug(
"[PROTOCOL_DEBUG] 👂 Listening for Bluetooth response",
                details: [
                    "commandHex": hexCommand,
                    "listeningOnCharacteristic": notifyCharacteristic.uuid.uuidString
                ]
            )

            peripheral.observeValueUpdateAndSetNotification(for: notifyCharacteristic)
                .compactMap { $0.value }
                .map { [UInt8]($0) }
                .filter { Data.isControlData($0) }
                .timeout(.seconds(10), scheduler: MainScheduler.instance)
                .do(onNext: { responseData in
                    let duration = Date().timeIntervalSince(startTime) * 1000
                    let hexResponse = responseData.toHexString()

                    print("receive control data: \(hexResponse)")

                    ZetaraLogger.debug(
"[PROTOCOL_DEBUG] 📥 Bluetooth response received",
                        details: [
                            "responseHex": hexResponse,
                            "responseBytes": responseData.map { String(format: "0x%02X", $0) }.joined(separator: " "),
                            "responseLength": responseData.count,
                            "durationMs": duration,
                            "isControlData": Data.isControlData(responseData),
                            "matchingCommand": hexCommand
                        ]
                    )
                })
                .observeOn(MainScheduler.instance)
                .subscribeOn(MainScheduler.instance)
                .subscribe(onNext: { _data in
                    let totalDuration = Date().timeIntervalSince(startTime) * 1000

                    ZetaraLogger.info(
"[PROTOCOL_DEBUG] ✅ writeControlData completed successfully",
                        details: [
                            "commandHex": hexCommand,
                            "responseHex": _data.toHexString(),
                            "totalDurationMs": totalDuration,
                            "success": true
                        ]
                    )

                    observer(.success(_data))
                }, onError: { error in
                    let totalDuration = Date().timeIntervalSince(startTime) * 1000
                    let isTimeout = error is RxError && error.localizedDescription.contains("timeout")

                    ZetaraLogger.error(
"[PROTOCOL_DEBUG] 💥 writeControlData failed with error",
                        details: [
                            "commandHex": hexCommand,
                            "totalDurationMs": totalDuration,
                            "errorType": String(describing: type(of: error)),
                            "errorDescription": error.localizedDescription,
                            "isTimeout": isTimeout
                        ]
                    )

                    observer(.error(error))
                })
                // ИСПРАВЛЕНИЕ КРАША (02.10.2025): убран force unwrap чтобы избежать краша когда DisposeBag nil
                .disposed(by: self.moduleIdDisposeBag ?? DisposeBag())

            return Disposables.create { [weak self] in
                self?.moduleIdDisposeBag = nil
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
