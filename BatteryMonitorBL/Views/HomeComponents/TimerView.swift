//
//  TimerView.swift
//  BatteryMonitorBL
//
//  Created by Evgenii Doronin on 2025/5/9.
//

import UIKit
import SnapKit

/// Компонент для отображения времени последнего обновления данных
class TimerView: UIView {
    
    // MARK: - Private Properties
    
    /// Метка для отображения времени последнего обновления
    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .darkGray
        label.textAlignment = .center
        label.text = "Last Update: --"
        return label
    }()
    
    /// Форматтер для отображения даты и времени
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter
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
        // Добавляем метку в иерархию
        addSubview(timeLabel)
        
        // Настраиваем ограничения
        timeLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-16)
        }
    }
    
    // MARK: - Public Methods
    
    /// Обновление времени последнего обновления
    /// - Parameter time: Время последнего обновления
    func updateTime(_ time: Date) {
        timeLabel.text = "Last Update: \(dateFormatter.string(from: time))"
    }
    
    /// Обновление времени последнего обновления с использованием строки
    /// - Parameter timeString: Строка с временем последнего обновления
    func updateTimeWithString(_ timeString: String) {
        timeLabel.text = timeString
    }
    
    /// Скрытие/отображение метки времени
    /// - Parameter isHidden: Флаг скрытия
    func setHidden(_ isHidden: Bool) {
        timeLabel.isHidden = isHidden
    }
}
