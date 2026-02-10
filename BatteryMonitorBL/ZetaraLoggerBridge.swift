//
//  ZetaraLoggerBridge.swift
//  BatteryMonitorBL
//
//  Created by Evgeniy Doronin on 18/9/25.
//

import Foundation
import Zetara

/// Мост для перенаправления логов из ZetaraManager в AppLogger
class ZetaraLoggerBridge: ZetaraLoggerProtocol {
    
    // MARK: - ZetaraLoggerProtocol Implementation
    
    func debug(_ message: String, details: [String: Any]?) {
        let (component, event) = determineComponentAndEvent(from: message)
        AppLogger.shared.debug(
            screen: AppLogger.Screen.zetaraManager,
            component: component,
            event: event,
            message: message,
            details: details
        )
    }
    
    func info(_ message: String, details: [String: Any]?) {
        let (component, event) = determineComponentAndEvent(from: message)
        AppLogger.shared.info(
            screen: AppLogger.Screen.zetaraManager,
            component: component,
            event: event,
            message: message,
            details: details
        )
    }
    
    func warning(_ message: String, details: [String: Any]?) {
        let (component, event) = determineComponentAndEvent(from: message)
        AppLogger.shared.warning(
            screen: AppLogger.Screen.zetaraManager,
            component: component,
            event: event,
            message: message,
            details: details
        )
    }
    
    func error(_ message: String, details: [String: Any]?) {
        let (component, event) = determineComponentAndEvent(from: message)
        AppLogger.shared.error(
            screen: AppLogger.Screen.zetaraManager,
            component: component,
            event: event,
            message: message,
            details: details
        )
    }
    
    func critical(_ message: String, details: [String: Any]?) {
        let (component, event) = determineComponentAndEvent(from: message)
        AppLogger.shared.critical(
            screen: AppLogger.Screen.zetaraManager,
            component: component,
            event: event,
            message: message,
            details: details
        )
    }
}

// MARK: - Enhanced Logging Methods

extension ZetaraLoggerBridge {
    
    /// Специализированное логирование для протокольных операций
    func logProtocolOperation(_ operation: String, result: ProtocolOperationResult, details: [String: Any]? = nil) {
        var enhancedDetails = details ?? [:]
        enhancedDetails["operation"] = operation
        enhancedDetails["result"] = result.rawValue
        
        switch result {
        case .success:
            info("✅ Protocol operation succeeded: \(operation)", details: enhancedDetails)
        case .failure:
            error("❌ Protocol operation failed: \(operation)", details: enhancedDetails)
        case .timeout:
            warning("⏱️ Protocol operation timed out: \(operation)", details: enhancedDetails)
        case .parsing_error:
            error("🔧 Protocol parsing error: \(operation)", details: enhancedDetails)
        }
    }
    
    /// Специализированное логирование для Bluetooth операций
    func logBluetoothOperation(_ operation: String, status: BluetoothOperationStatus, details: [String: Any]? = nil) {
        var enhancedDetails = details ?? [:]
        enhancedDetails["bluetoothOperation"] = operation
        enhancedDetails["status"] = status.rawValue
        
        switch status {
        case .started:
            debug("🔵 Bluetooth operation started: \(operation)", details: enhancedDetails)
        case .completed:
            info("✅ Bluetooth operation completed: \(operation)", details: enhancedDetails)
        case .failed:
            error("❌ Bluetooth operation failed: \(operation)", details: enhancedDetails)
        }
    }
    
    /// Специализированное логирование для данных BMS
    func logBMSData(_ event: String, data: [String: Any]) {
        info("📊 BMS Data: \(event)", details: data)
    }
}

// MARK: - Supporting Enums

/// Результат протокольной операции
enum ProtocolOperationResult: String {
    case success = "success"
    case failure = "failure"
    case timeout = "timeout"
    case parsing_error = "parsing_error"
}

/// Статус Bluetooth операции
enum BluetoothOperationStatus: String {
    case started = "started"
    case completed = "completed"
    case failed = "failed"
}

// MARK: - Private Helper Methods

extension ZetaraLoggerBridge {
    
    /// Определяет компонент и событие на основе содержания сообщения
    func determineComponentAndEvent(from message: String) -> (component: String, event: String) {
        
        // Определение компонента
        var component: String
        if message.contains("Module ID") || message.contains("getModuleId") {
            component = AppLogger.Component.protocolModuleId
        } else if message.contains("CAN") || message.contains("getCAN") {
            component = AppLogger.Component.protocolModuleCAN
        } else if message.contains("RS485") || message.contains("getRS485") {
            component = AppLogger.Component.protocolModuleRS485
        } else if message.contains("Bluetooth") || message.contains("writeControlData") {
            component = AppLogger.Component.bluetoothManager
        } else {
            component = AppLogger.Component.protocolModule
        }
        
        // Определение события
        var event: String
        if message.contains("✅") || message.contains("successfully") || message.contains("completed successfully") {
            event = AppLogger.Event.protocolOperationCompleted
        } else if message.contains("❌") || message.contains("Failed") || message.contains("failed") {
            event = AppLogger.Event.protocolOperationFailed
        } else if message.contains("💥") || message.contains("request failed") {
            event = AppLogger.Event.errorOccurred
        } else if message.contains("📡") || message.contains("called") || message.contains("started") {
            event = AppLogger.Event.protocolOperationStarted
        } else if message.contains("📥") || message.contains("received") || message.contains("response") {
            event = AppLogger.Event.dataReceived
        } else if message.contains("📤") || message.contains("Sending") {
            event = AppLogger.Event.connectionStarted
        } else if message.contains("🎭") || message.contains("Mock") {
            event = AppLogger.Event.dataUpdated
        } else if message.contains("parsed") && message.contains("successfully") {
            event = AppLogger.Event.protocolDataParsed
        } else if message.contains("parse") && (message.contains("Failed") || message.contains("failed")) {
            event = AppLogger.Event.protocolDataParsingFailed
        } else {
            event = AppLogger.Event.stateChanged
        }
        
        return (component: component, event: event)
    }
}
