//
//  AppLogger.swift
//  BatteryMonitorBL
//
//  Created on 2025/9/17.
//

import Foundation
import UIKit

/// Централизованная система логирования для приложения
class AppLogger {
    static let shared = AppLogger()

    /// Максимальное количество логов в памяти
    private let maxLogCount = 500

    /// Массив всех логов
    private var logs: [LogEntry] = []

    /// Очередь для безопасного доступа к логам
    private let logQueue = DispatchQueue(label: "app.logger.queue", qos: .utility)

    /// Форматтер для timestamp
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    /// Структура записи лога
    struct LogEntry {
        let timestamp: Date
        let level: LogLevel
        let screen: String
        let component: String?
        let event: String
        let details: [String: Any]?
        let message: String

        /// Преобразование в словарь для JSON
        func toDictionary() -> [String: Any] {
            var dict: [String: Any] = [
                "timestamp": AppLogger.shared.dateFormatter.string(from: timestamp),
                "level": level.rawValue,
                "screen": screen,
                "event": event,
                "message": message
            ]

            if let component = component {
                dict["component"] = component
            }

            if let details = details {
                dict["details"] = details
            }

            return dict
        }
    }

    /// Уровни логирования
    enum LogLevel: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case critical = "CRITICAL"
    }

    private init() {
        // Добавляем лог запуска приложения
        log(.info, screen: "AppDelegate", event: "appLaunched", message: "Application started")
    }

    /// Основной метод логирования
    func log(_ level: LogLevel,
             screen: String,
             component: String? = nil,
             event: String,
             details: [String: Any]? = nil,
             message: String) {

        logQueue.async { [weak self] in
            guard let self = self else { return }

            let entry = LogEntry(
                timestamp: Date(),
                level: level,
                screen: screen,
                component: component,
                event: event,
                details: details,
                message: message
            )

            self.logs.append(entry)

            // Ограничиваем количество логов
            if self.logs.count > self.maxLogCount {
                self.logs.removeFirst(self.logs.count - self.maxLogCount)
            }

            // Выводим в консоль для разработки
            #if DEBUG
            let timestamp = self.dateFormatter.string(from: entry.timestamp)
            let componentStr = component != nil ? ".\(component!)" : ""
            print("[\(timestamp)] \(level.rawValue) \(screen)\(componentStr) - \(event): \(message)")
            #endif
        }
    }

    /// Получение всех логов для отправки
    func getAllLogs() -> [[String: Any]] {
        return logQueue.sync {
            return logs.map { $0.toDictionary() }
        }
    }

    /// Получение логов определенного уровня
    func getLogs(level: LogLevel) -> [[String: Any]] {
        return logQueue.sync {
            return logs.filter { $0.level == level }.map { $0.toDictionary() }
        }
    }

    /// Получение логов за последний период
    func getRecentLogs(since: TimeInterval) -> [[String: Any]] {
        let cutoffDate = Date().addingTimeInterval(-since)
        return logQueue.sync {
            return logs.filter { $0.timestamp >= cutoffDate }.map { $0.toDictionary() }
        }
    }

    /// Очистка логов
    func clearLogs() {
        logQueue.async { [weak self] in
            self?.logs.removeAll()
        }
    }

    /// Количество логов
    func getLogCount() -> Int {
        return logQueue.sync {
            return logs.count
        }
    }
}

// MARK: - Convenience Methods

extension AppLogger {

    /// Логирование отладочной информации
    func debug(screen: String, component: String? = nil, event: String, message: String, details: [String: Any]? = nil) {
        log(.debug, screen: screen, component: component, event: event, details: details, message: message)
    }

    /// Логирование информационных сообщений
    func info(screen: String, component: String? = nil, event: String, message: String, details: [String: Any]? = nil) {
        log(.info, screen: screen, component: component, event: event, details: details, message: message)
    }

    /// Логирование предупреждений
    func warning(screen: String, component: String? = nil, event: String, message: String, details: [String: Any]? = nil) {
        log(.warning, screen: screen, component: component, event: event, details: details, message: message)
    }

    /// Логирование ошибок
    func error(screen: String, component: String? = nil, event: String, message: String, details: [String: Any]? = nil) {
        log(.error, screen: screen, component: component, event: event, details: details, message: message)
    }

    /// Логирование критических ошибок
    func critical(screen: String, component: String? = nil, event: String, message: String, details: [String: Any]? = nil) {
        log(.critical, screen: screen, component: component, event: event, details: details, message: message)
    }
}

// MARK: - Screen and Component Constants

extension AppLogger {

    /// Названия экранов
    struct Screen {
        static let home = "HomeViewController"
        static let settings = "SettingsViewController"
        static let diagnostics = "DiagnosticsViewController"
        static let connectivity = "ConnectivityViewController"
        static let zetaraManager = "ZetaraManager"
    }

    /// Названия компонентов
    struct Component {
        // Home screen components
        static let protocolButtonID = "protocolButton_ID"
        static let protocolButtonCAN = "protocolButton_CAN"
        static let protocolButtonRS485 = "protocolButton_RS485"
        static let connectionStatus = "connectionStatus"
        static let batteryInfo = "batteryInfo"

        // Settings screen components
        static let moduleIdPicker = "moduleIdPicker"
        static let canProtocolPicker = "canProtocolPicker"
        static let rs485ProtocolPicker = "rs485ProtocolPicker"
        static let saveButton = "saveButton"
        static let noteText = "noteText"

        // Bluetooth components
        static let bluetoothManager = "bluetoothManager"
        static let peripheral = "peripheral"
    }

    /// Типы событий
    struct Event {
        // UI Events
        static let viewDidLoad = "viewDidLoad"
        static let viewWillAppear = "viewWillAppear"
        static let viewDidAppear = "viewDidAppear"
        static let buttonTapped = "buttonTapped"
        static let valueChanged = "valueChanged"
        static let stateChanged = "stateChanged"

        // Connection Events
        static let connectionStarted = "connectionStarted"
        static let connectionSucceeded = "connectionSucceeded"
        static let connectionFailed = "connectionFailed"
        static let disconnectionStarted = "disconnectionStarted"
        static let disconnectionCompleted = "disconnectionCompleted"

        // Data Events
        static let dataReceived = "dataReceived"
        static let dataUpdated = "dataUpdated"
        static let dataParsingFailed = "dataParsingFailed"

        // Protocol Events
        static let protocolEnabled = "protocolEnabled"
        static let protocolDisabled = "protocolDisabled"
        static let protocolValueChanged = "protocolValueChanged"
        static let protocolsCleared = "protocolsCleared"

        // Settings Events
        static let settingsLoaded = "settingsLoaded"
        static let settingsSaved = "settingsSaved"
        static let settingsLoadFailed = "settingsLoadFailed"
        static let settingsSaveFailed = "settingsSaveFailed"

        // Error Events
        static let errorOccurred = "errorOccurred"
        static let warningOccurred = "warningOccurred"
    }
}