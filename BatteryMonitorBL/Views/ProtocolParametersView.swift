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
import RxSwift

/// Компонент для отображения параметров протоколов (Module ID, CAN, RS485)
class ProtocolParametersView: UIView {

    // MARK: - Properties

    private let disposeBag = DisposeBag()

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

    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
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

    // MARK: - Public Methods

    /// Привязывает компонент к ProtocolDataManager для реактивного обновления
    func bind(to protocolDataManager: ProtocolDataManager) {
        print("[PROTOCOLS VIEW] Binding to ProtocolDataManager...")

        // Подписываемся на Module ID
        protocolDataManager.moduleIdSubject
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] moduleIdData in
                guard let self = self else { return }
                if let data = moduleIdData {
                    let value = data.readableId()
                    print("[PROTOCOLS VIEW] Module ID updated: \(value)")
                    self.moduleIdBlock.setValue(value)
                } else {
                    print("[PROTOCOLS VIEW] Module ID cleared, showing --")
                    self.moduleIdBlock.setValue("--")
                }
            })
            .disposed(by: disposeBag)

        // Подписываемся на CAN
        protocolDataManager.canSubject
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] canData in
                guard let self = self else { return }
                if let data = canData {
                    let value = data.readableProtocol()
                    print("[PROTOCOLS VIEW] CAN updated: \(value)")
                    self.canBlock.setValue(value)
                } else {
                    print("[PROTOCOLS VIEW] CAN cleared, showing --")
                    self.canBlock.setValue("--")
                }
            })
            .disposed(by: disposeBag)

        // Подписываемся на RS485
        protocolDataManager.rs485Subject
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] rs485Data in
                guard let self = self else { return }
                if let data = rs485Data {
                    let value = data.readableProtocol()
                    print("[PROTOCOLS VIEW] RS485 updated: \(value)")
                    self.rs485Block.setValue(value)
                } else {
                    print("[PROTOCOLS VIEW] RS485 cleared, showing --")
                    self.rs485Block.setValue("--")
                }
            })
            .disposed(by: disposeBag)

        print("[PROTOCOLS VIEW] Successfully bound to ProtocolDataManager")
    }
}

// MARK: - Protocol Block

/// Отдельный блок для одного протокола
private class ProtocolBlock: UIView {
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 10, weight: .regular)
        label.textColor = .black
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .black
        label.textAlignment = .center
        return label
    }()
    
    init(title: String, iconName: String) {
        super.init(frame: .zero)

        // Формируем текст заголовка в формате "Selected ID", "Selected CAN", "Selected RS485"
        if title == "Module ID" {
            titleLabel.text = "Selected ID"
        } else {
            titleLabel.text = "Selected \(title)"
        }

        setupUI()

        // Устанавливаем начальное значение
        valueLabel.text = "--"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Белый фон
        backgroundColor = .white
        layer.cornerRadius = 10
        
        // Тень
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        
        // Layout - сначала значение, потом заголовок
        let stackView = UIStackView(arrangedSubviews: [valueLabel, titleLabel])
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.alignment = .center
        
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.left.right.equalToSuperview().inset(8)
        }
    }
    
    func setValue(_ value: String) {
        valueLabel.text = value
    }
}
