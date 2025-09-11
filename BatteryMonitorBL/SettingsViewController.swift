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
        
        // Добавляем фоновое изображение
        let backgroundImageView = UIImageView(image: R.image.background())
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.frame = view.bounds
        backgroundImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(backgroundImageView)
        view.sendSubviewToBack(backgroundImageView)
        
        moduleIdSettingItemView?.title = "Module ID"
        moduleIdSettingItemView?.options = Zetara.Data.ModuleIdControlData.readableIds()
        moduleIdSettingItemView?.selectedOptionIndex
            .skip(1)
            .subscribe {[weak self] index in
                // Отмечаем, что есть несохраненные изменения
                self?.hasUnsavedChanges = true
                self?.setModuleId(at:index)
        }.disposed(by: disposeBag)
        
        versionItemView?.title = "Version"
        versionItemView?.label = version()
        versionItemView?.options = [] // Явно устанавливаем пустой массив опций, чтобы скрыть стрелочку
        
        canProtocolView?.title = "CAN Protocol"
        canProtocolView?.options = []
        canProtocolView?.selectedOptionIndex
            .skip(1)
            .subscribe { [weak self] index in
                // Отмечаем, что есть несохраненные изменения
                self?.hasUnsavedChanges = true
                self?.setCAN(at: index)
            }.disposed(by: disposeBag)
        
        rs485ProtocolView?.title = "RS485 Protocol"
        rs485ProtocolView?.options = []
        rs485ProtocolView?.selectedOptionIndex
            .skip(1)
            .subscribe { [weak self] index in
                // Отмечаем, что есть несохраненные изменения
                self?.hasUnsavedChanges = true
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
                self?.canProtocolView?.label = nil
                self?.rs485ProtocolView?.label = nil
                self?.canData = nil
                self?.rs485Data = nil
                self?.moduleIdSettingItemView?.label = nil
            }.disposed(by: disposeBag)
        
//        self.moduleIdSettingItemView.selectedOptionIndex
//            .map { $0 == 0 }
//            .bind(to: self.canProtocolView.optionsButton.rx.isEnabled,
//                  self.rs485ProtocolView.optionsButton.rx.isEnabled)
//            .disposed(by: disposeBag)
        
        self.toggleRS485AndCAN(false)
        
        // Создаем отдельные индикаторы статуса (без constraints - они будут в контейнерах)
        setupStatusIndicatorsForStackView()
        
        // Добавляем кнопку Save (без constraints - будет в StackView)
        setupSaveButtonForStackView()
        
        // Добавляем информационный баннер (без constraints - будет в StackView)
        setupInformationBannerForStackView()
        
        // Создаем и настраиваем основной UIStackView
        setupMainStackView()
        
        // Заполняем StackView всеми элементами
        populateStackView()
        
        // Добавляем тестовые кнопки для демонстрации индикаторов
        // setupTestButtonsForStackView()
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
        label.textColor = .systemOrange
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
            // Неактивное состояние - серая кнопка
            button.isEnabled = false
            button.backgroundColor = UIColor.systemGray4
            button.alpha = 0.6
        }
    }
    
    /// Обработчик нажатия на кнопку Save
    @objc private func saveButtonTapped() {
        // Показываем упрощенный алерт с основным сообщением
        let alert = UIAlertController(
            title: "Settings Saved",
            message: "Settings will only be applied after restarting the battery",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Understood", style: .default) { [weak self] _ in
            // После подтверждения сбрасываем флаг несохраненных изменений
            self?.hasUnsavedChanges = false
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
    
    func toggleRS485AndCAN(_ enabled: Bool) {
        self.rs485ProtocolView?.optionsButton.isEnabled = enabled
        self.canProtocolView?.optionsButton.isEnabled = enabled
    }
    
    func getAllSettings() {
        Alert.show("Loading...", timeout: 3)
        
        // 一个一个来
        self.getModuleId().subscribe { [weak self] idData in
            Alert.hide()
            self?.moduleIdData = idData
            self?.moduleIdSettingItemView?.label = idData.readableId()
            self?.toggleRS485AndCAN(idData.otherProtocolsEnabled())
            self?.getRS485().subscribe(onSuccess: { [weak self] rs485 in
                Alert.hide()
                self?.rs485Data = rs485
                self?.rs485ProtocolView?.options = rs485.readableProtocols()
                self?.rs485ProtocolView?.label = rs485.readableProtocol()
                self?.getCAN().subscribe(onSuccess: { can in
                    Alert.hide()
                    self?.canData = can
                    self?.canProtocolView?.options = can.readableProtocols()
                    self?.canProtocolView?.label = can.readableProtocol()
                }, onError: { error in
                    Alert.hide()
//                    Alert.show("Invalid Response")
                })
            }, onError: { error in
                Alert.hide()
//                Alert.show("Invalid Response")
            })
        } onError: { error in
            Alert.hide()
//            Alert.show("Invalid Response")
        }.disposed(by: self.disposeBag)
    }
    
    func setModuleId(at index: Int) {
        Alert.show("Setting, please wait patiently", timeout: 3)
        // module id 从 1 开始的
        ZetaraManager.shared.setModuleId(index + 1)
            .subscribeOn(MainScheduler.instance)
            .timeout(.seconds(3), scheduler: MainScheduler.instance)
            .subscribe { [weak self] (success: Bool) in
                Alert.hide()
                if success, let idData = self?.moduleIdData {
                    let selectedValue = idData.readableId(at: index)
                    self?.moduleIdSettingItemView?.label = selectedValue
                    self?.toggleRS485AndCAN(index == 0) // 这里是 0 ，因为这里的 id 从 0 开始
                    
                    // Показываем индикатор подтверждения выбора с помощью отдельного лейбла
                    if let statusLabel = self?.moduleIdStatusLabel {
                        self?.showStatusIndicatorWithStackView(label: statusLabel, selectedValue: selectedValue)
                    }
                } else {
                    Alert.show("Set module id failed")
                }
            } onError: { _ in
                Alert.hide()
                Alert.show("Set module id error")
                
//                self?.moduleIdSettingItemView.set(label: "ID\(id + 1)")
//                self?.toggleRS485AndCAN(id == 0) // 这里是 0 ，因为这里的 id 从 0 开始
                
            }.disposed(by: disposeBag)
    }
    
    func setRS485(at index: Int) {
        Alert.show("Setting, please wait patiently", timeout: 3)
        ZetaraManager.shared.setRS485(index)
            .subscribeOn(MainScheduler.instance)
            .timeout(.seconds(3), scheduler: MainScheduler.instance)
            .subscribe { [weak self] success in
                Alert.hide()
                if success, let rs485 = self?.rs485Data {
                    let selectedValue = rs485.readableProtocol(at: index)
                    self?.rs485ProtocolView?.label = selectedValue
                    
                    // Показываем индикатор подтверждения выбора с помощью отдельного лейбла
                    if let statusLabel = self?.rs485ProtocolStatusLabel {
                        self?.showStatusIndicatorWithStackView(label: statusLabel, selectedValue: selectedValue)
                    }
                } else {
                    self?.rs485ProtocolView?.label = "fail"
                }
            } onError: { [weak self] _ in
                Alert.hide()
                self?.rs485ProtocolView?.label = "error"
            }.disposed(by: disposeBag)
    }
    
    func setCAN(at index: Int) {
        Alert.show("Setting, please wait patiently", timeout: 3)
        ZetaraManager.shared.setCAN(index)
            .subscribeOn(MainScheduler.instance)
            .timeout(.seconds(3), scheduler: MainScheduler.instance)
            .subscribe { [weak self] success in
                Alert.hide()
                if success, let can = self?.canData {
                    let selectedValue = can.readableProtocol(at: index)
                    self?.canProtocolView?.label = selectedValue
                    
                    // Показываем индикатор подтверждения выбора с помощью отдельного лейбла
                    if let statusLabel = self?.canProtocolStatusLabel {
                        self?.showStatusIndicatorWithStackView(label: statusLabel, selectedValue: selectedValue)
                    }
                } else {
                    self?.canProtocolView?.label = "fail"
                }
            } onError: { [weak self] _ in
                Alert.hide()
                self?.canProtocolView?.label = "error"
            }.disposed(by: disposeBag)
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
        mainStackView = UIStackView()
        mainStackView.axis = .vertical
        mainStackView.distribution = .fill
        mainStackView.alignment = .fill
        mainStackView.spacing = 16
        
        view.addSubview(mainStackView)
        mainStackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(20)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
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
        
        // 1. Version field (без контейнера, так как нет индикатора)
        if let versionView = versionItemView {
            mainStackView.addArrangedSubview(versionView)
        }
        
        // 2. Module ID field + индикатор
        if let moduleIdView = moduleIdSettingItemView, let moduleIdLabel = moduleIdStatusLabel {
            let container = createSettingContainer(settingView: moduleIdView, statusLabel: moduleIdLabel)
            moduleIdContainer = container
            mainStackView.addArrangedSubview(container)
        }
        
        // 3. CAN Protocol field + индикатор
        if let canView = canProtocolView, let canLabel = canProtocolStatusLabel {
            let container = createSettingContainer(settingView: canView, statusLabel: canLabel)
            canProtocolContainer = container
            mainStackView.addArrangedSubview(container)
        }
        
        // 4. RS485 Protocol field + индикатор
        if let rs485View = rs485ProtocolView, let rs485Label = rs485ProtocolStatusLabel {
            let container = createSettingContainer(settingView: rs485View, statusLabel: rs485Label)
            rs485ProtocolContainer = container
            mainStackView.addArrangedSubview(container)
        }
        
        // 5. Spacer для отталкивания нижних элементов
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        mainStackView.addArrangedSubview(spacer)
        
        // 6. Тестовые кнопки (временно)
        // Будут добавлены отдельно в setupTestButtons()
        
        // 7. Save кнопка
        if let saveBtn = saveButton {
            mainStackView.addArrangedSubview(saveBtn)
        }
        
        // 8. Информационный баннер
        if let bannerView = informationBannerView {
            mainStackView.addArrangedSubview(bannerView)
        }
    }
    
    /// Обновленные методы показа/скрытия индикаторов с поддержкой UIStackView анимаций
    private func showStatusIndicatorWithStackView(label: UILabel, selectedValue: String) {
        label.text = "Selected: \(selectedValue) – Restart the battery to apply changes"
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
        messageLabel.text = "Changes will only take effect after\nrestarting the battery"
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 2
        messageLabel.font = .systemFont(ofSize: 16, weight: .medium)
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
