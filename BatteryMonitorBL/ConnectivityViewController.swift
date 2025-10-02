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

    // MARK: - Constants

    /// Уведомление об обновлении протоколов (должно совпадать с HomeViewController.protocolsDidUpdateNotification)
    private static let protocolsDidUpdateNotification = Notification.Name("ProtocolsDidUpdateNotification")

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
                    let deviceName = peripheral.name ?? "Unknown"

                    AppLogger.shared.info(
                        screen: AppLogger.Screen.connectivity,
                        event: AppLogger.Event.disconnectionStarted,
                        message: "[PROTOCOL_DEBUG] 🔌 Disconnecting from device: \(deviceName)",
                        details: [
                            "deviceName": deviceName,
                            "deviceId": peripheral.identifier.uuidString
                        ]
                    )

                    ZetaraManager.shared.disconnect(peripheral)
                }
                return
            default:
                let peripheral = self.scannedPeripherals[indexPath.row]
                let deviceName = peripheral.peripheral.name ?? "Unknown"

                AppLogger.shared.info(
                    screen: AppLogger.Screen.connectivity,
                    event: AppLogger.Event.connectionStarted,
                    message: "[PROTOCOL_DEBUG] 🔗 Attempting to connect to device: \(deviceName)",
                    details: [
                        "deviceName": deviceName,
                        "deviceId": peripheral.peripheral.identifier.uuidString,
                        "rssi": peripheral.rssi ?? 0
                    ]
                )

                ZetaraManager.shared.connect(peripheral.peripheral)
                    .subscribeOn(MainScheduler.instance)
                    .subscribe(onNext: { [weak self] (connectedPeripheral:ZetaraManager.ConnectedPeripheral) in
                        let deviceName = connectedPeripheral.name ?? "Unknown"
                        let deviceId = connectedPeripheral.identifier.uuidString

                        AppLogger.shared.info(
                            screen: AppLogger.Screen.connectivity,
                            event: AppLogger.Event.connectionSucceeded,
                            message: "[PROTOCOL_DEBUG] 🎉 Device connected successfully: \(deviceName)",
                            details: [
                                "deviceName": deviceName,
                                "deviceId": deviceId,
                                "connectionTime": Date().timeIntervalSince1970
                            ]
                        )

                        self?.state = .connected
                        self?.tableView.reloadData()

                        // ИСПРАВЛЕНИЕ (02.10.2025): Загружаем протоколы сразу после подключения
                        // Это решает проблему пустого кэша когда пользователь не открывает Settings
                        AppLogger.shared.info(
                            screen: AppLogger.Screen.connectivity,
                            event: AppLogger.Event.dataUpdated,
                            message: "[PROTOCOL_DEBUG] 📡 Loading protocols after connection to fill cache"
                        )

                        self?.loadProtocolsAfterConnection()

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            AppLogger.shared.info(
                                screen: AppLogger.Screen.connectivity,
                                event: AppLogger.Event.stateChanged,
                                message: "[PROTOCOL_DEBUG] 🔙 Returning to Home screen after successful connection",
                                details: [
                                    "deviceName": deviceName,
                                    "willTriggerProtocolLoad": true
                                ]
                            )

                            // Отправляем уведомление об обновлении протоколов перед возвратом
                            NotificationCenter.default.post(name: ConnectivityViewController.protocolsDidUpdateNotification, object: nil)

                            self?.navigationController?.popViewController(animated: true)
                        }

                    }, onError: { [weak self] error in
                        AppLogger.shared.error(
                            screen: AppLogger.Screen.connectivity,
                            event: AppLogger.Event.connectionFailed,
                            message: "[PROTOCOL_DEBUG] 💥 Device connection failed: \(error.localizedDescription)",
                            details: [
                                "error": error.localizedDescription,
                                "errorCode": (error as NSError).code
                            ]
                        )

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

    // MARK: - Protocol Loading After Connection

    /// Загружает протоколы сразу после подключения чтобы заполнить кэш
    /// ИСПРАВЛЕНИЕ (02.10.2025): решает проблему пустого кэша когда пользователь не открывает Settings
    private func loadProtocolsAfterConnection() {
        let deviceName = ZetaraManager.shared.connectedPeripheral()?.name ?? "Unknown"

        // Загружаем Module ID
        ZetaraManager.shared.getModuleId()
            .timeout(.seconds(3), scheduler: MainScheduler.instance)
            .subscribe(onSuccess: { idData in
                // Сохраняем в кэш
                ZetaraManager.shared.cachedModuleIdData = idData

                AppLogger.shared.info(
                    screen: AppLogger.Screen.connectivity,
                    event: AppLogger.Event.dataUpdated,
                    message: "[PROTOCOL_DEBUG] ✅ Module ID loaded after connection: \(idData.readableId())",
                    details: ["deviceName": deviceName]
                )

                // Загружаем RS485
                ZetaraManager.shared.getRS485()
                    .timeout(.seconds(3), scheduler: MainScheduler.instance)
                    .subscribe(onSuccess: { rs485Data in
                        // Сохраняем в кэш
                        ZetaraManager.shared.cachedRS485Data = rs485Data

                        AppLogger.shared.info(
                            screen: AppLogger.Screen.connectivity,
                            event: AppLogger.Event.dataUpdated,
                            message: "[PROTOCOL_DEBUG] ✅ RS485 loaded after connection: \(rs485Data.readableProtocol())",
                            details: ["deviceName": deviceName]
                        )

                        // Загружаем CAN
                        ZetaraManager.shared.getCAN()
                            .timeout(.seconds(3), scheduler: MainScheduler.instance)
                            .subscribe(onSuccess: { canData in
                                // Сохраняем в кэш
                                ZetaraManager.shared.cachedCANData = canData

                                AppLogger.shared.info(
                                    screen: AppLogger.Screen.connectivity,
                                    event: AppLogger.Event.dataUpdated,
                                    message: "[PROTOCOL_DEBUG] ✅ CAN loaded after connection: \(canData.readableProtocol())",
                                    details: ["deviceName": deviceName]
                                )

                                // ВСЕ протоколы загружены - отправляем уведомление для Home
                                NotificationCenter.default.post(
                                    name: HomeViewController.protocolsDidUpdateNotification,
                                    object: nil
                                )
                            }, onError: { error in
                                AppLogger.shared.error(
                                    screen: AppLogger.Screen.connectivity,
                                    event: AppLogger.Event.errorOccurred,
                                    message: "[PROTOCOL_DEBUG] ❌ CAN load failed after connection: \(error.localizedDescription)",
                                    details: ["deviceName": deviceName]
                                )
                            })
                    }, onError: { error in
                        AppLogger.shared.error(
                            screen: AppLogger.Screen.connectivity,
                            event: AppLogger.Event.errorOccurred,
                            message: "[PROTOCOL_DEBUG] ❌ RS485 load failed after connection: \(error.localizedDescription)",
                            details: ["deviceName": deviceName]
                        )
                    })
            }, onError: { error in
                AppLogger.shared.error(
                    screen: AppLogger.Screen.connectivity,
                    event: AppLogger.Event.errorOccurred,
                    message: "[PROTOCOL_DEBUG] ❌ Module ID load failed after connection: \(error.localizedDescription)",
                    details: ["deviceName": deviceName]
                )
            })
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
