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
        
        // Устанавливаем фон
        makeGradientBackgroundView(in: self)
        
        // Регистрируем ячейки и заголовки
        collectionView.register(VoltageCell.self, forCellWithReuseIdentifier: "voltage")
        collectionView.register(TemperatureCell.self, forCellWithReuseIdentifier: "temperature")
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
    class VoltageCell: UICollectionViewCell {
        var label = UILabel().then {
            $0.font = .systemFont(ofSize: 16, weight: .bold)
            $0.textColor = R.color.detailsCellVoltageText()!
        }
        
        override init(frame: CGRect) {
            super.init(frame: .zero)
            contentView.addSubview(label)
            label.snp.makeConstraints { make in
                make.center.equalToSuperview()
            }
            
            contentView.layer.borderColor = R.color.detailsCellVoltageBorder()!.cgColor
            contentView.layer.borderWidth = 1
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
            
            contentView.addSubview(iconImageView)
            contentView.addSubview(titleLabel)
            contentView.addSubview(temperatureLabel)
            
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
        2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return cellVoltages.count
        } else {
            let cellTempsCount = cellVoltages.count == 16 ? cellTemps.count : 2
            return 1 + min(cellTempsCount, cellTemps.count)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "voltage", for: indexPath) as! VoltageCell
            cell.label.text = String(format: "%.3f", self.cellVoltages[indexPath.item])
            return cell
        } else {
            
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
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath) as! SectionHeader
        if indexPath.section == 0 {
            view.label.text = "Cell Voltage（V)"//"Cell Voltage（mV)"
        } else {
            view.label.text = "Temperature"
        }
        return view
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if indexPath.section == 0 {
            return CGSize(width: 60, height: 28)
        } else {
            return CGSize(width: collectionView.frame.width - 60, height: 60)
        }
    }
}
