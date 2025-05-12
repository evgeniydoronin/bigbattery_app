//
//  SummaryTabView.swift
//  BatteryMonitorBL
//
//  Created by Evgenii Doronin on 2025/5/9.
//

import UIKit
import SnapKit

class SummaryTabView: UIView {
    
    // MARK: - UI Elements
    
    // Первая строка
    private let maxVoltageView = ParameterView()
    private let minVoltageView = ParameterView()
    private let voltageDiffView = ParameterView()
    
    // Вторая строка
    private let powerView = ParameterView()
    private let internalTempView = ParameterView()
    private let avgVoltageView = ParameterView()
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
        setupInitialValues()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
        setupConstraints()
        setupInitialValues()
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        backgroundColor = .white
        
        // Настраиваем заголовки и подзаголовки для каждого параметра
        maxVoltageView.setup(title: "3.253 V", subtitle: "Max. Voltage")
        minVoltageView.setup(title: "3.213 V", subtitle: "Min. Voltage")
        voltageDiffView.setup(title: "0.040 V", subtitle: "Voltage Dif.")
        
        powerView.setup(title: "5.1 W", subtitle: "Power")
        internalTempView.setup(title: "75° F", subtitle: "Internal\nTemperature")
        avgVoltageView.setup(title: "3.233 V", subtitle: "Ave. Voltage")
        
        // Добавляем представления на экран
        addSubview(maxVoltageView)
        addSubview(minVoltageView)
        addSubview(voltageDiffView)
        
        addSubview(powerView)
        addSubview(internalTempView)
        addSubview(avgVoltageView)
    }
    
    private func setupConstraints() {
        // Размеры ячеек
        let cellHeight: CGFloat = 80
        
        // Первая строка
        maxVoltageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.equalToSuperview().offset(16)
            make.width.equalToSuperview().multipliedBy(0.3).offset(-24) // 1/3 ширины минус отступы
            make.height.equalTo(cellHeight)
        }
        
        minVoltageView.snp.makeConstraints { make in
            make.top.equalTo(maxVoltageView)
            make.centerX.equalToSuperview()
            make.width.equalTo(maxVoltageView)
            make.height.equalTo(cellHeight)
        }
        
        voltageDiffView.snp.makeConstraints { make in
            make.top.equalTo(maxVoltageView)
            make.trailing.equalToSuperview().offset(-16)
            make.width.equalTo(maxVoltageView)
            make.height.equalTo(cellHeight)
        }
        
        // Вторая строка
        powerView.snp.makeConstraints { make in
            make.top.equalTo(maxVoltageView.snp.bottom).offset(16)
            make.leading.equalToSuperview().offset(16)
            make.width.equalTo(maxVoltageView)
            make.height.equalTo(cellHeight)
        }
        
        internalTempView.snp.makeConstraints { make in
            make.top.equalTo(powerView)
            make.centerX.equalToSuperview()
            make.width.equalTo(maxVoltageView)
            make.height.equalTo(cellHeight)
        }
        
        avgVoltageView.snp.makeConstraints { make in
            make.top.equalTo(powerView)
            make.trailing.equalToSuperview().offset(-16)
            make.width.equalTo(maxVoltageView)
            make.height.equalTo(cellHeight)
            make.bottom.equalToSuperview().offset(-16) // Нижняя граница всего представления
        }
    }
    
    private func setupInitialValues() {
        // Устанавливаем начальные значения (нули)
        updateMaxVoltage(0)
        updateMinVoltage(0)
        updateVoltageDiff(0)
        updatePower(0)
        updateInternalTemp(0)
        updateAvgVoltage(0)
    }
    
    // MARK: - Public Methods
    
    /// Обновляет все параметры одновременно
    func updateAllParameters(maxVoltage: Float, minVoltage: Float, voltageDiff: Float, 
                            power: Float, internalTemp: Int8, avgVoltage: Float) {
        updateMaxVoltage(maxVoltage)
        updateMinVoltage(minVoltage)
        updateVoltageDiff(voltageDiff)
        updatePower(power)
        updateInternalTemp(internalTemp)
        updateAvgVoltage(avgVoltage)
    }
    
    /// Обновляет максимальное напряжение
    func updateMaxVoltage(_ value: Float) {
        maxVoltageView.updateValue(String(format: "%.3f V", value))
    }
    
    /// Обновляет минимальное напряжение
    func updateMinVoltage(_ value: Float) {
        minVoltageView.updateValue(String(format: "%.3f V", value))
    }
    
    /// Обновляет разницу напряжений
    func updateVoltageDiff(_ value: Float) {
        voltageDiffView.updateValue(String(format: "%.3f V", value))
    }
    
    /// Обновляет мощность
    func updatePower(_ value: Float) {
        powerView.updateValue(String(format: "%.1f W", value))
    }
    
    /// Обновляет внутреннюю температуру
    func updateInternalTemp(_ value: Int8) {
        let fahrenheit = Int(value).celsiusToFahrenheit()
        internalTempView.updateValue("\(fahrenheit)° F")
    }
    
    /// Обновляет среднее напряжение
    func updateAvgVoltage(_ value: Float) {
        avgVoltageView.updateValue(String(format: "%.3f V", value))
    }
}

/// Вспомогательный класс для отображения одного параметра
class ParameterView: UIView {
    
    // MARK: - UI Elements
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = .black
        label.textAlignment = .center
        return label
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .gray
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - Setup
    
    private func setupView() {
        backgroundColor = .white
        layer.cornerRadius = 10
        layer.borderWidth = 1
        layer.borderColor = UIColor.lightGray.withAlphaComponent(0.3).cgColor
        
        addSubview(valueLabel)
        addSubview(titleLabel)
        
        valueLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.centerX.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(8)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(valueLabel.snp.bottom).offset(8)
            make.centerX.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(8)
            make.bottom.equalToSuperview().offset(-12)
        }
    }
    
    // MARK: - Public Methods
    
    /// Настраивает представление с заданными значениями
    func setup(title: String, subtitle: String) {
        valueLabel.text = title
        titleLabel.text = subtitle
    }
    
    /// Обновляет значение параметра
    func updateValue(_ value: String) {
        valueLabel.text = value
    }
}
