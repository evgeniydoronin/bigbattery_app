//
//  BatteryStatusView.swift
//  BatteryMonitorBL
//
//  Created by Evgenii Doronin on 2025/5/23.
//

import UIKit
import SnapKit
import Zetara

/// Компонент для отображения текстового статуса батареи
class BatteryStatusView: UIView {
    
    // MARK: - Private Properties
    
    /// Контейнер для всех элементов
    private let containerView = UIView()
    
    /// Метка с текстом статуса батареи
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .regular)
        label.textColor = .black
        label.textAlignment = .center
        label.text = "Standby"
        return label
    }()
    
    /// Текущий статус батареи
    private var currentStatus: Zetara.Data.BMS.Status = .standby
    
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
        // Настройка контейнера
        containerView.layer.cornerRadius = 10
        containerView.layer.masksToBounds = true
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.black.withAlphaComponent(0.1).cgColor
        
        // Добавление элементов в иерархию
        addSubview(containerView)
        containerView.addSubview(statusLabel)
        
        // Настройка ограничений
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: -10, left: 150, bottom: 8, right: 150))
            make.height.equalTo(35) // Высота контейнера
        }
        
        statusLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }
        
        // Устанавливаем начальный стиль
        updateStatusStyle()
    }
    
    // MARK: - Private Methods
    
    /// Обновление стиля контейнера в зависимости от статуса
    private func updateStatusStyle() {
        let backgroundColor: UIColor
        let textColor: UIColor
        
        switch currentStatus {
        case .charging:
            backgroundColor = UIColor.systemGreen.withAlphaComponent(0.2)
            textColor = UIColor.systemGreen
        case .disCharging:
            backgroundColor = UIColor.systemOrange.withAlphaComponent(0.2)
            textColor = UIColor.systemOrange
        case .protecting:
            backgroundColor = UIColor.systemRed.withAlphaComponent(0.2)
            textColor = UIColor.systemRed
        case .chargingLimit:
            backgroundColor = UIColor.systemYellow.withAlphaComponent(0.2)
            textColor = UIColor.systemYellow
        case .standby:
            backgroundColor = UIColor.systemGray.withAlphaComponent(0.2)
            textColor = UIColor.systemGray
        }
        
        containerView.backgroundColor = backgroundColor
        statusLabel.textColor = textColor
    }
    
    // MARK: - Public Methods
    
    /// Обновление статуса батареи
    /// - Parameter status: Новый статус батареи
    func updateStatus(_ status: Zetara.Data.BMS.Status) {
        currentStatus = status
        statusLabel.text = status.description
        updateStatusStyle()
    }
    
    /// Обновление статуса батареи с анимацией
    /// - Parameter status: Новый статус батареи
    func updateStatusAnimated(_ status: Zetara.Data.BMS.Status) {
        currentStatus = status
        
        UIView.transition(with: statusLabel, duration: 0.3, options: .transitionCrossDissolve) {
            self.statusLabel.text = status.description
        }
        
        UIView.animate(withDuration: 0.3) {
            self.updateStatusStyle()
        }
    }
}
