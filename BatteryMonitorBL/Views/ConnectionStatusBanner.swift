//
//  ConnectionStatusBanner.swift
//  BatteryMonitorBL
//
//  Created by Claude on 2025-10-06.
//  Connection Status Banner для Settings экрана
//

import UIKit
import SnapKit

/// Баннер статуса подключения батареи
/// Показывает "Connected" (зеленая рамка) или "Not Connected" (красная рамка)
class ConnectionStatusBanner: UIView {

    // MARK: - UI Components

    private let bluetoothIcon: UIImageView = {
        let imageView = UIImageView(image: R.image.homeBluetooth())
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemBlue
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = .black
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        // По умолчанию "Not Connected"
        setConnected(false, animated: false)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setConnected(false, animated: false)
    }

    // MARK: - Setup

    private func setupUI() {
        // Базовые стили
        backgroundColor = .white
        layer.cornerRadius = 12
        layer.borderWidth = 2
        clipsToBounds = true

        // Добавляем элементы
        addSubview(bluetoothIcon)
        addSubview(statusLabel)

        // Constraints для иконки
        NSLayoutConstraint.activate([
            bluetoothIcon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            bluetoothIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            bluetoothIcon.widthAnchor.constraint(equalToConstant: 32),
            bluetoothIcon.heightAnchor.constraint(equalToConstant: 32)
        ])

        // Constraints для label
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: bluetoothIcon.trailingAnchor, constant: 16),
            statusLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16)
        ])
    }

    // MARK: - Public Methods

    /// Обновляет статус подключения
    /// - Parameters:
    ///   - connected: true если подключено, false если нет
    ///   - animated: анимировать ли изменение
    func setConnected(_ connected: Bool, animated: Bool = true) {
        let changes = {
            if connected {
                // Connected: зеленая рамка, белый фон
                self.layer.borderColor = UIColor.systemGreen.cgColor
                self.backgroundColor = .white
                self.statusLabel.text = "Connected"
            } else {
                // Not Connected: красная рамка, красный фон с alpha
                self.layer.borderColor = UIColor.red.cgColor
                self.backgroundColor = UIColor.red.withAlphaComponent(0.1)
                self.statusLabel.text = "Not Connected"
            }
        }

        if animated {
            UIView.animate(withDuration: 0.3) {
                changes()
            }
        } else {
            changes()
        }
    }
}
