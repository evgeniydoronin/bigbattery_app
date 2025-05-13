//
//  BluetoothConnectionView.swift
//  BatteryMonitorBL
//
//  Created by Evgenii Doronin on 2025/5/9.
//

import UIKit
import SnapKit
import RswiftResources

/// Компонент для отображения статуса Bluetooth-подключения и имени устройства
class BluetoothConnectionView: UIView {
    
    // MARK: - Public Properties
    
    /// Обработчик нажатия на компонент
    var onTap: (() -> Void)?
    
    // MARK: - Private Properties
    
    /// Контейнер для всех элементов
    private let containerView = UIView()
    
    /// Иконка Bluetooth
    private let bluetoothImageView: UIImageView = {
        let imageView = UIImageView(image: R.image.homeBluetooth())
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemBlue
        return imageView
    }()
    
    /// Метка с именем устройства
    private let deviceNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .medium)
        label.textColor = .black
        label.text = "Tap to Connect"
        return label
    }()
    
    /// Кнопка "+" для добавления устройства
    private let addButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.tintColor = .black
        button.contentMode = .scaleAspectFit
        return button
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
        // Настройка контейнера
        containerView.backgroundColor = UIColor.white // Белый цвет фона
        containerView.layer.cornerRadius = 10
        containerView.layer.masksToBounds = true
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.black.withAlphaComponent(0.25).cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowOpacity = 0.0
        containerView.layer.shadowRadius = 4
        containerView.clipsToBounds = false
        
        // Добавление элементов в иерархию
        addSubview(containerView)
        containerView.addSubview(bluetoothImageView)
        containerView.addSubview(deviceNameLabel)
        containerView.addSubview(addButton)
        
        // Настройка ограничений
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
            make.height.equalTo(50) // Устанавливаем высоту контейнера 80 пикселей
        }
        
        bluetoothImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(40)
        }
        
        deviceNameLabel.snp.makeConstraints { make in
            make.leading.equalTo(bluetoothImageView.snp.trailing).offset(16)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(addButton.snp.leading).offset(-16)
        }
        
        addButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }
        
        // Добавление обработчика нажатия
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        containerView.addGestureRecognizer(tapGesture)
        containerView.isUserInteractionEnabled = true
        
        // Добавление обработчика нажатия на кнопку "+"
        addButton.addTarget(self, action: #selector(handleAddButtonTap), for: .touchUpInside)
    }
    
    // MARK: - Actions
    
    /// Обработчик нажатия на компонент
    @objc private func handleTap() {
        onTap?()
    }
    
    /// Обработчик нажатия на кнопку "+"
    @objc private func handleAddButtonTap() {
        // Пока просто вызываем тот же обработчик, что и для всего компонента
        onTap?()
    }
    
    // MARK: - Public Methods
    
    /// Обновление имени устройства
    /// - Parameter name: Имя устройства или nil, если устройство не подключено
    func updateDeviceName(_ name: String?) {
        deviceNameLabel.text = name ?? "Tap to Connect"
    }
}
