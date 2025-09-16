//
//  ProtocolParametersView.swift
//  BatteryMonitorBL
//
//  Created by Evgenii Doronin on 2025/5/15.
//

import UIKit
import SnapKit
import RswiftResources

/// Компонент для отображения параметров протоколов (Module ID, CAN, RS485)
class ProtocolParametersView: UIView {

    // MARK: - Private Properties

    /// Горизонтальный стек для компонентов
    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    /// Компонент для отображения Module ID
    private let moduleIdComponentView: ComponentView

    /// Компонент для отображения CAN Protocol
    private let canProtocolComponentView: ComponentView

    /// Компонент для отображения RS485 Protocol
    private let rs485ProtocolComponentView: ComponentView

    /// Callback для обработки нажатий на блоки
    public var onModuleIdTap: (() -> Void)?
    public var onCanProtocolTap: (() -> Void)?
    public var onRS485ProtocolTap: (() -> Void)?

    // MARK: - Initialization

    init() {
        // Инициализируем компоненты
        moduleIdComponentView = ComponentView(icon: UIImage(systemName: "number.circle") ?? UIImage(), title: "Selected ID", value: "--")
        canProtocolComponentView = ComponentView(icon: UIImage(systemName: "wifi") ?? UIImage(), title: "Selected CAN", value: "--")
        rs485ProtocolComponentView = ComponentView(icon: UIImage(systemName: "cable.connector") ?? UIImage(), title: "Selected RS485", value: "--")

        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) {
        // Инициализируем компоненты
        moduleIdComponentView = ComponentView(icon: UIImage(systemName: "number.circle") ?? UIImage(), title: "Selected ID", value: "--")
        canProtocolComponentView = ComponentView(icon: UIImage(systemName: "wifi") ?? UIImage(), title: "Selected CAN", value: "--")
        rs485ProtocolComponentView = ComponentView(icon: UIImage(systemName: "cable.connector") ?? UIImage(), title: "Selected RS485", value: "--")

        super.init(coder: coder)
        setupView()
    }

    // MARK: - Setup

    private func setupView() {
        // Настраиваем внешний вид компонентов
        [moduleIdComponentView, canProtocolComponentView, rs485ProtocolComponentView].forEach { view in
            view.backgroundColor = UIColor.white
            view.layer.cornerRadius = 10
            view.layer.masksToBounds = false // Убираем masksToBounds для отображения тени
            view.layer.borderWidth = 1
            view.layer.borderColor = UIColor.black.withAlphaComponent(0.1).cgColor

            // Добавляем тень
            view.layer.shadowColor = UIColor.black.cgColor
            view.layer.shadowOffset = CGSize(width: 0, height: 2)
            view.layer.shadowOpacity = 0.1
            view.layer.shadowRadius = 4

            view.configureForHorizontalLayout()

            // Скрываем иконки в этих компонентах
            view.iconImageView.isHidden = true

            // Переопределяем constraints для titleLabel, чтобы он был по центру без иконки
            view.titleLabel.textAlignment = .center
            // Убеждаемся, что размеры шрифтов такие же, как в BatteryParametersView
            view.valueLabel.font = .systemFont(ofSize: 18, weight: .bold)
            view.titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
            view.titleLabel.snp.remakeConstraints { make in
                make.top.equalTo(view.valueLabel.snp.bottom).offset(8)
                make.leading.trailing.equalToSuperview().inset(8)
                make.bottom.equalToSuperview().offset(-12)
                make.centerX.equalToSuperview()
            }
        }

        // Добавляем обработчики нажатий
        setupTapGestures()

        // Добавляем компоненты в стек
        stackView.addArrangedSubview(moduleIdComponentView)
        stackView.addArrangedSubview(canProtocolComponentView)
        stackView.addArrangedSubview(rs485ProtocolComponentView)

        // Добавляем стек в иерархию
        addSubview(stackView)

        // Настраиваем ограничения
        stackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(0)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-8)
            make.height.equalTo(70)
        }
    }

    private func setupTapGestures() {
        // Module ID tap gesture
        let moduleIdTapGesture = UITapGestureRecognizer(target: self, action: #selector(moduleIdTapped))
        moduleIdComponentView.addGestureRecognizer(moduleIdTapGesture)
        moduleIdComponentView.isUserInteractionEnabled = true

        // CAN Protocol tap gesture
        let canProtocolTapGesture = UITapGestureRecognizer(target: self, action: #selector(canProtocolTapped))
        canProtocolComponentView.addGestureRecognizer(canProtocolTapGesture)
        canProtocolComponentView.isUserInteractionEnabled = true

        // RS485 Protocol tap gesture
        let rs485ProtocolTapGesture = UITapGestureRecognizer(target: self, action: #selector(rs485ProtocolTapped))
        rs485ProtocolComponentView.addGestureRecognizer(rs485ProtocolTapGesture)
        rs485ProtocolComponentView.isUserInteractionEnabled = true
    }

    // MARK: - Tap Handlers

    @objc private func moduleIdTapped() {
        print("🔵 [ProtocolParametersView] Module ID tapped!")
        onModuleIdTap?()
    }

    @objc private func canProtocolTapped() {
        print("🔵 [ProtocolParametersView] CAN Protocol tapped!")
        onCanProtocolTap?()
    }

    @objc private func rs485ProtocolTapped() {
        print("🔵 [ProtocolParametersView] RS485 Protocol tapped!")
        onRS485ProtocolTap?()
    }

    // MARK: - Public Methods

    /// Обновление значения Module ID
    /// - Parameter value: Значение Module ID в виде строки (например, "ID3")
    func updateModuleId(_ value: String) {
        moduleIdComponentView.value = value
    }

    /// Обновление значения CAN Protocol
    /// - Parameter value: Значение CAN Protocol в виде строки (например, "P06-LUX")
    func updateCanProtocol(_ value: String) {
        canProtocolComponentView.value = value
    }

    /// Обновление значения RS485 Protocol
    /// - Parameter value: Значение RS485 Protocol в виде строки (например, "P02-LUX")
    func updateRS485Protocol(_ value: String) {
        rs485ProtocolComponentView.value = value
    }

    /// Обновление всех параметров
    /// - Parameters:
    ///   - moduleId: Значение Module ID в виде строки
    ///   - canProtocol: Значение CAN Protocol в виде строки
    ///   - rs485Protocol: Значение RS485 Protocol в виде строки
    func updateAllParameters(moduleId: String, canProtocol: String, rs485Protocol: String) {
        updateModuleId(moduleId)
        updateCanProtocol(canProtocol)
        updateRS485Protocol(rs485Protocol)
    }
}