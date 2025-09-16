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

    var icon: UIImage? {
        didSet {
            iconImageView.image = icon
        }
    }
    
    var subtitle: String = "" {
        didSet {
            subtitleLabel.text = subtitle
        }
    }

    var iconColor: UIColor = .systemBlue {
        didSet {
            iconImageView.tintColor = iconColor
        }
    }

    var valueColor: UIColor = .systemBlue {
        didSet {
            selectedButton.setTitleColor(valueColor, for: .normal)
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
    
    private let iconImageView = UIImageView().then {
        $0.image = UIImage(systemName: "gearshape.fill")
        $0.contentMode = .scaleAspectFit
        $0.tintColor = .systemBlue
    }

    private let titleLabel = UILabel().then {
        $0.font = .systemFont(ofSize: 16, weight: .bold)
        $0.textColor = .black
    }

    private let subtitleLabel = UILabel().then {
        $0.font = .systemFont(ofSize: 12, weight: .regular)
        $0.textColor = .gray
        $0.numberOfLines = 1
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
        
        contentView.addSubview(iconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(optionsButton)
        contentView.addSubview(selectedButton)
        
        let action = UIAction {[weak self] _ in
            self?.expandOptionsMenu()
        }
        selectedButton.addAction(action, for: .touchUpInside)

        // Добавляем tap gesture на всю view для лучшего UX
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleViewTap))
        addGestureRecognizer(tapGesture)
        
        // Обновляем стиль шрифтов
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        selectedButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .regular)
        
        // Иконка слева
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }

        // Заголовок
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalTo(iconImageView.snp.trailing).offset(12)
        }

        // Подзаголовок
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.leading.equalTo(iconImageView.snp.trailing).offset(12)
            make.bottom.equalToSuperview().offset(-12)
        }

        // Стрелка справа
        optionsButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-16)
            make.width.height.equalTo(24)
        }

        // Значение рядом со стрелкой
        selectedButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(optionsButton.snp.leading).offset(-8)
        }
        
    }

    @objc private func handleViewTap() {
        expandOptionsMenu()
    }

    /// Обновляет внешний вид в зависимости от состояния enabled кнопки
    private func updateAppearanceForEnabledState() {
        if optionsButton.isEnabled {
            backgroundColor = UIColor.white.withAlphaComponent(0.7)
        } else {
            backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
        }
    }

    /// Публичный метод для установки состояния enabled и обновления внешнего вида
    public func setOptionsEnabled(_ enabled: Bool) {
        optionsButton.isEnabled = enabled
        updateAppearanceForEnabledState()
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
        if self.title == "App Version" {
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
        if label.isEmpty {
            self.selectedButton.setTitle("--", for: .normal)
        } else {
            self.selectedButton.setTitle(label, for: .normal)
        }
    }
    
}
