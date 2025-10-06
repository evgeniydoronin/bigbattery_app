//
//  ProtocolParametersView.swift
//  BatteryMonitorBL
//
//  Created by Cline on 2025-10-06.
//  Этап 3.2: Компонент для отображения протоколов на Home экране
//

import UIKit
import SnapKit
import Zetara

/// Компонент для отображения параметров протоколов (Module ID, CAN, RS485)
class ProtocolParametersView: UIView {
    
    // MARK: - UI Components
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 12
        return stack
    }()
    
    private let moduleIdBlock = ProtocolBlock(title: "Module ID", iconName: "gear")
    private let canBlock = ProtocolBlock(title: "CAN", iconName: "antenna.radiowaves.left.and.right")
    private let rs485Block = ProtocolBlock(title: "RS485", iconName: "cable.connector")
    
    // Callback для навигации в Settings
    var onTap: (() -> Void)?
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Добавляем блоки в stack
        stackView.addArrangedSubview(moduleIdBlock)
        stackView.addArrangedSubview(canBlock)
        stackView.addArrangedSubview(rs485Block)
        
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func setupGestures() {
        // Добавляем tap gesture для каждого блока
        let moduleIdTap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        moduleIdBlock.addGestureRecognizer(moduleIdTap)
        
        let canTap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        canBlock.addGestureRecognizer(canTap)
        
        let rs485Tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        rs485Block.addGestureRecognizer(rs485Tap)
    }
    
    @objc private func handleTap() {
        onTap?()
    }
    
    // MARK: - Public Methods
    
    /// Обновляет значения протоколов из кэша ZetaraManager
    func updateValues() {
        // Module ID
        if let moduleIdData = ZetaraManager.shared.cachedModuleIdData {
            moduleIdBlock.setValue("\(moduleIdData.number)")
        } else {
            moduleIdBlock.setValue("--")
        }
        
        // CAN
        if let canData = ZetaraManager.shared.cachedCANData {
            moduleIdBlock.setValue("\(canData.number)")
        } else {
            canBlock.setValue("--")
        }
        
        // RS485
        if let rs485Data = ZetaraManager.shared.cachedRS485Data {
            rs485Block.setValue("\(rs485Data.number)")
        } else {
            rs485Block.setValue("--")
        }
    }
}

// MARK: - Protocol Block

/// Отдельный блок для одного протокола
private class ProtocolBlock: UIView {
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white.withAlphaComponent(0.7)
        label.textAlignment = .center
        return label
    }()
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white.withAlphaComponent(0.5)
        return imageView
    }()
    
    init(title: String, iconName: String) {
        super.init(frame: .zero)
        
        titleLabel.text = title
        if let icon = UIImage(systemName: iconName) {
            iconImageView.image = icon
        }
        
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Белый фон с прозрачностью
        backgroundColor = UIColor.white.withAlphaComponent(0.1)
        layer.cornerRadius = 12
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        
        // Тень
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        
        // Layout
        let stackView = UIStackView(arrangedSubviews: [iconImageView, valueLabel, titleLabel])
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.alignment = .center
        
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.left.right.equalToSuperview().inset(8)
        }
        
        iconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(24)
        }
    }
    
    func setValue(_ value: String) {
        valueLabel.text = value
    }
}
