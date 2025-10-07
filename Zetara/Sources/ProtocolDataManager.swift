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

    // MARK: - Initialization

    public init() {
        print("[PROTOCOL MANAGER] Initialized")
    }

    /// Установить ссылку на ZetaraManager (вызывается из ZetaraManager.init())
    func setZetaraManager(_ manager: ZetaraManager) {
        self.zetaraManager = manager
    }

    // MARK: - Public Methods

    /// Загружает все протоколы последовательно через Request Queue
    /// - Parameter delay: Задержка перед началом загрузки (по умолчанию 1.5 секунды)
    public func loadAllProtocols(afterDelay delay: TimeInterval = 1.5) {
        print("[PROTOCOL MANAGER] Starting protocol loading after \(delay)s delay...")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.loadProtocolsSequentially()
        }
    }

    /// Очищает все протокольные данные
    public func clearProtocols() {
        print("[PROTOCOL MANAGER] Clearing all protocols")
        moduleIdSubject.onNext(nil)
        rs485Subject.onNext(nil)
        canSubject.onNext(nil)
    }

    // MARK: - Private Methods

    /// Загружает протоколы последовательно через Request Queue
    private func loadProtocolsSequentially() {
        guard let manager = zetaraManager else {
            print("[PROTOCOL MANAGER] ❌ ZetaraManager not set")
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
                print("[PROTOCOL MANAGER] ✅ Module ID loaded: \(moduleIdData.readableId())")
                self?.moduleIdSubject.onNext(moduleIdData)
            },
            onError: { [weak self] error in
                print("[PROTOCOL MANAGER] ❌ Failed to load Module ID after retry: \(error)")
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
                print("[PROTOCOL MANAGER] ✅ RS485 loaded: \(rs485Data.readableProtocol())")
                self?.rs485Subject.onNext(rs485Data)
            },
            onError: { [weak self] error in
                print("[PROTOCOL MANAGER] ❌ Failed to load RS485 after retry: \(error)")
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
                print("[PROTOCOL MANAGER] ✅ CAN loaded: \(canData.readableProtocol())")
                self?.canSubject.onNext(canData)
                print("[PROTOCOL MANAGER] 🎉 All protocols loaded successfully!")
            },
            onError: { [weak self] error in
                print("[PROTOCOL MANAGER] ❌ Failed to load CAN after retry: \(error)")
                self?.canSubject.onNext(nil)
            }
        )
        .disposed(by: disposeBag)
    }
}
