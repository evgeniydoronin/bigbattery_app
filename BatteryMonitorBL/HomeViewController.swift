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

// Импортируем компоненты
import class BatteryMonitorBL.SummaryTabView
import class BatteryMonitorBL.CellVoltageTabView
import class BatteryMonitorBL.TemperatureTabView
import class BatteryMonitorBL.BluetoothConnectionView
import class BatteryMonitorBL.BatteryParametersView
import class BatteryMonitorBL.TimerView
import class BatteryMonitorBL.BatteryProgressView
import class BatteryMonitorBL.TabsContainerView
import class BatteryMonitorBL.BatteryStatusView
import class BatteryMonitorBL.ProtocolParametersView

// Удаляем импорт BatteryInfoView

class HomeViewController: UIViewController {

    // MARK: - Constants

    /// Уведомление об обновлении протоколов
    static let protocolsDidUpdateNotification = Notification.Name("ProtocolsDidUpdateNotification")

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

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let deviceName = ZetaraManager.shared.connectedPeripheral()?.name ?? "none"
        let isConnected = ZetaraManager.shared.connectedPeripheral() != nil

        AppLogger.shared.info(
            screen: AppLogger.Screen.home,
            event: AppLogger.Event.viewWillAppear,
            message: "[PROTOCOL_DEBUG] 📱 HomeViewController.viewWillAppear",
            details: [
                "deviceConnected": isConnected,
                "deviceName": deviceName,
                "previousModuleId": moduleIdData?.readableId() ?? "nil",
                "previousCAN": canData?.readableProtocol() ?? "nil",
                "previousRS485": rs485Data?.readableProtocol() ?? "nil"
            ]
        )

        // Скрываем навигационный бар при возвращении на главный экран
        self.navigationController?.setNavigationBarHidden(true, animated: animated)

        // Загружаем данные протоколов если устройство подключено
        if isConnected {
            AppLogger.shared.info(
                screen: AppLogger.Screen.home,
                event: AppLogger.Event.dataUpdated,
                message: "[PROTOCOL_DEBUG] 🔄 Device connected: \(deviceName), clearing cached data"
            )

            // Очищаем кэшированные данные для принудительного обновления
            moduleIdData = nil
            canData = nil
            rs485Data = nil

            // Принудительно обновляем UI с дефолтными значениями
            updateProtocolUI()

            // Загружаем свежие данные протоколов с небольшой задержкой
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.loadProtocolData()
            }
        } else {
            AppLogger.shared.info(
                screen: AppLogger.Screen.home,
                event: AppLogger.Event.dataUpdated,
                message: "[PROTOCOL_DEBUG] 🚫 No device connected, showing default UI"
            )
            // Если устройство отключено, обновляем UI соответственно
            updateProtocolUI()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    // Отключаем жест смахивания назад на главном экране, чтобы избежать зависания
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Отключаем интерактивный переход назад для этого экрана
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }
    
    // Удаляем titleButton, так как теперь используем bluetoothButton из batteryInfoView

    @IBOutlet weak var timerLabel: UILabel! // Будет заменен на TimerView
    @IBOutlet weak var logoImageView: UIImageView!
    // batteryView заменен на batteryProgressView
    
    // Свойство для компонента BatteryProgressView
    private var batteryProgressView: BatteryProgressView!
    
    // Свойство для компонента TimerView
    private var timerView: TimerView!
    
    // Свойство для компонента BatteryParametersView
    private var batteryParametersView: BatteryParametersView!
    
    // Свойство для компонента BluetoothConnectionView
    private var bluetoothConnectionView: UIView!
    
    // Свойство для компонента BatteryStatusView
    private var batteryStatusView: BatteryStatusView!

    // Свойство для компонента ProtocolParametersView
    private var protocolParametersView: ProtocolParametersView!
    
    // Свойства для табов
    private var tabsContainer: UIView!
    
    // Ссылки на табы для обновления данных
    private var summaryView: SummaryTabView?
    private var cellVoltageView: CellVoltageTabView?
    private var temperatureView: TemperatureTabView?

    // Данные протоколов для отображения
    private var moduleIdData: Zetara.Data.ModuleIdControlData?
    private var canData: Zetara.Data.CANControlData?
    private var rs485Data: Zetara.Data.RS485ControlData?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        AppLogger.shared.info(screen: AppLogger.Screen.home, event: AppLogger.Event.viewDidLoad, message: "Home screen loaded")

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
        // timerLabel.isHidden = true - больше не используется, так как мы используем timerView
        
        // Обновляем имя устройства при загрузке экрана
        updateTitle(ZetaraManager.shared.connectedPeripheral())
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
            .subscribeOn(MainScheduler.instance) // Определяет поток для подписки
            .observe(on: MainScheduler.instance) // Гарантирует, что все последующие операции будут на главном потоке
            .subscribe { [weak self] _data in
                self?.updateUI(_data)
            } onError: { error in
                print("er:\(error)")
            }.disposed(by: disposeBag)
        
        ZetaraManager.shared.connectedPeripheralSubject
            .subscribeOn(MainScheduler.instance) // Определяет поток для подписки
            .observe(on: MainScheduler.instance) // Гарантирует, что все последующие операции будут на главном потоке
            .subscribe { [weak self] (peripheral: ZetaraManager.ConnectedPeripheral?) in
                if let peripheral = peripheral {
                    AppLogger.shared.info(
                        screen: AppLogger.Screen.home,
                        event: AppLogger.Event.connectionSucceeded,
                        message: "[PROTOCOL_DEBUG] 🔗 Device connected: \(peripheral.name ?? "Unknown")",
                        details: [
                            "deviceName": peripheral.name ?? "Unknown",
                            "deviceId": peripheral.identifier.uuidString,
                            "previouslyConnected": self?.moduleIdData != nil || self?.canData != nil || self?.rs485Data != nil
                        ]
                    )
                } else {
                    AppLogger.shared.info(
                        screen: AppLogger.Screen.home,
                        event: AppLogger.Event.disconnectionCompleted,
                        message: "[PROTOCOL_DEBUG] 🔌 Device disconnected",
                        details: [
                            "hadModuleId": self?.moduleIdData?.readableId() ?? "nil",
                            "hadCAN": self?.canData?.readableProtocol() ?? "nil",
                            "hadRS485": self?.rs485Data?.readableProtocol() ?? "nil"
                        ]
                    )
                }

                self?.updateTitle(peripheral)

                // При подключении к устройству загружаем данные протоколов с небольшой задержкой
                if peripheral != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.loadProtocolData()
                    }
                } else {
                    // При отключении сбрасываем данные протоколов
                    self?.clearProtocolData()
                }
            }.disposed(by: disposeBag)

        // Обработка отключения устройства для исправления "фантомного подключения"
        ZetaraManager.shared.observeDisconect()
            .subscribeOn(MainScheduler.instance)
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] (disconnectedPeripheral: ZetaraManager.ConnectedPeripheral) in
                print("🔴 [HomeViewController] Device disconnected: \(disconnectedPeripheral.name ?? "Unknown")")

                AppLogger.shared.info(
                    screen: AppLogger.Screen.home,
                    component: AppLogger.Component.connectionStatus,
                    event: AppLogger.Event.disconnectionCompleted,
                    message: "Device disconnected on Home screen",
                    details: ["deviceName": disconnectedPeripheral.name ?? "Unknown"]
                )

                // Принудительно очищаем состояние подключения
                self?.updateTitle(nil)
                self?.clearProtocolData()

                // Можно добавить уведомление пользователю о потере связи
                // Alert.show("Connection lost. Please reconnect.", timeout: 3)
            } onError: { error in
                print("🔴 [HomeViewController] Disconnect observation error: \(error)")
                AppLogger.shared.error(
                    screen: AppLogger.Screen.home,
                    component: AppLogger.Component.connectionStatus,
                    event: AppLogger.Event.errorOccurred,
                    message: "Disconnect observation error",
                    details: ["error": error.localizedDescription]
                )
            }.disposed(by: disposeBag)


        // Удаляем использование bluetoothButton из batteryInfoView

        // Подписываемся на уведомления об обновлении протоколов
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProtocolsUpdateNotification),
            name: HomeViewController.protocolsDidUpdateNotification,
            object: nil
        )

        // Обработка нажатия на bluetoothConnectionView теперь устанавливается через свойство onTap
    }
    
    @objc func handleBluetoothConnectionTap() {
        // Показываем навигационную панель перед переходом
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        performSegue(withIdentifier: R.segue.homeViewController.pushConnectivityPage, sender: navigationController)
    }

    @objc func handleProtocolsUpdateNotification() {
        AppLogger.shared.info(
            screen: AppLogger.Screen.home,
            event: AppLogger.Event.dataUpdated,
            message: "[PROTOCOL_DEBUG] 📲 Received protocols update notification",
            details: [
                "deviceConnected": ZetaraManager.shared.connectedPeripheral() != nil,
                "deviceName": ZetaraManager.shared.connectedPeripheral()?.name ?? "none"
            ]
        )

        // Если устройство подключено, перезагружаем данные протоколов
        if ZetaraManager.shared.connectedPeripheral() != nil {
            loadProtocolData()
        }
    }

    func navigateToSettings() {
        print("🟡 [HomeViewController] navigateToSettings() called")

        // Переключаемся на таб Settings (индекс 1)
        print("🟡 [HomeViewController] Switching to Settings tab (index 1)")
        self.tabBarController?.selectedIndex = 1
        print("🟡 [HomeViewController] Tab switch completed")
    }
    
    /// Обновление имени устройства
    func updateTitle(_ peripheral: ZetaraManager.ConnectedPeripheral?) {
        // Проверяем, есть ли реальное подключение к устройству
        let isDeviceActuallyConnected = ZetaraManager.shared.connectedPeripheral() != nil

        // КРИТИЧЕСКОЕ ЛОГИРОВАНИЕ для фантомного подключения
        AppLogger.shared.info(
            screen: AppLogger.Screen.home,
            event: AppLogger.Event.stateChanged,
            message: "updateTitle called - checking connection status",
            details: [
                "passedPeripheralName": peripheral?.name ?? "nil",
                "passedPeripheralId": peripheral?.identifier.uuidString ?? "nil",
                "isDeviceActuallyConnected": isDeviceActuallyConnected,
                "realPeripheralName": ZetaraManager.shared.connectedPeripheral()?.name ?? "nil",
                "mismatch": (peripheral != nil) != isDeviceActuallyConnected ? "PHANTOM CONNECTION DETECTED!" : "OK"
            ]
        )

        if isDeviceActuallyConnected {
            // Если есть реальное подключение, отображаем имя устройства
            timerView.setHidden(false) // Показываем таймер
            
            // Получаем имя устройства через метод getDeviceName
            let deviceName = ZetaraManager.shared.getDeviceName()
            
            // Обновляем название устройства в компоненте BluetoothConnectionView
            if let bluetoothView = bluetoothConnectionView as? BluetoothConnectionView {
                bluetoothView.updateDeviceName(deviceName)
            }
        } else {
            // Если нет реального подключения, скрываем таймер и отображаем "Tap to Connect"
            timerView.setHidden(true) // Скрываем таймер
            
            // Сбрасываем название устройства в компоненте BluetoothConnectionView
            if let bluetoothView = bluetoothConnectionView as? BluetoothConnectionView {
                bluetoothView.updateDeviceName(nil) // Передаем nil, чтобы отобразить "Tap to Connect"
            }
        }
    }
    
    // Настройка шапки и логотипа
    private func setupHeaderView() {
        // Структура экрана:
        // 1. Шапка с логотипом (headerView)
        // 2. Скроллируемый контейнер (scrollView) с вертикальным стеком (contentStackView), содержащим:
        //    - Плашка Bluetooth для подключения устройства
        //    - Визуализация уровня заряда батареи
        //    - Индикатор статуса батареи
        //    - Контейнер с параметрами батареи (напряжение, ток, температура)
        //    - Контейнер с табами (Summary, Cell Voltage, Temperature)
        //    - Контейнер с временем последнего обновления
        
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
        contentStackView.spacing = 16  // Возвращаем отступ между контейнерами
        scrollView.addSubview(contentStackView)
        
        // Создаем контейнеры для разных секций контента
        // 1. Контейнер для плашки Bluetooth - отображает статус подключения и имя устройства
        let bluetoothConnectionContainer = UIView()
        bluetoothConnectionContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // 2. Контейнер для визуализации уровня заряда батареи
        let batteryContainer = UIView()
        batteryContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // 3. Контейнер для индикатора статуса батареи
        let batteryStatusContainer = UIView()
        batteryStatusContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // 4. Контейнер для параметров батареи - отображает напряжение, ток и температуру
        let componentsContainer = UIView()
        componentsContainer.translatesAutoresizingMaskIntoConstraints = false

        // 5. Контейнер для параметров протоколов - отображает Module ID, CAN и RS485
        let protocolContainer = UIView()
        protocolContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // 5. Контейнер для табов (Summary, Cell Voltage, Temperature)
        let tabsContainer = UIView()
        tabsContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // 6. Контейнер для времени последнего обновления данных
        let timerContainer = UIView()
        timerContainer.translatesAutoresizingMaskIntoConstraints = false
        
        
        // Удаляем контейнер для логотипа внизу экрана
        
        // Добавляем контейнеры в стек
        contentStackView.addArrangedSubview(bluetoothConnectionContainer) // 1. Плашка для подключения Bluetooth
        contentStackView.addArrangedSubview(batteryContainer)            // 2. Визуализация уровня заряда батареи
        contentStackView.addArrangedSubview(batteryStatusContainer)      // 3. Индикатор статуса батареи
        contentStackView.addArrangedSubview(componentsContainer)         // 4. Контейнер с параметрами батареи (напряжение, ток, температура)
        contentStackView.addArrangedSubview(protocolContainer)           // 5. Контейнер с параметрами протоколов (Module ID, CAN, RS485)
        contentStackView.addArrangedSubview(tabsContainer)               // 6. Контейнер с табами
        contentStackView.addArrangedSubview(timerContainer)              // 7. Контейнер с временем последнего обновления
        
        // Добавляем отступы между контейнерами
        // contentStackView.setCustomSpacing(-1, after: bluetoothConnectionContainer) // Удаляем отрицательный отступ
        
        // Создаем компонент BluetoothConnectionView
        let bluetoothConnectionView = BluetoothConnectionView()
        bluetoothConnectionView.translatesAutoresizingMaskIntoConstraints = false
        bluetoothConnectionContainer.addSubview(bluetoothConnectionView)
        
        // Сохраняем ссылку на deviceNameLabel через компонент
        self.bluetoothConnectionView = bluetoothConnectionView
        
        // Устанавливаем обработчик нажатия
        bluetoothConnectionView.onTap = { [weak self] in
            self?.handleBluetoothConnectionTap()
        }
        
        // Проверяем видимость контейнеров
        bluetoothConnectionContainer.isHidden = false
        componentsContainer.isHidden = false
        
        // Создаем и настраиваем контейнер с табами
        self.tabsContainer = tabsContainer
        tabsContainer.backgroundColor = .clear // Делаем фон прозрачным
        
        // Создаем компонент TabsContainerView
        let tabsContainerView = TabsContainerView()
        tabsContainerView.translatesAutoresizingMaskIntoConstraints = false
        tabsContainer.addSubview(tabsContainerView)
        
        // Настраиваем ограничения для tabsContainerView
        tabsContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Сохраняем ссылки на табы для обновления данных
        self.summaryView = tabsContainerView.getSummaryTabView()
        self.cellVoltageView = tabsContainerView.getCellVoltageTabView()
        self.temperatureView = tabsContainerView.getTemperatureTabView()
        
        // Удаляем использование bringSubviewToFront, так как это может нарушить порядок отображения
        // contentStackView.bringSubviewToFront(bluetoothConnectionContainer)
        // contentStackView.bringSubviewToFront(componentsContainer)
        
        // Добавляем элементы в соответствующие контейнеры
        // Создаем компонент TimerView
        timerView = TimerView()
        timerView.translatesAutoresizingMaskIntoConstraints = false
        timerContainer.addSubview(timerView)
        
        // Создаем компонент BatteryProgressView вместо использования batteryView
        batteryProgressView = BatteryProgressView()
        batteryProgressView.translatesAutoresizingMaskIntoConstraints = false
        batteryContainer.addSubview(batteryProgressView)
        
        // Создаем компонент BatteryStatusView
        batteryStatusView = BatteryStatusView()
        batteryStatusView.translatesAutoresizingMaskIntoConstraints = false
        batteryStatusContainer.addSubview(batteryStatusView)

        // Создаем компонент ProtocolParametersView
        protocolParametersView = ProtocolParametersView()
        protocolParametersView.translatesAutoresizingMaskIntoConstraints = false
        protocolContainer.addSubview(protocolParametersView)

        // Настраиваем обработчики нажатий для параметров протоколов
        protocolParametersView.onModuleIdTap = { [weak self] in
            print("🟠 [HomeViewController] Module ID callback triggered")
            AppLogger.shared.info(
                screen: AppLogger.Screen.home,
                component: AppLogger.Component.protocolButtonID,
                event: AppLogger.Event.buttonTapped,
                message: "Module ID button tapped",
                details: ["currentValue": self?.moduleIdData?.readableId() ?? "unknown"]
            )
            self?.navigateToSettings()
        }
        protocolParametersView.onCanProtocolTap = { [weak self] in
            print("🟠 [HomeViewController] CAN Protocol callback triggered")
            AppLogger.shared.info(
                screen: AppLogger.Screen.home,
                component: AppLogger.Component.protocolButtonCAN,
                event: AppLogger.Event.buttonTapped,
                message: "CAN Protocol button tapped",
                details: ["currentValue": self?.canData?.readableProtocol() ?? "unknown"]
            )
            self?.navigateToSettings()
        }
        protocolParametersView.onRS485ProtocolTap = { [weak self] in
            print("🟠 [HomeViewController] RS485 Protocol callback triggered")
            AppLogger.shared.info(
                screen: AppLogger.Screen.home,
                component: AppLogger.Component.protocolButtonRS485,
                event: AppLogger.Event.buttonTapped,
                message: "RS485 Protocol button tapped",
                details: ["currentValue": self?.rs485Data?.readableProtocol() ?? "unknown"]
            )
            self?.navigateToSettings()
        }
        
        // Создаем горизонтальный стек для компонентов
        let componentsStackView = UIStackView()
        componentsStackView.translatesAutoresizingMaskIntoConstraints = false
        componentsStackView.axis = .horizontal
        componentsStackView.distribution = .fillEqually
        componentsStackView.spacing = 10
        componentsContainer.addSubview(componentsStackView)
        
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
            make.edges.equalToSuperview() // Просто заполняем весь контейнер
        }
        
        // Настраиваем ограничения для bluetoothConnectionContainer - адаптируется к размеру компонента
        bluetoothConnectionContainer.snp.makeConstraints { make in
            // Высота определяется содержимым
        }
        
        // Настраиваем ограничения для batteryStatusView
        batteryStatusView.snp.makeConstraints { make in
            make.edges.equalToSuperview() // Просто заполняем весь контейнер
        }
        
        // Настраиваем ограничения для batteryStatusContainer - адаптируется к размеру компонента
        batteryStatusContainer.snp.makeConstraints { make in
            // Высота определяется содержимым
        }
        
        // Настраиваем ограничения для componentsContainer
        componentsContainer.snp.makeConstraints { make in
            make.height.equalTo(80) // Задаем явную высоту
        }

        // Настраиваем ограничения для protocolContainer
        protocolContainer.snp.makeConstraints { make in
            make.height.equalTo(80) // Задаем явную высоту
        }
        
        // Настраиваем ограничения для tabsContainer (только высота, без отступов)
        tabsContainer.snp.makeConstraints { make in
            make.height.equalTo(330) // Увеличиваем высоту контейнера с табами для размещения всех параметров
        }
        
        // Ограничения для элементов внутри bluetoothConnectionView теперь настраиваются в самом компоненте
        
        // Обновляем ограничения для timerView
        timerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-16)
        }
        
        
        // Обновляем ограничения для batteryProgressView
        batteryProgressView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(350) // Увеличиваем размер для круговой диаграммы
            make.top.equalToSuperview().offset(16)
            make.bottom.equalToSuperview().offset(-16)
        }
        
        
        // Создаем компонент BatteryParametersView
        batteryParametersView = BatteryParametersView()
        batteryParametersView.translatesAutoresizingMaskIntoConstraints = false
        componentsContainer.addSubview(batteryParametersView)
        
        // Настраиваем ограничения для batteryParametersView
        batteryParametersView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        // Настраиваем ограничения для protocolParametersView
        protocolParametersView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Удаляем ограничения для logoImageView, так как контейнер удален
    }
    
    func updateUI(_ data: Zetara.Data.BMS) {
        // Обновляем время в компоненте TimerView
        timerView.updateTime(Date())
        
        // Проверяем, есть ли реальное подключение к устройству
        let isDeviceActuallyConnected = ZetaraManager.shared.connectedPeripheral() != nil
        
        if isDeviceActuallyConnected {
            // Если есть реальное подключение, отображаем данные
            let battery = Float(data.soc)/100.0
            
            /// Уровень заряда
            batteryProgressView.level = battery
            batteryProgressView.updateChargingStatus(isCharging: data.status == .charging)
            
            /// Статус батареи
            batteryStatusView.updateStatusAnimated(data.status)
            
            /// Информация о параметрах
            batteryParametersView.updateVoltage("\(data.voltage)V")
            batteryParametersView.updateCurrent("\(data.current)A")
            batteryParametersView.updateTemperature("\(data.tempEnv.celsiusToFahrenheit())°F/\(data.tempEnv)°C")
            
            // Обновляем данные в SummaryTabView
            if let summaryView = self.summaryView {
                // Вычисляем параметры для SummaryTabView
                let maxVoltage = data.cellVoltages.max() ?? 0
                let minVoltage = data.cellVoltages.min() ?? 0
                let voltageDiff = maxVoltage - minVoltage
                let power = data.voltage * data.current
                let avgVoltage = data.cellVoltages.reduce(0, +) / Float(max(1, data.cellVoltages.count))
                
                // Обновляем все параметры в SummaryTabView
                summaryView.updateAllParameters(
                    maxVoltage: maxVoltage,
                    minVoltage: minVoltage,
                    voltageDiff: voltageDiff,
                    power: power,
                    internalTemp: data.tempPCB,
                    avgVoltage: avgVoltage
                )
            }
            
            // Обновляем данные в CellVoltageTabView
            if let cellVoltageView = self.cellVoltageView {
                // Обновляем напряжения ячеек в CellVoltageTabView
                cellVoltageView.updateCellVoltages(data.cellVoltages)
            }
            
            // Обновляем данные в TemperatureTabView
            if let temperatureView = self.temperatureView {
                // Обновляем температуры в TemperatureTabView
                temperatureView.updateTemperatures(
                    pcbTemp: data.tempPCB,
                    envTemp: data.tempEnv,
                    cellTemps: data.cellTemps
                )
            }
        } else {
            // Если нет реального подключения, отображаем прочерки

            /// Уровень заряда (показываем 0%)
            batteryProgressView.level = 0
            batteryProgressView.updateChargingStatus(isCharging: false)

            /// Статус батареи (показываем Not Connected)
            batteryStatusView.updateStatus(.notConnected)
            
            /// Информация о параметрах
            batteryParametersView.updateVoltage("-- V")
            batteryParametersView.updateCurrent("-- A")
            batteryParametersView.updateTemperature("-- °F/-- °C")
            
            // Обновляем данные в SummaryTabView
            if let summaryView = self.summaryView {
                // Обновляем все параметры в SummaryTabView с прочерками
                summaryView.updateAllParameters(
                    maxVoltage: 0,
                    minVoltage: 0,
                    voltageDiff: 0,
                    power: 0,
                    internalTemp: 0,
                    avgVoltage: 0,
                    showDashes: true // Добавим параметр для отображения прочерков
                )
            }
            
            // Обновляем данные в CellVoltageTabView
            if let cellVoltageView = self.cellVoltageView {
                // Обновляем напряжения ячеек в CellVoltageTabView с прочерками
                cellVoltageView.updateCellVoltages([], showDashes: true) // Добавим параметр для отображения прочерков
            }
            
            // Обновляем данные в TemperatureTabView
            if let temperatureView = self.temperatureView {
                // Обновляем температуры в TemperatureTabView с прочерками
                temperatureView.updateTemperatures(
                    pcbTemp: 0,
                    envTemp: 0,
                    cellTemps: [],
                    showDashes: true // Добавим параметр для отображения прочерков
                )
            }
        }
    }
    
    // Метод для изменения порядка компонентов
    func reorderComponents(order: [BatteryParametersView.ComponentType]) {
        // Используем метод reorderComponents компонента BatteryParametersView
        batteryParametersView.reorderComponents(order: order)
    }
    
    var formatter: DateFormatter = {
        let d = DateFormatter()
        d.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return d
    }()

    // Методы для работы с табами перенесены в TabsContainerView

    // MARK: - Protocol Data Methods

    /// Загрузка данных протоколов при подключении к устройству
    private func loadProtocolData() {
        let deviceName = ZetaraManager.shared.connectedPeripheral()?.name ?? "Unknown"

        AppLogger.shared.info(
            screen: AppLogger.Screen.home,
            event: AppLogger.Event.dataUpdated,
            message: "[PROTOCOL_DEBUG] 🚀 Starting protocol data loading for device: \(deviceName)"
        )

        // Загружаем Module ID с retry логикой
        loadModuleIdWithRetry()

        // Загружаем CAN данные с retry логикой
        loadCANWithRetry()

        // Загружаем RS485 данные с retry логикой
        loadRS485WithRetry()
    }

    /// Загрузка Module ID с retry логикой
    private func loadModuleIdWithRetry(attempt: Int = 1, maxAttempts: Int = 3) {
        let startTime = Date()

        AppLogger.shared.info(
            screen: AppLogger.Screen.home,
            event: AppLogger.Event.dataUpdated,
            message: "[PROTOCOL_DEBUG] 📡 Loading Module ID (attempt \(attempt)/\(maxAttempts))..."
        )

        ZetaraManager.shared.getModuleId()
            .subscribeOn(MainScheduler.instance)
            .observe(on: MainScheduler.instance)
            .subscribe { [weak self] idData in
                let duration = Int(Date().timeIntervalSince(startTime) * 1000)
                let readableId = idData.readableId()

                AppLogger.shared.info(
                    screen: AppLogger.Screen.home,
                    event: AppLogger.Event.dataUpdated,
                    message: "[PROTOCOL_DEBUG] ✅ Module ID loaded: \(readableId) (took \(duration)ms)",
                    details: [
                        "moduleId": readableId,
                        "duration": duration,
                        "attempt": attempt,
                        "rawModuleId": idData.moduleId
                    ]
                )

                self?.moduleIdData = idData
                self?.updateProtocolUI()
            } onError: { [weak self] error in
                let duration = Int(Date().timeIntervalSince(startTime) * 1000)

                AppLogger.shared.error(
                    screen: AppLogger.Screen.home,
                    event: AppLogger.Event.errorOccurred,
                    message: "[PROTOCOL_DEBUG] ❌ Module ID failed: \(error.localizedDescription) (attempt \(attempt)/\(maxAttempts), took \(duration)ms)",
                    details: [
                        "error": error.localizedDescription,
                        "attempt": attempt,
                        "maxAttempts": maxAttempts,
                        "duration": duration
                    ]
                )

                // Retry если не последняя попытка
                if attempt < maxAttempts {
                    AppLogger.shared.info(
                        screen: AppLogger.Screen.home,
                        event: AppLogger.Event.dataUpdated,
                        message: "[PROTOCOL_DEBUG] 🔄 Retrying Module ID in 1s..."
                    )

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.loadModuleIdWithRetry(attempt: attempt + 1, maxAttempts: maxAttempts)
                    }
                } else {
                    AppLogger.shared.error(
                        screen: AppLogger.Screen.home,
                        event: AppLogger.Event.errorOccurred,
                        message: "[PROTOCOL_DEBUG] 💀 Module ID loading failed after \(maxAttempts) attempts"
                    )
                }
            }.disposed(by: disposeBag)
    }

    /// Загрузка CAN данных с retry логикой
    private func loadCANWithRetry(attempt: Int = 1, maxAttempts: Int = 3) {
        let startTime = Date()

        AppLogger.shared.info(
            screen: AppLogger.Screen.home,
            event: AppLogger.Event.dataUpdated,
            message: "[PROTOCOL_DEBUG] 📡 Loading CAN protocol (attempt \(attempt)/\(maxAttempts))..."
        )

        getCAN()
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] canData in
                let duration = Int(Date().timeIntervalSince(startTime) * 1000)
                let readableProtocol = canData.readableProtocol()

                AppLogger.shared.info(
                    screen: AppLogger.Screen.home,
                    event: AppLogger.Event.dataUpdated,
                    message: "[PROTOCOL_DEBUG] ✅ CAN loaded: \(readableProtocol) (took \(duration)ms)",
                    details: [
                        "canProtocol": readableProtocol,
                        "duration": duration,
                        "attempt": attempt,
                        "selectedIndex": canData.selectedIndex,
                        "totalProtocols": canData.protocols.count
                    ]
                )

                self?.canData = canData
                self?.updateProtocolUI()
            }, onError: { [weak self] error in
                let duration = Int(Date().timeIntervalSince(startTime) * 1000)

                AppLogger.shared.error(
                    screen: AppLogger.Screen.home,
                    event: AppLogger.Event.errorOccurred,
                    message: "[PROTOCOL_DEBUG] ❌ CAN failed: \(error.localizedDescription) (attempt \(attempt)/\(maxAttempts), took \(duration)ms)",
                    details: [
                        "error": error.localizedDescription,
                        "attempt": attempt,
                        "maxAttempts": maxAttempts,
                        "duration": duration
                    ]
                )

                // Retry если не последняя попытка
                if attempt < maxAttempts {
                    let isTimeout = error.localizedDescription.contains("timeout")
                    let retryDelay = isTimeout ? 2.0 : 1.0 // Больше времени для timeout ошибок

                    AppLogger.shared.info(
                        screen: AppLogger.Screen.home,
                        event: AppLogger.Event.dataUpdated,
                        message: "[PROTOCOL_DEBUG] 🔄 Retrying CAN in \(retryDelay)s...",
                        details: [
                            "isTimeoutError": isTimeout,
                            "retryDelay": retryDelay,
                            "nextAttempt": attempt + 1
                        ]
                    )

                    DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
                        self?.loadCANWithRetry(attempt: attempt + 1, maxAttempts: maxAttempts)
                    }
                } else {
                    AppLogger.shared.error(
                        screen: AppLogger.Screen.home,
                        event: AppLogger.Event.errorOccurred,
                        message: "[PROTOCOL_DEBUG] 💀 CAN loading failed after \(maxAttempts) attempts"
                    )
                }
            }).disposed(by: disposeBag)
    }

    /// Загрузка RS485 данных с retry логикой
    private func loadRS485WithRetry(attempt: Int = 1, maxAttempts: Int = 3) {
        let startTime = Date()

        AppLogger.shared.info(
            screen: AppLogger.Screen.home,
            event: AppLogger.Event.dataUpdated,
            message: "[PROTOCOL_DEBUG] 📡 Loading RS485 protocol (attempt \(attempt)/\(maxAttempts))..."
        )

        getRS485()
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] rs485Data in
                let duration = Int(Date().timeIntervalSince(startTime) * 1000)
                let readableProtocol = rs485Data.readableProtocol()

                AppLogger.shared.info(
                    screen: AppLogger.Screen.home,
                    event: AppLogger.Event.dataUpdated,
                    message: "[PROTOCOL_DEBUG] ✅ RS485 loaded: \(readableProtocol) (took \(duration)ms)",
                    details: [
                        "rs485Protocol": readableProtocol,
                        "duration": duration,
                        "attempt": attempt,
                        "selectedIndex": rs485Data.selectedIndex,
                        "totalProtocols": rs485Data.protocols.count
                    ]
                )

                self?.rs485Data = rs485Data
                self?.updateProtocolUI()
            }, onError: { [weak self] error in
                let duration = Int(Date().timeIntervalSince(startTime) * 1000)

                AppLogger.shared.error(
                    screen: AppLogger.Screen.home,
                    event: AppLogger.Event.errorOccurred,
                    message: "[PROTOCOL_DEBUG] ❌ RS485 failed: \(error.localizedDescription) (attempt \(attempt)/\(maxAttempts), took \(duration)ms)",
                    details: [
                        "error": error.localizedDescription,
                        "attempt": attempt,
                        "maxAttempts": maxAttempts,
                        "duration": duration
                    ]
                )

                // Retry если не последняя попытка
                if attempt < maxAttempts {
                    let isTimeout = error.localizedDescription.contains("timeout")
                    let retryDelay = isTimeout ? 2.0 : 1.0 // Больше времени для timeout ошибок

                    AppLogger.shared.info(
                        screen: AppLogger.Screen.home,
                        event: AppLogger.Event.dataUpdated,
                        message: "[PROTOCOL_DEBUG] 🔄 Retrying RS485 in \(retryDelay)s...",
                        details: [
                            "isTimeoutError": isTimeout,
                            "retryDelay": retryDelay,
                            "nextAttempt": attempt + 1
                        ]
                    )

                    DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
                        self?.loadRS485WithRetry(attempt: attempt + 1, maxAttempts: maxAttempts)
                    }
                } else {
                    AppLogger.shared.error(
                        screen: AppLogger.Screen.home,
                        event: AppLogger.Event.errorOccurred,
                        message: "[PROTOCOL_DEBUG] 💀 RS485 loading failed after \(maxAttempts) attempts"
                    )
                }
            }).disposed(by: disposeBag)
    }

    // MARK: - Protocol Wrapper Methods

    /// Wrapper метод для получения CAN протокола с коротким timeout (аналогично SettingsViewController)
    private func getCAN() -> Maybe<Zetara.Data.CANControlData> {
        AppLogger.shared.info(
            screen: AppLogger.Screen.home,
            event: AppLogger.Event.dataUpdated,
            message: "[PROTOCOL_DEBUG] 🎁 HomeViewController.getCAN() wrapper called"
        )

        return ZetaraManager.shared.getCAN()
            .timeout(.seconds(3), scheduler: MainScheduler.instance)
            .subscribeOn(MainScheduler.instance)
    }

    /// Wrapper метод для получения RS485 протокола с коротким timeout (аналогично SettingsViewController)
    private func getRS485() -> Maybe<Zetara.Data.RS485ControlData> {
        AppLogger.shared.info(
            screen: AppLogger.Screen.home,
            event: AppLogger.Event.dataUpdated,
            message: "[PROTOCOL_DEBUG] 🎁 HomeViewController.getRS485() wrapper called"
        )

        return ZetaraManager.shared.getRS485()
            .timeout(.seconds(3), scheduler: MainScheduler.instance)
            .subscribeOn(MainScheduler.instance)
    }

    /// Сбрасывает данные протоколов при отключении от устройства
    private func clearProtocolData() {
        AppLogger.shared.info(
            screen: AppLogger.Screen.home,
            event: AppLogger.Event.protocolsCleared,
            message: "Protocol data cleared due to disconnection"
        )
        moduleIdData = nil
        canData = nil
        rs485Data = nil
        updateProtocolUI()
    }

    /// Обновляет UI блоков протоколов в зависимости от состояния подключения
    private func updateProtocolUI() {
        let isDeviceConnected = ZetaraManager.shared.connectedPeripheral() != nil
        let deviceName = ZetaraManager.shared.connectedPeripheral()?.name ?? "none"

        if isDeviceConnected {
            // Если устройство подключено, показываем данные
            let moduleIdText = moduleIdData?.readableId() ?? "--"
            let canText = canData?.readableProtocol() ?? "--"
            let rs485Text = rs485Data?.readableProtocol() ?? "--"

            // Определяем статус загрузки данных
            let moduleIdStatus = moduleIdData != nil ? "loaded" : "pending"
            let canStatus = canData != nil ? "loaded" : "pending"
            let rs485Status = rs485Data != nil ? "loaded" : "pending"

            AppLogger.shared.info(
                screen: AppLogger.Screen.home,
                event: AppLogger.Event.dataUpdated,
                message: "[PROTOCOL_DEBUG] 🎨 UI Updated: Module=\(moduleIdText), CAN=\(canText), RS485=\(rs485Text)",
                details: [
                    "deviceName": deviceName,
                    "moduleId": moduleIdText,
                    "canProtocol": canText,
                    "rs485Protocol": rs485Text,
                    "moduleIdStatus": moduleIdStatus,
                    "canStatus": canStatus,
                    "rs485Status": rs485Status,
                    "connected": true
                ]
            )

            protocolParametersView.updateAllParameters(
                moduleId: moduleIdText,
                canProtocol: canText,
                rs485Protocol: rs485Text
            )
        } else {
            // Если устройство не подключено, показываем прочерки
            AppLogger.shared.info(
                screen: AppLogger.Screen.home,
                event: AppLogger.Event.dataUpdated,
                message: "[PROTOCOL_DEBUG] 🎨 UI Updated: Device disconnected - showing dashes",
                details: [
                    "deviceName": deviceName,
                    "moduleId": "--",
                    "canProtocol": "--",
                    "rs485Protocol": "--",
                    "connected": false
                ]
            )

            protocolParametersView.updateAllParameters(
                moduleId: "--",
                canProtocol: "--",
                rs485Protocol: "--"
            )
        }
    }
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

extension UIColor {
    /// Создание цвета из шестнадцатеричной строки
    /// - Parameter hex: Шестнадцатеричная строка (например, "FF0000" для красного)
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}
