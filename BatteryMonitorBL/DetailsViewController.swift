//
//  DetailsViewController.swift
//  VoltGoPower
//
//  Created by xxtx on 2022/12/5.
//

import Foundation
import UIKit
import Zetara
import RxSwift
import RxBluetoothKit2

class DetailsViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    var cellVoltages: [Float] = []
    var cellTemps: [Int8] = []
    var pcbTemperature: Int8 = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Добавляем фоновое изображение
        let backgroundImageView = UIImageView(image: R.image.background())
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.frame = view.bounds
        backgroundImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(backgroundImageView)
        view.sendSubviewToBack(backgroundImageView)
        
        // Явно назначаем делегат и источник данных
        collectionView.delegate = self
        collectionView.dataSource = self
        
        // Настраиваем flowLayout
        let flowLayout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        flowLayout.sectionInset = .init(top: 0, left: 30, bottom: 20, right: 30)
        flowLayout.headerReferenceSize = CGSize(width: self.view.frame.size.width - 60, height: 60)
        flowLayout.minimumInteritemSpacing = 10
        flowLayout.minimumLineSpacing = 10
        
        // Убеждаемся, что collectionView имеет правильные ограничения
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        if collectionView.constraints.isEmpty {
            NSLayoutConstraint.activate([
                collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
        
        // Делаем фон collectionView прозрачным
        collectionView.backgroundColor = .clear
        
        // Регистрируем ячейки и заголовки
        collectionView.register(VoltageCell.self, forCellWithReuseIdentifier: "voltage")
        collectionView.register(TemperatureCell.self, forCellWithReuseIdentifier: "temperature")
        collectionView.register(LogoCell.self, forCellWithReuseIdentifier: "logo")
        collectionView.register(SectionHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "header")
        
        // Настраиваем наблюдателей
        setupObservers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Перезагружаем данные при появлении экрана
        collectionView.reloadData()
    }
    
    var disposeBag = DisposeBag()
    func setupObservers() {
        ZetaraManager.shared.bmsDataSubject
            .subscribeOn(MainScheduler.instance)
            .subscribe { [weak self] (_data: Zetara.Data.BMS) in
                self?.cellVoltages = _data.cellVoltages
                self?.cellTemps = _data.cellTemps
                self?.pcbTemperature = _data.tempPCB
                self?.collectionView.reloadData()
            }.disposed(by: disposeBag)
    }
}

extension DetailsViewController {
    class LogoCell: UICollectionViewCell {
        var logoImageView = UIImageView(image: .init(named: "LogoColor"))
        
        override init(frame: CGRect) {
            super.init(frame: .zero)
            
            // Настраиваем изображение
            logoImageView.contentMode = .scaleAspectFit
            contentView.addSubview(logoImageView)
            
            logoImageView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.width.height.equalTo(150) // Размер можно настроить
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    class VoltageCell: UICollectionViewCell {
        var label = UILabel().then {
            $0.font = .systemFont(ofSize: 16, weight: .bold)
            $0.textColor = R.color.detailsCellVoltageText()!
        }
        
        override init(frame: CGRect) {
            super.init(frame: .zero)
            
            // Добавляем полупрозрачный фон
            contentView.backgroundColor = UIColor.white.withAlphaComponent(0.7)
            
            // Добавляем скругление углов
            contentView.layer.cornerRadius = 8
            contentView.clipsToBounds = true
            
            // Добавляем тонкую рамку
            contentView.layer.borderColor = R.color.detailsCellVoltageBorder()!.cgColor
            contentView.layer.borderWidth = 1
            
            // Добавляем тень для эффекта глубины (по гайдлайнам Apple)
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOffset = CGSize(width: 0, height: 1)
            layer.shadowOpacity = 0.1
            layer.shadowRadius = 2
            layer.masksToBounds = false
            
            contentView.addSubview(label)
            label.snp.makeConstraints { make in
                make.center.equalToSuperview()
            }
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
        }
    }
    
    class TemperatureCell: UICollectionViewCell {
        var iconImageView = UIImageView(frame: .zero)
        var titleLabel = UILabel().then {
            $0.font = .systemFont(ofSize: 14)
            $0.textColor = R.color.detailsTemperatureTitle()
        }
        
        var temperatureLabel = UILabel().then {
            $0.font = .systemFont(ofSize: 14, weight: .regular)
            $0.textColor = .black
        }
        
        override init(frame: CGRect) {
            super.init(frame: .zero)
            
            // Добавляем полупрозрачный фон
            contentView.backgroundColor = UIColor.white.withAlphaComponent(0.7)
            
            // Добавляем скругление углов
            contentView.layer.cornerRadius = 12
            contentView.clipsToBounds = true
            
            // Добавляем тень для эффекта глубины (по гайдлайнам Apple)
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOffset = CGSize(width: 0, height: 1)
            layer.shadowOpacity = 0.1
            layer.shadowRadius = 2
            layer.masksToBounds = false
            
            // Добавляем отступы для контента
            let paddingView = UIView()
            contentView.addSubview(paddingView)
            paddingView.snp.makeConstraints { make in
                make.edges.equalToSuperview().inset(UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12))
            }
            
            paddingView.addSubview(iconImageView)
            paddingView.addSubview(titleLabel)
            paddingView.addSubview(temperatureLabel)
            
            iconImageView.snp.makeConstraints { make in
                make.leading.centerY.equalToSuperview()
                make.width.height.equalTo(34)
            }
            
            titleLabel.snp.makeConstraints { make in
                make.leading.equalTo(iconImageView.snp.trailing).offset(8)
                make.centerY.equalToSuperview()
            }
            
            temperatureLabel.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.trailing.equalToSuperview()
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    class SectionHeader: UICollectionReusableView {
        let label = UILabel().then {
            $0.font = .systemFont(ofSize: 16, weight: .bold)
            $0.textColor = .black
        }
        
        override init(frame: CGRect) {
            super.init(frame: .zero)
            addSubview(label)
            
            label.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(30)
                make.centerY.equalToSuperview()
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

extension DetailsViewController: UICollectionViewDelegateFlowLayout,
                                 UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        3 // Добавляем третью секцию для логотипа
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            // Возвращаем 0 вместо cellVoltages.count, чтобы скрыть секцию
            return 0
        } else if section == 1 {
            let cellTempsCount = cellVoltages.count == 16 ? cellTemps.count : 2
            return 1 + min(cellTempsCount, cellTemps.count)
        } else {
            return 1 // Одна ячейка для логотипа
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "voltage", for: indexPath) as! VoltageCell
            cell.label.text = String(format: "%.3f", self.cellVoltages[indexPath.item])
            return cell
        } else if indexPath.section == 1 {
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "temperature", for: indexPath) as! TemperatureCell
            
            if indexPath.item == 0 {
                cell.iconImageView.image = R.image.detailsPCB()
                cell.titleLabel.text = "PCB Temperature"
                cell.temperatureLabel.text = "\(self.pcbTemperature)°C/\(self.pcbTemperature.celsiusToFahrenheit())°F"
            } else {
                // 第一个indexpath是 pcb，所以这里要 -1
                let cellTemp = self.cellTemps[indexPath.row - 1]
//                let cellTempString = String(format: "%.3f", cellTemp)
//                let cellFahrenheitString = String(format: "%.3f", cellTemp.celsiusToFahrenheit())
                cell.iconImageView.image = R.image.detailsCellTemperature()
                cell.titleLabel.text = "Cell Temperature \(indexPath.item)"
                cell.temperatureLabel.text = "\(cellTemp)°C/\(cellTemp.celsiusToFahrenheit())°F"
            }
            
            return cell
        } else {
            // Секция для логотипа
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "logo", for: indexPath) as! LogoCell
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath) as! SectionHeader
        if indexPath.section == 0 {
            // Скрываем заголовок для секции Cell Voltage
            view.label.text = ""
        } else if indexPath.section == 1 {
            view.label.text = "Temperature"
        } else {
            view.label.text = "" // Пустой заголовок для секции логотипа
        }
        return view
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if indexPath.section == 0 {
            return CGSize(width: 60, height: 28)
        } else if indexPath.section == 1 {
            return CGSize(width: collectionView.frame.width - 60, height: 60)
        } else {
            return CGSize(width: collectionView.frame.width - 60, height: 100) // Размер ячейки для логотипа
        }
    }
}
