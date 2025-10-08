//
//  ProtocolDataManager.swift
//  Zetara
//
//  Created by Claude Code on 2025-10-07.
//  Сервис для управления протокольными данными (Module ID, CAN, RS485)
//

import Foundation
import RxSwift
import RxCocoa

public class ProtocolDataManager {

    // MARK: - Properties

    /// BehaviorSubjects для реактивного управления данными протоколов
    public let moduleIdSubject = BehaviorSubject<Data.ModuleIdControlData?>(value: nil)
    public let rs485Subject = BehaviorSubject<Data.RS485ControlData?>(value: nil)
    public let canSubject = BehaviorSubject<Data.CANControlData?>(value: nil)

    /// DisposeBag для управления подписками
    private let disposeBag = DisposeBag()

    /// Ссылка на ZetaraManager для доступа к методам запросов
    private weak var zetaraManager: ZetaraManager?

    // MARK: - Logging

    /// Массив логов протоколов (последние 30 событий)
    private var protocolLogs: [String] = []

    /// Максимальное количество хранимых логов
    private let maxLogs = 30

    // MARK: - Initialization

    public init() {
        print("[PROTOCOL MANAGER] Initialized")
    }

    /// Установить ссылку на ZetaraManager (вызывается из ZetaraManager.init())
    func setZetaraManager(_ manager: ZetaraManager) {
        self.zetaraManager = manager
    }

    // MARK: - Logging Methods

    /// Логирует событие протокола с timestamp
    /// - Parameter message: Сообщение для логирования
    public func logProtocolEvent(_ message: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        let timestamp = dateFormatter.string(from: Date())
        let logEntry = "[\(timestamp)] \(message)"

        // Добавляем в начало массива (новые логи сверху)
        protocolLogs.insert(logEntry, at: 0)

        // Ограничиваем размер массива
        if protocolLogs.count > maxLogs {
            protocolLogs.removeLast()
        }

        // Также выводим в console для Xcode
        print(logEntry)
    }

    /// Возвращает массив логов протоколов (для DiagnosticsViewController)
    /// - Returns: Массив строк с логами (последние 30 событий)
    public func getProtocolLogs() -> [String] {
        return protocolLogs
    }

    // MARK: - Public Methods

    /// Загружает все протоколы последовательно через Request Queue
    /// - Parameter delay: Задержка перед началом загрузки (по умолчанию 1.5 секунды)
    public func loadAllProtocols(afterDelay delay: TimeInterval = 1.5) {
        logProtocolEvent("[PROTOCOL MANAGER] Starting protocol loading after \(delay)s delay...")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.loadProtocolsSequentially()
        }
    }

    /// Очищает все протокольные данные
    public func clearProtocols() {
        logProtocolEvent("[PROTOCOL MANAGER] Clearing all protocols")
        moduleIdSubject.onNext(nil)
        rs485Subject.onNext(nil)
        canSubject.onNext(nil)
    }

    // MARK: - Private Methods

    /// Загружает протоколы последовательно через Request Queue
    private func loadProtocolsSequentially() {
        guard let manager = zetaraManager else {
            logProtocolEvent("[PROTOCOL MANAGER] ❌ ZetaraManager not set")
            return
        }

        // 1. Загружаем Module ID
        loadModuleId(manager: manager)

        // 2. Загружаем RS485 (Request Queue обеспечит минимум 500ms после Module ID)
        loadRS485(manager: manager)

        // 3. Загружаем CAN (Request Queue обеспечит минимум 500ms после RS485)
        loadCAN(manager: manager)
    }

    /// Загружает Module ID с retry логикой
    private func loadModuleId(manager: ZetaraManager) {
        manager.queuedRequest("getModuleId") {
            return manager.getModuleId()
        }
        .retry(1) // Одна попытка повтора при ошибке
        .subscribe(
            onSuccess: { [weak self] moduleIdData in
                self?.logProtocolEvent("[PROTOCOL MANAGER] ✅ Module ID loaded: \(moduleIdData.readableId())")
                self?.moduleIdSubject.onNext(moduleIdData)
            },
            onError: { [weak self] error in
                // Различаем timeout от других ошибок (timeout теперь приходит из ZetaraManager.writeControlData)
                if case RxError.timeout = error {
                    self?.logProtocolEvent("[PROTOCOL MANAGER] ⏱️ Module ID timeout after 10s")
                } else {
                    self?.logProtocolEvent("[PROTOCOL MANAGER] ❌ Failed to load Module ID after retry: \(error)")
                }
                self?.moduleIdSubject.onNext(nil)
            }
        )
        .disposed(by: disposeBag)
    }

    /// Загружает RS485 с retry логикой
    private func loadRS485(manager: ZetaraManager) {
        manager.queuedRequest("getRS485") {
            return manager.getRS485()
        }
        .retry(1) // Одна попытка повтора при ошибке
        .subscribe(
            onSuccess: { [weak self] rs485Data in
                self?.logProtocolEvent("[PROTOCOL MANAGER] ✅ RS485 loaded: \(rs485Data.readableProtocol())")
                self?.rs485Subject.onNext(rs485Data)
            },
            onError: { [weak self] error in
                // Различаем timeout от других ошибок (timeout теперь приходит из ZetaraManager.writeControlData)
                if case RxError.timeout = error {
                    self?.logProtocolEvent("[PROTOCOL MANAGER] ⏱️ RS485 timeout after 10s")
                } else {
                    self?.logProtocolEvent("[PROTOCOL MANAGER] ❌ Failed to load RS485 after retry: \(error)")
                }
                self?.rs485Subject.onNext(nil)
            }
        )
        .disposed(by: disposeBag)
    }

    /// Загружает CAN с retry логикой
    private func loadCAN(manager: ZetaraManager) {
        manager.queuedRequest("getCAN") {
            return manager.getCAN()
        }
        .retry(1) // Одна попытка повтора при ошибке
        .subscribe(
            onSuccess: { [weak self] canData in
                self?.logProtocolEvent("[PROTOCOL MANAGER] ✅ CAN loaded: \(canData.readableProtocol())")
                self?.canSubject.onNext(canData)
                self?.logProtocolEvent("[PROTOCOL MANAGER] 🎉 All protocols loaded successfully!")
            },
            onError: { [weak self] error in
                // Различаем timeout от других ошибок (timeout теперь приходит из ZetaraManager.writeControlData)
                if case RxError.timeout = error {
                    self?.logProtocolEvent("[PROTOCOL MANAGER] ⏱️ CAN timeout after 10s")
                } else {
                    self?.logProtocolEvent("[PROTOCOL MANAGER] ❌ Failed to load CAN after retry: \(error)")
                }
                self?.canSubject.onNext(nil)
            }
        )
        .disposed(by: disposeBag)
    }
}
