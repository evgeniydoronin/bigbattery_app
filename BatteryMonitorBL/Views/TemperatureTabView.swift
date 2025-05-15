//
//  TemperatureTabView.swift
//  BatteryMonitorBL
//
//  Created by Evgenii Doronin on 2025/5/15.
//

import UIKit
import SnapKit

/// Компонент для отображения температуры датчиков в виде списка
class TemperatureTabView: UIView {
    
    // MARK: - Private Properties
    
    /// Таблица для отображения датчиков температуры
    private let tableView: UITableView
    
    /// Данные о температуре датчиков
    private var temperatures: [TemperatureSensorData] = []
    
    /// Идентификатор ячейки таблицы
    private let cellIdentifier = "TemperatureSensorCell"
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        // Создаем таблицу с группированным стилем для поддержки отступов между ячейками
        tableView = UITableView(frame: .zero, style: .grouped)
        
        super.init(frame: frame)
        
        setupView()
    }
    
    required init?(coder: NSCoder) {
        // Создаем таблицу с группированным стилем для поддержки отступов между ячейками
        tableView = UITableView(frame: .zero, style: .grouped)
        
        super.init(coder: coder)
        
        setupView()
    }
    
    // MARK: - Setup
    
    private func setupView() {
        // НАСТРОЙКА: Параметры таблицы
        
        // НАСТРОЙКА: Цвет фона таблицы
        // Варианты: .clear (прозрачный), .white, .systemBackground и т.д.
        tableView.backgroundColor = .clear
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(TemperatureSensorCell.self, forCellReuseIdentifier: cellIdentifier)
        
        // Отключаем разделители между ячейками
        tableView.separatorStyle = .none
        
        // Отключаем автоматическое следование отступам для читаемой ширины
        tableView.cellLayoutMarginsFollowReadableWidth = false
        
        // Убираем отступы, которые добавляет группированный стиль таблицы
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        
        // Включение вертикальной прокрутки
        tableView.alwaysBounceVertical = true
        
        // Показывать индикатор прокрутки (полосу справа)
        tableView.showsVerticalScrollIndicator = true
        
        // НАСТРОЙКА: Отступы таблицы от краев экрана
        // Увеличьте значения для большего отступа от краев
        tableView.contentInset = UIEdgeInsets(
            top: 10,    // Отступ сверху
            left: 0,    // Отступ слева
            bottom: 10, // Отступ снизу
            right: 0    // Отступ справа
        )
        
        // Добавляем таблицу на view
        addSubview(tableView)
        
        // Настраиваем ограничения для таблицы
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Инициализируем заглушку с 5 датчиками
        setupDefaultSensors()
    }
    
    /// Создает заглушку с 5 датчиками температуры
    private func setupDefaultSensors() {
        // Создаем массив с 5 датчиками температуры по умолчанию (75°F/24°C для всех датчиков)
        temperatures = [
            TemperatureSensorData(name: "Temp. Sensor #1", fahrenheit: 75, celsius: 24),
            TemperatureSensorData(name: "Temp. Sensor #2", fahrenheit: 75, celsius: 24),
            TemperatureSensorData(name: "Temp. Sensor #3", fahrenheit: 75, celsius: 24),
            TemperatureSensorData(name: "Temp. Sensor #4", fahrenheit: 75, celsius: 24),
            TemperatureSensorData(name: "Temp. Sensor #5", fahrenheit: 75, celsius: 24)
        ]
        tableView.reloadData()
    }
    
    // MARK: - Public Methods
    
    /// Обновляет данные о температуре датчиков
    /// - Parameters:
    ///   - pcbTemp: Температура PCB в Цельсиях
    ///   - envTemp: Температура окружающей среды в Цельсиях
    ///   - cellTemps: Массив температур ячеек в Цельсиях
    func updateTemperatures(pcbTemp: Int8, envTemp: Int8, cellTemps: [Int8]) {
        // Очищаем массив температур
        temperatures.removeAll()
        
        // Добавляем температуру PCB
        temperatures.append(TemperatureSensorData(
            name: "Temp. Sensor #1",
            fahrenheit: Int(pcbTemp.celsiusToFahrenheit()),
            celsius: Int(pcbTemp)
        ))
        
        // Добавляем температуру окружающей среды
        temperatures.append(TemperatureSensorData(
            name: "Temp. Sensor #2",
            fahrenheit: Int(envTemp.celsiusToFahrenheit()),
            celsius: Int(envTemp)
        ))
        
        // Добавляем температуры ячеек
        for (index, temp) in cellTemps.enumerated() {
            temperatures.append(TemperatureSensorData(
                name: "Temp. Sensor #\(index + 3)",
                fahrenheit: Int(temp.celsiusToFahrenheit()),
                celsius: Int(temp)
            ))
        }
        
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource

extension TemperatureTabView: UITableViewDataSource {
    // НАСТРОЙКА: Количество секций в таблице
    // Каждая ячейка находится в своей собственной секции, чтобы добавить отступы между ячейками
    func numberOfSections(in tableView: UITableView) -> Int {
        return temperatures.count
    }
    
    // В каждой секции только одна ячейка
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! TemperatureSensorCell
        
        // Настраиваем ячейку
        // Используем indexPath.section вместо indexPath.row, так как каждая ячейка находится в своей секции
        let sensorData = temperatures[indexPath.section]
        cell.configure(with: sensorData)
        
        return cell
    }
}

// MARK: - UITableViewDelegate

extension TemperatureTabView: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // НАСТРОЙКА: Высота ячейки
        // Изменяйте это значение, чтобы увеличить или уменьшить высоту ячейки
        let cellHeight: CGFloat = 40
        return cellHeight
    }
    
    // НАСТРОЙКА: Отступы между ячейками
    // Добавляем пустой footer после каждой ячейки для создания отступа
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footerView = UIView()
        footerView.backgroundColor = .clear
        return footerView
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        // НАСТРОЙКА: Высота отступа между ячейками
        // Увеличьте значение для большего отступа между ячейками
        // Примеры:
        // - 5 - маленький отступ
        // - 10 - средний отступ
        // - 20 - большой отступ
        return 10
    }
    
    // Убираем header секции, чтобы не было лишних отступов
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView()
        headerView.backgroundColor = .clear
        return headerView
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0.1 // Минимальная высота, чтобы header не занимал место
    }
}

// MARK: - TemperatureSensorData

/// Структура для хранения данных о температуре датчика
struct TemperatureSensorData {
    /// Название датчика
    let name: String
    
    /// Температура в градусах Фаренгейта
    let fahrenheit: Int
    
    /// Температура в градусах Цельсия
    let celsius: Int
}

// MARK: - TemperatureSensorCell

/// Ячейка для отображения информации о датчике температуры
class TemperatureSensorCell: UITableViewCell {
    
    // MARK: - UI Elements
    
    /// Иконка термометра
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        
        // Режим отображения изображения (сохранение пропорций)
        imageView.contentMode = .scaleAspectFit
        
        // НАСТРОЙКА: Цвет иконки термометра
        // Варианты: .systemBlue, .systemGreen, .systemRed, .black и т.д.
        imageView.tintColor = .systemBlue
        
        return imageView
    }()
    
    /// Метка для отображения названия датчика
    private let nameLabel: UILabel = {
        let label = UILabel()
        
        // НАСТРОЙКА: Шрифт для названия датчика
        // Изменяйте размер (ofSize) и толщину (weight) шрифта
        label.font = .systemFont(ofSize: 14, weight: .regular)
        
        // НАСТРОЙКА: Цвет текста для названия датчика
        label.textColor = .darkGray
        
        // НАСТРОЙКА: Выравнивание текста для названия датчика
        // Варианты: .left, .center, .right
        label.textAlignment = .left
        
        return label
    }()
    
    /// Метка для отображения температуры
    private let temperatureLabel: UILabel = {
        let label = UILabel()
        
        // НАСТРОЙКА: Шрифт для значения температуры
        // Изменяйте размер (ofSize) и толщину (weight) шрифта
        label.font = .systemFont(ofSize: 16, weight: .bold)
        
        // НАСТРОЙКА: Цвет текста для значения температуры
        label.textColor = .black
        
        // НАСТРОЙКА: Выравнивание текста для значения температуры
        // Варианты: .left, .center, .right
        label.textAlignment = .right
        
        return label
    }()
    
    // MARK: - Initialization
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - Setup
    
    private func setupView() {
        // НАСТРОЙКА: Стили ячейки
        
        // Отключаем выделение ячейки при нажатии
        selectionStyle = .none
        
        // Устанавливаем прозрачный фон для ячейки и contentView
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        
        // Создаем фоновую view с закругленными углами
        let backgroundView = UIView()
        backgroundView.backgroundColor = .white
        backgroundView.layer.cornerRadius = 10
        backgroundView.layer.borderWidth = 1
        backgroundView.layer.borderColor = UIColor.lightGray.withAlphaComponent(0.3).cgColor
        backgroundView.clipsToBounds = true
        
        // Добавляем фоновую view в contentView
        contentView.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Добавляем элементы на backgroundView, а не на contentView
        // чтобы они были видны внутри скругленного фона
        backgroundView.addSubview(iconImageView)
        backgroundView.addSubview(nameLabel)
        backgroundView.addSubview(temperatureLabel)
        
        // Загружаем иконку термометра
        iconImageView.image = UIImage(named: "Details.Cell.Temperature")
        
        // НАСТРОЙКА: Отступы и размеры для иконки термометра
        iconImageView.snp.makeConstraints { make in
            // НАСТРОЙКА: Отступ слева от края ячейки
            // Увеличьте значение для большего отступа
            make.leading.equalToSuperview().offset(10)
            
            // НАСТРОЙКА: Центрирование по вертикали
            // Можно изменить на make.top.equalToSuperview().offset(X) для выравнивания по верхнему краю
            make.centerY.equalToSuperview()
            
            // НАСТРОЙКА: Размер иконки (ширина и высота)
            // Увеличьте значение для большей иконки
            make.width.height.equalTo(32)
        }
        
        // НАСТРОЙКА: Отступы и размеры для названия датчика
        nameLabel.snp.makeConstraints { make in
            // НАСТРОЙКА: Отступ слева от иконки
            // Увеличьте значение для большего отступа между иконкой и названием
            make.leading.equalTo(iconImageView.snp.trailing).offset(5)
            
            // НАСТРОЙКА: Центрирование по вертикали
            // Можно изменить на make.top.equalToSuperview().offset(X) для выравнивания по верхнему краю
            make.centerY.equalToSuperview()
            
            // НАСТРОЙКА: Ширина названия датчика
            // Увеличьте значение для более длинных названий датчиков
            make.width.equalTo(150)
        }
        
        // НАСТРОЙКА: Отступы и размеры для значения температуры
        temperatureLabel.snp.makeConstraints { make in
            // НАСТРОЙКА: Отступ слева от названия датчика
            // Увеличьте значение для большего отступа между названием и значением
            make.leading.equalTo(nameLabel.snp.trailing).offset(16)
            
            // НАСТРОЙКА: Отступ справа от края ячейки
            // Увеличьте значение для большего отступа от правого края
            make.trailing.equalToSuperview().offset(-16)
            
            // НАСТРОЙКА: Центрирование по вертикали
            // Можно изменить на make.top.equalToSuperview().offset(X) для выравнивания по верхнему краю
            make.centerY.equalToSuperview()
        }
    }
    
    // MARK: - Public Methods
    
    /// Настраивает ячейку с заданными значениями
    /// - Parameter data: Данные о температуре датчика
    func configure(with data: TemperatureSensorData) {
        // НАСТРОЙКА: Формат отображения названия датчика
        nameLabel.text = data.name
        
        // НАСТРОЙКА: Формат отображения температуры
        // Можно изменить формат отображения температуры, например:
        // - "\(data.fahrenheit)°F" - только Фаренгейты
        // - "\(data.celsius)°C" - только Цельсии
        // - "F: \(data.fahrenheit)° | C: \(data.celsius)°" - другой формат
        // - String(format: "%.1f°F / %.1f°C", Float(data.fahrenheit), Float(data.celsius)) - с десятичными знаками
        temperatureLabel.text = "\(data.fahrenheit)°F / \(data.celsius)°C"
    }
}
