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
        
        // Скрываем навигационный бар при возвращении на главный экран
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
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
    
    // Свойства для новой плашки Bluetooth
    private var bluetoothConnectionView: UIView!
    private var deviceNameLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /// Настройка внешнего вида панели вкладок
        let appearance = UITabBarAppearance()

        /// Общие настройки
        appearance.backgroundColor = .white
        appearance.shadowImage = UIImage()
        appearance.shadowColor = appColor.withAlphaComponent(0.25)

        /// Обычные вкладки
        appearance.stackedLayoutAppearance.normal.iconColor = appColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [NSAttributedString.Key.foregroundColor: appColor.withAlphaComponent(0.25)]
        appearance.stackedLayoutAppearance.normal.badgeBackgroundColor = .white

        /// Выбранная вкладка
        appearance.stackedLayoutAppearance.selected.iconColor = appColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [NSAttributedString.Key.foregroundColor: appColor]

        self.tabBarController!.tabBar.standardAppearance = appearance
        
        /// Подключение, если устройство не подключено
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
            // Показываем навигационную панель перед переходом
            self?.navigationController?.setNavigationBarHidden(false, animated: true)
            self?.performSegue(withIdentifier: R.segue.homeViewController.pushConnectivityPage, sender: self?.navigationController)
        }).disposed(by: disposeBag)
        
        // Добавляем обработку нажатия на новую плашку bluetoothConnectionView
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBluetoothConnectionTap))
        bluetoothConnectionView.addGestureRecognizer(tapGesture)
        bluetoothConnectionView.isUserInteractionEnabled = true
    }
    
    @objc func handleBluetoothConnectionTap() {
        // Показываем навигационную панель перед переходом
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        performSegue(withIdentifier: R.segue.homeViewController.pushConnectivityPage, sender: navigationController)
    }
    
    /// Обновление имени устройства
    func updateTitle(_ peripheral: ZetaraManager.ConnectedPeripheral?) {
        if let peripheral = peripheral,
           let name = peripheral.name {
            timerLabel.isHidden = false
            batteryInfoView.updateBluetoothButton(title: name)
            // Обновляем название устройства в новой плашке
            deviceNameLabel.text = name
        } else {
            timerLabel.isHidden = true
            batteryInfoView.updateBluetoothButton(title: nil as String?)
            // Сбрасываем название устройства в новой плашке
            deviceNameLabel.text = "Connect Device"
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
        // Создаем контейнер для новой плашки Bluetooth
        let bluetoothConnectionContainer = UIView()
        bluetoothConnectionContainer.translatesAutoresizingMaskIntoConstraints = false
        
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
        contentStackView.addArrangedSubview(bluetoothConnectionContainer) // Добавляем новый контейнер в самый верх
        contentStackView.addArrangedSubview(timerContainer)
        contentStackView.addArrangedSubview(batteryInfoContainer)
        contentStackView.addArrangedSubview(batteryContainer)
        contentStackView.addArrangedSubview(componentsContainer)
        contentStackView.addArrangedSubview(logoContainer)
        
        // Создаем и настраиваем bluetoothConnectionView
        bluetoothConnectionView = UIView()
        bluetoothConnectionView.backgroundColor = UIColor.white
        bluetoothConnectionView.layer.cornerRadius = 10
        bluetoothConnectionView.layer.masksToBounds = true
        bluetoothConnectionView.layer.borderWidth = 1 // Ширина границы в пикселях 
        bluetoothConnectionView.layer.borderColor = UIColor.black.cgColor // Цвет границы
        bluetoothConnectionView.layer.borderColor = UIColor.black.withAlphaComponent(0.25).cgColor
        bluetoothConnectionView.layer.shadowOffset = CGSize(width: 0, height: 2)
        bluetoothConnectionView.layer.shadowOpacity = 0.0
        bluetoothConnectionView.layer.shadowRadius = 4
        bluetoothConnectionView.clipsToBounds = false
        bluetoothConnectionView.translatesAutoresizingMaskIntoConstraints = false
        bluetoothConnectionContainer.addSubview(bluetoothConnectionView)
        
        // Создаем иконку Bluetooth
        let bluetoothImageView = UIImageView(image: R.image.homeBluetooth())
        bluetoothImageView.contentMode = .scaleAspectFit
        bluetoothImageView.tintColor = .systemBlue
        bluetoothImageView.translatesAutoresizingMaskIntoConstraints = false
        bluetoothConnectionView.addSubview(bluetoothImageView)
        
        // Создаем лейбл для названия устройства
        deviceNameLabel = UILabel()
        deviceNameLabel.font = .systemFont(ofSize: 20, weight: .medium)
        deviceNameLabel.textColor = .black
        deviceNameLabel.text = "Connect Device"
        deviceNameLabel.translatesAutoresizingMaskIntoConstraints = false
        bluetoothConnectionView.addSubview(deviceNameLabel)
        
        // Создаем кнопку "+"
        let addButton = UIButton(type: .system)
        addButton.setImage(UIImage(systemName: "plus"), for: .normal)
        addButton.tintColor = .black
        addButton.contentMode = .scaleAspectFit
        addButton.translatesAutoresizingMaskIntoConstraints = false
        bluetoothConnectionView.addSubview(addButton)
        
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
        
        // Настраиваем ограничения для bluetoothConnectionView
        bluetoothConnectionView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(26)
            make.leading.equalToSuperview().offset(56)
            make.trailing.equalToSuperview().offset(-56)
            make.bottom.equalToSuperview().offset(-16)
            make.height.equalTo(50) // Высота плашки
        }
        
        // Настраиваем ограничения для элементов внутри bluetoothConnectionView
        bluetoothImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }
        
        deviceNameLabel.snp.makeConstraints { make in
            make.leading.equalTo(bluetoothImageView.snp.trailing).offset(16)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(addButton.snp.leading).offset(-16)
        }
        
        addButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }
        
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

        // Заряд батареи и статус
        batteryInfoView.update(battery: battery, status: data.status.description)
        batteryInfoView.charging = data.status == .charging

        /// Уровень заряда
        batteryView.level = battery

        /// Информация о параметрах
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
    /// Преобразование из Цельсия в Фаренгейт
    /// - Returns: Температура в градусах Фаренгейта
    func celsiusToFahrenheit() -> Int {
        return Int(self) * 9/5 + 32
    }
}

//extension Int {
//
//    /// Преобразование из Цельсия в Фаренгейт
//    /// - Returns: Температура в градусах Фаренгейта
//    func celsiusToFahrenheit() -> Int {
//        return Int(self * 9/5 + 32)
//    }
//}

extension Float {
    /// Преобразование из Цельсия в Фаренгейт
    func celsiusToFahrenheit() -> Float {
        return self * 9/5 + 32
    }
}
