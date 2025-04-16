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
import RxBluetoothKit

class DetailsViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    var cellVoltages: [Float] = []
    var cellTemps: [Int8] = []
    var pcbTemperature: Int8 = 0
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let flowLayout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        
        // Настраиваем flowLayout для collectionView
        flowLayout.sectionInset = .init(top: 0, left: 30, bottom: 20, right: 30)
        flowLayout.headerReferenceSize = CGSize(width: self.view.frame.size.width - 60, height: 60)
        flowLayout.minimumLineSpacing = 10
        flowLayout.minimumInteritemSpacing = 10
        
        // Отключаем автоматическое определение размера ячеек
        flowLayout.estimatedItemSize = .zero
        
        makeGradientBackgroundView(in: self)
        
        // Проверяем, что collectionView существует и имеет правильный размер
        print("DetailsViewController.viewDidLoad: collectionView.frame=\(collectionView.frame)")
        
        // Исправляем constraints для collectionView
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), // Начинаем от верхнего края экрана
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        // Делаем collectionView видимым
        collectionView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.2)
        
        collectionView.register(VoltageCell.self, forCellWithReuseIdentifier: "voltage")
        collectionView.register(TemperatureCell.self, forCellWithReuseIdentifier: "temperature")
        collectionView.register(SectionHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "header")
        
        collectionView.delegate = self
        collectionView.dataSource = self
        
        
        setupObservers()
    }
    
    var disposeBag = DisposeBag()
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Обновляем collectionView после изменения размеров view
        print("DetailsViewController.viewDidLayoutSubviews: collectionView.frame=\(collectionView.frame)")
        collectionView.collectionViewLayout.invalidateLayout()
    }
    
    func setupObservers() {
        ZetaraManager.shared.bmsDataSubject
            .subscribeOn(MainScheduler.instance)
            .subscribe { [weak self] (_data: Zetara.Data.BMS) in
                print("DetailsViewController получил данные: cellVoltages=\(_data.cellVoltages.count), cellTemps=\(_data.cellTemps.count), pcbTemperature=\(_data.tempPCB)")
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
        print("DetailsViewController.numberOfSections: cellVoltages=\(cellVoltages.count), cellTemps=\(cellTemps.count)")
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            print("DetailsViewController.numberOfItemsInSection(0): cellVoltages=\(cellVoltages.count)")
            return cellVoltages.count
        } else {
            let cellTempsCount = cellVoltages.count == 16 ? cellTemps.count : 2
            print("DetailsViewController.numberOfItemsInSection(1): cellTempsCount=\(cellTempsCount), cellTemps.count=\(cellTemps.count)")
            return 1 + min(cellTempsCount, cellTemps.count)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        print("DetailsViewController.cellForItemAt: section=\(indexPath.section), item=\(indexPath.item)")
        
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "voltage", for: indexPath) as! VoltageCell
            let voltage = self.cellVoltages[indexPath.item]
            print("DetailsViewController.cellForItemAt: voltage=\(voltage)")
            cell.label.text = String(format: "%.3f", voltage)
            
            // Делаем ячейку более заметной
            cell.contentView.backgroundColor = UIColor.yellow.withAlphaComponent(0.3)
            
            return cell
        } else {
            
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "temperature", for: indexPath) as! TemperatureCell
            
            // Делаем ячейку более заметной
            cell.contentView.backgroundColor = UIColor.green.withAlphaComponent(0.3)
            
            if indexPath.item == 0 {
                print("DetailsViewController.cellForItemAt: PCB temperature=\(self.pcbTemperature)")
                cell.iconImageView.image = R.image.detailsPCB()
                cell.titleLabel.text = "PCB Temperature"
                cell.temperatureLabel.text = "\(self.pcbTemperature)°C/\(self.pcbTemperature.celsiusToFahrenheit())°F"
            } else {
                // 第一个indexpath是 pcb，所以这里要 -1
                let cellTemp = self.cellTemps[indexPath.row - 1]
                print("DetailsViewController.cellForItemAt: Cell temperature \(indexPath.item)=\(cellTemp)")
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
        print("DetailsViewController.viewForSupplementaryElementOfKind: kind=\(kind), section=\(indexPath.section)")
        
        if kind == UICollectionView.elementKindSectionHeader {
            let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath) as! SectionHeader
            
            // Делаем заголовок более заметным
            view.backgroundColor = UIColor.blue.withAlphaComponent(0.2)
            
            if indexPath.section == 0 {
                view.label.text = "Cell Voltage（V)"//"Cell Voltage（mV)"
            } else {
                view.label.text = "Temperature"
            }
            return view
        }
        
        // Этот код не должен выполняться, но нужен для компиляции
        return UICollectionReusableView()
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if indexPath.section == 0 {
            return CGSize(width: 60, height: 28)
        } else {
            return CGSize(width: collectionView.frame.width - 60, height: 60)
        }
    }
}
