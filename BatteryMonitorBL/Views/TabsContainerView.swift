//
//  TabsContainerView.swift
//  BatteryMonitorBL
//
//  Created by Evgenii Doronin on 2025/5/13.
//

import UIKit
import SnapKit
import GradientView

/// Компонент для отображения контейнера с табами
class TabsContainerView: UIView {
    
    // MARK: - Public Properties
    
    /// Обработчик изменения активного таба
    var onTabChanged: ((Int) -> Void)?
    
    // MARK: - Private Properties
    
    /// Внутренний контейнер для табов с отступами
    private let innerContainer = UIView()
    
    /// Горизонтальный стек для кнопок табов
    private let tabButtonsStackView = UIStackView()
    
    /// Контейнер для содержимого активного таба
    private let tabContentContainer = UIView()
    
    /// Кнопки табов
    private var tabButtons: [UIButton] = []
    
    /// Содержимое табов
    private var tabContents: [UIView] = []
    
    /// Текущий активный таб
    private var activeTabIndex: Int = 0
    
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
        backgroundColor = .clear
        
        // Настраиваем внутренний контейнер
        innerContainer.backgroundColor = .clear
        innerContainer.layer.cornerRadius = 16
        innerContainer.layer.masksToBounds = true
        innerContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(innerContainer)
        
        // Добавляем градиентный фон
        let gradientView = GradientView(frame: .zero)
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        innerContainer.addSubview(gradientView)
        innerContainer.sendSubviewToBack(gradientView)
        
        // Настраиваем градиент
        gradientView.direction = .vertical
        gradientView.colors = [
            UIColor.white,
            UIColor(hex: "D8E7F6")
        ]
        
        // Настраиваем стек для кнопок табов
        tabButtonsStackView.translatesAutoresizingMaskIntoConstraints = false
        tabButtonsStackView.axis = .horizontal
        tabButtonsStackView.distribution = .fillEqually
        tabButtonsStackView.spacing = 10
        innerContainer.addSubview(tabButtonsStackView)
        
        // Настраиваем контейнер для содержимого
        tabContentContainer.translatesAutoresizingMaskIntoConstraints = false
        tabContentContainer.backgroundColor = .clear
        innerContainer.addSubview(tabContentContainer)
        
        // Настраиваем ограничения
        setupConstraints()
        
        // Добавляем стандартные табы
        setupDefaultTabs()
    }
    
    private func setupConstraints() {
        // Ограничения для внутреннего контейнера
        innerContainer.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16))
        }
        
        // Ограничения для градиентного вида
        innerContainer.subviews.first?.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Ограничения для стека кнопок
        tabButtonsStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.height.equalTo(40)
        }
        
        // Ограничения для контейнера содержимого
        tabContentContainer.snp.makeConstraints { make in
            make.top.equalTo(tabButtonsStackView.snp.bottom).offset(16)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-16)
        }
    }
    
    private func setupDefaultTabs() {
        // Создаем стандартные табы
        addTab(title: "Summary", content: SummaryTabView(), isActive: true)
        addTab(title: "Cell Voltage", content: createDefaultTabContent(title: "Cell Voltage Tab Content"))
        addTab(title: "Temperature", content: createDefaultTabContent(title: "Temperature Tab Content"))
    }
    
    private func createDefaultTabContent(title: String) -> UIView {
        let contentView = UIView()
        contentView.backgroundColor = .white
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 22, weight: .medium)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }
        
        return contentView
    }
    
    // MARK: - Public Methods
    
    /// Добавляет новый таб
    /// - Parameters:
    ///   - title: Заголовок таба
    ///   - content: Содержимое таба
    ///   - isActive: Флаг активности таба
    func addTab(title: String, content: UIView, isActive: Bool = false) {
        // Создаем кнопку таба
        let button = createTabButton(title: title, isActive: isActive)
        tabButtons.append(button)
        tabButtonsStackView.addArrangedSubview(button)
        
        // Добавляем содержимое таба
        content.translatesAutoresizingMaskIntoConstraints = false
        tabContents.append(content)
        tabContentContainer.addSubview(content)
        
        // Настраиваем ограничения для содержимого
        content.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Скрываем содержимое, если таб не активен
        content.isHidden = !isActive
        
        // Если таб активен, обновляем индекс активного таба
        if isActive {
            activeTabIndex = tabButtons.count - 1
        }
        
        // Добавляем обработчик нажатия
        button.tag = tabButtons.count - 1
        button.addTarget(self, action: #selector(tabButtonTapped(_:)), for: .touchUpInside)
    }
    
    /// Активирует таб с указанным индексом
    /// - Parameter index: Индекс таба
    func activateTab(at index: Int) {
        guard index >= 0 && index < tabButtons.count else { return }
        
        // Обновляем внешний вид всех кнопок
        for (i, button) in tabButtons.enumerated() {
            updateTabButtonAppearance(button, isActive: i == index)
        }
        
        // Скрываем все содержимое табов
        for content in tabContents {
            content.isHidden = true
        }
        
        // Показываем содержимое активного таба
        tabContents[index].isHidden = false
        
        // Обновляем индекс активного таба
        activeTabIndex = index
        
        // Вызываем обработчик изменения таба
        onTabChanged?(index)
    }
    
    /// Возвращает содержимое активного таба
    /// - Returns: Содержимое активного таба
    func getActiveTabContent() -> UIView? {
        guard activeTabIndex >= 0 && activeTabIndex < tabContents.count else { return nil }
        return tabContents[activeTabIndex]
    }
    
    /// Возвращает содержимое таба Summary, если оно есть
    /// - Returns: Содержимое таба Summary
    func getSummaryTabView() -> SummaryTabView? {
        return tabContents.first { $0 is SummaryTabView } as? SummaryTabView
    }
    
    // MARK: - Private Methods
    
    /// Создает кнопку таба
    /// - Parameters:
    ///   - title: Заголовок таба
    ///   - isActive: Флаг активности таба
    /// - Returns: Кнопка таба
    private func createTabButton(title: String, isActive: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        button.backgroundColor = .white
        button.layer.cornerRadius = 20
        button.layer.masksToBounds = true
        
        // Настраиваем внешний вид в зависимости от активности
        updateTabButtonAppearance(button, isActive: isActive)
        
        return button
    }
    
    /// Обновляет внешний вид кнопки таба
    /// - Parameters:
    ///   - button: Кнопка таба
    ///   - isActive: Флаг активности таба
    private func updateTabButtonAppearance(_ button: UIButton, isActive: Bool) {
        if isActive {
            button.setTitleColor(.systemGreen, for: .normal)
            button.layer.borderWidth = 2
            button.layer.borderColor = UIColor.systemGreen.cgColor
        } else {
            button.setTitleColor(.darkGray, for: .normal)
            button.layer.borderWidth = 0
        }
    }
    
    /// Обработчик нажатия на кнопку таба
    /// - Parameter sender: Кнопка таба
    @objc private func tabButtonTapped(_ sender: UIButton) {
        activateTab(at: sender.tag)
    }
}
