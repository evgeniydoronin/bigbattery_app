//
//  ZetaraLoggerTest.swift
//  BatteryMonitorBL
//
//  Created on 2025/9/18.
//  Тест для проверки интеграции ZetaraLogger с AppLogger
//

import Foundation
import Testing
import Zetara

/// Тестовый класс для проверки работы интеграции ZetaraLogger
@Suite("ZetaraLogger Integration Tests")
struct ZetaraLoggerIntegrationTests {
    
    @Test("ZetaraLogger can log without crashing when bridge is not set")
    func testZetaraLoggerWithoutBridge() async throws {
        // Очищаем настройку моста
        ZetaraLogger.shared = nil
        
        // Эти вызовы должны работать через fallback на print()
        ZetaraLogger.info("Test message without bridge", details: ["test": true])
        ZetaraLogger.debug("Debug message", details: ["debug": 123])
        ZetaraLogger.warning("Warning message")
        ZetaraLogger.error("Error message", details: ["error": "test error"])
        ZetaraLogger.critical("Critical message")
        
        // Тест проходит, если не произошло краха приложения
        #expect(true, "ZetaraLogger should handle nil bridge gracefully")
    }
    
    @Test("ZetaraLogger works correctly with bridge")
    func testZetaraLoggerWithBridge() async throws {
        // Создаем мост
        let bridge = ZetaraLoggerBridge()
        ZetaraLogger.shared = bridge
        
        let initialLogCount = AppLogger.shared.getLogCount()
        
        // Отправляем тестовые логи
        ZetaraLogger.info("Test Module ID operation", details: ["moduleId": 1])
        ZetaraLogger.debug("Test CAN protocol", details: ["protocol": "CAN"])
        ZetaraLogger.error("Test RS485 error", details: ["error": "timeout"])
        
        // Проверяем, что логи попали в AppLogger
        let finalLogCount = AppLogger.shared.getLogCount()
        
        #expect(finalLogCount > initialLogCount, "AppLogger should receive logs from ZetaraLogger")
        #expect(finalLogCount >= initialLogCount + 3, "Should have at least 3 new log entries")
    }
    
    @Test("Bridge correctly categorizes protocol messages")
    func testBridgeMessageCategorization() async throws {
        let bridge = ZetaraLoggerBridge()
        ZetaraLogger.shared = bridge
        
        let testMessages = [
            ("Module ID operation started", "protocolModule_ID", "protocolOperationStarted"),
            ("CAN data received successfully", "protocolModule_CAN", "protocolOperationCompleted"),
            ("RS485 request failed", "protocolModule_RS485", "protocolOperationFailed"),
            ("Bluetooth characteristics ready", "bluetoothManager", "stateChanged"),
            ("✅ writeControlData completed successfully", "bluetoothManager", "protocolOperationCompleted")
        ]
        
        // Тестируем каждое сообщение
        for (message, expectedComponent, expectedEvent) in testMessages {
            let (component, event) = bridge.determineComponentAndEvent(from: message)
            
            #expect(component == expectedComponent, 
                   "Message '\(message)' should be categorized as component '\(expectedComponent)', got '\(component)'")
            #expect(event == expectedEvent,
                   "Message '\(message)' should be categorized as event '\(expectedEvent)', got '\(event)'")
        }
    }
}