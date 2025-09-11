//
//  SettingItemView.swift
//  VoltGoPower
//
//  Created by xxtx on 2022/12/7.
//

import UIKit
import SnapKit
import Then
import RxSwift
import RxCocoa

class SettingItemView: UIView {
    
    /// 标题
    var title: String = "" {
        didSet {
            titleLabel.text = title
        }
    }
    
    var label: String? {
        didSet {
            if let label = label {
                update(label: label)
            } else {
                update(label: "")
            }
        }
    }
    
    /// 选项列表
    var options: [String] = [] {
        didSet {
            print("Options set to \(options)")
            update(options: options)
        }
    }
    
    var selectedOptionIndex = BehaviorSubject<Int>(value: 0)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private let titleLabel = UILabel().then {
        $0.font = .systemFont(ofSize: 16, weight: .bold)
        $0.textColor = .black
    }
    
    private let selectedButton = UIButton().then {
        $0.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        $0.setTitleColor(R.color.detailsTemperatureTitle(), for: .normal)
    }
    
    public let optionsButton = UIButton().then {
        $0.setImage(R.image.settingsUp(), for: .highlighted)
        $0.setImage(R.image.settingsDown(), for: .normal)
    }
    
    
    func setupUI() {
        // Добавляем полупрозрачный фон
        backgroundColor = UIColor.white.withAlphaComponent(0.7)
        
        // Добавляем скругление углов
        layer.cornerRadius = 12
        clipsToBounds = true
        
        // Добавляем тень для эффекта глубины (по гайдлайнам Apple)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowOpacity = 0.1
        layer.shadowRadius = 2
        layer.masksToBounds = false
        
        // Создаем контейнер для контента с отступами
        let contentView = UIView()
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0))
        }
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(optionsButton)
        contentView.addSubview(selectedButton)
        
        let action = UIAction {[weak self] _ in
            self?.expandOptionsMenu()
        }
        selectedButton.addAction(action, for: .touchUpInside)
        
        // Обновляем стиль шрифтов
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        selectedButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .regular)
        
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(24)
        }
        
        optionsButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-24)
            make.width.height.equalTo(24) // Фиксированный размер для кнопки
        }
        
        selectedButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(optionsButton.snp.leading).offset(-18)
        }
        
    }
    
    fileprivate func expandOptionsMenu() {
        
        guard self.optionsButton.isEnabled else {
            return
        }
        
        let touchDownGestureRecognizer = optionsButton.gestureRecognizers?.first{
            let dd = String(describing: type(of: $0))
            return dd.hasSuffix("TouchDownGestureRecognizer")
        }
        touchDownGestureRecognizer?.touchesBegan([], with: UIEvent())
    }
    
    fileprivate func onOptionTapped(_ option: String) {
        if let index = self.options.firstIndex(of: option) {
            self.selectedOptionIndex.onNext(index)
        }
    }
    
    
    fileprivate func update(options: [String]?) {
        // Специальная обработка для ячейки версии
        if self.title == "Version" {
            // Для ячейки версии всегда скрываем кнопку с опциями
            self.optionsButton.isHidden = true
            optionsButton.menu = nil
            
            // Обновляем constraints для selectedButton, чтобы он был привязан к правому краю
            selectedButton.snp.remakeConstraints { make in
                make.centerY.equalToSuperview()
                make.trailing.equalToSuperview().offset(-24)
            }
        } else {
            // Для всех остальных ячеек всегда показываем кнопку с опциями
            self.optionsButton.isHidden = false
            
            // Обновляем constraints для selectedButton, чтобы он был привязан к optionsButton
            selectedButton.snp.remakeConstraints { make in
                make.centerY.equalToSuperview()
                make.trailing.equalTo(optionsButton.snp.leading).offset(-18)
            }
            
            if let options = options {
                let menu = UIMenu(title: "", options: [], children: options.map({
                    UIAction(title: $0) { [weak self] action in
                        self?.onOptionTapped(action.title)
                    }
                }))
                optionsButton.menu = menu
                optionsButton.showsMenuAsPrimaryAction = true
            } else {
                optionsButton.menu = nil
            }
        }
    }
    
    fileprivate func update(label: String) {
        self.selectedButton.setTitle(label, for: .normal)
    }
    
}
