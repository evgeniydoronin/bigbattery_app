//
//  ZetaraLogger.swift
//  Zetara
//
//  Created on 2025/9/18.
//

import Foundation

/// Протокол для логирования в ZetaraManager
public protocol ZetaraLoggerProtocol: AnyObject {
    /// Логирование отладочной информации
    func debug(_ message: String, details: [String: Any]?)
    
    /// Логирование информационных сообщений
    func info(_ message: String, details: [String: Any]?)
    
    /// Логирование предупреждений
    func warning(_ message: String, details: [String: Any]?)
    
    /// Логирование ошибок
    func error(_ message: String, details: [String: Any]?)
    
    /// Логирование критических ошибок
    func critical(_ message: String, details: [String: Any]?)
}

/// Централизованный логгер для ZetaraManager
public class ZetaraLogger {
    /// Слабая ссылка на делегат логирования
    public static weak var shared: ZetaraLoggerProtocol?
    
    /// Приватный инициализатор для предотвращения создания экземпляров
    private init() {}
    
    // MARK: - Convenience Methods
    
    /// Логирование отладочной информации с fallback на print()
    public static func debug(_ message: String, details: [String: Any]? = nil) {
        if let logger = shared {
            logger.debug(message, details: details)
        } else {
            // Fallback на print() если logger не установлен
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[ZETARA_DEBUG] [\(timestamp)] \(message)")
            if let details = details {
                print("[ZETARA_DEBUG] Details: \(details)")
            }
        }
    }
    
    /// Логирование информационных сообщений с fallback на print()
    public static func info(_ message: String, details: [String: Any]? = nil) {
        if let logger = shared {
            logger.info(message, details: details)
        } else {
            // Fallback на print() если logger не установлен
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[ZETARA_INFO] [\(timestamp)] \(message)")
            if let details = details {
                print("[ZETARA_INFO] Details: \(details)")
            }
        }
    }
    
    /// Логирование предупреждений с fallback на print()
    public static func warning(_ message: String, details: [String: Any]? = nil) {
        if let logger = shared {
            logger.warning(message, details: details)
        } else {
            // Fallback на print() если logger не установлен
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[ZETARA_WARNING] [\(timestamp)] \(message)")
            if let details = details {
                print("[ZETARA_WARNING] Details: \(details)")
            }
        }
    }
    
    /// Логирование ошибок с fallback на print()
    public static func error(_ message: String, details: [String: Any]? = nil) {
        if let logger = shared {
            logger.error(message, details: details)
        } else {
            // Fallback на print() если logger не установлен
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[ZETARA_ERROR] [\(timestamp)] \(message)")
            if let details = details {
                print("[ZETARA_ERROR] Details: \(details)")
            }
        }
    }
    
    /// Логирование критических ошибок с fallback на print()
    public static func critical(_ message: String, details: [String: Any]? = nil) {
        if let logger = shared {
            logger.critical(message, details: details)
        } else {
            // Fallback на print() если logger не установлен
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[ZETARA_CRITICAL] [\(timestamp)] \(message)")
            if let details = details {
                print("[ZETARA_CRITICAL] Details: \(details)")
            }
        }
    }
}