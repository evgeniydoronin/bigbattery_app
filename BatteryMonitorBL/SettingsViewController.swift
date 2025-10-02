//
//  SettingsViewController.swift
//  VoltGoPower
//
//  Created by xxtx on 2022/12/5.
//  Updated by Evgenii Doronin on 2025/5/15 - Removed logo from settings page
//

import Foundation
import UIKit
import Zetara
import RxSwift
import RxBluetoothKit2
import RxViewController

class SettingsViewController: UIViewController {
    @IBOutlet weak var versionItemView: SettingItemView?
    @IBOutlet weak var moduleIdSettingItemView: SettingItemView?
    @IBOutlet weak var canProtocolView: SettingItemView?
    @IBOutlet weak var rs485ProtocolView: SettingItemView?
    
    // Информационный баннер для уведомления о необходимости перезагрузки батареи
    private var informationBannerView: UIView?
    
    // Кнопка Save для подтверждения изменений настроек
    private var saveButton: UIButton?
    
    // Кнопка Refresh Connection для обновления подключения
    private var refreshConnectionButton: UIButton?

    // Баннер статуса подключения батареи
    private var connectionStatusBanner: UIView?

    // Заголовки секций
    private var protocolSettingsLabel: UILabel?
    private var protocolNoteLabel: UILabel?
    private var applicationInfoLabel: UILabel?
    
    // Флаг для отслеживания несохраненных изменений
    private var hasUnsavedChanges: Bool = false {
        didSet {
            updateSaveButtonState()
        }
    }
    
    // Отдельные индикаторы статуса для каждой настройки
    private var moduleIdStatusLabel: UILabel?
    private var canProtocolStatusLabel: UILabel?
    private var rs485ProtocolStatusLabel: UILabel?
    
    // ScrollView для прокрутки контента
    private var scrollView: UIScrollView!
    // Основной UIStackView для гибкого layout
    private var mainStackView: UIStackView!
    
    // Контейнеры для настроек + индикаторов
    private var moduleIdContainer: UIView?
    private var canProtocolContainer: UIView?
    private var rs485ProtocolContainer: UIView?
    
    private var moduleIdData: Zetara.Data.ModuleIdControlData?
    private var rs485Data: Zetara.Data.RS485ControlData?
    private var canData: Zetara.Data.CANControlData?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        AppLogger.shared.info(screen: AppLogger.Screen.settings, event: AppLogger.Event.viewDidLoad, message: "Settings screen loaded")

        // Скрываем навигационный бар, так как мы добавляем свою шапку
        navigationController?.setNavigationBarHidden(true, animated: false)

        // Добавляем фоновое изображение
        let backgroundImageView = UIImageView(image: R.image.background())
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.frame = view.bounds
        backgroundImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(backgroundImageView)
        view.sendSubviewToBack(backgroundImageView)

        // Добавляем шапку с логотипом
        setupLogoHeader()
        
        moduleIdSettingItemView?.title = "Module ID"
        moduleIdSettingItemView?.subtitle = "BMS module identifier"
        moduleIdSettingItemView?.iconColor = UIColor(hex: "#165EA0")
        moduleIdSettingItemView?.valueColor = UIColor(hex: "#165EA0")
        moduleIdSettingItemView?.label = "" // Покажет "--"
        moduleIdSettingItemView?.options = Zetara.Data.ModuleIdControlData.readableIds()
        moduleIdSettingItemView?.selectedOptionIndex
            .skip(1)
            .subscribe {[weak self] index in
                // Отмечаем, что есть несохраненные изменения
                self?.hasUnsavedChanges = true

                let newValue = Zetara.Data.ModuleIdControlData.readableIds()[index]
                let oldValue = self?.moduleIdData?.readableId() ?? "unknown"

                AppLogger.shared.info(
                    screen: AppLogger.Screen.settings,
                    component: AppLogger.Component.moduleIdPicker,
                    event: AppLogger.Event.valueChanged,
                    message: "Module ID changed",
                    details: [
                        "oldValue": oldValue,
                        "newValue": newValue,
                        "index": index
                    ]
                )

                self?.setModuleId(at:index)
        }.disposed(by: disposeBag)
        
        versionItemView?.title = "App Version"
        versionItemView?.subtitle = "BigBattery Husky 2"
        versionItemView?.icon = R.image.homeBluetooth()
        versionItemView?.iconColor = .systemBlue
        versionItemView?.label = version()
        versionItemView?.options = [] // Явно устанавливаем пустой массив опций, чтобы скрыть стрелочку
        
        canProtocolView?.title = "CAN Protocol"
        canProtocolView?.subtitle = "Controller area network protocol"
        canProtocolView?.iconColor = UIColor(hex: "#12C04C")
        canProtocolView?.valueColor = UIColor(hex: "#12C04C")
        canProtocolView?.label = "" // Покажет "--"
        canProtocolView?.options = []
        canProtocolView?.selectedOptionIndex
            .skip(1)
            .subscribe { [weak self] index in
                // Отмечаем, что есть несохраненные изменения
                self?.hasUnsavedChanges = true

                let newValue = self?.canData?.readableProtocol(at: index) ?? "unknown"
                let oldValue = self?.canData?.readableProtocol() ?? "unknown"

                AppLogger.shared.info(
                    screen: AppLogger.Screen.settings,
                    component: AppLogger.Component.canProtocolPicker,
                    event: AppLogger.Event.valueChanged,
                    message: "CAN Protocol changed",
                    details: [
                        "oldValue": oldValue,
                        "newValue": newValue,
                        "index": index
                    ]
                )

                self?.setCAN(at: index)
            }.disposed(by: disposeBag)
        
        rs485ProtocolView?.title = "RS485 Protocol"
        rs485ProtocolView?.subtitle = "Serial communication protocol"
        rs485ProtocolView?.iconColor = UIColor(hex: "#ED1000")
        rs485ProtocolView?.valueColor = UIColor(hex: "#ED1000")
        rs485ProtocolView?.label = "" // Покажет "--"
        rs485ProtocolView?.options = []
        rs485ProtocolView?.selectedOptionIndex
            .skip(1)
            .subscribe { [weak self] index in
                // Отмечаем, что есть несохраненные изменения
                self?.hasUnsavedChanges = true

                let newValue = self?.rs485Data?.readableProtocol(at: index) ?? "unknown"
                let oldValue = self?.rs485Data?.readableProtocol() ?? "unknown"

                AppLogger.shared.info(
                    screen: AppLogger.Screen.settings,
                    component: AppLogger.Component.rs485ProtocolPicker,
                    event: AppLogger.Event.valueChanged,
                    message: "RS485 Protocol changed",
                    details: [
                        "oldValue": oldValue,
                        "newValue": newValue,
                        "index": index
                    ]
                )

                self?.setRS485(at: index)
        }.disposed(by: disposeBag)
        
        // 进入设置页，就暂停 bms data 刷新，离开恢复
        self.rx.isVisible.subscribe { [weak self] (visible: Bool) in
            print("visible change")
            if visible {
                ZetaraManager.shared.pauseRefreshBMSData()
                
                let deviceConnected = (try? ZetaraManager.shared.connectedPeripheralSubject.value()) != nil
                let protocolDataIsEmpty = (self?.canData == nil || self?.rs485Data == nil)
                if deviceConnected && protocolDataIsEmpty {
                    self?.getAllSettings()
                }
                
            } else {
                ZetaraManager.shared.resumeRefreshBMSData()
            }
        }.disposed(by: disposeBag)
        
        ZetaraManager.shared.connectedPeripheralSubject
            .subscribeOn(MainScheduler.instance) // Определяет поток для подписки
            .observe(on: MainScheduler.instance) // Гарантирует, что все последующие операции будут на главном потоке
            .filter { $0 == nil }
            .subscribe { [weak self] _ in
                // Теперь этот блок гарантированно выполняется на главном потоке
                self?.canProtocolView?.options = []
                self?.rs485ProtocolView?.options = []
                self?.canProtocolView?.label = ""
                self?.rs485ProtocolView?.label = ""
                self?.canData = nil
                self?.rs485Data = nil
                self?.moduleIdSettingItemView?.label = ""
            }.disposed(by: disposeBag)

        // Подписка на изменения состояния подключения для обновления баннера статуса
        ZetaraManager.shared.connectedPeripheralSubject
            .subscribeOn(MainScheduler.instance)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] peripheral in
                let isConnected = peripheral != nil
                self?.updateConnectionStatus(isConnected: isConnected)
                // Включаем/выключаем Module ID в зависимости от подключения
                self?.toggleModuleId(isConnected)
                // CAN и RS485 остаются выключенными до загрузки настроек
                if !isConnected {
                    self?.toggleRS485AndCAN(false)
                }
            }).disposed(by: disposeBag)

//        self.moduleIdSettingItemView.selectedOptionIndex
//            .map { $0 == 0 }
//            .bind(to: self.canProtocolView.optionsButton.rx.isEnabled,
//                  self.rs485ProtocolView.optionsButton.rx.isEnabled)
//            .disposed(by: disposeBag)

        self.toggleModuleId(false)
        self.toggleRS485AndCAN(false)
        
        // Создаем отдельные индикаторы статуса (без constraints - они будут в контейнерах)
        setupStatusIndicatorsForStackView()

        // Добавляем баннер статуса подключения (без constraints - будет в StackView)
        setupConnectionStatusBannerForStackView()

        // Добавляем заголовки секций
        setupSectionHeaders()

        // Добавляем кнопку Refresh Connection (без constraints - будет в StackView)
        // setupRefreshConnectionButtonForStackView()

        // Добавляем кнопку Save (без constraints - будет в StackView)
        setupSaveButtonForStackView()

        // Добавляем информационный баннер (без constraints - будет в StackView)
        setupInformationBannerForStackView()
        
        // Настраиваем автоматический refresh при восстановлении связи
        setupAutoRefresh()
        
        // Создаем и настраиваем основной UIStackView
        setupMainStackView()
        
        // Заполняем StackView всеми элементами
        populateStackView()
        
        // Добавляем тестовые кнопки для демонстрации индикаторов
        // setupTestButtonsForStackView()
    }
    
    // MARK: - Logo Header

    /// Создает и настраивает шапку с логотипом BigBattery (точно как в HomeViewController)
    private func setupLogoHeader() {
        // Создаем шапку точно как в HomeViewController
        let headerView = UIView()
        headerView.backgroundColor = .white
        headerView.translatesAutoresizingMaskIntoConstraints = false

        // Создаем логотип точно как в HomeViewController
        let headerLogoImageView = UIImageView(image: R.image.headerLogo())
        headerLogoImageView.contentMode = .scaleAspectFit
        headerLogoImageView.translatesAutoresizingMaskIntoConstraints = false

        // Добавляем шапку на экран
        view.addSubview(headerView)

        // Добавляем логотип в шапку
        headerView.addSubview(headerLogoImageView)

        // Настраиваем ограничения для шапки точно как в HomeViewController
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60) // 60 пикселей ниже safeArea
        ])

        // Настраиваем ограничения для логотипа точно как в HomeViewController
        NSLayoutConstraint.activate([
            headerLogoImageView.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            // Центрируем логотип по вертикали в безопасной зоне
            headerLogoImageView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 30),
            headerLogoImageView.widthAnchor.constraint(equalToConstant: 200), // Ширина логотипа
            headerLogoImageView.heightAnchor.constraint(equalToConstant: 60) // Высота логотипа
        ])
    }

    // MARK: - Информационный баннер
    
    /// Создает и настраивает информационный баннер внизу экрана
    private func setupInformationBanner() {
        // Создаем контейнер для баннера
        let bannerContainer = UIView()
        bannerContainer.backgroundColor = UIColor.white.withAlphaComponent(0.95)
        bannerContainer.layer.cornerRadius = 12
        bannerContainer.clipsToBounds = true
        
        // Добавляем тень для эффекта глубины
        bannerContainer.layer.shadowColor = UIColor.black.cgColor
        bannerContainer.layer.shadowOffset = CGSize(width: 0, height: -2)
        bannerContainer.layer.shadowOpacity = 0.15
        bannerContainer.layer.shadowRadius = 4
        bannerContainer.layer.masksToBounds = false
        
        // Создаем текстовый лейбл
        let messageLabel = UILabel()
        messageLabel.text = "Changes will only take effect after\nrestarting the battery"
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 2
        messageLabel.font = .systemFont(ofSize: 16, weight: .medium)
        messageLabel.textColor = .black
        
        // Добавляем элементы в иерархию
        view.addSubview(bannerContainer)
        bannerContainer.addSubview(messageLabel)
        
        // Настраиваем constraints с помощью SnapKit
        bannerContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-16)
            make.height.equalTo(60)
        }
        
        messageLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }
        
        // Сохраняем ссылку на баннер
        self.informationBannerView = bannerContainer
    }
    
    // MARK: - Индикаторы статуса
    
    /// Создает и настраивает отдельные индикаторы статуса для каждой настройки
    private func setupStatusIndicators() {
        // Создаем индикатор для Module ID
        let moduleIdLabel = createStatusLabel()
        moduleIdStatusLabel = moduleIdLabel
        view.addSubview(moduleIdLabel)
        
        // Создаем индикатор для CAN Protocol
        let canLabel = createStatusLabel()
        canProtocolStatusLabel = canLabel
        view.addSubview(canLabel)
        
        // Создаем индикатор для RS485 Protocol
        let rs485Label = createStatusLabel()
        rs485ProtocolStatusLabel = rs485Label
        view.addSubview(rs485Label)
        
        // Настраиваем constraints для правильного позиционирования
        setupStatusIndicatorConstraints()
    }
    
    /// Создает настроенный лейбл для индикатора статуса
    private func createStatusLabel() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(hex: "#808080")
        label.numberOfLines = 2
        label.textAlignment = .left
        label.isHidden = true // Скрыт по умолчанию
        return label
    }
    
    /// Настраивает constraints для индикаторов статуса между полями настроек
    private func setupStatusIndicatorConstraints() {
        guard let moduleIdView = moduleIdSettingItemView,
              let canView = canProtocolView,
              let rs485View = rs485ProtocolView,
              let moduleIdLabel = moduleIdStatusLabel,
              let canLabel = canProtocolStatusLabel,
              let rs485Label = rs485ProtocolStatusLabel else {
            return
        }
        
        // Индикатор Module ID - под полем Module ID
        moduleIdLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(24)
            make.top.equalTo(moduleIdView.snp.bottom).offset(8)
        }
        
        // Индикатор CAN Protocol - под полем CAN Protocol
        canLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(24)
            make.top.equalTo(canView.snp.bottom).offset(8)
        }
        
        // Индикатор RS485 Protocol - под полем RS485 Protocol
        rs485Label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(24)
            make.top.equalTo(rs485View.snp.bottom).offset(8)
        }
    }
    
    /// Показывает индикатор подтверждения для указанной настройки
    /// - Parameters:
    ///   - label: Лейбл индикатора
    ///   - selectedValue: Выбранное значение
    private func showStatusIndicator(label: UILabel, selectedValue: String) {
        label.text = "Selected: \(selectedValue) – Restart the battery to apply changes"
        label.isHidden = false
        
        // Анимация появления для привлечения внимания
        label.alpha = 0
        UIView.animate(withDuration: 0.3) {
            label.alpha = 1
        }
    }
    
    /// Скрывает индикатор подтверждения
    /// - Parameter label: Лейбл индикатора для скрытия
    private func hideStatusIndicator(label: UILabel) {
        UIView.animate(withDuration: 0.3) {
            label.alpha = 0
        } completion: { _ in
            label.isHidden = true
        }
    }
    
    /// Скрывает все индикаторы статуса
    private func hideAllStatusIndicators() {
        if let moduleIdLabel = moduleIdStatusLabel {
            hideStatusIndicator(label: moduleIdLabel)
        }
        if let canLabel = canProtocolStatusLabel {
            hideStatusIndicator(label: canLabel)
        }
        if let rs485Label = rs485ProtocolStatusLabel {
            hideStatusIndicator(label: rs485Label)
        }
    }
    
    // MARK: - Кнопка Save
    
    /// Создает и настраивает кнопку Save выше информационного баннера
    private func setupSaveButton() {
        // Создаем кнопку Save
        let button = UIButton(type: .system)
        button.setTitle("Save", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.clipsToBounds = true
        
        // Добавляем тень для эффекта глубины
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.1
        button.layer.shadowRadius = 4
        button.layer.masksToBounds = false
        
        // Добавляем действие для кнопки
        button.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        
        // Добавляем кнопку в иерархию
        view.addSubview(button)
        
        // Настраиваем constraints - кнопка должна быть выше информационного баннера
        button.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(50)
            if let bannerView = informationBannerView {
                make.bottom.equalTo(bannerView.snp.top).offset(-16)
            } else {
                make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-92) // 60 (баннер) + 16 (отступ) + 16 (отступ)
            }
        }
        
        // Сохраняем ссылку на кнопку
        self.saveButton = button
        
        // Устанавливаем начальное состояние кнопки (неактивная)
        updateSaveButtonState()
    }
    
    /// Обновляет состояние кнопки Save в зависимости от наличия несохраненных изменений
    private func updateSaveButtonState() {
        guard let button = saveButton else { return }

        if hasUnsavedChanges {
            // Активное состояние - синяя кнопка
            button.isEnabled = true
            button.backgroundColor = UIColor.systemBlue
            button.alpha = 1.0
        } else {
            // Неактивное состояние - серая кнопка (как у неактивных кнопок протоколов)
            button.isEnabled = false
            button.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
            button.alpha = 1.0
        }
    }
    
    /// Обработчик нажатия на кнопку Save
    @objc private func saveButtonTapped() {
        AppLogger.shared.info(
            screen: AppLogger.Screen.settings,
            component: AppLogger.Component.saveButton,
            event: AppLogger.Event.buttonTapped,
            message: "Save button tapped",
            details: [
                "hasUnsavedChanges": hasUnsavedChanges,
                "moduleId": moduleIdData?.readableId() ?? "unknown",
                "canProtocol": canData?.readableProtocol() ?? "unknown",
                "rs485Protocol": rs485Data?.readableProtocol() ?? "unknown"
            ]
        )

        // Показываем упрощенный алерт с основным сообщением
        let alert = UIAlertController(
            title: "Settings Saved",
            message: "Settings will only be applied after restarting the battery",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Understood", style: .default) { [weak self] _ in
            // После подтверждения сбрасываем флаг несохраненных изменений
            self?.hasUnsavedChanges = false
            // Скрываем все индикаторы статуса после сохранения
            self?.hideAllStatusIndicators()

            // 🔧 ИСПРАВЛЕНИЕ ФАНТОМНОГО ПОДКЛЮЧЕНИЯ:
            // При сохранении настроек принудительно отключаем устройство
            // чтобы изменения применились корректно
            if let connectedPeripheral = ZetaraManager.shared.connectedPeripheral() {
                print("🔄 [SettingsViewController] Disconnecting device after settings save...")

                AppLogger.shared.info(
                    screen: AppLogger.Screen.settings,
                    event: AppLogger.Event.settingsSaved,
                    message: "Settings saved, disconnecting device for changes to apply",
                    details: [
                        "deviceName": connectedPeripheral.name ?? "unknown",
                        "moduleId": self?.moduleIdData?.readableId() ?? "unknown",
                        "canProtocol": self?.canData?.readableProtocol() ?? "unknown",
                        "rs485Protocol": self?.rs485Data?.readableProtocol() ?? "unknown"
                    ]
                )

                ZetaraManager.shared.disconnect(connectedPeripheral)

                // Показываем уведомление о необходимости переподключения
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    Alert.show("Please reconnect to apply new settings", timeout: 5)
                }
            }
        })
        
        present(alert, animated: true)
    }
    
    func version() -> String {
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return ""
        }
        
        if let shortVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(version)(\(shortVersion))"
        } else {
            return version
        }
    }
    
    var disposeBag = DisposeBag()
    
    func toggleModuleId(_ enabled: Bool) {
        self.moduleIdSettingItemView?.setOptionsEnabled(enabled)
    }

    func toggleRS485AndCAN(_ enabled: Bool) {
        AppLogger.shared.info(
            screen: AppLogger.Screen.settings,
            event: enabled ? AppLogger.Event.protocolEnabled : AppLogger.Event.protocolDisabled,
            message: "CAN and RS485 protocols \(enabled ? "enabled" : "disabled")",
            details: [
                "enabled": enabled,
                "reason": enabled ? "Module ID = 1" : "Module ID != 1",
                "currentCanValue": canData?.readableProtocol() ?? "unknown",
                "currentRS485Value": rs485Data?.readableProtocol() ?? "unknown"
            ]
        )

        self.rs485ProtocolView?.setOptionsEnabled(enabled)
        self.canProtocolView?.setOptionsEnabled(enabled)

        // Если протоколы отключены (Module ID != 1), очищаем значения
        if !enabled {
            self.rs485ProtocolView?.label = "--"
            self.canProtocolView?.label = "--"

            AppLogger.shared.info(
                screen: AppLogger.Screen.settings,
                event: AppLogger.Event.protocolsCleared,
                message: "Protocol values cleared to '--'",
                details: ["reason": "protocols disabled"]
            )
        } else {
            // Если протоколы включены (Module ID = 1), восстанавливаем актуальные значения
            if let rs485Data = self.rs485Data {
                self.rs485ProtocolView?.label = rs485Data.readableProtocol()
            }
            if let canData = self.canData {
                self.canProtocolView?.label = canData.readableProtocol()
            }

            AppLogger.shared.info(
                screen: AppLogger.Screen.settings,
                event: AppLogger.Event.protocolValueChanged,
                message: "Protocol values restored",
                details: [
                    "canValue": canData?.readableProtocol() ?? "no data",
                    "rs485Value": rs485Data?.readableProtocol() ?? "no data"
                ]
            )
        }
    }
    
    func getAllSettings() {
        Alert.show("Loading...", timeout: 3)

        AppLogger.shared.info(
            screen: AppLogger.Screen.settings,
            event: AppLogger.Event.settingsLoaded,
            message: "Starting to load all settings from device"
        )
        
        // 一个一个来
        self.getModuleId().subscribe(onSuccess: { [weak self] idData in
            Alert.hide()
            self?.moduleIdData = idData
            self?.moduleIdSettingItemView?.label = idData.readableId()
            self?.toggleModuleId(true)
            self?.toggleRS485AndCAN(idData.otherProtocolsEnabled())

            // Сохраняем Module ID в кэш ZetaraManager для Home экрана
            // Home прочитает это БЕЗ Bluetooth запросов → нет конфликта
            ZetaraManager.shared.cachedModuleIdData = idData
            self?.getRS485().subscribe(onSuccess: { [weak self] rs485 in
                Alert.hide()
                self?.rs485Data = rs485
                self?.rs485ProtocolView?.options = rs485.readableProtocols()
                self?.rs485ProtocolView?.label = rs485.readableProtocol()

                // Сохраняем RS485 в кэш для Home экрана
                ZetaraManager.shared.cachedRS485Data = rs485

                self?.getCAN().subscribe(onSuccess: { can in
                    Alert.hide()
                    self?.canData = can
                    self?.canProtocolView?.options = can.readableProtocols()
                    self?.canProtocolView?.label = can.readableProtocol()

                    // Сохраняем CAN в кэш для Home экрана
                    ZetaraManager.shared.cachedCANData = can
                }, onError: { error in
                    Alert.hide()
//                    Alert.show("Invalid Response")
                })
            }, onError: { error in
                Alert.hide()
//                Alert.show("Invalid Response")
            })
        }, onError: { error in
            Alert.hide()
//            Alert.show("Invalid Response")
        })
        .disposed(by: self.disposeBag)
    }
    
    /// Возвращает Observable версию getAllSettings для использования в refresh логике
    private func getAllSettingsObservable() -> Single<Void> {
        return Single.create { [weak self] observer in
            // Загружаем все настройки последовательно
            self?.getModuleId().subscribe(onSuccess: { [weak self] idData in
                self?.moduleIdData = idData
                self?.moduleIdSettingItemView?.label = idData.readableId()
                self?.toggleRS485AndCAN(idData.otherProtocolsEnabled())

                // Сохраняем Module ID в кэш
                ZetaraManager.shared.cachedModuleIdData = idData

                self?.getRS485().subscribe(onSuccess: { [weak self] rs485 in
                    self?.rs485Data = rs485
                    self?.rs485ProtocolView?.options = rs485.readableProtocols()
                    self?.rs485ProtocolView?.label = rs485.readableProtocol()

                    // Сохраняем RS485 в кэш
                    ZetaraManager.shared.cachedRS485Data = rs485

                    self?.getCAN().subscribe(onSuccess: { can in
                        self?.canData = can
                        self?.canProtocolView?.options = can.readableProtocols()
                        self?.canProtocolView?.label = can.readableProtocol()

                        // Сохраняем CAN в кэш
                        ZetaraManager.shared.cachedCANData = can

                        // Все настройки загружены успешно
                        observer(.success(()))
                    }, onError: { error in
                        observer(.failure(error))
                    })
                }, onError: { error in
                    observer(.failure(error))
                })
            }, onError: { error in
                observer(.failure(error))
            })
            .disposed(by: self?.disposeBag ?? DisposeBag())
            
            return Disposables.create()
        }
    }
    
    func setModuleId(at index: Int) {
        let startTime = Date()
        let deviceName = ZetaraManager.shared.connectedPeripheral()?.name ?? "Unknown"

        // Предупреждение для инвертора
        if index != 0 {  // ID1 имеет индекс 0
            Alert.show("⚠️ Warning: For inverter communication, Module ID must be set to ID1", timeout: 5)
        }

        let newModuleId = index + 1
        let oldModuleId = self.moduleIdData?.moduleId ?? 0
        let oldValue = self.moduleIdData?.readableId() ?? "unknown"
        let newValue = Zetara.Data.ModuleIdControlData.readableIds()[index]

        AppLogger.shared.info(
            screen: AppLogger.Screen.settings,
            event: "setModuleId_started",
            message: "[PROTOCOL_DEBUG] 🔧 Setting Module ID: \(oldValue) -> \(newValue) on device: \(deviceName)",
            details: [
                "deviceName": deviceName,
                "oldModuleId": oldModuleId,
                "newModuleId": newModuleId,
                "oldValue": oldValue,
                "newValue": newValue,
                "index": index,
                "willDisableProtocols": newModuleId != 1
            ]
        )

        Alert.show("Setting, please wait patiently", timeout: 3)
        // module id 从 1 开始的
        ZetaraManager.shared.setModuleId(index + 1)
            .subscribeOn(MainScheduler.instance)
            .timeout(.seconds(3), scheduler: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] success in
                let duration = Int(Date().timeIntervalSince(startTime) * 1000)
                Alert.hide()

                if success, let idData = self?.moduleIdData {
                    let selectedValue = idData.readableId(at: index)
                    self?.moduleIdSettingItemView?.label = selectedValue

                    AppLogger.shared.info(
                        screen: AppLogger.Screen.settings,
                        event: "setModuleId_success",
                        message: "[PROTOCOL_DEBUG] ✅ Module ID changed successfully: \(selectedValue) (took \(duration)ms)",
                        details: [
                            "deviceName": deviceName,
                            "oldValue": oldValue,
                            "newValue": selectedValue,
                            "newModuleId": index + 1,
                            "displayValue": selectedValue,
                            "protocolsEnabled": index == 0,
                            "duration": duration
                        ]
                    )

                    self?.toggleRS485AndCAN(index == 0) // 这里是 0 ，因为这里的 id 从 0 开始

                    // Перезагружаем Module ID с устройства чтобы получить актуальное значение
                    // и обновляем кэш для Home экрана
                    self?.getModuleId().subscribe(onSuccess: { [weak self] updatedIdData in
                        self?.moduleIdData = updatedIdData
                        // Обновляем кэш с новым значением Module ID
                        ZetaraManager.shared.cachedModuleIdData = updatedIdData

                        // Показываем индикатор подтверждения выбора с помощью отдельного лейбла
                        if let statusLabel = self?.moduleIdStatusLabel {
                            self?.showStatusIndicatorWithStackView(label: statusLabel, selectedValue: selectedValue)
                        }

                        // Отправляем уведомление об обновлении протоколов
                        NotificationCenter.default.post(name: HomeViewController.protocolsDidUpdateNotification, object: nil)
                    }, onError: { error in
                        print("Failed to reload Module ID after change: \(error)")
                        // Отправляем уведомление даже если перезагрузка не удалась
                        NotificationCenter.default.post(name: HomeViewController.protocolsDidUpdateNotification, object: nil)
                    })
                } else {
                    AppLogger.shared.error(
                        screen: AppLogger.Screen.settings,
                        event: "setModuleId_failed",
                        message: "[PROTOCOL_DEBUG] ❌ Module ID change failed (took \(duration)ms)",
                        details: [
                            "deviceName": deviceName,
                            "oldValue": oldValue,
                            "targetValue": newValue,
                            "attemptedModuleId": index + 1,
                            "duration": duration
                        ]
                    )
                    Alert.show("Set module id failed")
                }
            }, onError: { error in
                let duration = Int(Date().timeIntervalSince(startTime) * 1000)
                Alert.hide()

                AppLogger.shared.error(
                    screen: AppLogger.Screen.settings,
                    event: "setModuleId_error",
                    message: "[PROTOCOL_DEBUG] 💥 Module ID change error: \(error.localizedDescription) (took \(duration)ms)",
                    details: [
                        "deviceName": deviceName,
                        "error": error.localizedDescription,
                        "oldValue": oldValue,
                        "targetValue": newValue,
                        "attemptedModuleId": index + 1,
                        "duration": duration
                    ]
                )

                Alert.show("Set module id error")

//                self?.moduleIdSettingItemView.set(label: "ID\(id + 1)")
//                self?.toggleRS485AndCAN(id == 0) // 这里是 0 ，因为这里的 id 从 0 开始

            })
            .disposed(by: disposeBag)
    }
    
    func setRS485(at index: Int) {
        let startTime = Date()
        let deviceName = ZetaraManager.shared.connectedPeripheral()?.name ?? "Unknown"
        let oldValue = rs485Data?.readableProtocol() ?? "unknown"
        let newValue = rs485Data?.readableProtocol(at: index) ?? "unknown"

        AppLogger.shared.info(
            screen: AppLogger.Screen.settings,
            event: "setRS485_started",
            message: "[PROTOCOL_DEBUG] 🔧 Setting RS485: \(oldValue) -> \(newValue) on device: \(deviceName)",
            details: [
                "deviceName": deviceName,
                "oldValue": oldValue,
                "newValue": newValue,
                "index": index
            ]
        )

        Alert.show("Setting, please wait patiently", timeout: 3)
        ZetaraManager.shared.setRS485(index)
            .subscribeOn(MainScheduler.instance)
            .timeout(.seconds(3), scheduler: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] success in
                let duration = Int(Date().timeIntervalSince(startTime) * 1000)
                Alert.hide()

                if success, let rs485 = self?.rs485Data {
                    let selectedValue = rs485.readableProtocol(at: index)
                    self?.rs485ProtocolView?.label = selectedValue

                    AppLogger.shared.info(
                        screen: AppLogger.Screen.settings,
                        event: "setRS485_success",
                        message: "[PROTOCOL_DEBUG] ✅ RS485 changed successfully: \(selectedValue) (took \(duration)ms)",
                        details: [
                            "deviceName": deviceName,
                            "oldValue": oldValue,
                            "newValue": selectedValue,
                            "index": index,
                            "duration": duration
                        ]
                    )

                    // Перезагружаем RS485 с устройства и обновляем кэш
                    self?.getRS485().subscribe(onSuccess: { [weak self] updatedRS485 in
                        self?.rs485Data = updatedRS485
                        // Обновляем кэш с новым значением RS485
                        ZetaraManager.shared.cachedRS485Data = updatedRS485

                        // Показываем индикатор подтверждения выбора с помощью отдельного лейбла
                        if let statusLabel = self?.rs485ProtocolStatusLabel {
                            self?.showStatusIndicatorWithStackView(label: statusLabel, selectedValue: selectedValue)
                        }

                        // Отправляем уведомление об обновлении протоколов
                        NotificationCenter.default.post(name: HomeViewController.protocolsDidUpdateNotification, object: nil)
                    }, onError: { error in
                        print("Failed to reload RS485 after change: \(error)")
                        NotificationCenter.default.post(name: HomeViewController.protocolsDidUpdateNotification, object: nil)
                    })
                } else {
                    AppLogger.shared.error(
                        screen: AppLogger.Screen.settings,
                        event: "setRS485_failed",
                        message: "[PROTOCOL_DEBUG] ❌ RS485 change failed (took \(duration)ms)",
                        details: [
                            "deviceName": deviceName,
                            "oldValue": oldValue,
                            "targetValue": newValue,
                            "index": index,
                            "duration": duration
                        ]
                    )
                    self?.rs485ProtocolView?.label = "fail"
                }
            }, onError: { [weak self] error in
                let duration = Int(Date().timeIntervalSince(startTime) * 1000)
                Alert.hide()

                AppLogger.shared.error(
                    screen: AppLogger.Screen.settings,
                    event: "setRS485_error",
                    message: "[PROTOCOL_DEBUG] 💥 RS485 change error: \(error.localizedDescription) (took \(duration)ms)",
                    details: [
                        "deviceName": deviceName,
                        "error": error.localizedDescription,
                        "oldValue": oldValue,
                        "targetValue": newValue,
                        "index": index,
                        "duration": duration
                    ]
                )
                self?.rs485ProtocolView?.label = "error"
            })
            .disposed(by: disposeBag)
    }
    
    func setCAN(at index: Int) {
        let startTime = Date()
        let deviceName = ZetaraManager.shared.connectedPeripheral()?.name ?? "Unknown"
        let oldValue = canData?.readableProtocol() ?? "unknown"
        let newValue = canData?.readableProtocol(at: index) ?? "unknown"

        AppLogger.shared.info(
            screen: AppLogger.Screen.settings,
            event: "setCAN_started",
            message: "[PROTOCOL_DEBUG] 🔧 Setting CAN: \(oldValue) -> \(newValue) on device: \(deviceName)",
            details: [
                "deviceName": deviceName,
                "oldValue": oldValue,
                "newValue": newValue,
                "index": index
            ]
        )

        Alert.show("Setting, please wait patiently", timeout: 3)
        ZetaraManager.shared.setCAN(index)
            .subscribeOn(MainScheduler.instance)
            .timeout(.seconds(3), scheduler: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] success in
                let duration = Int(Date().timeIntervalSince(startTime) * 1000)
                Alert.hide()

                if success, let can = self?.canData {
                    let selectedValue = can.readableProtocol(at: index)
                    self?.canProtocolView?.label = selectedValue

                    AppLogger.shared.info(
                        screen: AppLogger.Screen.settings,
                        event: "setCAN_success",
                        message: "[PROTOCOL_DEBUG] ✅ CAN changed successfully: \(selectedValue) (took \(duration)ms)",
                        details: [
                            "deviceName": deviceName,
                            "oldValue": oldValue,
                            "newValue": selectedValue,
                            "index": index,
                            "duration": duration
                        ]
                    )

                    // Перезагружаем CAN с устройства и обновляем кэш
                    self?.getCAN().subscribe(onSuccess: { [weak self] updatedCAN in
                        self?.canData = updatedCAN
                        // Обновляем кэш с новым значением CAN
                        ZetaraManager.shared.cachedCANData = updatedCAN

                        // Показываем индикатор подтверждения выбора с помощью отдельного лейбла
                        if let statusLabel = self?.canProtocolStatusLabel {
                            self?.showStatusIndicatorWithStackView(label: statusLabel, selectedValue: selectedValue)
                        }

                        // Отправляем уведомление об обновлении протоколов
                        NotificationCenter.default.post(name: HomeViewController.protocolsDidUpdateNotification, object: nil)
                    }, onError: { error in
                        print("Failed to reload CAN after change: \(error)")
                        NotificationCenter.default.post(name: HomeViewController.protocolsDidUpdateNotification, object: nil)
                    })
                } else {
                    AppLogger.shared.error(
                        screen: AppLogger.Screen.settings,
                        event: "setCAN_failed",
                        message: "[PROTOCOL_DEBUG] ❌ CAN change failed (took \(duration)ms)",
                        details: [
                            "deviceName": deviceName,
                            "oldValue": oldValue,
                            "targetValue": newValue,
                            "index": index,
                            "duration": duration
                        ]
                    )
                    self?.canProtocolView?.label = "fail"
                }
            }, onError: { [weak self] error in
                let duration = Int(Date().timeIntervalSince(startTime) * 1000)
                Alert.hide()

                AppLogger.shared.error(
                    screen: AppLogger.Screen.settings,
                    event: "setCAN_error",
                    message: "[PROTOCOL_DEBUG] 💥 CAN change error: \(error.localizedDescription) (took \(duration)ms)",
                    details: [
                        "deviceName": deviceName,
                        "error": error.localizedDescription,
                        "oldValue": oldValue,
                        "targetValue": newValue,
                        "index": index,
                        "duration": duration
                    ]
                )
                self?.canProtocolView?.label = "error"
            })
            .disposed(by: disposeBag)
    }
    
    func getModuleId() -> Maybe<Zetara.Data.ModuleIdControlData> {
        print("get control data: module id")
        return ZetaraManager.shared.getModuleId().timeout(.seconds(3), scheduler: MainScheduler.instance).subscribeOn(MainScheduler.instance)
    }
    
    func getRS485() -> Maybe<Zetara.Data.RS485ControlData> {
        print("get control data: rs485")
        return ZetaraManager.shared.getRS485().timeout(.seconds(3), scheduler: MainScheduler.instance).subscribeOn(MainScheduler.instance)
    }
    
    func getCAN() -> Maybe<Zetara.Data.CANControlData> {
        print("get control data: can")
        return ZetaraManager.shared.getCAN().timeout(.seconds(3), scheduler: MainScheduler.instance).subscribeOn(MainScheduler.instance)
    }
    
    // MARK: - Refresh Connection Methods
    
    /// Обработчик нажатия на кнопку Refresh Connection - выполняет двухэтапную логику переподключения
    @objc private func refreshConnectionTapped() {
        print("Refresh Connection button tapped")
        
        // Показываем индикатор загрузки
        Alert.show("Refreshing connection...", timeout: 10)
        
        // Этап 1: Мягкий refresh - просто перезагрузка данных
        getAllSettingsObservable()
            .subscribe(
                onSuccess: { [weak self] in
                    Alert.hide()
                    Alert.show("Connection refreshed successfully", timeout: 2)
                    // Сбрасываем флаг несохраненных изменений
                    self?.hasUnsavedChanges = false
                    // Скрываем все индикаторы статуса
                    self?.hideAllStatusIndicators()
                },
                onFailure: { [weak self] error in
                    print("Soft refresh failed, attempting full reconnect: \(error)")
                    // Если мягкий refresh не помог, переходим к жесткому
                    self?.performFullReconnect()
                }
            ).disposed(by: disposeBag)
    }
    
    /// Выполняет полное переподключение к устройству (жесткий refresh)
    private func performFullReconnect() {
        print("Performing full reconnect")
        Alert.show("Attempting full reconnection...", timeout: 15)
        
        // Получаем текущее подключенное устройство
        guard let currentPeripheral = try? ZetaraManager.shared.connectedPeripheralSubject.value() else {
            Alert.hide()
            Alert.show("No device connected", timeout: 3)
            return
        }
        
        // Отключаемся от текущего устройства
        ZetaraManager.shared.disconnect(currentPeripheral)
        
        // Ждем отключения и пытаемся переподключиться
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            ZetaraManager.shared.connect(currentPeripheral)
                .subscribe(
                    onNext: { [weak self] _ in
                        print("Full reconnection successful, loading settings")
                        // После успешного переподключения загружаем настройки
                        self?.getAllSettingsObservable()
                            .subscribe(
                                onSuccess: { [weak self] in
                                    Alert.hide()
                                    Alert.show("Full reconnection successful", timeout: 2)
                                    self?.hasUnsavedChanges = false
                                    self?.hideAllStatusIndicators()
                                },
                                onFailure: { _ in
                                    Alert.hide()
                                    Alert.show("Reconnection failed", timeout: 3)
                                }
                            ).disposed(by: self?.disposeBag ?? DisposeBag())
                    },
                    onError: { _ in
                        Alert.hide()
                        Alert.show("Reconnection failed", timeout: 3)
                    }
                ).disposed(by: self?.disposeBag ?? DisposeBag())
        }
    }
    
    /// Настраивает автоматический refresh при восстановлении связи
    private func setupAutoRefresh() {
        print("Setting up auto-refresh monitoring")
        
        // Мониторим переподключения через существующие Observable
        ZetaraManager.shared.connectedPeripheralSubject
            .distinctUntilChanged { $0?.identifier == $1?.identifier }
            .skip(1) // Пропускаем первое значение
            .filter { $0 != nil } // Только успешные подключения
            .delay(.seconds(1), scheduler: MainScheduler.instance) // Небольшая задержка
            .subscribe { [weak self] _ in
                self?.performAutoRefresh()
            }.disposed(by: disposeBag)
    }
    
    /// Выполняет автоматическое обновление данных при восстановлении связи
    private func performAutoRefresh() {
        print("Auto-refresh triggered after reconnection")
        
        // Автоматически загружаем настройки без показа алертов
        getAllSettingsObservable()
            .subscribe(
                onSuccess: { [weak self] in
                    print("Auto-refresh completed successfully")
                    // Сбрасываем состояние без уведомлений пользователя
                    self?.hasUnsavedChanges = false
                    self?.hideAllStatusIndicators()
                },
                onFailure: { error in
                    print("Auto-refresh failed: \(error)")
                    // Не показываем ошибки пользователю при автоматическом обновлении
                }
            ).disposed(by: disposeBag)
    }
    
    // MARK: - Тестовые кнопки для демонстрации индикаторов
    
    /// Создает тестовые кнопки для демонстрации визуальных индикаторов
    private func setupTestButtons() {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 8
        
        let testButton1 = createTestButton(title: "Test Module ID", action: #selector(testModuleIdTapped))
        let testButton2 = createTestButton(title: "Test CAN", action: #selector(testCANTapped))
        let testButton3 = createTestButton(title: "Test RS485", action: #selector(testRS485Tapped))
        
        stackView.addArrangedSubview(testButton1)
        stackView.addArrangedSubview(testButton2)
        stackView.addArrangedSubview(testButton3)
        
        view.addSubview(stackView)
        
        // Размещаем над кнопкой Save
        stackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(40)
            if let saveButton = saveButton {
                make.bottom.equalTo(saveButton.snp.top).offset(-16)
            } else {
                make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-150)
            }
        }
    }
    
    /// Создает тестовую кнопку с заданным заголовком и действием
    private func createTestButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.8)
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
    
    /// Тестирует индикатор Module ID
    @objc private func testModuleIdTapped() {
        if let statusLabel = moduleIdStatusLabel {
            showStatusIndicatorWithStackView(label: statusLabel, selectedValue: "ID2")
        }
        hasUnsavedChanges = true // Активируем кнопку Save для тестирования
    }
    
    /// Тестирует индикатор CAN Protocol
    @objc private func testCANTapped() {
        if let statusLabel = canProtocolStatusLabel {
            showStatusIndicatorWithStackView(label: statusLabel, selectedValue: "LUX")
        }
        hasUnsavedChanges = true
    }
    
    /// Тестирует индикатор RS485 Protocol
    @objc private func testRS485Tapped() {
        if let statusLabel = rs485ProtocolStatusLabel {
            showStatusIndicatorWithStackView(label: statusLabel, selectedValue: "Modbus")
        }
        hasUnsavedChanges = true
    }
    
    // MARK: - UIStackView Layout Methods
    
    /// Создает и настраивает основной UIStackView для гибкого layout
    private func setupMainStackView() {
        // Создаем ScrollView
        scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        scrollView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(75) // Отступ под headerView (60px + 15px)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
        }

        // Создаем StackView внутри ScrollView
        mainStackView = UIStackView()
        mainStackView.axis = .vertical
        mainStackView.distribution = .fill
        mainStackView.alignment = .fill
        mainStackView.spacing = 16

        scrollView.addSubview(mainStackView)
        mainStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 20, bottom: 20, right: 20))
            make.width.equalTo(scrollView).offset(-40) // Учитываем отступы слева и справа
        }
    }
    
    /// Создает контейнер для настройки + индикатора статуса
    /// - Parameters:
    ///   - settingView: Элемент настройки
    ///   - statusLabel: Индикатор статуса
    /// - Returns: Контейнер с правильно настроенными constraints
    private func createSettingContainer(settingView: SettingItemView, statusLabel: UILabel) -> UIView {
        let container = UIView()
        
        container.addSubview(settingView)
        container.addSubview(statusLabel)
        
        // Настройка constraints для элемента настройки
        settingView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(60) // Фиксированная высота для настройки
        }
        
        // Настройка constraints для индикатора статуса
        statusLabel.snp.makeConstraints { make in
            make.top.equalTo(settingView.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(4)
            make.bottom.equalToSuperview()
        }
        
        return container
    }
    
    /// Заполняет основной StackView всеми элементами в правильном порядке
    private func populateStackView() {
        // Очищаем существующие элементы
        mainStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // 0. Connection status banner (самый первый элемент)
        if let statusBanner = connectionStatusBanner {
            mainStackView.addArrangedSubview(statusBanner)
        }

        // 0.5. Заголовок Protocol Settings
        if let protocolHeader = protocolSettingsLabel {
            let containerView = UIView()
            containerView.addSubview(protocolHeader)
            protocolHeader.snp.makeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.leading.equalToSuperview().offset(4)
                make.trailing.equalToSuperview().offset(-4)
                make.height.equalTo(30)
            }
            mainStackView.addArrangedSubview(containerView)
        }

        // 0.6. Note текст
        if let noteLabel = protocolNoteLabel {
            mainStackView.addArrangedSubview(noteLabel)

            // Добавляем отступы для Note через пустой UIView
            let spacerAfterNote = UIView()
            spacerAfterNote.snp.makeConstraints { make in
                make.height.equalTo(8)
            }
            mainStackView.addArrangedSubview(spacerAfterNote)
        }

        // 1. Module ID field + индикатор
        if let moduleIdView = moduleIdSettingItemView, let moduleIdLabel = moduleIdStatusLabel {
            let container = createSettingContainer(settingView: moduleIdView, statusLabel: moduleIdLabel)
            moduleIdContainer = container
            mainStackView.addArrangedSubview(container)
        }
        
        // 2. CAN Protocol field + индикатор
        if let canView = canProtocolView, let canLabel = canProtocolStatusLabel {
            let container = createSettingContainer(settingView: canView, statusLabel: canLabel)
            canProtocolContainer = container
            mainStackView.addArrangedSubview(container)
        }
        
        // 3. RS485 Protocol field + индикатор
        if let rs485View = rs485ProtocolView, let rs485Label = rs485ProtocolStatusLabel {
            let container = createSettingContainer(settingView: rs485View, statusLabel: rs485Label)
            rs485ProtocolContainer = container
            mainStackView.addArrangedSubview(container)
        }

        // 3.5. Заголовок Application Information
        if let appInfoHeader = applicationInfoLabel {
            let containerView = UIView()
            containerView.addSubview(appInfoHeader)
            appInfoHeader.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(10)
                make.bottom.equalToSuperview()
                make.leading.equalToSuperview().offset(4)
                make.trailing.equalToSuperview().offset(-4)
                make.height.equalTo(30)
            }
            mainStackView.addArrangedSubview(containerView)
        }

        // 4. Version field (последнее поле настроек, без контейнера, так как нет индикатора)
        if let versionView = versionItemView {
            mainStackView.addArrangedSubview(versionView)
        }
        
        // 5. Refresh Connection button (после Version field)
        // if let refreshButton = refreshConnectionButton {
        //     mainStackView.addArrangedSubview(refreshButton)
        // }
        
        // 6. Spacer для отталкивания нижних элементов
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        mainStackView.addArrangedSubview(spacer)
        
        // 7. Тестовые кнопки (временно)
        // Будут добавлены отдельно в setupTestButtons()
        
        // 8. Save кнопка
        if let saveBtn = saveButton {
            mainStackView.addArrangedSubview(saveBtn)
        }
        
        // 9. Информационный баннер
        if let bannerView = informationBannerView {
            mainStackView.addArrangedSubview(bannerView)
        }
    }
    
    /// Обновленные методы показа/скрытия индикаторов с поддержкой UIStackView анимаций
    private func showStatusIndicatorWithStackView(label: UILabel, selectedValue: String) {
        label.text = "Selected: \(selectedValue) - Click 'Save' below, then restart the battery and reconnect to the app to verify changes."
        label.isHidden = false

        // Анимированное появление с автоматическим перестроением layout
        label.alpha = 0
        UIView.animate(withDuration: 0.3) {
            label.alpha = 1
            // UIStackView автоматически перестроит layout
            self.view.layoutIfNeeded()
        }
    }
    
    /// Скрывает индикатор с анимацией UIStackView
    private func hideStatusIndicatorWithStackView(label: UILabel) {
        UIView.animate(withDuration: 0.3) {
            label.alpha = 0
            self.view.layoutIfNeeded()
        } completion: { _ in
            label.isHidden = true
        }
    }
    
    // MARK: - StackView Setup Methods
    
    /// Создает индикаторы статуса для использования в StackView (без constraints)
    private func setupStatusIndicatorsForStackView() {
        // Создаем индикатор для Module ID
        let moduleIdLabel = createStatusLabel()
        moduleIdStatusLabel = moduleIdLabel
        
        // Создаем индикатор для CAN Protocol
        let canLabel = createStatusLabel()
        canProtocolStatusLabel = canLabel
        
        // Создаем индикатор для RS485 Protocol
        let rs485Label = createStatusLabel()
        rs485ProtocolStatusLabel = rs485Label
        
        // Не добавляем в view и не настраиваем constraints - они будут в контейнерах
    }
    
    /// Создает кнопку Save для использования в StackView (без constraints)
    private func setupSaveButtonForStackView() {
        // Создаем кнопку Save
        let button = UIButton(type: .system)
        button.setTitle("Save", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.clipsToBounds = true
        
        // Добавляем тень для эффекта глубины
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.1
        button.layer.shadowRadius = 4
        button.layer.masksToBounds = false
        
        // Добавляем действие для кнопки
        button.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        
        // Устанавливаем фиксированную высоту для StackView
        button.snp.makeConstraints { make in
            make.height.equalTo(50)
        }
        
        // Сохраняем ссылку на кнопку
        self.saveButton = button
        
        // Устанавливаем начальное состояние кнопки (неактивная)
        updateSaveButtonState()
    }
    
    /// Создает информационный баннер для использования в StackView (без constraints)
    private func setupInformationBannerForStackView() {
        // Создаем контейнер для баннера
        let bannerContainer = UIView()
        bannerContainer.backgroundColor = UIColor.white.withAlphaComponent(0.95)
        bannerContainer.layer.cornerRadius = 12
        bannerContainer.clipsToBounds = true

        // Добавляем тень для эффекта глубины
        bannerContainer.layer.shadowColor = UIColor.black.cgColor
        bannerContainer.layer.shadowOffset = CGSize(width: 0, height: -2)
        bannerContainer.layer.shadowOpacity = 0.15
        bannerContainer.layer.shadowRadius = 4
        bannerContainer.layer.masksToBounds = false

        // Создаем текстовый лейбл
        let messageLabel = UILabel()
        messageLabel.text = "You must restart the battery using the power button after saving, then reconnect to the app to verify changes."
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.font = .systemFont(ofSize: 12, weight: .medium)
        messageLabel.textColor = .black
        
        // Добавляем лейбл в контейнер
        bannerContainer.addSubview(messageLabel)
        
        // Настраиваем constraints только внутри контейнера
        bannerContainer.snp.makeConstraints { make in
            make.height.equalTo(60)
        }
        
        messageLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }
        
        // Сохраняем ссылку на баннер
        self.informationBannerView = bannerContainer
    }
    
    /// Создает кнопку Refresh Connection для использования в StackView (без constraints)
    private func setupRefreshConnectionButtonForStackView() {
        // Создаем кнопку Refresh Connection в стиле Secondary
        let button = UIButton(type: .system)
        button.setTitle("🔄 Refresh Connection", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = UIColor.white
        button.setTitleColor(.systemBlue, for: .normal)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemBlue.cgColor
        button.clipsToBounds = true
        
        // Добавляем тень для эффекта глубины
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowOpacity = 0.1
        button.layer.shadowRadius = 2
        button.layer.masksToBounds = false
        
        // Добавляем действие для кнопки
        button.addTarget(self, action: #selector(refreshConnectionTapped), for: .touchUpInside)
        
        // Устанавливаем фиксированную высоту для StackView
        button.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
        
        // Сохраняем ссылку на кнопку
        self.refreshConnectionButton = button
    }

    /// Создает баннер статуса подключения для использования в StackView
    private func setupConnectionStatusBannerForStackView() {
        // Создаем контейнер для баннера
        let bannerContainer = UIView()
        bannerContainer.backgroundColor = UIColor.white
        bannerContainer.layer.cornerRadius = 12
        bannerContainer.clipsToBounds = true
        bannerContainer.layer.borderWidth = 2
        bannerContainer.layer.borderColor = UIColor.red.cgColor

        // Создаем иконку Bluetooth
        let bluetoothImageView = UIImageView(image: R.image.homeBluetooth())
        bluetoothImageView.contentMode = .scaleAspectFit
        bluetoothImageView.tintColor = .systemBlue

        // Создаем текстовый лейбл
        let statusLabel = UILabel()
        statusLabel.text = "Not Connected"
        statusLabel.textAlignment = .center
        statusLabel.font = .systemFont(ofSize: 18, weight: .medium)
        statusLabel.textColor = .black
        statusLabel.tag = 100 // Тег для идентификации лейбла при обновлении

        // Добавляем элементы в иерархию
        bannerContainer.addSubview(bluetoothImageView)
        bannerContainer.addSubview(statusLabel)

        // Настраиваем ограничения
        bluetoothImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }

        statusLabel.snp.makeConstraints { make in
            make.leading.equalTo(bluetoothImageView.snp.trailing).offset(16)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview().offset(-16)
        }

        // Устанавливаем фиксированную высоту для StackView
        bannerContainer.snp.makeConstraints { make in
            make.height.equalTo(40)
        }

        // Сохраняем ссылку на баннер
        self.connectionStatusBanner = bannerContainer

        // Устанавливаем начальное состояние на основе текущего подключения
        let peripheral = try? ZetaraManager.shared.connectedPeripheralSubject.value()
        let isConnected = peripheral != nil
        updateConnectionStatus(isConnected: isConnected)
    }

    /// Обновляет внешний вид баннера статуса подключения
    /// - Parameter isConnected: Статус подключения батареи
    private func updateConnectionStatus(isConnected: Bool) {
        guard let banner = connectionStatusBanner,
              let statusLabel = banner.viewWithTag(100) as? UILabel else { return }

        UIView.animate(withDuration: 0.3) {
            if isConnected {
                // Подключено: зеленая рамка, белый фон
                banner.layer.borderColor = UIColor.systemGreen.cgColor
                banner.backgroundColor = UIColor.white
                statusLabel.text = "Connected"
                statusLabel.textColor = .black
            } else {
                // Не подключено: красная рамка, красный полупрозрачный фон
                banner.layer.borderColor = UIColor.red.cgColor
                banner.backgroundColor = UIColor.red.withAlphaComponent(0.1)
                statusLabel.text = "Not Connected"
                statusLabel.textColor = .black
            }
        }
    }

    /// Создает заголовки секций для использования в StackView
    private func setupSectionHeaders() {
        // Заголовок Protocol Settings
        let protocolLabel = UILabel()
        protocolLabel.text = "Protocol Settings"
        protocolLabel.font = .systemFont(ofSize: 24, weight: .bold)
        protocolLabel.textColor = .black
        protocolLabel.textAlignment = .left
        self.protocolSettingsLabel = protocolLabel

        // Note текст с форматированием
        let noteLabel = UILabel()
        let noteText = "Note: The battery connected directly to the inverter or meter via the communication cable must be set to ID1. All other batteries should be assigned unique IDs (ID2, ID3, etc.)."

        let attributedString = NSMutableAttributedString(string: noteText)

        // Базовые атрибуты для всего текста
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor(red: 0x80/255.0, green: 0x80/255.0, blue: 0x80/255.0, alpha: 1.0)
        ]
        attributedString.addAttributes(baseAttributes, range: NSRange(location: 0, length: noteText.count))

        // Выделяем "Note:" жирным
        if let noteRange = noteText.range(of: "Note:") {
            let nsRange = NSRange(noteRange, in: noteText)
            attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 12, weight: .bold), range: nsRange)
        }

        // Выделяем "ID1" жирным
        if let id1Range = noteText.range(of: "ID1") {
            let nsRange = NSRange(id1Range, in: noteText)
            attributedString.addAttribute(.font, value: UIFont.systemFont(ofSize: 12, weight: .bold), range: nsRange)
        }

        noteLabel.attributedText = attributedString
        noteLabel.numberOfLines = 0
        noteLabel.lineBreakMode = .byWordWrapping
        noteLabel.textAlignment = .left
        self.protocolNoteLabel = noteLabel

        // Заголовок Application Information
        let appInfoLabel = UILabel()
        appInfoLabel.text = "Application Information"
        appInfoLabel.font = .systemFont(ofSize: 24, weight: .bold)
        appInfoLabel.textColor = .black
        appInfoLabel.textAlignment = .left
        self.applicationInfoLabel = appInfoLabel
    }

    /// Создает тестовые кнопки для использования в StackView
    private func setupTestButtonsForStackView() {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 8
        
        let testButton1 = createTestButton(title: "Test Module ID", action: #selector(testModuleIdTapped))
        let testButton2 = createTestButton(title: "Test CAN", action: #selector(testCANTapped))
        let testButton3 = createTestButton(title: "Test RS485", action: #selector(testRS485Tapped))
        
        stackView.addArrangedSubview(testButton1)
        stackView.addArrangedSubview(testButton2)
        stackView.addArrangedSubview(testButton3)
        
        // Устанавливаем фиксированную высоту для StackView
        stackView.snp.makeConstraints { make in
            make.height.equalTo(40)
        }
        
        // Добавляем в основной StackView
        if let spacerIndex = mainStackView.arrangedSubviews.firstIndex(where: { $0.subviews.isEmpty }) {
            mainStackView.insertArrangedSubview(stackView, at: spacerIndex)
        }
    }
}
