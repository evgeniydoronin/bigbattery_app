//
//  HomeViewController.swift
//  VoltGoPower
//
//  Created by xxtx on 2022/5/23.
//

import UIKit
import Zetara
import GradientView
import SnapKit
import RxSwift
import RxCocoa
import RxBluetoothKit2

class TitleButton: UIButton {
    override var intrinsicContentSize: CGSize {
        UIView.layoutFittingExpandedSize
    }
}

class HomeViewController: UIViewController {
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    lazy var titleButton: TitleButton = {
        let b = TitleButton()
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setImage(R.image.homeBluetooth(), for: .normal)
        b.imageView?.contentMode = .scaleAspectFill
        b.titleLabel?.font = .systemFont(ofSize: 20, weight: .medium)
        b.setTitleColor(.black, for: .normal)
        b.imageEdgeInsets = UIEdgeInsets(top: 4, left: 0, bottom: 0, right: 12)
        return b
    }()

    @IBOutlet weak var timerLabel: UILabel!
    @IBOutlet weak var logoImageView: UIImageView!
    @IBOutlet weak var componentsStackView: UIStackView!
    @IBOutlet weak var batteryInfoView: BatteryInfoView!
    @IBOutlet weak var batteryView: BatteryView!
    
    var voltageComponentView: ComponentView = ComponentView(icon: R.image.homeComponentVoltage()!, title:"Voltage" , value: "0")
    var currentComponentView: ComponentView = ComponentView(icon: R.image.homeComponentCurrent()!, title: "Current", value: "0")
    var tempComponentView: ComponentView = ComponentView(icon: R.image.homeComponentTemperature()!, title: "Temperature", value: "0°C/0°F")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /// Tab bar appearance
        let appearance = UITabBarAppearance()

        /// General
        appearance.backgroundColor = .white
        appearance.shadowImage = UIImage()
        appearance.shadowColor = appColor.withAlphaComponent(0.25)

        /// Normal tabs
        appearance.stackedLayoutAppearance.normal.iconColor = appColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [NSAttributedString.Key.foregroundColor: appColor.withAlphaComponent(0.25)]
        appearance.stackedLayoutAppearance.normal.badgeBackgroundColor = .white

        /// Selected tab
        appearance.stackedLayoutAppearance.selected.iconColor = appColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [NSAttributedString.Key.foregroundColor: appColor]

        self.tabBarController!.tabBar.standardAppearance = appearance
        
        /// Connect if no device connected
//        if ZetaraManager.shared.connectedPeripheral() == nil {
//            self.performSegue(withIdentifier: R.segue.homeViewController.pushConnectivityPage, sender: self.navigationController)
//        }
        
        self.navigationItem.titleView = titleButton
        componentsStackView.addArrangedSubview(voltageComponentView)
        componentsStackView.addArrangedSubview(currentComponentView)
        componentsStackView.addArrangedSubview(tempComponentView)
        componentsStackView.setCustomSpacing(36, after: tempComponentView)
        
        setupObservers()
        timerLabel.isHidden = true
    }
    
    var disposeBag: DisposeBag = DisposeBag()
    func setupObservers() {
        
        ZetaraManager.shared.observableState
            .subscribeOn(MainScheduler.instance)
            .subscribe { (state: BluetoothState) in
                switch state {
                    case .poweredOff:
                        print("error")
                    default:
                        return
                }
            }.disposed(by: disposeBag)
        
        ZetaraManager.shared.bmsDataSubject
            .subscribeOn(MainScheduler.instance)
            .subscribe { [weak self] _data in
                self?.updateUI(_data)
            } onError: { error in
                print("er:\(error)")
            }.disposed(by: disposeBag)
        
        ZetaraManager.shared.connectedPeripheralSubject
            .subscribeOn(MainScheduler.instance)
            .subscribe { [weak self] (peripheral: ZetaraManager.ConnectedPeripheral?) in
                self?.updateTitle(peripheral)
            }.disposed(by: disposeBag)
        
        
        titleButton.rx.tap.subscribe(onNext: { [weak self] _ in
            self?.performSegue(withIdentifier: R.segue.homeViewController.pushConnectivityPage, sender: self?.navigationController)
        }).disposed(by: disposeBag)
    }
    
    /// 设备名称
    func updateTitle(_ peripheral: ZetaraManager.ConnectedPeripheral?) {
        if let peripheral = peripheral,
           let name = peripheral.name {
            timerLabel.isHidden = false
            titleButton.setTitle(name, for: .normal)
        } else {
            timerLabel.isHidden = true
            titleButton.setTitle(nil, for: .normal)
        }
    }
    
    func updateUI(_ data: Zetara.Data.BMS) {
        
        timerLabel.text = "Last Update: \(formatter.string(from: Date()))"
        
        let battery = Float(data.soc)/100.0

        // 电量 & 状态
        batteryInfoView.update(battery: battery, status: data.status.description)
        batteryInfoView.charging = data.status == .charging

        /// 电量
        batteryView.level = battery

        /// 信息
        voltageComponentView.value = "\(data.voltage)V"
        currentComponentView.value = "\(data.current)A"
        tempComponentView.value = "\(data.tempEnv)°C/\(data.tempEnv.celsiusToFahrenheit())°F"
    }
    
    var formatter: DateFormatter = {
        let d = DateFormatter()
        d.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return d
    }()
}


extension BinaryInteger {
    /// 摄氏度转华氏度
    /// - Returns: 华氏度温度
    func celsiusToFahrenheit() -> Int {
        return Int(self) * 9/5 + 32
    }
}

//extension Int {
//
//    /// 摄氏度转华氏度
//    /// - Returns: 华氏度温度
//    func celsiusToFahrenheit() -> Int {
//        return Int(self * 9/5 + 32)
//    }
//}

extension Float {
    func celsiusToFahrenheit() -> Float {
        return self * 9/5 + 32
    }
}
