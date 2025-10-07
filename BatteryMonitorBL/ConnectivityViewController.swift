//
//  ConnectivityViewController.swift
//  VoltGoPower
//
//  Created by xxtx on 2022/12/5.
//

import Foundation
import UIKit
import Zetara
import Combine
import SnapKit
import CoreBluetooth
import RxSwift
import RxBluetoothKit2

class ConnectivityViewController : UIViewController {
    
    lazy var bluetoothSwitch = UISwitch()
    
    lazy var tableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.backgroundColor = nil
        return tableView
    }()
    
    var state: ConnectionState = .unconnected
    
    var scannedPeripherals: [ScannedPeripheral] = []
    var disposeBag = DisposeBag()
    
    deinit {
        print("deinit ConnectivityViewController.")
    }
    
    // Метод для возврата на предыдущий экран
    @objc func goBack() {
        navigationController?.popViewController(animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Показываем навигационную панель
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        
        // Добавляем кнопку "Back"
        let backButton = UIBarButtonItem(title: "Back", style: .plain, target: self, action: #selector(goBack))
        navigationItem.leftBarButtonItem = backButton
        
        // Включаем жесты смахивания
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
        
        // Добавляем фоновое изображение
        let backgroundImageView = UIImageView(image: R.image.background())
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.frame = view.bounds
        backgroundImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(backgroundImageView)
        view.sendSubviewToBack(backgroundImageView)
        
        bluetoothSwitch.onTintColor = appColor
        let rightBarButtonItem = UIBarButtonItem(customView: bluetoothSwitch)
        self.navigationItem.rightBarButtonItem = rightBarButtonItem
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        tableView.register(ConnectivityTableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.delegate = self
        tableView.dataSource = self
        
        bluetoothSwitch.setOn(true, animated: true)
        
        ZetaraManager.shared.connectedPeripheralSubject
            .compactMap { $0 }
            .take(1)
            .subscribe { [weak self] (_: ZetaraManager.ConnectedPeripheral) in
                self?.state = .connected
                self?.tableView.reloadData()
            }.disposed(by: disposeBag)
        
        ZetaraManager.shared.observableState
            .filter { $0 == .poweredOn }
            .flatMap { _ in ZetaraManager.shared.startScan() }
            .filter { $0.isNotEmpty }
            .subscribeOn(MainScheduler.instance)
            .subscribe { [weak self] (scannedPeripherals: [ScannedPeripheral]) in
                self?.scannedPeripherals = scannedPeripherals
                self?.tableView.reloadData()
            }.disposed(by: self.disposeBag)
        
        ZetaraManager.shared.observeDisconect()
            .subscribeOn(MainScheduler.instance)
            .subscribe {[weak self] event in
                self?.state = .unconnected
                self?.tableView.reloadData()
            }.disposed(by: self.disposeBag)

    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        print("[CONNECTIVITY] View will disappear - cancelling pending requests")

        // Отменяем все текущие подписки
        disposeBag = DisposeBag()
    }
}

extension ConnectivityViewController {
    enum ConnectionState {
        case unconnected
        case connected
    }
}

extension ConnectivityViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard indexPath.row < self.scannedPeripherals.count else {
            print("some thing error when did selected")
            return
        }

        switch state {
            case .connected where indexPath.section == 0:
                if let peripheral = try? ZetaraManager.shared.connectedPeripheralSubject.value() {
                    ZetaraManager.shared.disconnect(peripheral)
                }
                return
            default:
                let peripheral = self.scannedPeripherals[indexPath.row]
                ZetaraManager.shared.connect(peripheral.peripheral)
                    .subscribeOn(MainScheduler.instance)
                    .subscribe(onNext: { [weak self] (connectedPeripheral:ZetaraManager.ConnectedPeripheral) in
                        self?.state = .connected
                        self?.tableView.reloadData()
                        
                        // Загружаем протоколы через 1.5 сек после подключения (Этап 3.1)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self?.loadProtocolsViaQueue()
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self?.navigationController?.popViewController(animated: true)
                        }
                        
                    }, onError: { [weak self] error in
                        self?.state = .unconnected
                        Alert.show("Invalid device")
                    }).disposed(by: disposeBag)
        }
    }
}

extension ConnectivityViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        switch state {
            case .unconnected:
                return 1
            case .connected:
                return 2
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch state {
            case .unconnected:
                return self.scannedPeripherals.count
            case .connected where section == 0:
                return 1
            case .connected:
                return self.scannedPeripherals.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        guard indexPath.row <= self.scannedPeripherals.count else {
            return cell
        }

        switch state {
            case .connected where indexPath.section == 0:
                cell.detailTextLabel?.text = "Connected"
                cell.accessoryType = .none
                if let name = try? ZetaraManager.shared.connectedPeripheralSubject.value()?.name {
                    cell.textLabel?.text =  name
                } else {
                    cell.textLabel?.text = ""
                }
                
            default:
                let device = self.scannedPeripherals[indexPath.row]
                cell.textLabel?.text = device.peripheral.name
                cell.accessoryType = .disclosureIndicator
        }

        cell.backgroundColor = R.color.connectivityCellBackground()!
        cell.layer.cornerRadius = 2
        cell.layer.borderWidth = 1
        cell.layer.borderColor = R.color.connectivityCellBorder()?.cgColor
        cell.textLabel?.textColor = R.color.connectivityCellTitle()
        cell.detailTextLabel?.textColor = R.color.connectivityCellSubtitle()

        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch state {
            case .connected:
                if section == 0 {
                    return "Paired devices"
                } else {
                    return "Available devices"
                }

            case .unconnected:
                return "Available devices"
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        71
    }
    
    // MARK: - Protocol Loading (Этап 3.1)
    
    /// Загружает протоколы через ProtocolDataManager
    private func loadProtocolsViaQueue() {
        print("[PROTOCOLS] Starting protocol loading after connection...")

        // Загружаем все протоколы через ProtocolDataManager
        // Request Queue автоматически обеспечит минимальные интервалы между запросами
        ZetaraManager.shared.protocolDataManager.loadAllProtocols(afterDelay: 1.5)
    }
}


class ConnectivityTableViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        self.textLabel?.text = nil
        self.detailTextLabel?.text = nil
        self.accessoryType = .none
    }
}
