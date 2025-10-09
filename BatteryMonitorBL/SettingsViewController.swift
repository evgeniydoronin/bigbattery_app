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
import class BatteryMonitorBL.HeaderLogoView
import class BatteryMonitorBL.ConnectionStatusBanner

class SettingsViewController: UIViewController {

    // Компонент для белой шапки с логотипом BigBattery
    private let headerLogoView = HeaderLogoView()

    // Connection Status Banner
    private let connectionStatusBanner = ConnectionStatusBanner()

    // Protocol Settings Header
    private let protocolSettingsHeader: UILabel = {
        let label = UILabel()
        label.text = "Protocol Settings"
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .black
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // Note Label
    private let noteLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // Application Information Header
    private let applicationInfoHeader: UILabel = {
        let label = UILabel()
        label.text = "Application Information"
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .black
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // Save Button
    private let saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Save", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false

        // Тень
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.1
        button.layer.shadowRadius = 4

        // Изначально inactive
        button.isEnabled = false
        button.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
        button.setTitleColor(.white, for: .normal)

        return button
    }()

    // Information Banner
    private let informationBanner: UIView = {
        let container = UIView()
        container.backgroundColor = UIColor.white.withAlphaComponent(0.95)
        container.layer.cornerRadius = 12
        container.translatesAutoresizingMaskIntoConstraints = false

        // Message Label
        let messageLabel = UILabel()
        messageLabel.text = "You must restart the battery using the power button after saving, then reconnect to the app to verify changes."
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.font = .systemFont(ofSize: 10, weight: .medium)
        messageLabel.textColor = .black
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(messageLabel)
        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            messageLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            messageLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16)
        ])

        return container
    }()

    // ScrollView для контента
    private let scrollView = UIScrollView()

    // StackView с настройками (находится программно из Storyboard)
    private var settingsStackView: UIStackView?

    // Status Indicators (серый текст под каждым setting card)
    private let moduleIdStatusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(red: 0x80/255.0, green: 0x80/255.0, blue: 0x80/255.0, alpha: 1.0)
        label.textAlignment = .left
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true // Изначально скрыт через isHidden
        label.alpha = 0
        return label
    }()

    private let canStatusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(red: 0x80/255.0, green: 0x80/255.0, blue: 0x80/255.0, alpha: 1.0)
        label.textAlignment = .left
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true // Изначально скрыт через isHidden
        label.alpha = 0
        return label
    }()

    private let rs485StatusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(red: 0x80/255.0, green: 0x80/255.0, blue: 0x80/255.0, alpha: 1.0)
        label.textAlignment = .left
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true // Изначально скрыт через isHidden
        label.alpha = 0
        return label
    }()

    @IBOutlet weak var versionItemView: SettingItemView?
    @IBOutlet weak var moduleIdSettingItemView: SettingItemView?
    @IBOutlet weak var canProtocolView: SettingItemView?
    @IBOutlet weak var rs485ProtocolView: SettingItemView?

    private var moduleIdData: Zetara.Data.ModuleIdControlData?
    private var rs485Data: Zetara.Data.RS485ControlData?
    private var canData: Zetara.Data.CANControlData?

    // Tracking pending changes (nil = no change)
    private var pendingModuleIdIndex: Int?
    private var pendingCANIndex: Int?
    private var pendingRS485Index: Int?

    // Flag to prevent showing status indicators during data loading
    private var isLoadingData = false

    // Restart popup properties
    private var restartPopupOverlay: UIView?
    private var restartPopupTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Добавляем фоновое изображение
        let backgroundImageView = UIImageView(image: R.image.background())
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.frame = view.bounds
        backgroundImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(backgroundImageView)
        view.sendSubviewToBack(backgroundImageView)

        // Добавляем шапку с логотипом (переиспользуемый компонент)
        view.addSubview(headerLogoView)
        headerLogoView.setupConstraints(in: view)
        view.bringSubviewToFront(headerLogoView)

        // Скрываем navigation bar
        self.navigationController?.setNavigationBarHidden(true, animated: false)

        // Находим stackView программно (он уже создан в Storyboard)
        if let stackView = view.subviews.first(where: { $0 is UIStackView }) as? UIStackView {
            print("[SETTINGS] ✅ Found stackView programmatically")
            settingsStackView = stackView
            // Настраиваем ScrollView для контента
            setupScrollView()
        } else {
            print("[SETTINGS] ❌ stackView not found in view.subviews!")
        }

        // Module ID Setting (синий)
        moduleIdSettingItemView?.title = "Module ID"
        moduleIdSettingItemView?.subtitle = "BMS module identifier"
        moduleIdSettingItemView?.icon = UIImage(systemName: "gearshape.fill")
        moduleIdSettingItemView?.iconColor = UIColor(red: 0x16/255.0, green: 0x5E/255.0, blue: 0xA0/255.0, alpha: 1.0)
        moduleIdSettingItemView?.options = Zetara.Data.ModuleIdControlData.readableIds()
        moduleIdSettingItemView?.selectedOptionIndex
            .skip(1)
            .subscribe {[weak self] index in
                guard let self = self else { return }
                // Skip if we're just loading data from battery
                guard !self.isLoadingData else { return }
                // Track pending change
                self.pendingModuleIdIndex = index
                // Get selected value name
                let selectedValue = self.moduleIdData?.readableId(at: index) ?? "ID\(index + 1)"
                // Update card label
                self.moduleIdSettingItemView?.label = selectedValue
                // Update and show status indicator
                self.moduleIdStatusLabel.text = "Selected: \(selectedValue) - Click 'Save' below, then restart the battery and reconnect to the app to verify changes."
                self.showStatusLabel(self.moduleIdStatusLabel)
                // Activate Save button
                self.activateSaveButton()
        }.disposed(by: disposeBag)

        // CAN Protocol Setting (зеленый)
        canProtocolView?.title = "CAN Protocol"
        canProtocolView?.subtitle = "Controller area network protocol"
        canProtocolView?.icon = UIImage(systemName: "gearshape.fill")
        canProtocolView?.iconColor = UIColor(red: 0x12/255.0, green: 0xC0/255.0, blue: 0x4C/255.0, alpha: 1.0)
        canProtocolView?.options = []
        canProtocolView?.selectedOptionIndex
            .skip(1)
            .subscribe { [weak self] index in
                guard let self = self else { return }
                // Skip if we're just loading data from battery
                guard !self.isLoadingData else { return }
                // Track pending change
                self.pendingCANIndex = index
                // Get selected value name
                let selectedValue = self.canData?.readableProtocol(at: index) ?? "Protocol \(index)"
                // Update card label
                self.canProtocolView?.label = selectedValue
                // Update and show status indicator
                self.canStatusLabel.text = "Selected: \(selectedValue) - Click 'Save' below, then restart the battery and reconnect to the app to verify changes."
                self.showStatusLabel(self.canStatusLabel)
                // Activate Save button
                self.activateSaveButton()
            }.disposed(by: disposeBag)

        // RS485 Protocol Setting (красный)
        rs485ProtocolView?.title = "RS485 Protocol"
        rs485ProtocolView?.subtitle = "Serial communication protocol"
        rs485ProtocolView?.icon = UIImage(systemName: "gearshape.fill")
        rs485ProtocolView?.iconColor = UIColor(red: 0xED/255.0, green: 0x10/255.0, blue: 0x00/255.0, alpha: 1.0)
        rs485ProtocolView?.options = []
        rs485ProtocolView?.selectedOptionIndex
            .skip(1)
            .subscribe { [weak self] index in
                guard let self = self else { return }
                // Skip if we're just loading data from battery
                guard !self.isLoadingData else { return }
                // Track pending change
                self.pendingRS485Index = index
                // Get selected value name
                let selectedValue = self.rs485Data?.readableProtocol(at: index) ?? "Protocol \(index)"
                // Update card label
                self.rs485ProtocolView?.label = selectedValue
                // Update and show status indicator
                self.rs485StatusLabel.text = "Selected: \(selectedValue) - Click 'Save' below, then restart the battery and reconnect to the app to verify changes."
                self.showStatusLabel(self.rs485StatusLabel)
                // Activate Save button
                self.activateSaveButton()
        }.disposed(by: disposeBag)

        // Version Setting (синий bluetooth icon)
        versionItemView?.title = "App Version"
        versionItemView?.subtitle = "BigBattery Husky 2"
        versionItemView?.icon = R.image.homeBluetooth()
        versionItemView?.iconColor = .systemBlue
        versionItemView?.label = version()
        versionItemView?.options = [] // Явно устанавливаем пустой массив опций, чтобы скрыть стрелочку
        
        // Настраиваем подписки на ProtocolDataManager один раз
        getAllSettings()

        // 进入设置页，就暂停 bms data 刷新，离开恢复
        self.rx.isVisible.subscribe { [weak self] (visible: Bool) in
            print("visible change")
            if visible {
                ZetaraManager.shared.pauseRefreshBMSData()

                // Загружаем протоколы если подключено и данные пустые
                let deviceConnected = (try? ZetaraManager.shared.connectedPeripheralSubject.value()) != nil
                let protocolDataIsEmpty = (self?.canData == nil || self?.rs485Data == nil || self?.moduleIdData == nil)
                if deviceConnected && protocolDataIsEmpty {
                    ZetaraManager.shared.protocolDataManager.logProtocolEvent("[SETTINGS] Loading protocols via ProtocolDataManager")
                    self?.isLoadingData = true
                    ZetaraManager.shared.protocolDataManager.loadAllProtocols(afterDelay: 0.5)
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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Скрываем navigation bar при возвращении на экран
        self.navigationController?.setNavigationBarHidden(true, animated: animated)

        // Загружаем протоколы если подключено и данные пустые
        if ZetaraManager.shared.connectedPeripheral() != nil {
            let protocolDataIsEmpty = (canData == nil || rs485Data == nil || moduleIdData == nil)
            if protocolDataIsEmpty {
                ZetaraManager.shared.protocolDataManager.logProtocolEvent("[SETTINGS] Loading protocols via ProtocolDataManager in viewWillAppear")
                isLoadingData = true
                ZetaraManager.shared.protocolDataManager.loadAllProtocols(afterDelay: 0.5)
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        print("[SETTINGS] View will disappear - cancelling pending requests")

        // Отменяем все текущие подписки
        disposeBag = DisposeBag()
    }

    // MARK: - Setup ScrollView

    private func setupScrollView() {
        guard let stackView = settingsStackView else {
            print("[SETTINGS] ⚠️ settingsStackView is nil - check Storyboard outlet connection!")
            return
        }

        // Настраиваем ScrollView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        // Constraints для ScrollView: под header, над tabbar
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: headerLogoView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        // Добавляем Connection Status Banner в scrollView
        connectionStatusBanner.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(connectionStatusBanner)

        // Constraints для Connection Status Banner (margins 30pt как у StackView)
        NSLayoutConstraint.activate([
            connectionStatusBanner.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            connectionStatusBanner.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 30),
            connectionStatusBanner.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -30),
            connectionStatusBanner.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -60), // -60 = -30*2
            connectionStatusBanner.heightAnchor.constraint(equalToConstant: 40)
        ])

        // Удаляем stackView из superview и все его constraints
        stackView.removeFromSuperview()

        // Извлекаем versionItemView из stackView (последний элемент)
        let versionView = stackView.arrangedSubviews.last
        if let versionView = versionView {
            stackView.removeArrangedSubview(versionView)
            versionView.removeFromSuperview()
        }

        // Добавляем Protocol Settings Header (margins 30pt)
        scrollView.addSubview(protocolSettingsHeader)
        NSLayoutConstraint.activate([
            protocolSettingsHeader.topAnchor.constraint(equalTo: connectionStatusBanner.bottomAnchor, constant: 16),
            protocolSettingsHeader.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 30),
            protocolSettingsHeader.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -30),
            protocolSettingsHeader.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -60), // -60 = -30*2
            protocolSettingsHeader.heightAnchor.constraint(equalToConstant: 30)
        ])

        // Настраиваем форматирование для Note Label
        setupNoteLabel()

        // Добавляем Note Label (margins 30pt как у StackView)
        scrollView.addSubview(noteLabel)
        NSLayoutConstraint.activate([
            noteLabel.topAnchor.constraint(equalTo: protocolSettingsHeader.bottomAnchor, constant: 8),
            noteLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 30),
            noteLabel.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -30),
            noteLabel.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -60) // -60 = -30*2
        ])

        // Добавляем stackView в scrollView (теперь только 3 элемента протоколов)
        scrollView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        // Constraints для stackView (без bottomAnchor к scrollView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: noteLabel.bottomAnchor, constant: 16), // 8pt spacer + 8pt margin
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 30),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -30),
            // Важно: ширина stackView = ширина scrollView для правильного скроллинга
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -60) // -60 = -30*2 (margins)
        ])

        // Добавляем Status Indicators в stackView как arrangedSubviews
        // Они будут автоматически двигать остальные элементы при показе/скрытии
        // arrangedSubviews[0] = moduleIdSettingItemView
        // arrangedSubviews[1] = canProtocolView
        // arrangedSubviews[2] = rs485ProtocolView

        // Добавляем status labels после соответствующих карточек
        if stackView.arrangedSubviews.count >= 3 {
            // Вставляем в обратном порядке, чтобы индексы не сбивались
            stackView.insertArrangedSubview(rs485StatusLabel, at: 3) // После rs485ProtocolView
            stackView.insertArrangedSubview(canStatusLabel, at: 2)   // После canProtocolView
            stackView.insertArrangedSubview(moduleIdStatusLabel, at: 1) // После moduleIdSettingItemView
        }

        // Добавляем Application Information Header после stackView (margins 30pt)
        scrollView.addSubview(applicationInfoHeader)
        NSLayoutConstraint.activate([
            applicationInfoHeader.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 26), // 16 обычный + 10 дополнительный
            applicationInfoHeader.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 30),
            applicationInfoHeader.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -30),
            applicationInfoHeader.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -60), // -60 = -30*2
            applicationInfoHeader.heightAnchor.constraint(equalToConstant: 30)
        ])

        // Добавляем Version после Application Information Header
        if let versionView = versionView {
            versionView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.addSubview(versionView)

            NSLayoutConstraint.activate([
                versionView.topAnchor.constraint(equalTo: applicationInfoHeader.bottomAnchor, constant: 8),
                versionView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 30),
                versionView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -30),
                versionView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -60),
                versionView.heightAnchor.constraint(equalToConstant: 60)
            ])

            // Добавляем Save Button после Version (margins 30pt)
            scrollView.addSubview(saveButton)
            saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
            NSLayoutConstraint.activate([
                saveButton.topAnchor.constraint(equalTo: versionView.bottomAnchor, constant: 16),
                saveButton.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 30),
                saveButton.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -30),
                saveButton.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -60),
                saveButton.heightAnchor.constraint(equalToConstant: 50)
            ])

            // Добавляем Information Banner после Save Button (margins 30pt)
            scrollView.addSubview(informationBanner)
            NSLayoutConstraint.activate([
                informationBanner.topAnchor.constraint(equalTo: saveButton.bottomAnchor, constant: 16),
                informationBanner.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 30),
                informationBanner.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -30),
                informationBanner.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -60),
                informationBanner.heightAnchor.constraint(equalToConstant: 60),
                informationBanner.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24)
            ])
        }

        // Подписываемся на изменения подключения
        setupConnectionStatusObserver()

        print("[SETTINGS] ✅ ScrollView configured successfully")
    }

    private func setupNoteLabel() {
        let noteText = "Note: The battery connected directly to the inverter or meter via the communication cable must be set to ID1. All other batteries should be assigned unique IDs (ID2, ID3, etc.)."

        // Создаем attributed string
        let attributedString = NSMutableAttributedString(string: noteText)

        // Базовые атрибуты (серый цвет, 12pt)
        let grayColor = UIColor(red: 0x80/255.0, green: 0x80/255.0, blue: 0x80/255.0, alpha: 1.0)
        let normalFont = UIFont.systemFont(ofSize: 12)
        let boldFont = UIFont.systemFont(ofSize: 12, weight: .bold)

        attributedString.addAttributes([
            .font: normalFont,
            .foregroundColor: grayColor
        ], range: NSRange(location: 0, length: noteText.count))

        // Делаем "Note:" жирным
        if let noteRange = noteText.range(of: "Note:") {
            let nsRange = NSRange(noteRange, in: noteText)
            attributedString.addAttribute(.font, value: boldFont, range: nsRange)
        }

        // Делаем "ID1" жирным
        if let id1Range = noteText.range(of: "ID1") {
            let nsRange = NSRange(id1Range, in: noteText)
            attributedString.addAttribute(.font, value: boldFont, range: nsRange)
        }

        noteLabel.attributedText = attributedString
    }

    private func setupConnectionStatusObserver() {
        // Защита от дублирования subscriptions
        guard !hasSetupObservers else {
            print("[SETTINGS] Observers already set up, skipping")
            return
        }

        hasSetupObservers = true

        ZetaraManager.shared.connectedPeripheralSubject
            .subscribeOn(MainScheduler.instance)
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] (peripheral: ZetaraManager.ConnectedPeripheral?) in
                let isConnected = peripheral != nil
                self?.connectionStatusBanner.setConnected(isConnected, animated: true)
            }
            .disposed(by: disposeBag)

        // Устанавливаем начальное состояние
        let initiallyConnected = ZetaraManager.shared.connectedPeripheral() != nil
        connectionStatusBanner.setConnected(initiallyConnected, animated: false)
    }

    // MARK: - Status Label and Save Button Helpers

    private func showStatusLabel(_ label: UILabel) {
        label.isHidden = false
        UIView.animate(withDuration: 0.3) {
            label.alpha = 1.0
        }
    }

    private func hideStatusLabel(_ label: UILabel) {
        UIView.animate(withDuration: 0.3, animations: {
            label.alpha = 0.0
        }, completion: { _ in
            label.isHidden = true
        })
    }

    private func showRestartPopup() {
        // Overlay (темный полупрозрачный фон)
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        overlay.alpha = 0
        overlay.translatesAutoresizingMaskIntoConstraints = false

        // Popup card (белая карточка)
        let popupCard = UIView()
        popupCard.backgroundColor = .white
        popupCard.layer.cornerRadius = 12
        popupCard.translatesAutoresizingMaskIntoConstraints = false

        // Text label
        let label = UILabel()
        label.text = "You must restart the battery using the power button after saving, then reconnect to the app to verify changes."
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false

        // Layout
        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        overlay.addSubview(popupCard)
        NSLayoutConstraint.activate([
            popupCard.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            popupCard.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            popupCard.widthAnchor.constraint(equalToConstant: 300)
        ])

        popupCard.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: popupCard.topAnchor, constant: 24),
            label.leadingAnchor.constraint(equalTo: popupCard.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: popupCard.trailingAnchor, constant: -24),
            label.bottomAnchor.constraint(equalTo: popupCard.bottomAnchor, constant: -24)
        ])

        // Tap gesture на overlay для закрытия
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(hideRestartPopup))
        overlay.addGestureRecognizer(tapGesture)

        // Fade in анимация
        UIView.animate(withDuration: 0.3) {
            overlay.alpha = 1
        }

        // Таймер на 3 секунды
        restartPopupTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.hideRestartPopup()
        }

        restartPopupOverlay = overlay
    }

    @objc private func hideRestartPopup() {
        restartPopupTimer?.invalidate()
        restartPopupTimer = nil

        UIView.animate(withDuration: 0.3, animations: {
            self.restartPopupOverlay?.alpha = 0
        }, completion: { _ in
            self.restartPopupOverlay?.removeFromSuperview()
            self.restartPopupOverlay = nil
        })
    }

    private func activateSaveButton() {
        saveButton.isEnabled = true
        UIView.animate(withDuration: 0.3) {
            self.saveButton.backgroundColor = .systemBlue
        }
    }

    private func deactivateSaveButton() {
        saveButton.isEnabled = false
        UIView.animate(withDuration: 0.3) {
            self.saveButton.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
        }
    }

    @objc private func saveButtonTapped() {
        // Hide all status indicators
        hideStatusLabel(moduleIdStatusLabel)
        hideStatusLabel(canStatusLabel)
        hideStatusLabel(rs485StatusLabel)

        // Show loading alert
        Alert.show("Saving settings...", timeout: 10)

        // Track how many operations completed
        var completedOperations = 0
        let totalOperations = [pendingModuleIdIndex, pendingCANIndex, pendingRS485Index].compactMap { $0 }.count

        let checkCompletion = { [weak self] in
            completedOperations += 1
            if completedOperations == totalOperations {
                Alert.hide()
                // Show custom restart popup
                self?.showRestartPopup()
                // Clear pending changes
                self?.pendingModuleIdIndex = nil
                self?.pendingCANIndex = nil
                self?.pendingRS485Index = nil
                // Deactivate Save button
                self?.deactivateSaveButton()
            }
        }

        // Apply Module ID change if pending
        if let index = pendingModuleIdIndex {
            setModuleId(at: index, completion: checkCompletion)
        }

        // Apply CAN change if pending
        if let index = pendingCANIndex {
            setCAN(at: index, completion: checkCompletion)
        }

        // Apply RS485 change if pending
        if let index = pendingRS485Index {
            setRS485(at: index, completion: checkCompletion)
        }

        // If no pending changes (shouldn't happen), just hide alert
        if totalOperations == 0 {
            Alert.hide()
            deactivateSaveButton()
        }
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

    // Флаг для предотвращения дублирования subscriptions
    private var hasSetupObservers = false

    func toggleRS485AndCAN(_ enabled: Bool) {
        self.rs485ProtocolView?.optionsButton.isEnabled = enabled
        self.canProtocolView?.optionsButton.isEnabled = enabled
    }
    
    func getAllSettings() {
        // Настраиваем подписки на ProtocolDataManager subjects
        // Теперь Settings просто слушает изменения, а не запрашивает данные напрямую
        let protocolManager = ZetaraManager.shared.protocolDataManager

        // Подписываемся на Module ID updates
        protocolManager.moduleIdSubject
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] moduleIdData in
                guard let self = self else { return }

                if let data = moduleIdData {
                    self.moduleIdData = data
                    self.moduleIdSettingItemView?.label = data.readableId()

                    // Синхронизируем selectedOptionIndex с загруженным значением (только если не загружаем)
                    if !self.isLoadingData {
                        let currentId = data.readableId()
                        if let index = Zetara.Data.ModuleIdControlData.readableIds().firstIndex(of: currentId) {
                            self.moduleIdSettingItemView?.selectedOptionIndex.onNext(index)
                        }
                    }

                    self.toggleRS485AndCAN(data.otherProtocolsEnabled())
                } else {
                    self.moduleIdSettingItemView?.label = "--"
                }
            })
            .disposed(by: disposeBag)

        // Подписываемся на RS485 updates
        protocolManager.rs485Subject
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] rs485Data in
                guard let self = self else { return }

                if let data = rs485Data {
                    self.rs485Data = data
                    self.rs485ProtocolView?.options = data.readableProtocols()
                    self.rs485ProtocolView?.label = data.readableProtocol()

                    // Синхронизируем selectedOptionIndex с загруженным значением (только если не загружаем)
                    if !self.isLoadingData {
                        let current = data.readableProtocol()
                        if let index = data.readableProtocols().firstIndex(of: current) {
                            self.rs485ProtocolView?.selectedOptionIndex.onNext(index)
                        }
                    }
                } else {
                    self.rs485ProtocolView?.label = "--"
                }
            })
            .disposed(by: disposeBag)

        // Подписываемся на CAN updates
        protocolManager.canSubject
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] canData in
                guard let self = self else { return }

                if let data = canData {
                    self.canData = data
                    self.canProtocolView?.options = data.readableProtocols()
                    self.canProtocolView?.label = data.readableProtocol()

                    // Синхронизируем selectedOptionIndex с загруженным значением (только если не загружаем)
                    if !self.isLoadingData {
                        let current = data.readableProtocol()
                        if let index = data.readableProtocols().firstIndex(of: current) {
                            self.canProtocolView?.selectedOptionIndex.onNext(index)
                        }
                    }

                    // Сбрасываем флаг загрузки после успешной загрузки всех данных
                    self.isLoadingData = false
                } else {
                    self.canProtocolView?.label = "--"
                }
            })
            .disposed(by: disposeBag)
    }
    
    func setModuleId(at index: Int, completion: (() -> Void)? = nil) {
        // module id 从 1 开始的
        ZetaraManager.shared.setModuleId(index + 1)
            .subscribeOn(MainScheduler.instance)
            .timeout(.seconds(3), scheduler: MainScheduler.instance)
            .subscribe { [weak self] (success: Bool) in
                if success, let idData = self?.moduleIdData {
                    self?.moduleIdSettingItemView?.label = idData.readableId(at: index)
                    self?.toggleRS485AndCAN(index == 0) // 这里是 0 ，因为这里的 id 从 0 开始
                } else {
                    print("[SETTINGS] ⚠️ Set module id failed")
                }
                completion?()
            } onError: { _ in
                print("[SETTINGS] ❌ Set module id error")
                completion?()
            }.disposed(by: disposeBag)
    }
    
    func setRS485(at index: Int, completion: (() -> Void)? = nil) {
        ZetaraManager.shared.setRS485(index)
            .subscribeOn(MainScheduler.instance)
            .timeout(.seconds(3), scheduler: MainScheduler.instance)
            .subscribe { [weak self] success in
                if success, let rs485 = self?.rs485Data {
                    self?.rs485ProtocolView?.label = rs485.readableProtocol(at: index)
                } else {
                    print("[SETTINGS] ⚠️ Set RS485 failed")
                }
                completion?()
            } onError: { _ in
                print("[SETTINGS] ❌ Set RS485 error")
                completion?()
            }.disposed(by: disposeBag)
    }
    
    func setCAN(at index: Int, completion: (() -> Void)? = nil) {
        ZetaraManager.shared.setCAN(index)
            .subscribeOn(MainScheduler.instance)
            .timeout(.seconds(3), scheduler: MainScheduler.instance)
            .subscribe { [weak self] success in
                if success, let can = self?.canData {
                    self?.canProtocolView?.label = can.readableProtocol(at: index)
                } else {
                    print("[SETTINGS] ⚠️ Set CAN failed")
                }
                completion?()
            } onError: { _ in
                print("[SETTINGS] ❌ Set CAN error")
                completion?()
            }.disposed(by: disposeBag)
    }
    
}
