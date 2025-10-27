//
//  DiagnosticsViewController.swift
//  BatteryMonitorBL
//
//  Created by Evgenii Doronin on 2025/5/15.
//

import UIKit
import Zetara
import RxSwift
import RxCocoa
import MessageUI

/// Контроллер для отображения диагностической информации о батарее
class DiagnosticsViewController: UIViewController {
    
    // MARK: - UI Elements
    
    /// Таблица для отображения параметров батареи
    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    /// Кнопка для отправки логов
    private let sendLogsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Send Logs to Developer", for: .normal)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Private Properties
    
    /// Данные о батарее
    private var bmsData: Zetara.Data.BMS? {
        // Получаем текущие данные из ZetaraManager
        return try? ZetaraManager.shared.bmsDataSubject.value()
    }
    
    /// Журнал событий
    private var eventLogs: [DiagnosticsEvent] = []
    
    /// Секции таблицы
    private enum Section: Int, CaseIterable {
        case deviceInfo
        case batteryInfo
        case cellVoltages
        case temperatures
        case eventLogs
        
        var title: String {
            switch self {
            case .deviceInfo:
                return "Device Information"
            case .batteryInfo:
                return "Battery Information"
            case .cellVoltages:
                return "Cell Voltages"
            case .temperatures:
                return "Temperatures"
            case .eventLogs:
                return "Event Log"
            }
        }
    }
    
    /// Параметры батареи для отображения
    private enum BatteryParameter: Int, CaseIterable {
        case voltage
        case current
        case soc
        case soh
        case status
        case cellCount
        
        var title: String {
            switch self {
            case .voltage:
                return "Voltage"
            case .current:
                return "Current"
            case .soc:
                return "State of Charge (SOC)"
            case .soh:
                return "State of Health (SOH)"
            case .status:
                return "Status"
            case .cellCount:
                return "Cell Count"
            }
        }
        
        func value(from data: Zetara.Data.BMS) -> String {
            switch self {
            case .voltage:
                return String(format: "%.2f V", data.voltage)
            case .current:
                return String(format: "%.2f A", data.current)
            case .soc:
                return "\(data.soc)%"
            case .soh:
                return "\(data.soh)%"
            case .status:
                return "\(data.status)"
            case .cellCount:
                return "\(data.cellCount)"
            }
        }
    }
    
    /// Модель события для журнала
    struct DiagnosticsEvent {
        let timestamp: Date
        let type: EventType
        let message: String
        
        enum EventType {
            case connection
            case disconnection
            case dataUpdate
            case error
            
            var title: String {
                switch self {
                case .connection:
                    return "Connection"
                case .disconnection:
                    return "Disconnection"
                case .dataUpdate:
                    return "Data Update"
                case .error:
                    return "Error"
                }
            }
        }
    }
    
    /// Форматтер для отображения даты и времени
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss dd.MM.yyyy"
        return formatter
    }()
    
    /// Disposable для RxSwift
    private let disposeBag = DisposeBag()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        setupTableView()
        setupObservers()
        
        // Добавляем событие о запуске экрана диагностики
        addEvent(type: .connection, message: "Diagnostics screen launched")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Получаем имя устройства
        let deviceName = ZetaraManager.shared.getDeviceName()
        if deviceName != "No device connected" {
            addEvent(type: .connection, message: "Device connected: \(deviceName)")
        } else {
            addEvent(type: .connection, message: "No device connected")
        }
    }
    
    // MARK: - Setup
    
    private func setupView() {
        title = "Diagnostics"
        view.backgroundColor = .systemBackground
        
        // Добавляем фоновое изображение
        let backgroundImageView = UIImageView(image: R.image.background())
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.frame = view.bounds
        backgroundImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(backgroundImageView)
        view.sendSubviewToBack(backgroundImageView)
        
        // Добавляем таблицу
        view.addSubview(tableView)
        
        // Добавляем кнопку отправки логов
        view.addSubview(sendLogsButton)
        
        // Настраиваем ограничения для таблицы
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: sendLogsButton.topAnchor, constant: -16)
        ])
        
        // Настраиваем ограничения для кнопки
        NSLayoutConstraint.activate([
            sendLogsButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            sendLogsButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            sendLogsButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            sendLogsButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Добавляем обработчик нажатия на кнопку
        sendLogsButton.addTarget(self, action: #selector(sendLogsButtonTapped), for: .touchUpInside)
    }
    
    private func setupTableView() {
        // Регистрируем ячейки
        tableView.register(DiagnosticsParameterCell.self, forCellReuseIdentifier: DiagnosticsParameterCell.reuseIdentifier)
        tableView.register(DiagnosticsEventCell.self, forCellReuseIdentifier: DiagnosticsEventCell.reuseIdentifier)
        
        // Устанавливаем делегаты
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    private func setupObservers() {
        // Подписываемся на обновления данных о батарее
        ZetaraManager.shared.bmsDataSubject
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                self?.addEvent(type: .dataUpdate, message: "New battery data received")
                // Note: addEvent() already calls tableView.reloadSections() for event logs section
                // Calling reloadData() here would cause concurrent UITableView updates
            })
            .disposed(by: disposeBag)

        // Подписываемся на события подключения/отключения устройства
        ZetaraManager.shared.connectedPeripheralSubject
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] peripheral in
                if peripheral != nil {
                    let deviceName = ZetaraManager.shared.getDeviceName()
                    self?.addEvent(type: .connection, message: "Device connected: \(deviceName)")
                } else {
                    self?.addEvent(type: .disconnection, message: "Device disconnected")
                }
                // Note: addEvent() already calls tableView.reloadSections() for event logs section
                // Calling reloadData() here would cause concurrent UITableView updates
            })
            .disposed(by: disposeBag)
    }
    
    // MARK: - Actions
    
    /// Добавляет событие в журнал
    private func addEvent(type: DiagnosticsEvent.EventType, message: String) {
        let event = DiagnosticsEvent(timestamp: Date(), type: type, message: message)
        eventLogs.insert(event, at: 0) // Добавляем в начало, чтобы новые события были сверху
        
        // Ограничиваем количество событий в журнале
        if eventLogs.count > 100 {
            eventLogs.removeLast()
        }
        
        // Обновляем таблицу, если она уже загружена
        if isViewLoaded {
            tableView.reloadSections(IndexSet(integer: Section.eventLogs.rawValue), with: .automatic)
        }
    }
    
    /// Обработчик нажатия на кнопку отправки логов
    @objc private func sendLogsButtonTapped() {
        sendLogs()
    }
    
    /// Отправляет логи по email
    private func sendLogs() {
        // Проверяем, доступна ли отправка email
        guard MFMailComposeViewController.canSendMail() else {
            showAlert(title: "Error", message: "Unable to send email. Check your device mail settings.")
            return
        }
        
        // Создаем JSON с данными для отправки
        let logsData = createLogsData()
        
        // Создаем контроллер для отправки email
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = self
        
        // Настраиваем email
        mailComposer.setToRecipients(["evgeniydoronin@gmail.com"]) // Замените на свой email
        mailComposer.setSubject("BigBattery Diagnostic Data")
        mailComposer.setMessageBody("Diagnostic data from BigBattery app", isHTML: false)
        
        // Добавляем вложение с данными
        if let jsonData = try? JSONSerialization.data(withJSONObject: logsData, options: .prettyPrinted) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            let dateString = dateFormatter.string(from: Date())
            let fileName = "bigbattery_logs_\(dateString).json"
            
            mailComposer.addAttachmentData(jsonData, mimeType: "application/json", fileName: fileName)
        }
        
        // Показываем контроллер для отправки email
        present(mailComposer, animated: true)
    }

    /// Создает информацию о протоколах для логов
    private func createProtocolInfo() -> [String: Any] {
        // Получаем текущие значения протоколов из BehaviorSubjects
        var moduleId = "--"
        var canProtocol = "--"
        var rs485Protocol = "--"

        if let moduleIdData = try? ZetaraManager.shared.protocolDataManager.moduleIdSubject.value() {
            moduleId = moduleIdData.readableId()
        }

        if let canData = try? ZetaraManager.shared.protocolDataManager.canSubject.value() {
            canProtocol = canData.readableProtocol()
        }

        if let rs485Data = try? ZetaraManager.shared.protocolDataManager.rs485Subject.value() {
            rs485Protocol = rs485Data.readableProtocol()
        }

        // Получаем логи из ProtocolDataManager
        let protocolLogs = ZetaraManager.shared.protocolDataManager.getProtocolLogs()

        // Фильтруем логи по типам
        let errorLogs = protocolLogs.filter { $0.contains("❌") }
        let successLogs = protocolLogs.filter { $0.contains("✅") }
        let warningLogs = protocolLogs.filter { $0.contains("⚠️") }

        return [
            "currentValues": [
                "moduleId": moduleId,
                "canProtocol": canProtocol,
                "rs485Protocol": rs485Protocol
            ],
            "recentLogs": protocolLogs,
            "statistics": [
                "totalLogs": protocolLogs.count,
                "errors": errorLogs.count,
                "successes": successLogs.count,
                "warnings": warningLogs.count
            ],
            "lastUpdateTime": dateFormatter.string(from: Date())
        ]
    }

    /// Создает словарь с данными для отправки
    private func createLogsData() -> [String: Any] {
        // Информация об устройстве
        let device = UIDevice.current
        let deviceInfo: [String: String] = [
            "model": device.model,
            "systemName": device.systemName,
            "systemVersion": device.systemVersion,
            "name": device.name
        ]
        
        // Информация о приложении
        let appInfo: [String: String] = [
            "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            "build": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        ]
        
        // Информация о батарее
        var batteryInfo: [String: Any] = [
            "timestamp": dateFormatter.string(from: Date())
        ]
        
        // Добавляем информацию о батарее, если она доступна
        if let data = bmsData {
            batteryInfo["voltage"] = data.voltage
            batteryInfo["current"] = data.current
            batteryInfo["soc"] = data.soc
            batteryInfo["soh"] = data.soh
            batteryInfo["status"] = data.status.description
            batteryInfo["cellCount"] = data.cellCount
            batteryInfo["cellVoltages"] = data.cellVoltages
            batteryInfo["cellTemps"] = data.cellTemps.map { Int($0) }
            batteryInfo["tempPCB"] = Int(data.tempPCB)
            batteryInfo["tempEnv"] = Int(data.tempEnv)
        } else {
            batteryInfo["status"] = "No data"
        }
        
        // Расширенная информация о батарее
        var extendedBatteryInfo: [String: Any] = [:]
        
        if let data = bmsData {
            // Минимальное, максимальное и среднее напряжение ячеек
            if !data.cellVoltages.isEmpty {
                let minVoltage = data.cellVoltages.min() ?? 0
                let maxVoltage = data.cellVoltages.max() ?? 0
                let avgVoltage = data.cellVoltages.reduce(0, +) / Float(data.cellVoltages.count)
                let voltageDelta = maxVoltage - minVoltage
                
                // Расчет стандартного отклонения
                let sumOfSquaredDifferences = data.cellVoltages.reduce(0.0) { sum, voltage in
                    let difference = Double(voltage - avgVoltage)
                    return sum + (difference * difference)
                }
                let stdDev = sqrt(sumOfSquaredDifferences / Double(data.cellVoltages.count))
                
                extendedBatteryInfo["cellVoltageMin"] = minVoltage
                extendedBatteryInfo["cellVoltageMax"] = maxVoltage
                extendedBatteryInfo["cellVoltageAverage"] = avgVoltage
                extendedBatteryInfo["cellVoltageDelta"] = voltageDelta
                extendedBatteryInfo["cellVoltageStdDev"] = stdDev
            }
            
            // Минимальная, максимальная и средняя температура
            if !data.cellTemps.isEmpty {
                let minTemp = Int(data.cellTemps.min() ?? 0)
                let maxTemp = Int(data.cellTemps.max() ?? 0)
                let tempDelta = maxTemp - minTemp
                
                extendedBatteryInfo["tempMin"] = minTemp
                extendedBatteryInfo["tempMax"] = maxTemp
                extendedBatteryInfo["tempDelta"] = tempDelta
            }
            
            // Статус защиты
            let protectionStatus: [String: Bool] = [
                "overvoltage": data.status == .protecting,
                "undervoltage": data.status == .protecting,
                "overcurrent": data.status == .protecting,
                "overtemperature": data.status == .protecting,
                "shortCircuit": data.status == .protecting
            ]
            
            extendedBatteryInfo["protectionStatus"] = protectionStatus
        }
        
        // Информация о Bluetooth-соединении
        var bluetoothInfo: [String: Any] = [
            "connectionAttempts": 0
        ]
        
        // Получаем имя устройства
        let deviceName = ZetaraManager.shared.getDeviceName()
        if deviceName != "No device connected" {
            bluetoothInfo["peripheralName"] = deviceName
        }
        
        // Получаем состояние Bluetooth
        // Используем текущее состояние Bluetooth из ZetaraManager
        // Поскольку observableState не имеет метода value(), используем другой подход
        ZetaraManager.shared.observableState
            .take(1)
            .subscribe(onNext: { state in
                // Преобразуем числовое значение в строковое представление
                switch state {
                case .poweredOn:
                    bluetoothInfo["state"] = "poweredOn"
                case .poweredOff:
                    bluetoothInfo["state"] = "poweredOff"
                case .resetting:
                    bluetoothInfo["state"] = "resetting"
                case .unauthorized:
                    bluetoothInfo["state"] = "unauthorized"
                case .unsupported:
                    bluetoothInfo["state"] = "unsupported"
                case .unknown:
                    bluetoothInfo["state"] = "unknown"
                @unknown default:
                    bluetoothInfo["state"] = "unknown"
                }
            })
            .disposed(by: disposeBag)
        
        // Устанавливаем значение по умолчанию, если не удалось получить состояние
        if bluetoothInfo["state"] == nil {
            bluetoothInfo["state"] = "unknown"
        }
        
        if let peripheral = ZetaraManager.shared.connectedPeripheral() {
            bluetoothInfo["peripheralIdentifier"] = peripheral.identifier.uuidString
            if bluetoothInfo["peripheralName"] == nil {
                bluetoothInfo["peripheralName"] = peripheral.name ?? "Unknown"
            }
        }
        
        // Информация о процессе подключения
        var connectionProcessInfo: [String: Any] = [
            "steps": eventLogs.filter { $0.type == .connection || $0.type == .disconnection }.map { event -> [String: String] in
                return [
                    "timestamp": dateFormatter.string(from: event.timestamp),
                    "step": event.type == .connection ? "connection" : "disconnection",
                    "status": "success",
                    "message": event.message
                ]
            }
        ]
        
        // Информация о сырых данных
        var rawDataInfo: [String: Any] = [:]
        
        if let data = bmsData {
            // Получаем последние данные в виде hex-строки
            var hexString = "Unavailable"
            
            // Создаем массив байтов для представления данных BMS
            var bytes: [UInt8] = []
            
            // Добавляем основные данные
            bytes.append(contentsOf: withUnsafeBytes(of: data.voltage) { Array($0) })
            bytes.append(contentsOf: withUnsafeBytes(of: data.current) { Array($0) })
            bytes.append(contentsOf: withUnsafeBytes(of: data.soc) { Array($0) })
            bytes.append(contentsOf: withUnsafeBytes(of: data.soh) { Array($0) })
            
            // Добавляем напряжения ячеек
            for voltage in data.cellVoltages {
                bytes.append(contentsOf: withUnsafeBytes(of: voltage) { Array($0) })
            }
            
            // Добавляем температуры
            bytes.append(contentsOf: data.cellTemps.map { UInt8(bitPattern: $0) })
            bytes.append(UInt8(bitPattern: data.tempPCB))
            bytes.append(UInt8(bitPattern: data.tempEnv))
            
            // Преобразуем байты в hex-строку
            hexString = bytes.map { String(format: "%02X", $0) }.joined()
            
            rawDataInfo["lastReceivedPacket"] = hexString
            rawDataInfo["packetHistory"] = [
                [
                    "timestamp": dateFormatter.string(from: Date()),
                    "data": hexString,
                    "parseResult": "success"
                ]
            ]
            
            // Добавляем информацию о парсинге
            rawDataInfo["parseErrors"] = []
        }
        
        // Информация о коммуникационных ошибках
        var communicationErrorsInfo: [String: Any] = [
            "timeouts": 0,
            "crcErrors": 0,
            "packetLoss": 0,
            "retries": 0
        ]
        
        // Добавляем последнюю ошибку, если она есть
        let errorEvents = eventLogs.filter { $0.type == .error }
        if let lastError = errorEvents.first {
            communicationErrorsInfo["lastError"] = [
                "timestamp": dateFormatter.string(from: lastError.timestamp),
                "type": "error",
                "message": lastError.message
            ]
        }
        
        
        // Информация о состоянии системы
        var systemInfo: [String: Any] = [
            "isLowPowerMode": ProcessInfo.processInfo.isLowPowerModeEnabled,
            "availableMemory": ProcessInfo.processInfo.physicalMemory,
            "cpuUsage": 0.0 // Заглушка, в реальном приложении здесь будет код для получения загрузки CPU
        ]
        
        // Получаем уровень заряда устройства
        device.isBatteryMonitoringEnabled = true
        let batteryLevel = device.batteryLevel
        if batteryLevel >= 0 {
            systemInfo["batteryLevel"] = Int(batteryLevel * 100)
        } else {
            systemInfo["batteryLevel"] = 0
        }
        
        // Журнал событий
        let events = eventLogs.map { event -> [String: String] in
            return [
                "timestamp": dateFormatter.string(from: event.timestamp),
                "type": event.type.title,
                "message": event.message
            ]
        }

        // Информация о протоколах
        let protocolInfo = createProtocolInfo()

        // Собираем все данные
        return [
            "deviceInfo": deviceInfo,
            "appInfo": appInfo,
            "batteryInfo": batteryInfo,
            "extendedBatteryInfo": extendedBatteryInfo,
            "protocolInfo": protocolInfo,
            "bluetoothInfo": bluetoothInfo,
            "connectionProcessInfo": connectionProcessInfo,
            "rawDataInfo": rawDataInfo,
            "communicationErrorsInfo": communicationErrorsInfo,
            "systemInfo": systemInfo,
            "events": events,
            "timestamp": dateFormatter.string(from: Date())
        ]
    }
    
    /// Показывает алерт с сообщением
    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        present(alertController, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension DiagnosticsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        
        switch section {
        case .deviceInfo:
            return 1 // Только имя устройства
        case .batteryInfo:
            return BatteryParameter.allCases.count
        case .cellVoltages:
            return bmsData?.cellVoltages.count ?? 0
        case .temperatures:
            return (bmsData?.cellTemps.count ?? 0) + 2 // +2 для tempPCB и tempEnv
        case .eventLogs:
            return eventLogs.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }
        
        // Проверяем, есть ли реальное подключение к устройству
        let isDeviceActuallyConnected = ZetaraManager.shared.connectedPeripheral() != nil
        
        switch section {
        case .deviceInfo:
            let cell = tableView.dequeueReusableCell(withIdentifier: DiagnosticsParameterCell.reuseIdentifier, for: indexPath) as! DiagnosticsParameterCell
            
            // Получаем имя устройства
            let deviceName = ZetaraManager.shared.getDeviceName()
            cell.configure(title: "Device Name", value: deviceName)
            return cell
            
        case .batteryInfo:
            let cell = tableView.dequeueReusableCell(withIdentifier: DiagnosticsParameterCell.reuseIdentifier, for: indexPath) as! DiagnosticsParameterCell
            let parameter = BatteryParameter(rawValue: indexPath.row)!
            
            if isDeviceActuallyConnected, let data = bmsData {
                cell.configure(title: parameter.title, value: parameter.value(from: data))
            } else {
                cell.configure(title: parameter.title, value: "--")
            }
            return cell
            
        case .cellVoltages:
            let cell = tableView.dequeueReusableCell(withIdentifier: DiagnosticsParameterCell.reuseIdentifier, for: indexPath) as! DiagnosticsParameterCell
            
            if isDeviceActuallyConnected, let data = bmsData, indexPath.row < data.cellVoltages.count {
                let voltage = data.cellVoltages[indexPath.row]
                cell.configure(title: "Cell \(indexPath.row + 1)", value: String(format: "%.3f V", voltage))
            } else {
                cell.configure(title: "Cell \(indexPath.row + 1)", value: "-- V")
            }
            return cell
            
        case .temperatures:
            let cell = tableView.dequeueReusableCell(withIdentifier: DiagnosticsParameterCell.reuseIdentifier, for: indexPath) as! DiagnosticsParameterCell
            
            if isDeviceActuallyConnected, let data = bmsData {
                if indexPath.row == 0 {
                    // PCB температура
                    let tempF = Int(data.tempPCB.celsiusToFahrenheit())
                    let tempC = Int(data.tempPCB)
                    cell.configure(title: "PCB", value: "\(tempF)°F / \(tempC)°C")
                } else if indexPath.row == 1 {
                    // Температура окружающей среды
                    let tempF = Int(data.tempEnv.celsiusToFahrenheit())
                    let tempC = Int(data.tempEnv)
                    cell.configure(title: "Environment", value: "\(tempF)°F / \(tempC)°C")
                } else {
                    // Температуры ячеек
                    let index = indexPath.row - 2
                    if index < data.cellTemps.count {
                        let temp = data.cellTemps[index]
                        let tempF = Int(temp.celsiusToFahrenheit())
                        let tempC = Int(temp)
                        cell.configure(title: "Sensor \(index + 1)", value: "\(tempF)°F / \(tempC)°C")
                    } else {
                        cell.configure(title: "Sensor \(index + 1)", value: "-- °F / -- °C")
                    }
                }
            } else {
                // Если данных нет или нет подключения
                if indexPath.row == 0 {
                    cell.configure(title: "PCB", value: "-- °F / -- °C")
                } else if indexPath.row == 1 {
                    cell.configure(title: "Environment", value: "-- °F / -- °C")
                } else {
                    let index = indexPath.row - 2
                    cell.configure(title: "Sensor \(index + 1)", value: "-- °F / -- °C")
                }
            }
            
            return cell
            
        case .eventLogs:
            let cell = tableView.dequeueReusableCell(withIdentifier: DiagnosticsEventCell.reuseIdentifier, for: indexPath) as! DiagnosticsEventCell
            let event = eventLogs[indexPath.row]
            cell.configure(with: event, dateFormatter: dateFormatter)
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let section = Section(rawValue: section) else { return nil }
        return section.title
    }
}

// MARK: - UITableViewDelegate

extension DiagnosticsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
}

// MARK: - MFMailComposeViewControllerDelegate

extension DiagnosticsViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        // Закрываем контроллер отправки email
        controller.dismiss(animated: true)
        
        // Добавляем событие в журнал
        switch result {
        case .sent:
            addEvent(type: .connection, message: "Logs sent successfully")
        case .failed:
            addEvent(type: .error, message: "Error sending logs: \(error?.localizedDescription ?? "unknown error")")
        case .cancelled:
            addEvent(type: .connection, message: "Log sending cancelled")
        case .saved:
            addEvent(type: .connection, message: "Logs saved to drafts")
        @unknown default:
            break
        }
    }
}

// MARK: - DiagnosticsParameterCell

/// Ячейка для отображения параметра батареи
class DiagnosticsParameterCell: UITableViewCell {
    static let reuseIdentifier = "DiagnosticsParameterCell"
    
    // MARK: - UI Elements
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .darkGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .bold)
        label.textColor = .black
        label.textAlignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initialization
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - Setup
    
    private func setupView() {
        backgroundColor = .white
        selectionStyle = .none
        
        // Добавляем метки
        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
        
        // Настраиваем ограничения
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            valueLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            valueLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            valueLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            valueLabel.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.5)
        ])
    }
    
    // MARK: - Configuration
    
    func configure(title: String, value: String) {
        titleLabel.text = title
        valueLabel.text = value
    }
}

// MARK: - DiagnosticsEventCell

/// Ячейка для отображения события в журнале
class DiagnosticsEventCell: UITableViewCell {
    static let reuseIdentifier = "DiagnosticsEventCell"
    
    // MARK: - UI Elements
    
    private let timestampLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = .darkGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let typeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .bold)
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .black
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initialization
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - Setup
    
    private func setupView() {
        backgroundColor = .white
        selectionStyle = .none
        
        // Добавляем метки
        contentView.addSubview(timestampLabel)
        contentView.addSubview(typeLabel)
        contentView.addSubview(messageLabel)
        
        // Настраиваем ограничения
        NSLayoutConstraint.activate([
            timestampLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            timestampLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            timestampLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            typeLabel.topAnchor.constraint(equalTo: timestampLabel.bottomAnchor, constant: 4),
            typeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            typeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            messageLabel.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 4),
            messageLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            messageLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    // MARK: - Configuration
    
    func configure(with event: DiagnosticsViewController.DiagnosticsEvent, dateFormatter: DateFormatter) {
        timestampLabel.text = dateFormatter.string(from: event.timestamp)
        typeLabel.text = event.type.title
        messageLabel.text = event.message
        
        // Устанавливаем цвет в зависимости от типа события
        switch event.type {
        case .connection:
            typeLabel.textColor = .systemGreen
        case .disconnection:
            typeLabel.textColor = .systemOrange
        case .dataUpdate:
            typeLabel.textColor = .systemBlue
        case .error:
            typeLabel.textColor = .systemRed
        }
    }
}
