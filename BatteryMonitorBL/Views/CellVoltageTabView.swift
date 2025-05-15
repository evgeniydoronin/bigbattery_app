//
//  CellVoltageTabView.swift
//  BatteryMonitorBL
//
//  Created by Evgenii Doronin on 2025/5/15.
//

import UIKit
import SnapKit

/// Компонент для отображения напряжения ячеек батареи в виде сетки
class CellVoltageTabView: UIView {
    
    // MARK: - Private Properties
    
    /// Коллекция для отображения ячеек батареи
    private let collectionView: UICollectionView
    
    /// Данные о напряжении ячеек батареи
    private var cellVoltages: [Float] = []
    
    /// Количество ячеек в заглушке
    private let defaultCellCount = 16
    
    /// Идентификатор ячейки коллекции
    private let cellIdentifier = "CellVoltageCell"
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        // Создаем layout для коллекции
        let layout = UICollectionViewFlowLayout()
        
        // НАСТРОЙКА: Отступы между ячейками
        // Вертикальный отступ между строками ячеек
        layout.minimumLineSpacing = 5
        
        // Горизонтальный отступ между ячейками в строке
        layout.minimumInteritemSpacing = 5
        
        // Создаем коллекцию с layout
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        
        super.init(frame: frame)
        
        setupView()
    }
    
    required init?(coder: NSCoder) {
        // Создаем layout для коллекции
        let layout = UICollectionViewFlowLayout()
        
        // НАСТРОЙКА: Отступы между ячейками
        // Вертикальный отступ между строками ячеек
        layout.minimumLineSpacing = 5
        
        // Горизонтальный отступ между ячейками в строке
        layout.minimumInteritemSpacing = 5
        
        // Создаем коллекцию с layout
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        
        super.init(coder: coder)
        
        setupView()
    }
    
    // MARK: - Setup
    
    private func setupView() {
        // НАСТРОЙКА: Параметры коллекции
        
        // Цвет фона коллекции (прозрачный)
        collectionView.backgroundColor = .clear
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(CellVoltageCell.self, forCellWithReuseIdentifier: cellIdentifier)
        
        // Включение вертикальной прокрутки
        collectionView.alwaysBounceVertical = true
        
        // Показывать индикатор прокрутки (полосу справа)
        collectionView.showsVerticalScrollIndicator = true
        
        // НАСТРОЙКА: Отступы коллекции от краев экрана
        // Увеличьте значения для большего отступа от краев
        collectionView.contentInset = UIEdgeInsets(
            top: 10,    // Отступ сверху
            left: 0,   // Отступ слева
            bottom: 10, // Отступ снизу
            right: 0   // Отступ справа
        )
        
        // Добавляем коллекцию на view
        addSubview(collectionView)
        
        // Настраиваем ограничения для коллекции
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Инициализируем заглушку с 16 ячейками
        setupDefaultCells()
    }
    
    /// Создает заглушку с 16 ячейками
    private func setupDefaultCells() {
        // Создаем массив с 16 значениями напряжения по умолчанию (3.25V для всех ячеек)
        cellVoltages = Array(repeating: 3.25, count: defaultCellCount)
        collectionView.reloadData()
    }
    
    // MARK: - Public Methods
    
    /// Обновляет данные о напряжении ячеек батареи
    /// - Parameter voltages: Массив значений напряжения ячеек
    func updateCellVoltages(_ voltages: [Float]) {
        cellVoltages = voltages
        collectionView.reloadData()
    }
}

// MARK: - UICollectionViewDataSource

extension CellVoltageTabView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // Всегда возвращаем defaultCellCount (16) ячеек
        return defaultCellCount
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as! CellVoltageCell
        
        // Если индекс выходит за пределы массива, используем значение по умолчанию (3.25V)
        let voltage: Float
        if indexPath.item < cellVoltages.count {
            voltage = cellVoltages[indexPath.item]
        } else {
            voltage = 3.25
        }
        
        // Настраиваем ячейку
        cell.configure(voltage: voltage, cellNumber: indexPath.item + 1)
        cell.isHidden = false
        
        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

// MARK: - Настройка размеров ячеек

extension CellVoltageTabView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Вычисляем размер ячейки (4 ячейки в ряду с учетом отступов)
        // Учитываем отступы contentInset и межячеечные отступы
        let availableWidth = collectionView.bounds.width - collectionView.contentInset.left - collectionView.contentInset.right
        let interitemSpacing = (collectionViewLayout as! UICollectionViewFlowLayout).minimumInteritemSpacing
        let width = (availableWidth - interitemSpacing * 3) / 4 // 3 отступа между 4 ячейками
        
        // НАСТРОЙКА: Высота ячейки
        // Изменяйте это значение, чтобы увеличить или уменьшить высоту ячейки
        let cellHeight: CGFloat = 70
        
        return CGSize(width: width, height: cellHeight)
    }
}

// MARK: - CellVoltageCell

/// Ячейка для отображения напряжения одной ячейки батареи
class CellVoltageCell: UICollectionViewCell {
    
    // MARK: - UI Elements
    
    /// Иконка батареи
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        
        // Режим отображения изображения (сохранение пропорций)
        imageView.contentMode = .scaleAspectFit
        
        // НАСТРОЙКА: Цвет иконки батареи
        // Варианты: .systemGreen, .systemBlue, .systemRed, .black и т.д.
        imageView.tintColor = .systemGreen
        
        return imageView
    }()
    
    /// Метка для отображения напряжения
    private let voltageLabel: UILabel = {
        let label = UILabel()
        
        // НАСТРОЙКА: Шрифт для значения напряжения
        // Изменяйте размер (ofSize) и толщину (weight) шрифта
        label.font = .systemFont(ofSize: 16, weight: .bold)
        
        // НАСТРОЙКА: Цвет текста для значения напряжения
        label.textColor = .black
        
        // НАСТРОЙКА: Выравнивание текста для значения напряжения
        // Варианты: .left, .center, .right
        label.textAlignment = .center
        
        return label
    }()
    
    /// Метка для отображения номера ячейки
    private let cellNumberLabel: UILabel = {
        let label = UILabel()
        
        // НАСТРОЙКА: Шрифт для номера ячейки
        // Изменяйте размер (ofSize) и толщину (weight) шрифта
        label.font = .systemFont(ofSize: 11, weight: .regular)
        
        // НАСТРОЙКА: Цвет текста для номера ячейки
        label.textColor = .gray
        
        // НАСТРОЙКА: Выравнивание текста для номера ячейки
        // Варианты: .left, .center, .right
        label.textAlignment = .left
        
        return label
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
        // НАСТРОЙКА: Стили ячейки
        
        // Цвет фона ячейки
        contentView.backgroundColor = .white
        
        // Скругление углов ячейки (увеличьте для более круглых углов)
        contentView.layer.cornerRadius = 10
        
        // Толщина рамки ячейки (0 - без рамки)
        contentView.layer.borderWidth = 1
        
        // Цвет рамки ячейки (прозрачность можно регулировать через withAlphaComponent)
        contentView.layer.borderColor = UIColor.lightGray.withAlphaComponent(0.3).cgColor
        
        // Добавляем элементы на contentView
        contentView.addSubview(voltageLabel)
        
        // Создаем контейнер для иконки и номера ячейки
        let iconAndNumberContainer = UIView()
        contentView.addSubview(iconAndNumberContainer)
        
        // Добавляем иконку и номер ячейки в контейнер
        iconAndNumberContainer.addSubview(iconImageView)
        iconAndNumberContainer.addSubview(cellNumberLabel)
        
        // Загружаем иконку батареи
        iconImageView.image = UIImage(named: "cell_icon")
        
        // НАСТРОЙКА: Отступы и размеры контейнера для иконки и номера ячейки
        iconAndNumberContainer.snp.makeConstraints { make in
            // Отступ снизу от края ячейки
            make.bottom.equalToSuperview().offset(-8)
            
            // Отступы слева и справа от края ячейки
            make.leading.trailing.equalToSuperview().inset(8)
            
            // Высота контейнера для иконки и номера ячейки
            make.height.equalTo(24)
        }
        
        // НАСТРОЙКА: Отступы и размеры для значения напряжения (первая строка)
        voltageLabel.snp.makeConstraints { make in
            // Отступ сверху от края ячейки
            make.top.equalToSuperview().offset(12)
            
            // Центрирование по горизонтали
            make.centerX.equalToSuperview()
            
            // Отступы слева и справа от края ячейки
            make.leading.trailing.equalToSuperview().inset(8)
            
            // Высота метки с напряжением
            make.height.equalTo(24)
        }
        
        // НАСТРОЙКА: Отступы и размеры для иконки (вторая строка, слева)
        iconImageView.snp.makeConstraints { make in
            // Отступ слева от края контейнера
            make.leading.equalToSuperview().offset(0)
            
            // Центрирование по вертикали внутри контейнера
            make.centerY.equalToSuperview()
            
            // Размер иконки (ширина и высота)
            make.width.height.equalTo(20)
        }
        
        // НАСТРОЙКА: Отступы для номера ячейки (вторая строка, справа)
        cellNumberLabel.snp.makeConstraints { make in
            // Отступ слева от иконки
            make.leading.equalTo(iconImageView.snp.trailing).offset(4)
            
            // Отступ справа от края контейнера
            make.trailing.equalToSuperview().offset(-4)
            
            // Центрирование по вертикали внутри контейнера
            make.centerY.equalToSuperview()
        }
    }
    
    // MARK: - Public Methods
    
    /// Настраивает ячейку с заданными значениями
    /// - Parameters:
    ///   - voltage: Напряжение ячейки
    ///   - cellNumber: Номер ячейки
    func configure(voltage: Float, cellNumber: Int) {
        // НАСТРОЙКА: Формат отображения напряжения
        // %.2f - два знака после запятой
        // %.3f - три знака после запятой
        // %.1f - один знак после запятой
        voltageLabel.text = String(format: "%.2f V", voltage)
        
        // НАСТРОЙКА: Формат отображения номера ячейки
        // Можно изменить префикс "Cell" на любой другой или убрать совсем
        cellNumberLabel.text = "Cell \(cellNumber)"
    }
}
