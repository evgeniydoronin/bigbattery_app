//
//  BatteryProgressView.swift
//  BatteryMonitorBL
//
//  Created by Evgenii Doronin on 2025/5/12.
//

import UIKit
import SnapKit

/// Компонент для отображения круговой диаграммы прогресса заряда батареи
class BatteryProgressView: UIView {
    
    // MARK: - Private Properties
    
    /// Контейнер для изображения батареи
    private let batteryImageContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    /// Изображение батареи
    private let batteryImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "Battery/BatteryFull") // Используем существующее изображение
        return imageView
    }()
    
    /// Внешний круг прогресса (серый)
    private let outerCircleLayer = CAShapeLayer()
    
    /// Внутренний круг прогресса (зеленый)
    private let progressLayer = CAShapeLayer()
    
    /// Метка для отображения процента заряда
    private let percentLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 48, weight: .bold)
        label.textColor = .black
        label.textAlignment = .center
        label.text = "0%"
        return label
    }()
    
    /// Метки для отображения минимального и максимального значений
    private let minLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .darkGray
        label.textAlignment = .center
        label.text = "0"
        return label
    }()
    
    private let maxLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .darkGray
        label.textAlignment = .center
        label.text = "100"
        return label
    }()
    
    /// Текущий уровень заряда (от 0.0 до 1.0)
    private var _level: Float = 0.0
    
    /// Публичное свойство для установки уровня заряда
    var level: Float {
        get {
            return _level
        }
        set {
            _level = min(max(newValue, 0.0), 1.0) // Ограничиваем значение от 0.0 до 1.0
            updateProgress(animated: true)
        }
    }
    
    /// Цвет прогресса в зависимости от уровня заряда
    private var progressColor: UIColor {
        if _level <= 0.1 {
            return .systemRed // Красный для низкого заряда
        } else if _level <= 0.3 {
            return .systemOrange // Оранжевый для среднего заряда
        } else {
            return .systemGreen // Зеленый для высокого заряда
        }
    }
    
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
        backgroundColor = .clear
        
        // Добавляем контейнер для изображения батареи
        addSubview(batteryImageContainer)
        batteryImageContainer.addSubview(batteryImageView)
        
        // Добавляем метки
        addSubview(percentLabel)
        addSubview(minLabel)
        addSubview(maxLabel)
        
        // Настраиваем ограничения
        batteryImageContainer.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(150)
        }
        
        batteryImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(120)
        }
        
        percentLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-20)
        }
        
        minLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalToSuperview().offset(-20)
        }
        
        maxLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.bottom.equalToSuperview().offset(-20)
        }
        
        // Настраиваем слои для круговой диаграммы
        setupCircleLayers()
        
        // Устанавливаем начальный уровень заряда
        updateProgress(animated: false)
    }
    
    private func setupCircleLayers() {
        // Настраиваем внешний круг (серый)
        outerCircleLayer.fillColor = UIColor.clear.cgColor
        outerCircleLayer.strokeColor = UIColor.lightGray.cgColor
        outerCircleLayer.lineWidth = 20
        outerCircleLayer.lineCap = .round
        layer.addSublayer(outerCircleLayer)
        
        // Настраиваем внутренний круг (зеленый)
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = progressColor.cgColor
        progressLayer.lineWidth = 20
        progressLayer.lineCap = .round
        layer.addSublayer(progressLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Обновляем пути для кругов при изменении размеров
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - 30 // Отступ от края
        
        // Создаем путь для кругов (от -210 до 30 градусов)
        let startAngle = CGFloat(-210) * .pi / 180
        let endAngle = CGFloat(30) * .pi / 180
        
        let circlePath = UIBezierPath(arcCenter: center,
                                     radius: radius,
                                     startAngle: startAngle,
                                     endAngle: endAngle,
                                     clockwise: true)
        
        // Обновляем пути для слоев
        outerCircleLayer.path = circlePath.cgPath
        progressLayer.path = circlePath.cgPath
        
        // Обновляем прогресс
        updateProgress(animated: false)
    }
    
    // MARK: - Public Methods
    
    /// Обновление прогресса
    /// - Parameter animated: Флаг анимации
    private func updateProgress(animated: Bool) {
        // Обновляем цвет прогресса
        progressLayer.strokeColor = progressColor.cgColor
        
        // Обновляем текст процента
        percentLabel.text = "\(Int(_level * 100))%"
        
        // Обновляем прогресс
        let progress = CGFloat(_level) // Преобразуем Float в CGFloat
        
        if animated {
            // Создаем анимацию для прогресса
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = progressLayer.strokeEnd
            animation.toValue = progress
            animation.duration = 0.3
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            progressLayer.strokeEnd = CGFloat(progress)
            progressLayer.add(animation, forKey: "progressAnimation")
        } else {
            // Без анимации
            progressLayer.strokeEnd = CGFloat(progress)
        }
    }
    
    /// Обновление статуса зарядки
    /// - Parameter isCharging: Флаг зарядки
    func updateChargingStatus(isCharging: Bool) {
        if isCharging {
            batteryImageView.image = UIImage(named: "Battery/BatteryCharging")
        } else if _level <= 0.1 {
            batteryImageView.image = UIImage(named: "Battery/BatteryLow")
        } else {
            batteryImageView.image = UIImage(named: "Battery/BatteryFull")
        }
    }
}
