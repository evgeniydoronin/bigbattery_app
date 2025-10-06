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

    /// Заголовок
    var title: String = "" {
        didSet {
            titleLabel.text = title
        }
    }

    /// Подзаголовок (subtitle)
    var subtitle: String = "" {
        didSet {
            subtitleLabel.text = subtitle
        }
    }

    /// Цвет иконки (и значения)
    var iconColor: UIColor = .black {
        didSet {
            iconImageView.tintColor = iconColor
            selectedButton.setTitleColor(iconColor, for: .normal)
        }
    }

    /// Иконка (SF Symbol или custom image)
    var icon: UIImage? {
        didSet {
            iconImageView.image = icon?.withRenderingMode(.alwaysTemplate)
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

    /// Список опций
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

    // MARK: - UI Components

    private let iconImageView = UIImageView().then {
        $0.contentMode = .scaleAspectFit
        $0.tintColor = .black
    }

    private let titleLabel = UILabel().then {
        $0.font = .systemFont(ofSize: 16, weight: .bold)
        $0.textColor = .black
    }

    private let subtitleLabel = UILabel().then {
        $0.font = .systemFont(ofSize: 10, weight: .regular)
        $0.textColor = UIColor(red: 0x80/255.0, green: 0x80/255.0, blue: 0x80/255.0, alpha: 1.0)
    }

    private let selectedButton = UIButton().then {
        $0.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        $0.setTitleColor(.black, for: .normal)
    }

    public let optionsButton = UIButton().then {
        $0.setImage(R.image.settingsUp(), for: .highlighted)
        $0.setImage(R.image.settingsDown(), for: .normal)
    }
    
    func setupUI() {
        // Серый фон по спецификации
        backgroundColor = UIColor(red: 0xE8/255.0, green: 0xE8/255.0, blue: 0xE8/255.0, alpha: 1.0)

        // Скругление углов
        layer.cornerRadius = 12
        clipsToBounds = true

        // Добавляем все элементы
        addSubview(iconImageView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(selectedButton)
        addSubview(optionsButton)

        let action = UIAction {[weak self] _ in
            self?.expandOptionsMenu()
        }
        selectedButton.addAction(action, for: .touchUpInside)

        // Layout: [icon] [title/subtitle] [value] [chevron]

        // Icon (32x32pt, слева)
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }

        // Title/Subtitle stack (вертикально, после иконки)
        let textStackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStackView.axis = .vertical
        textStackView.spacing = 2
        textStackView.alignment = .leading
        addSubview(textStackView)

        textStackView.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
        }

        // Chevron (справа)
        optionsButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-16)
            make.width.height.equalTo(24)
        }

        // Value (между текстом и chevron)
        selectedButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(optionsButton.snp.leading).offset(-12)
            make.leading.greaterThanOrEqualTo(textStackView.snp.trailing).offset(8)
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
        // Скрываем стрелочку только для Version/App Version (где options не нужны)
        let shouldHideChevron = (self.title == "Version" || self.title == "App Version")

        if shouldHideChevron {
            // Скрываем кнопку с опциями
            self.optionsButton.isHidden = true
            optionsButton.menu = nil

            // Обновляем constraints для selectedButton, чтобы он был привязан к правому краю
            selectedButton.snp.remakeConstraints { make in
                make.centerY.equalToSuperview()
                make.trailing.equalToSuperview().offset(-16)
                make.leading.greaterThanOrEqualTo(iconImageView.snp.trailing).offset(8)
            }
        } else {
            // Показываем кнопку с опциями
            self.optionsButton.isHidden = false

            // Обновляем constraints для selectedButton, чтобы он был привязан к optionsButton
            selectedButton.snp.remakeConstraints { make in
                make.centerY.equalToSuperview()
                make.trailing.equalTo(optionsButton.snp.leading).offset(-12)
                make.leading.greaterThanOrEqualTo(iconImageView.snp.trailing).offset(8)
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
