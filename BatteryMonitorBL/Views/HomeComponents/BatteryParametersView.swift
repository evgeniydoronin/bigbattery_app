//
//  BatteryParametersView.swift
//  BatteryMonitorBL
//
//  Created by Evgenii Doronin on 2025/5/9.
//

import UIKit
import SnapKit
import RswiftResources

/// Компонент для отображения параметров батареи (напряжение, ток, температура)
class BatteryParametersView: UIView {
    
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
    
    /// Компонент для отображения напряжения
    private let voltageComponentView: ComponentView
    
    /// Компонент для отображения тока
    private let currentComponentView: ComponentView
    
    /// Компонент для отображения температуры
    private let temperatureComponentView: ComponentView
    
    // MARK: - Initialization
    
    init() {
        // Инициализируем компоненты
        voltageComponentView = ComponentView(icon: R.image.homeComponentVoltage()!, title: "Total Voltage", value: "0V")
        currentComponentView = ComponentView(icon: R.image.homeComponentCurrent()!, title: "Total Current", value: "0A")
        temperatureComponentView = ComponentView(icon: R.image.homeComponentTemperature()!, title: "Total Temp.", value: "0°C/0°F")
        
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        // Инициализируем компоненты
        voltageComponentView = ComponentView(icon: R.image.homeComponentVoltage()!, title: "Total Voltage", value: "0V")
        currentComponentView = ComponentView(icon: R.image.homeComponentCurrent()!, title: "Total Current", value: "0A")
        temperatureComponentView = ComponentView(icon: R.image.homeComponentTemperature()!, title: "Total Temp.", value: "0°C/0°F")
        
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - Setup
    
    private func setupView() {
        // Настраиваем внешний вид компонентов
        [voltageComponentView, currentComponentView, temperatureComponentView].forEach { view in
            view.backgroundColor = UIColor.white
            view.layer.cornerRadius = 10
            view.layer.masksToBounds = true
            view.layer.borderWidth = 1
            view.layer.borderColor = UIColor.black.withAlphaComponent(0.1).cgColor
            view.configureForHorizontalLayout()
        }
        
        // Добавляем компоненты в стек
        stackView.addArrangedSubview(voltageComponentView)
        stackView.addArrangedSubview(currentComponentView)
        stackView.addArrangedSubview(temperatureComponentView)
        
        // Добавляем стек в иерархию
        addSubview(stackView)
        
        // Настраиваем ограничения
        stackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(0)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-8)
            make.height.equalTo(80)
        }
    }
    
    // MARK: - Public Methods
    
    /// Обновление значения напряжения
    /// - Parameter value: Значение напряжения в виде строки (например, "53.35V")
    func updateVoltage(_ value: String) {
        voltageComponentView.value = value
    }
    
    /// Обновление значения тока
    /// - Parameter value: Значение тока в виде строки (например, "0.35A")
    func updateCurrent(_ value: String) {
        currentComponentView.value = value
    }
    
    /// Обновление значения температуры
    /// - Parameter value: Значение температуры в виде строки (например, "75°F/24°C")
    func updateTemperature(_ value: String) {
        temperatureComponentView.value = value
    }
    
    /// Обновление всех параметров
    /// - Parameters:
    ///   - voltage: Значение напряжения в виде строки
    ///   - current: Значение тока в виде строки
    ///   - temperature: Значение температуры в виде строки
    func updateAllParameters(voltage: String, current: String, temperature: String) {
        updateVoltage(voltage)
        updateCurrent(current)
        updateTemperature(temperature)
    }
    
    /// Изменение порядка компонентов
    /// - Parameter order: Массив компонентов в нужном порядке
    func reorderComponents(order: [ComponentType]) {
        // Удаляем все существующие компоненты
        for view in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        // Добавляем компоненты в новом порядке
        for type in order {
            switch type {
            case .voltage:
                stackView.addArrangedSubview(voltageComponentView)
            case .current:
                stackView.addArrangedSubview(currentComponentView)
            case .temperature:
                stackView.addArrangedSubview(temperatureComponentView)
            }
        }
    }
    
    // MARK: - Enums
    
    /// Типы компонентов для изменения порядка
    enum ComponentType {
        case voltage
        case current
        case temperature
    }
}
