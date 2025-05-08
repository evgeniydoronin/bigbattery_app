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

// Класс TitleButton перемещен в BatteryInfoView.swift

class HomeViewController: UIViewController {
    
    // Добавляем шапку с белым фоном
    private let headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Добавляем логотип в шапку
    private let headerLogoImageView: UIImageView = {
        let imageView = UIImageView(image: R.image.headerLogo())
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
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
    
    // Удаляем titleButton, так как теперь используем bluetoothButton из batteryInfoView

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
        
        // Скрываем навигационный бар, так как мы добавляем свою шапку
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        
        // Добавляем шапку и логотип
        setupHeaderView()
        
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
        
        
        // Используем bluetoothButton из batteryInfoView вместо titleButton
        batteryInfoView.bluetoothButton.rx.tap.subscribe(onNext: { [weak self] _ in
            self?.performSegue(withIdentifier: R.segue.homeViewController.pushConnectivityPage, sender: self?.navigationController)
        }).disposed(by: disposeBag)
    }
    
    /// 设备名称
    func updateTitle(_ peripheral: ZetaraManager.ConnectedPeripheral?) {
        if let peripheral = peripheral,
           let name = peripheral.name {
            timerLabel.isHidden = false
            batteryInfoView.updateBluetoothButton(title: name)
        } else {
            timerLabel.isHidden = true
            batteryInfoView.updateBluetoothButton(title: nil)
        }
    }
    
    // Настройка шапки и логотипа
    private func setupHeaderView() {
        // Очищаем все существующие ограничения
        for subview in view.subviews {
            subview.removeFromSuperview()
        }
        
        // Добавляем фоновое изображение
        let backgroundImageView = UIImageView(image: R.image.background())
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundImageView)
        
        // Добавляем шапку на экран
        view.addSubview(headerView)
        
        // Добавляем логотип в шапку
        headerView.addSubview(headerLogoImageView)
        
        // Создаем скроллируемый контейнер для всего контента под шапкой
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        
        // Создаем вертикальный стек для размещения контейнеров с контентом
        let contentStackView = UIStackView()
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.alignment = .fill
        contentStackView.distribution = .fill
        contentStackView.spacing = 16
        scrollView.addSubview(contentStackView)
        
        // Создаем контейнеры для разных секций контента
        let timerContainer = UIView()
        timerContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let batteryInfoContainer = UIView()
        batteryInfoContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let batteryContainer = UIView()
        batteryContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let componentsContainer = UIView()
        componentsContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let logoContainer = UIView()
        logoContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // Добавляем контейнеры в стек
        contentStackView.addArrangedSubview(timerContainer)
        contentStackView.addArrangedSubview(batteryInfoContainer)
        contentStackView.addArrangedSubview(batteryContainer)
        contentStackView.addArrangedSubview(componentsContainer)
        contentStackView.addArrangedSubview(logoContainer)
        
        // Добавляем элементы в соответствующие контейнеры
        timerContainer.addSubview(timerLabel)
        batteryInfoContainer.addSubview(batteryInfoView)
        batteryContainer.addSubview(batteryView)
        componentsContainer.addSubview(componentsStackView)
        logoContainer.addSubview(logoImageView)
        
        // Настраиваем ограничения для фонового изображения
        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Настраиваем ограничения для шапки с учетом safeArea
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.topAnchor), // Начинаем от верха view
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // Высота шапки должна включать safeArea сверху плюс дополнительное пространство для контента
            headerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60) // 60 пикселей ниже safeArea
        ])
        
        // Настраиваем ограничения для логотипа - размещаем его в безопасной зоне
        NSLayoutConstraint.activate([
            headerLogoImageView.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            // Центрируем логотип по вертикали в безопасной зоне
            headerLogoImageView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 30),
            headerLogoImageView.widthAnchor.constraint(equalToConstant: 200), // Ширина логотипа
            headerLogoImageView.heightAnchor.constraint(equalToConstant: 60) // Высота логотипа
        ])
        
        // Настраиваем ограничения для скроллируемого контейнера
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor), // Начинаем под шапкой
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Настраиваем ограничения для стека с контентом
        NSLayoutConstraint.activate([
            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor) // Важно для правильного скроллинга
        ])
        
        // Обновляем ограничения для timerLabel
        timerLabel.snp.remakeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-16)
        }
        
        // Обновляем ограничения для batteryInfoView
        batteryInfoView.snp.remakeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-16)
            make.height.equalTo(84) // Увеличиваем высоту, чтобы вместить кнопку Bluetooth
        }
        
        // Обновляем ограничения для batteryView
        batteryView.snp.remakeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(120)
            make.height.equalTo(300)
            make.top.equalToSuperview().offset(16)
            make.bottom.equalToSuperview().offset(-16)
        }
        
        // Обновляем ограничения для componentsStackView
        componentsStackView.snp.remakeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.equalToSuperview().offset(30)
            make.trailing.equalToSuperview().offset(-30)
            make.bottom.equalToSuperview().offset(-16)
            make.height.equalTo(120)
        }
        
        // Обновляем ограничения для logoImageView
        logoImageView.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(16)
            make.bottom.equalToSuperview().offset(-16)
        }
        
        // Добавляем компоненты в componentsStackView
        componentsStackView.addArrangedSubview(voltageComponentView)
        componentsStackView.addArrangedSubview(currentComponentView)
        componentsStackView.addArrangedSubview(tempComponentView)
        componentsStackView.setCustomSpacing(36, after: tempComponentView)
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
