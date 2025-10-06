//
//  HeaderLogoView.swift
//  BatteryMonitorBL
//
//  Created by Claude on 2025-10-06.
//  Переиспользуемый компонент для белой шапки с логотипом BigBattery
//

import UIKit
import SnapKit

/// Белая шапка с логотипом BigBattery
/// Используется на экранах Home и Settings
class HeaderLogoView: UIView {

    // MARK: - UI Components

    private let logoImageView: UIImageView = {
        let imageView = UIImageView(image: R.image.headerLogo())
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        // Белый фон
        backgroundColor = .white
        translatesAutoresizingMaskIntoConstraints = false

        // Добавляем логотип
        addSubview(logoImageView)
    }

    // MARK: - Public Methods

    /// Настраивает constraints для header в родительском view
    /// - Parameter parentView: родительский view (обычно self.view контроллера)
    func setupConstraints(in parentView: UIView) {
        // Constraints для самого header
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: parentView.topAnchor),
            leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
            // Высота: от верха view до safeArea + 60pt
            bottomAnchor.constraint(equalTo: parentView.safeAreaLayoutGuide.topAnchor, constant: 60)
        ])

        // Constraints для логотипа
        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            // Логотип по центру в безопасной зоне (30pt от верха safeArea)
            logoImageView.centerYAnchor.constraint(equalTo: parentView.safeAreaLayoutGuide.topAnchor, constant: 30),
            logoImageView.widthAnchor.constraint(equalToConstant: 200),
            logoImageView.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
}
