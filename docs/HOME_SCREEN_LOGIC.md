# 📱 HOME SCREEN - Детальная логика работы

**Дата создания:** 07.10.2025
**Версия:** 1.0
**Автор:** Технический анализ кодовой базы

---

## 📋 СОДЕРЖАНИЕ

1. [Обзор архитектуры](#обзор-архитектуры)
2. [Real-time Data Updates - Ядро системы](#real-time-data-updates---ядро-системы)
3. [Цепочка вызовов Lifecycle](#цепочка-вызовов-lifecycle)
4. [Детальный анализ кода](#детальный-анализ-кода)
5. [Поток данных](#поток-данных)
6. [UI Компоненты](#ui-компоненты)
7. [Configuration и Mock Data](#configuration-и-mock-data)
8. [Визуальные схемы](#визуальные-схемы)
9. [FAQ и примеры](#faq-и-примеры)
10. [Связанные файлы](#связанные-файлы)

---

## 🏗️ ОБЗОР АРХИТЕКТУРЫ

### Назначение Home экрана

Home экран - это **главный экран приложения**, который отображает real-time данные о состоянии BMS (Battery Management System):

- **Уровень заряда батареи** (SOC - State of Charge)
- **Статус батареи** (Charging, Discharging, Standby, etc.)
- **Основные параметры** - напряжение, ток, температура
- **Протоколы связи** - Module ID, CAN, RS485
- **Детальные данные** в 3 табах:
  - Summary - сводка параметров
  - Cell Voltage - напряжения 16 ячеек
  - Temperature - температуры 5 датчиков

### Ключевые компоненты UI

```
HomeViewController
    ├── headerLogoView (HeaderLogoView)
    ├── ScrollView
    │   └── ContentStackView (UIStackView)
    │       ├── BluetoothConnectionView - плашка подключения
    │       ├── BatteryProgressView - круговая диаграмма заряда
    │       ├── BatteryStatusView - индикатор статуса
    │       ├── BatteryParametersView - напряжение/ток/температура
    │       ├── ProtocolParametersView - Module ID/CAN/RS485
    │       ├── TabsContainerView - контейнер с табами
    │       │   ├── SummaryTabView
    │       │   ├── CellVoltageTabView
    │       │   └── TemperatureTabView
    │       └── TimerView - время последнего обновления
```

### Зависимости

**Внутренние:**
- `Zetara.Data.BMS` - структура данных BMS
- `ZetaraManager` - менеджер Bluetooth коммуникации
- `Configuration` - конфигурация приложения
- 8+ переиспользуемых UI компонентов

**Внешние:**
- `RxSwift` - реактивное программирование
- `RxBluetoothKit2` - Bluetooth LE коммуникация
- `SnapKit` - Auto Layout DSL
- `GradientView` - градиентные фоны

---

## ⚡ REAL-TIME DATA UPDATES - Ядро системы

### Критическая архитектура

Home экран работает в режиме **real-time обновления данных** от BMS через Bluetooth.

#### Три ключевых механизма:

### 1. Timer - Автоматическое обновление данных

**Код:**
```swift
// Файл: ZetaraManager.swift:414-427
func startRefreshBMSData() {
    self.timer = Timer.scheduledTimer(
        withTimeInterval: Self.configuration.refreshBMSTimeInterval,
        repeats: true
    ) { [weak self] _ in
        self?.getBMSData()
            .subscribe(onSuccess: { [weak self] _data in
                self?.bmsDataSubject.asObserver().onNext(_data)
            })
    }
    self.timer?.fire() // Первое обновление сразу
}
```

**Параметры:**
- **Интервал:** `refreshBMSTimeInterval` (по умолчанию **5 секунд**)
- **Режим:** repeats: true - бесконечный цикл
- **Первое обновление:** немедленно через `.fire()`

**Жизненный цикл:**
```
Подключение к устройству
    ↓
startRefreshBMSData() вызывается
    ↓
Timer запускается (каждые 5 сек)
    ↓
getBMSData() → bmsDataSubject.onNext()
    ↓
HomeViewController получает данные → updateUI()
```

**Background/Foreground handling:**
```swift
// Файл: ZetaraManager.swift:97-105
// При уходе в фон - останавливаем обновления
UIApplication.didEnterBackgroundNotification → pauseRefreshBMSData()

// При возвращении - возобновляем обновления
UIApplication.willEnterForegroundNotification → resumeRefreshBMSData()
```

---

### 2. Request Queue - Последовательность запросов

**Проблема:** Bluetooth не может обрабатывать множество одновременных запросов.

**Решение:** Request Queue с минимальным интервалом 500ms между запросами.

**Код:**
```swift
// Файл: ZetaraManager.swift:302-346
public func queuedRequest<T>(_ requestName: String,
                             _ request: @escaping () -> Maybe<T>) -> Maybe<T> {
    return Maybe.create { observer in
        self.requestQueue.async {
            // Ждем если прошло < 500ms с последнего запроса
            if let lastTime = self.lastRequestTime {
                let elapsed = Date().timeIntervalSince(lastTime)
                if elapsed < self.minimumRequestInterval {
                    let waitTime = self.minimumRequestInterval - elapsed
                    Thread.sleep(forTimeInterval: waitTime)
                }
            }

            // Обновляем время последнего запроса
            self.lastRequestTime = Date()

            // Выполняем запрос
            request().subscribe(...)
        }
    }
}
```

**Параметры:**
- **Минимальный интервал:** 500ms (`minimumRequestInterval = 0.5`)
- **Очередь:** Serial DispatchQueue (по одному запросу)
- **Timeout:** 10 секунд (встроен в RxSwift)

**Пример использования:**
```swift
// На Settings экране при загрузке протоколов:
ZetaraManager.shared.queuedRequest("getModuleId") {
    ZetaraManager.shared.getModuleId()
}
```

**Лог запросов:**
```
[QUEUE] 📥 Request queued: getModuleId
[QUEUE] ⏳ Waiting 100ms before getModuleId
[QUEUE] 🚀 Executing getModuleId
[QUEUE] ✅ getModuleId completed in 320ms
```

---

### 3. Connection Monitor - Проверка подключения

**Проблема:** "Phantom connections" - iOS может показывать устройство как подключенное, хотя реально связь потеряна.

**Решение:** Периодическая проверка реального состояния через CoreBluetooth.

**Код:**
```swift
// Файл: ZetaraManager.swift:351-399
func startConnectionMonitor() {
    connectionMonitorTimer = Timer.scheduledTimer(
        withTimeInterval: connectionCheckInterval,  // 2 секунды
        repeats: true
    ) { [weak self] _ in
        self?.verifyConnectionState()
    }
}

func verifyConnectionState() {
    guard let peripheral = try? connectedPeripheralSubject.value() else {
        return  // Нет подключенного устройства - это нормально
    }

    let currentState = peripheral.state

    // Проверяем РЕАЛЬНОЕ состояние через CoreBluetooth
    if currentState != .connected {
        print("[CONNECTION] ⚠️ Phantom connection detected!")
        cleanConnection()  // Принудительная очистка
    }
}
```

**Параметры:**
- **Интервал проверки:** 2 секунды (`connectionCheckInterval = 2.0`)
- **Проверка:** `peripheral.state != .connected`
- **Действие:** автоматическая очистка через `cleanConnection()`

**Почему это важно:**
```
Сценарий без Connection Monitor:
1. Пользователь подключил устройство ✅
2. Батарея выключена 🔌
3. iOS считает устройство подключенным ❌
4. Приложение продолжает показывать "Connected" ❌
5. Пользователь видит устаревшие данные ❌

Сценарий с Connection Monitor:
1. Пользователь подключил устройство ✅
2. Батарея выключена 🔌
3. Connection Monitor через 2 сек обнаруживает ⚠️
4. Автоматическая очистка через cleanConnection() 🧹
5. UI обновляется: "Tap to Connect" ✅
```

---

## 🔄 ЦЕПОЧКА ВЫЗОВОВ LIFECYCLE

### Lifecycle диаграмма

```
┌─────────────────────────────────────────────────────────────┐
│                     APP START                                │
│                                                              │
│  AppDelegate.didFinishLaunchingWithOptions()                │
│  → ZetaraManager.setup(Configuration)                       │
│  → refreshBMSTimeInterval = 5 сек                           │
│  → mockData (для DEBUG сборок)                              │
│                                                              │
└──────────────────────────┬──────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                   viewDidLoad()                              │
│                                                              │
│  1. setupHeaderView()                                       │
│     → Создание всех UI компонентов                          │
│     → ScrollView + ContentStackView                         │
│     → 8 view компонентов в стеке                           │
│                                                              │
│  2. setupObservers()                                        │
│     → Подписка на observableState (Bluetooth)               │
│     → Подписка на bmsDataSubject (данные BMS)               │
│     → Подписка на connectedPeripheralSubject (подключение)  │
│                                                              │
│  3. updateTitle()                                           │
│     → Обновление имени устройства                           │
│                                                              │
└──────────────────────────┬──────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                   viewWillAppear()                           │
│                                                              │
│  Скрываем navigation bar                                    │
│                                                              │
└──────────────────────────┬──────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                   viewDidAppear()                            │
│                                                              │
│  Отключаем жест смахивания назад                            │
│  (для предотвращения зависаний)                             │
│                                                              │
└──────────────────────────┬──────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│   ПОЛЬЗОВАТЕЛЬ ПОДКЛЮЧАЕТ УСТРОЙСТВО (ConnectivityVC)       │
│                                                              │
│  connect(peripheral) → connectedPeripheralSubject.onNext()  │
│     ↓                                                        │
│  startConnectionMonitor() ← Запуск мониторинга (каждые 2 сек)│
│     ↓                                                        │
│  startRefreshBMSData() ← Запуск Timer (каждые 5 сек)       │
│     ↓                                                        │
│  Timer.fire() → Первое обновление немедленно                │
│                                                              │
└──────────────────────────┬──────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│             ЦИКЛ ОБНОВЛЕНИЯ ДАННЫХ (каждые 5 сек)           │
│                                                              │
│  Timer срабатывает каждые 5 секунд                          │
│     ↓                                                        │
│  getBMSData()                                               │
│     ↓                                                        │
│  Bluetooth запрос: writeValue(getBMSData)                   │
│     ↓                                                        │
│  Ответ от BMS: observeValueUpdate()                         │
│     ↓                                                        │
│  Обработка: bmsDataHandler.append(bytes)                    │
│     ↓                                                        │
│  bmsDataSubject.onNext(bmsData)                             │
│     ↓                                                        │
│  HomeViewController получает данные                         │
│     ↓                                                        │
│  updateUI(bmsData)                                          │
│     ↓                                                        │
│  Обновление всех компонентов:                               │
│    - BatteryProgressView (level = soc/100)                  │
│    - BatteryStatusView (status = charging/discharging)      │
│    - BatteryParametersView (V, A, T)                        │
│    - ProtocolParametersView (Module ID, CAN, RS485)         │
│    - SummaryTabView (max/min voltage, power, etc.)          │
│    - CellVoltageTabView (16 ячеек)                          │
│    - TemperatureTabView (5 датчиков)                        │
│    - TimerView (Last Update: 2025/10/07 12:34:56)          │
│                                                              │
│  ⏱️  Ждем 5 секунд...                                       │
│  ↻ ПОВТОР                                                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Обработка отключения

```
┌─────────────────────────────────────────────────────────────┐
│           УСТРОЙСТВО ОТКЛЮЧИЛОСЬ                             │
│                                                              │
│  observeDisconnect() → cleanConnection()                    │
│     ↓                                                        │
│  stopConnectionMonitor() ← Остановка мониторинга            │
│     ↓                                                        │
│  timer?.invalidate() ← Остановка Timer                      │
│     ↓                                                        │
│  Очистка кэша протоколов                                    │
│     ↓                                                        │
│  connectedPeripheralSubject.onNext(nil)                     │
│     ↓                                                        │
│  HomeViewController получает nil                            │
│     ↓                                                        │
│  updateUI() → Отображение прочерков ("-- V", "-- A")        │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 📝 ДЕТАЛЬНЫЙ АНАЛИЗ КОДА

### 1. Инициализация UI (setupHeaderView)

**Файл:** `HomeViewController.swift:202-459`

**Что происходит:**
```swift
private func setupHeaderView() {
    // 1. Очищаем все существующие view
    for subview in view.subviews {
        subview.removeFromSuperview()
    }

    // 2. Добавляем фоновое изображение
    let backgroundImageView = UIImageView(image: R.image.background())
    view.addSubview(backgroundImageView)

    // 3. Добавляем шапку с логотипом
    view.addSubview(headerLogoView)
    headerLogoView.setupConstraints(in: view)

    // 4. Создаем ScrollView для скроллинга контента
    let scrollView = UIScrollView()
    scrollView.alwaysBounceVertical = true
    view.addSubview(scrollView)

    // 5. Создаем вертикальный стек для компонентов
    let contentStackView = UIStackView()
    contentStackView.axis = .vertical
    contentStackView.spacing = 16  // Отступы между компонентами
    scrollView.addSubview(contentStackView)

    // 6. Создаем 7 контейнеров для компонентов
    let bluetoothConnectionContainer = UIView()
    let batteryContainer = UIView()
    let batteryStatusContainer = UIView()
    let componentsContainer = UIView()
    let protocolsContainer = UIView()
    let tabsContainer = UIView()
    let timerContainer = UIView()

    // 7. Добавляем контейнеры в стек
    contentStackView.addArrangedSubview(bluetoothConnectionContainer)
    contentStackView.addArrangedSubview(batteryContainer)
    contentStackView.addArrangedSubview(batteryStatusContainer)
    contentStackView.addArrangedSubview(componentsContainer)
    contentStackView.addArrangedSubview(protocolsContainer)
    contentStackView.addArrangedSubview(tabsContainer)
    contentStackView.addArrangedSubview(timerContainer)

    // 8. Создаем и добавляем компоненты в контейнеры...
}
```

**Структура:**
```
UIViewController.view
    ├── backgroundImageView (фон)
    ├── headerLogoView (шапка)
    └── scrollView
        └── contentStackView (вертикальный стек)
            ├── bluetoothConnectionContainer
            │   └── BluetoothConnectionView
            ├── batteryContainer
            │   └── BatteryProgressView (350x350)
            ├── batteryStatusContainer
            │   └── BatteryStatusView
            ├── componentsContainer (height: 80)
            │   └── BatteryParametersView
            ├── protocolsContainer (height: 86)
            │   └── ProtocolParametersView
            ├── tabsContainer (height: 330)
            │   └── TabsContainerView
            └── timerContainer
                └── TimerView
```

**Constraints (SnapKit):**
```swift
// ScrollView заполняет пространство под шапкой
scrollView.snp.makeConstraints { make in
    make.top.equalTo(headerLogoView.bottomAnchor)
    make.leading.trailing.bottom.equalToSuperview()
}

// ContentStackView определяет ширину и высоту контента
contentStackView.snp.makeConstraints { make in
    make.edges.equalToSuperview()
    make.width.equalTo(scrollView)  // Важно для правильного скроллинга
}

// BatteryProgressView (круговая диаграмма)
batteryProgressView.snp.makeConstraints { make in
    make.center.equalToSuperview()
    make.width.height.equalTo(350)  // Большой круг
    make.top.offset(16)
    make.bottom.offset(-16)
}

// TabsContainer (самый большой блок)
tabsContainer.snp.makeConstraints { make in
    make.height.equalTo(330)  // Фиксированная высота для табов
}
```

---

### 2. Настройка подписок (setupObservers)

**Файл:** `HomeViewController.swift:133-166`

```swift
func setupObservers() {

    // ПОДПИСКА 1: Состояние Bluetooth
    ZetaraManager.shared.observableState
        .subscribeOn(MainScheduler.instance)
        .subscribe { (state: BluetoothState) in
            switch state {
                case .poweredOff:
                    print("Bluetooth выключен")
                default:
                    return
            }
        }.disposed(by: disposeBag)

    // ПОДПИСКА 2: Данные BMS (ГЛАВНАЯ ПОДПИСКА!)
    ZetaraManager.shared.bmsDataSubject
        .subscribeOn(MainScheduler.instance)
        .observe(on: MainScheduler.instance)
        .subscribe { [weak self] _data in
            self?.updateUI(_data)  // ← Обновляем UI при каждом новом значении
        } onError: { error in
            print("er:\(error)")
        }.disposed(by: disposeBag)

    // ПОДПИСКА 3: Подключенное устройство
    ZetaraManager.shared.connectedPeripheralSubject
        .subscribeOn(MainScheduler.instance)
        .observe(on: MainScheduler.instance)
        .subscribe { [weak self] (peripheral: ZetaraManager.ConnectedPeripheral?) in
            self?.updateTitle(peripheral)  // ← Обновляем имя устройства
        }.disposed(by: disposeBag)
}
```

**Что делают подписки:**

1. **observableState** - отслеживает состояние Bluetooth (poweredOn, poweredOff)
2. **bmsDataSubject** - получает новые данные BMS каждые 5 секунд → вызывает `updateUI()`
3. **connectedPeripheralSubject** - отслеживает подключение/отключение устройства → обновляет UI

**RxSwift цепочка:**
```
Timer срабатывает (каждые 5 сек)
    ↓
getBMSData() → Maybe<Data.BMS>
    ↓
bmsDataSubject.onNext(bmsData)  ← Отправка нового значения
    ↓
.subscribe { data in ... }      ← HomeViewController получает
    ↓
updateUI(data)                  ← Обновление UI
```

---

### 3. Обновление UI (updateUI)

**Файл:** `HomeViewController.swift:461-590`

**Самый важный метод в HomeViewController!**

```swift
func updateUI(_ data: Zetara.Data.BMS) {
    // Обновляем время последнего обновления
    timerView.updateTime(Date())

    // Проверяем реальное подключение
    let isDeviceActuallyConnected = ZetaraManager.shared.connectedPeripheral() != nil

    if isDeviceActuallyConnected {
        // ===== ЕСТЬ ПОДКЛЮЧЕНИЕ - ОТОБРАЖАЕМ РЕАЛЬНЫЕ ДАННЫЕ =====

        // 1. Уровень заряда (SOC → 0.0...1.0)
        let battery = Float(data.soc)/100.0
        batteryProgressView.level = battery
        batteryProgressView.updateChargingStatus(isCharging: data.status == .charging)

        // 2. Статус батареи
        batteryStatusView.updateStatusAnimated(data.status)

        // 3. Основные параметры
        batteryParametersView.updateVoltage("\(data.voltage)V")
        batteryParametersView.updateCurrent("\(data.current)A")

        // 4. Температура (средняя от всех датчиков)
        var totalTemp: Int = 0
        var tempCount = 0

        // Добавляем PCB температуру
        if data.tempPCB != 0 {
            totalTemp += Int(data.tempPCB)
            tempCount += 1
        }

        // Добавляем все температуры сенсоров
        for cellTemp in data.cellTemps {
            if cellTemp != 0 {
                totalTemp += Int(cellTemp)
                tempCount += 1
            }
        }

        // Вычисляем среднее (fallback на tempEnv если нет датчиков)
        let avgTemp = tempCount > 0 ? Int8(totalTemp / tempCount) : data.tempEnv
        batteryParametersView.updateTemperature("\(avgTemp.celsiusToFahrenheit())°F/\(avgTemp)°C")

        // 5. Протоколы (из кэша ZetaraManager)
        protocolParametersView.updateValues()

        // 6. Summary Tab
        if let summaryView = self.summaryView {
            let maxVoltage = data.cellVoltages.max() ?? 0
            let minVoltage = data.cellVoltages.min() ?? 0
            let voltageDiff = maxVoltage - minVoltage
            let power = data.voltage * data.current
            let avgVoltage = data.cellVoltages.reduce(0, +) / Float(max(1, data.cellVoltages.count))

            summaryView.updateAllParameters(
                maxVoltage: maxVoltage,
                minVoltage: minVoltage,
                voltageDiff: voltageDiff,
                power: power,
                internalTemp: data.tempPCB,
                avgVoltage: avgVoltage
            )
        }

        // 7. Cell Voltage Tab (16 ячеек)
        if let cellVoltageView = self.cellVoltageView {
            cellVoltageView.updateCellVoltages(data.cellVoltages)
        }

        // 8. Temperature Tab (5 датчиков)
        if let temperatureView = self.temperatureView {
            temperatureView.updateTemperatures(
                pcbTemp: data.tempPCB,
                envTemp: data.tempEnv,
                cellTemps: data.cellTemps
            )
        }

    } else {
        // ===== НЕТ ПОДКЛЮЧЕНИЯ - ОТОБРАЖАЕМ ПРОЧЕРКИ =====

        batteryProgressView.level = 0
        batteryStatusView.updateStatus(.standby)

        batteryParametersView.updateVoltage("-- V")
        batteryParametersView.updateCurrent("-- A")
        batteryParametersView.updateTemperature("-- °F/-- °C")

        summaryView?.updateAllParameters(..., showDashes: true)
        cellVoltageView?.updateCellVoltages([], showDashes: true)
        temperatureView?.updateTemperatures(..., showDashes: true)
    }
}
```

**Частота вызова:**
- **Каждые 5 секунд** (через Timer в ZetaraManager)
- **При первом подключении** (немедленно через `.fire()`)
- **При отключении** (через `connectedPeripheralSubject`)

---

### 4. Получение данных BMS (getBMSData)

**Файл:** `ZetaraManager.swift:442-545`

**Самый важный метод в ZetaraManager!**

```swift
func getBMSData() -> Maybe<Data.BMS> {
    print("!!! МЕТОД getBMSData() ВЫЗВАН !!!")

    // Проверяем наличие подключенного устройства
    let isDeviceConnected = (try? connectedPeripheralSubject.value()) != nil &&
                            writeCharacteristic != nil &&
                            notifyCharacteristic != nil

    // MOCK DATA: Используем мок-данные если нет подключения
    if !isDeviceConnected, let mockBMSData = Self.configuration.mockData {
        print("!!! Используем мок-данные !!!")
        return Maybe.create { [weak self] observer in
            let bytes = [UInt8](mockBMSData)

            // Обрабатываем мок-данные через BMSDataHandler
            if let data = self?.bmsDataHandler.append(bytes) {
                observer(.success(data))
            }

            return Disposables.create {}
        }
    }

    // REAL DATA: Используем реальные данные от подключенного устройства
    guard let peripheral = try? connectedPeripheralSubject.value(),
          let writeCharacteristic = writeCharacteristic,
          let notifyCharacteristic = notifyCharacteristic else {
        print("!!! ОШИБКА: Нет подключенного устройства !!!")
        cleanConnection()
        return Maybe.error(ZetaraManager.Error.connectionError)
    }

    print("!!! Используем реальные данные от подключенного устройства !!!")

    // 1. Отправляем команду на получение данных BMS
    let data = Foundation.Data.getBMSData  // 01030000002705d0
    print("getting bms data write data: \(data.toHexString())")
    peripheral.writeValue(data, for: writeCharacteristic, type: .withResponse)

    // 2. Ждем ответ от BMS
    return Maybe.create { observer in
        peripheral.observeValueUpdateAndSetNotification(for: notifyCharacteristic)
            .compactMap { $0.value }
            .do { print("recevie bms data: \($0.toHexString())") }
            .map { [UInt8]($0) }
            .filter { $0.crc16Verify() && Data.BMS.isBMSData($0) }  // Проверка CRC16
            .compactMap { [weak self] _bytes in
                return self?.bmsDataHandler.append(_bytes)  // Обработка фрагментов
            }
            .flatMap { Observable.of($0) }
            .subscribe { bmsEvent in
                switch bmsEvent {
                    case .next(let data):
                        observer(.success(data))  // ← Отправляем данные в bmsDataSubject
                    default:
                        return
                }
            }

        return Disposables.create {}
    }
}
```

**Что происходит:**

1. **Проверка подключения** - есть ли устройство?
2. **Mock Data fallback** - если нет устройства, используем мок-данные (для DEBUG)
3. **Отправка команды** - `writeValue(getBMSData)` через Bluetooth
4. **Получение ответа** - `observeValueUpdate()` подписка на notify characteristic
5. **Проверка CRC16** - валидация данных
6. **Обработка фрагментов** - `bmsDataHandler.append()` собирает фрагменты
7. **Отправка данных** - `observer(.success(data))` → `bmsDataSubject`

**Bluetooth протокол:**

```
Request:  01 03 00 00 00 27 05 d0
          ││ ││ ││ ││ ││ ││ └└─ CRC16
          ││ ││ ││ ││ └└─ Length (39 bytes)
          ││ ││ └└─ Start address (0x0000)
          ││ └─ Function code (0x03 = Read Holding Registers)
          └─ Device address (0x01)

Response: 01 03 4E [78 bytes of BMS data] [CRC16]
          ││ ││ └─ Length (78 bytes)
          ││ └─ Function code (0x03)
          └─ Device address (0x01)
```

---

### 5. Обработка фрагментированных данных (BMSDataHandler)

**Файл:** `Data.swift:143-198`

**Проблема:** BMS может отправлять данные в нескольких фрагментах (frames), если батарея имеет > 16 ячеек.

**Решение:** `BMSDataHandler` накапливает фрагменты и собирает полные данные.

```swift
class BMSDataHandler {
    var data: BMS?  // Временное хранилище для незавершенных данных

    func append(_ bytes: [UInt8]) -> BMS? {
        if BMS.FunctionCode.isNormal(of: bytes) {
            // Первый фрагмент (frame 0)
            let cellCount = bytes.cellCount()

            let realBytes = Array(bytes[3 ..< bytes.count - 5])

            if let data = BMS(realBytes) {
                if data.cellCount <= 16 {
                    // Все данные в одном фрагменте ✅
                    reset()
                    return data
                } else {
                    // Данные в нескольких фрагментах, сохраняем временно
                    self.data = data
                    return nil  // Ждем следующих фрагментов
                }
            }

        } else if var _data = self.data {
            // Второй/третий/... фрагмент (frame 1, 2, ...)
            let frameNo = Int(bytes[2])
            let cellCountLeft = min(_data.cellCount - frameNo * 16, 16)

            // Добавляем напряжения ячеек из этого фрагмента
            let cellVoltages = bytes.voltagesFromOtherFrame(...)
            for index in ... {
                _data.cellVoltages.insert(cellVoltages[...], at: index)
            }

            // Проверяем, это последний фрагмент?
            let totalFrame = (_data.cellCount + 15) / 16
            if frameNo == totalFrame - 1 {
                // Все фрагменты получены! ✅
                reset()
                return _data
            }

            return nil  // Ждем еще фрагментов
        }
    }
}
```

**Пример для 32 ячеек:**

```
Frame 0 (isNormal):
  - Основные данные: voltage, current, soc, status
  - Ячейки 1-16: voltages
  - frameNo = 0
  → Сохраняем во временное хранилище

Frame 1 (isSplit):
  - Ячейки 17-32: voltages
  - frameNo = 1
  - totalFrame = 2
  - frameNo == totalFrame - 1 ✅
  → Возвращаем полные данные
```

---

## 🔀 ПОТОК ДАННЫХ

### Диаграмма потока данных

```
┌──────────────────────────────────────────────────────────────────┐
│                        BMS DEVICE                                 │
│                     (Battery Hardware)                            │
│                                                                   │
│  Данные:                                                          │
│  - Voltage (53.35V)                                              │
│  - Current (0.35A)                                               │
│  - SOC (87%)                                                     │
│  - Status (Charging)                                             │
│  - 16 Cell Voltages [3.253, 3.213, ...]                         │
│  - 4 Cell Temps [24°C, 25°C, 24°C, 24°C]                        │
│  - PCB Temp, Env Temp                                            │
│                                                                   │
└────────────────────────────┬─────────────────────────────────────┘
                             │ Bluetooth LE (Service 1006)
                             │ Write: 1008, Notify: 1007
                             ↓
┌──────────────────────────────────────────────────────────────────┐
│                      ZETA MANAGER                                │
│                    (Bluetooth Manager)                           │
│                                                                   │
│  1. Timer (каждые 5 сек)                                        │
│     → getBMSData()                                              │
│                                                                   │
│  2. Bluetooth Request                                            │
│     writeValue(0x01030000002705d0)                              │
│                                                                   │
│  3. Bluetooth Response                                           │
│     observeValueUpdate()                                         │
│     → [UInt8] bytes                                              │
│                                                                   │
│  4. Validation                                                   │
│     .crc16Verify() ✅                                            │
│     .isBMSData() ✅                                              │
│                                                                   │
│  5. Parsing                                                      │
│     bmsDataHandler.append(bytes)                                 │
│     → Data.BMS struct                                            │
│                                                                   │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                             │ RxSwift Observable
                             ↓
┌──────────────────────────────────────────────────────────────────┐
│                  BEHAVIOR SUBJECT                                │
│                                                                   │
│  bmsDataSubject: BehaviorSubject<Data.BMS>                      │
│                                                                   │
│  .onNext(bmsData) ← Новые данные каждые 5 сек                  │
│                                                                   │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                             │ .subscribe { data in ... }
                             ↓
┌──────────────────────────────────────────────────────────────────┐
│                 HOME VIEW CONTROLLER                             │
│                                                                   │
│  .subscribe { [weak self] data in                               │
│      self?.updateUI(data)                                       │
│  }                                                               │
│                                                                   │
│  updateUI(data: Data.BMS) {                                     │
│      // Извлекаем данные из struct                              │
│      let battery = Float(data.soc) / 100.0                      │
│      let voltage = data.voltage                                 │
│      let current = data.current                                 │
│      // ...                                                      │
│                                                                   │
│      // Обновляем UI компоненты                                 │
│      batteryProgressView.level = battery                        │
│      batteryParametersView.updateVoltage("\(voltage)V")         │
│      // ...                                                      │
│  }                                                               │
│                                                                   │
└────────────────────────────┬─────────────────────────────────────┘
                             │
            ┌────────────────┼────────────────┐
            ↓                ↓                ↓
┌──────────────────┐ ┌──────────────┐ ┌─────────────────┐
│ BatteryProgress  │ │  BatteryPara │ │  TabsContainer  │
│      View        │ │   metersView │ │      View       │
│                  │ │              │ │                 │
│  level = 0.87    │ │  V: 53.35V   │ │  Summary Tab    │
│  (87%)           │ │  A: 0.35A    │ │  CellVolt Tab   │
│                  │ │  T: 24°C     │ │  Temp Tab       │
└──────────────────┘ └──────────────┘ └─────────────────┘
```

### Структура данных Data.BMS

**Файл:** `Data.swift:12-141`

```swift
public struct BMS {
    // Основные параметры
    public var voltage: Float = 0        // Общее напряжение батареи (V)
    public var current: Float = 0        // Текущий ток (A, может быть отрицательным)
    public var soc: Int = 0              // State of Charge (0-100%)
    public var soh: Int = 0              // State of Health (0-100%)
    public var status: Status = .standby // Статус (charging, discharging, etc.)

    // Ячейки
    public var cellCount: Int = 0                 // Количество ячеек
    public var cellVoltages: Array<Float> = []    // Напряжения ячеек (до 16)
    public var cellTemps: Array<Int8> = []        // Температуры ячеек (до 4)

    // Температуры
    public var tempPCB: Int8 = 0   // Температура платы управления
    public var tempEnv: Int8 = 0   // Температура окружающей среды

    // Статусы
    public enum Status {
        case charging      // Зарядка
        case disCharging   // Разрядка
        case protecting    // Защита
        case chargingLimit // Лимит зарядки
        case standby       // Ожидание
    }
}
```

**Индексы в байтовом массиве:**
```swift
enum Index: Int {
    case function = 1         // Функциональный код
    case totalVoltage = 0     // Общее напряжение (2 байта)
    case current = 2          // Ток (2 байта)
    case tempPCB = 36         // Температура PCB
    case tempMax = 40         // Максимальная температура
    case soh = 46             // State of Health
    case soc = 48             // State of Charge
    case status = 51          // Статус батареи
    case cellCount = 72       // Количество ячеек
    case cellVoltage = 4      // Начало массива напряжений
    case cellTemps = 66       // Начало массива температур
}
```

**Пример разбора данных:**
```
Байты: 01 03 4E 14 BA 00 00 0C B1 0C B4 0C B1 0C B2 ...
       ││ ││ ││ └└── totalVoltage (0x14BA = 5306 → 53.06V)
       ││ ││ └─ length (78 bytes)
       ││ └─ function (0x03)
       └─ address (0x01)

cellVoltage[0]: 0C B1 = 3249 → 3.249V
cellVoltage[1]: 0C B4 = 3252 → 3.252V
...

soc: 65 = 101 → 101% (ошибка, max 100)
```

---

## 🎨 UI КОМПОНЕНТЫ

### 1. BluetoothConnectionView

**Файл:** `BluetoothConnectionView.swift:13-137`

**Назначение:** Плашка для подключения к устройству Bluetooth.

**UI Structure:**
```
BluetoothConnectionView
    └── containerView (белый фон, rounded corners)
        ├── bluetoothImageView (иконка Bluetooth)
        ├── deviceNameLabel ("Tap to Connect" / "Husky 2")
        └── addButton (кнопка "+")
```

**Методы:**
```swift
// Обновление имени устройства
func updateDeviceName(_ name: String?) {
    deviceNameLabel.text = name ?? "Tap to Connect"
}

// Обработчик нажатия
var onTap: (() -> Void)?
```

**Использование в HomeViewController:**
```swift
// Создание
let bluetoothConnectionView = BluetoothConnectionView()

// Обработчик нажатия
bluetoothConnectionView.onTap = { [weak self] in
    self?.handleBluetoothConnectionTap()
}

// Обновление имени
bluetoothConnectionView.updateDeviceName(deviceName)
```

**UI States:**
```
НЕТ ПОДКЛЮЧЕНИЯ:
┌─────────────────────────────────────────┐
│  🔵  Tap to Connect              [+]   │
└─────────────────────────────────────────┘

ЕСТЬ ПОДКЛЮЧЕНИЕ:
┌─────────────────────────────────────────┐
│  🔵  Husky 2 (Mock)              [+]   │
└─────────────────────────────────────────┘
```

---

### 2. BatteryProgressView

**Файл:** `BatteryProgressView.swift:12-250`

**Назначение:** Круговая диаграмма прогресса заряда батареи.

**UI Structure:**
```
BatteryProgressView (350x350)
    ├── outerCircleLayer (серый круг)
    ├── progressLayer (зеленый/оранжевый/красный круг)
    ├── batteryImageContainer
    │   └── huskyImageView (изображение husky2)
    ├── percentLabelContainer (контейнер с процентом)
    │   └── percentLabel ("87%")
    ├── minLabel ("0")
    └── maxLabel ("100")
```

**Методы:**
```swift
// Установка уровня заряда (0.0 - 1.0)
var level: Float {
    get { return _level }
    set {
        _level = min(max(newValue, 0.0), 1.0)
        updateProgress(animated: true)
    }
}

// Обновление статуса зарядки
func updateChargingStatus(isCharging: Bool) {
    // Пустая реализация для совместимости
}
```

**Цвета прогресса:**
```swift
private var progressColor: UIColor {
    if _level <= 0.1 {
        return .systemRed      // 0-10%: Красный
    } else if _level <= 0.3 {
        return .systemOrange   // 11-30%: Оранжевый
    } else {
        return .systemGreen    // 31-100%: Зеленый
    }
}
```

**Визуализация:**
```
        100
         │
    ┌────┴────┐
    │         │
    │  ████   │  ← progressLayer (зеленый, strokeEnd = 0.87)
    │  ████   │
    │  ████   │
    │   87%   │  ← percentLabel с цветным фоном
    │         │
    └─────────┘
0                 ← minLabel, maxLabel
```

---

### 3. BatteryStatusView

**Файл:** `BatteryStatusView.swift:13-126`

**Назначение:** Текстовый индикатор статуса батареи с цветным фоном.

**UI Structure:**
```
BatteryStatusView
    └── containerView (цветной фон)
        └── statusLabel ("Charging", "Standby", etc.)
```

**Методы:**
```swift
// Обновление статуса
func updateStatus(_ status: Zetara.Data.BMS.Status) {
    currentStatus = status
    statusLabel.text = status.description
    updateStatusStyle()
}

// Обновление с анимацией
func updateStatusAnimated(_ status: Zetara.Data.BMS.Status) {
    UIView.transition(with: statusLabel, duration: 0.3) {
        self.statusLabel.text = status.description
    }
    UIView.animate(withDuration: 0.3) {
        self.updateStatusStyle()
    }
}
```

**Цвета статусов:**
```swift
switch currentStatus {
case .charging:
    backgroundColor = UIColor.systemGreen.withAlphaComponent(0.2)
    textColor = UIColor.systemGreen

case .disCharging:
    backgroundColor = UIColor.systemOrange.withAlphaComponent(0.2)
    textColor = UIColor.systemOrange

case .protecting:
    backgroundColor = UIColor.systemRed.withAlphaComponent(0.2)
    textColor = UIColor.systemRed

case .standby:
    backgroundColor = UIColor.systemGray.withAlphaComponent(0.2)
    textColor = UIColor.systemGray
}
```

**Визуализация:**
```
CHARGING:
┌──────────────┐
│   Charging   │  ← Зеленый фон + зеленый текст
└──────────────┘

STANDBY:
┌──────────────┐
│   Standby    │  ← Серый фон + серый текст
└──────────────┘
```

---

### 4. BatteryParametersView

**Файл:** `BatteryParametersView.swift:13-151`

**Назначение:** Отображение 3 основных параметров (напряжение, ток, температура).

**UI Structure:**
```
BatteryParametersView
    └── stackView (horizontal)
        ├── voltageComponentView (ComponentView)
        ├── currentComponentView (ComponentView)
        └── temperatureComponentView (ComponentView)
```

**Методы:**
```swift
// Обновление отдельных параметров
func updateVoltage(_ value: String)
func updateCurrent(_ value: String)
func updateTemperature(_ value: String)

// Обновление всех параметров
func updateAllParameters(voltage: String, current: String, temperature: String)

// Изменение порядка компонентов
func reorderComponents(order: [ComponentType])
```

**ComponentView:**
```swift
// Каждый компонент содержит:
- icon: UIImage (иконка)
- title: String ("Total Voltage")
- value: String ("53.35V")
```

**Визуализация:**
```
┌─────────────┬─────────────┬─────────────┐
│  ⚡ 53.35V  │  ⚡ 0.35A   │  🌡 24°C/75°F│
│ Total       │ Total       │ Total Temp. │
│ Voltage     │ Current     │             │
└─────────────┴─────────────┴─────────────┘
```

---

### 5. ProtocolParametersView

**Файл:** `ProtocolParametersView.swift:14-163`

**Назначение:** Отображение протоколов связи (Module ID, CAN, RS485).

**UI Structure:**
```
ProtocolParametersView
    └── stackView (horizontal)
        ├── moduleIdBlock (ProtocolBlock)
        ├── canBlock (ProtocolBlock)
        └── rs485Block (ProtocolBlock)
```

**Методы:**
```swift
// Обновление значений из кэша ZetaraManager
func updateValues() {
    // Module ID
    if let moduleIdData = ZetaraManager.shared.cachedModuleIdData {
        moduleIdBlock.setValue(moduleIdData.readableId())  // "ID 1"
    }

    // CAN
    if let canData = ZetaraManager.shared.cachedCANData {
        canBlock.setValue(canData.readableProtocol())  // "PYLON"
    }

    // RS485
    if let rs485Data = ZetaraManager.shared.cachedRS485Data {
        rs485Block.setValue(rs485Data.readableProtocol())  // "Generic"
    }
}
```

**ProtocolBlock:**
```swift
private class ProtocolBlock: UIView {
    private let titleLabel: UILabel   // "Selected ID"
    private let valueLabel: UILabel   // "ID 1"

    func setValue(_ value: String) {
        valueLabel.text = value
    }
}
```

**Визуализация:**
```
┌─────────────┬─────────────┬─────────────┐
│     ID 1    │    PYLON    │   Generic   │
│  Selected   │  Selected   │  Selected   │
│     ID      │     CAN     │    RS485    │
└─────────────┴─────────────┴─────────────┘
```

**Откуда берутся данные?**

Данные загружаются при подключении к устройству:

```swift
// ConnectivityViewController.swift:144-147
ZetaraManager.shared.connect(peripheral)
    .subscribe(onNext: { [weak self] connectedPeripheral in
        // Через 1.5 сек загружаем протоколы
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self?.loadProtocolsViaQueue()
        }
    })

func loadProtocolsViaQueue() {
    // Загружаем Module ID → CAN → RS485 через Request Queue
    ZetaraManager.shared.queuedRequest("getModuleId") {
        ZetaraManager.shared.getModuleId()
    }
    .subscribe(onSuccess: { data in
        ZetaraManager.shared.cachedModuleIdData = data  // ← Сохраняем в кэш
    })

    // Аналогично для CAN и RS485
}
```

---

### 6. TabsContainerView

**Файл:** `TabsContainerView.swift:18-282`

**Назначение:** Контейнер с 3 табами (Summary, Cell Voltage, Temperature).

**UI Structure:**
```
TabsContainerView
    └── innerContainer (белый фон с градиентом)
        ├── tabButtonsStackView (кнопки табов)
        │   ├── "Summary" Button
        │   ├── "Cell Voltage" Button
        │   └── "Temperature" Button
        └── tabContentContainer
            ├── SummaryTabView (скрыт/показан)
            ├── CellVoltageTabView (скрыт/показан)
            └── TemperatureTabView (скрыт/показан)
```

**Методы:**
```swift
// Активация таба
func activateTab(at index: Int) {
    // Обновляем кнопки
    for (i, button) in tabButtons.enumerated() {
        updateTabButtonAppearance(button, isActive: i == index)
    }

    // Показываем содержимое активного таба
    tabContents[index].isHidden = false
}

// Получение содержимого табов
func getSummaryTabView() -> SummaryTabView?
func getCellVoltageTabView() -> CellVoltageTabView?
func getTemperatureTabView() -> TemperatureTabView?
```

**Визуализация:**
```
┌─────────────────────────────────────────────┐
│ [Summary] [Cell Voltage] [Temperature]      │  ← Кнопки табов
├─────────────────────────────────────────────┤
│                                             │
│  ┌───────────────────────────────────────┐ │
│  │  Max. Voltage    Min. Voltage  ...    │ │
│  │     3.253V          3.213V            │ │
│  └───────────────────────────────────────┘ │  ← Активный таб (Summary)
│                                             │
│  ┌───────────────────────────────────────┐ │
│  │  Power           Int. Temp    ...     │ │
│  │   5.1W              75°F              │ │
│  └───────────────────────────────────────┘ │
│                                             │
└─────────────────────────────────────────────┘
```

---

### 7. SummaryTabView

**Файл:** `SummaryTabView.swift:11-357`

**Назначение:** Сводка из 6 параметров в виде сетки 3x2.

**UI Structure:**
```
SummaryTabView
    ├── maxVoltageView (ParameterView)
    ├── minVoltageView (ParameterView)
    ├── voltageDiffView (ParameterView)
    ├── powerView (ParameterView)
    ├── internalTempView (ParameterView)
    └── avgVoltageView (ParameterView)
```

**Методы:**
```swift
// Обновление всех параметров
func updateAllParameters(
    maxVoltage: Float,
    minVoltage: Float,
    voltageDiff: Float,
    power: Float,
    internalTemp: Int8,
    avgVoltage: Float,
    showDashes: Bool = false
)

// Обновление отдельных параметров
func updateMaxVoltage(_ value: Float)
func updateMinVoltage(_ value: Float)
// ...
```

**Визуализация:**
```
┌─────────────┬─────────────┬─────────────┐
│ ⚡ 3.253 V  │ ⚡ 3.213 V  │ ⚡ 0.040 V  │
│ Max.        │ Min.        │ Voltage     │
│ Voltage     │ Voltage     │ Dif.        │
├─────────────┼─────────────┼─────────────┤
│ ⚡ 5.1 W    │ 🌡 75° F    │ ⚡ 3.233 V  │
│ Power       │ Int. Temp.  │ Ave.        │
│             │             │ Voltage     │
└─────────────┴─────────────┴─────────────┘
```

**ParameterView:**
```swift
class ParameterView: UIView {
    private let iconImageView: UIImageView     // Иконка
    private let valueLabel: UILabel            // Значение (3.253 V)
    private let titleLabel: UILabel            // Название (Max. Voltage)

    func setup(title: String, subtitle: String, icon: UIImage?)
    func updateValue(_ value: String)
}
```

---

### 8. CellVoltageTabView

**Файл:** `CellVoltageTabView.swift:12-367`

**Назначение:** Отображение напряжения 16 ячеек в виде сетки 4x4.

**UI Structure:**
```
CellVoltageTabView
    └── collectionView (UICollectionView)
        ├── Cell 1 (3.25V)
        ├── Cell 2 (3.26V)
        ├── ...
        └── Cell 16 (3.25V)
```

**Методы:**
```swift
// Обновление напряжений ячеек
func updateCellVoltages(_ voltages: [Float], showDashes: Bool = false) {
    cellVoltages = voltages
    self.showDashes = showDashes
    collectionView.reloadData()
}
```

**CellVoltageCell:**
```swift
class CellVoltageCell: UICollectionViewCell {
    private let iconImageView: UIImageView     // Иконка батареи
    private let voltageLabel: UILabel          // Напряжение (3.25 V)
    private let cellNumberLabel: UILabel       // Номер ячейки (Cell 1)

    func configure(voltage: Float, cellNumber: Int)
    func configureDashes(cellNumber: Int)  // Для отображения прочерков
}
```

**Layout:**
```
4 ячейки в ряд:
┌──────┬──────┬──────┬──────┐
│ 🔋   │ 🔋   │ 🔋   │ 🔋   │
│3.25 V│3.26 V│3.25 V│3.24 V│
│Cell 1│Cell 2│Cell 3│Cell 4│
├──────┼──────┼──────┼──────┤
│ 🔋   │ 🔋   │ 🔋   │ 🔋   │
│3.25 V│3.26 V│3.25 V│3.24 V│
│Cell 5│Cell 6│Cell 7│Cell 8│
├──────┼──────┼──────┼──────┤
│ ...  │ ...  │ ...  │ ...  │
└──────┴──────┴──────┴──────┘
```

**Использование в HomeViewController:**
```swift
// Обновление данных
cellVoltageView?.updateCellVoltages(data.cellVoltages)

// Отображение прочерков (нет подключения)
cellVoltageView?.updateCellVoltages([], showDashes: true)
```

---

### 9. TemperatureTabView

**Файл:** `TemperatureTabView.swift:12-426`

**Назначение:** Отображение температуры 5 датчиков в виде списка.

**UI Structure:**
```
TemperatureTabView
    └── tableView (UITableView)
        ├── Section 0: Temp. Sensor #1 (PCB)
        ├── Section 1: Temp. Sensor #2 (Env)
        ├── Section 2: Temp. Sensor #3 (Cell 1)
        ├── Section 3: Temp. Sensor #4 (Cell 2)
        └── Section 4: Temp. Sensor #5 (Cell 3)
```

**Методы:**
```swift
// Обновление температур
func updateTemperatures(
    pcbTemp: Int8,
    envTemp: Int8,
    cellTemps: [Int8],
    showDashes: Bool = false
) {
    temperatures.removeAll()

    // Добавляем PCB температуру
    temperatures.append(TemperatureSensorData(
        name: "Temp. Sensor #1",
        fahrenheit: Int(pcbTemp.celsiusToFahrenheit()),
        celsius: Int(pcbTemp)
    ))

    // Добавляем Env температуру
    temperatures.append(...)

    // Добавляем Cell температуры
    for (index, temp) in cellTemps.enumerated() {
        temperatures.append(...)
    }

    tableView.reloadData()
}
```

**TemperatureSensorCell:**
```swift
class TemperatureSensorCell: UITableViewCell {
    private let iconImageView: UIImageView         // Иконка термометра
    private let nameLabel: UILabel                 // "Temp. Sensor #1"
    private let temperatureLabel: UILabel          // "75°F / 24°C"

    func configure(with data: TemperatureSensorData)
}
```

**Визуализация:**
```
┌──────────────────────────────────────────┐
│ 🌡 Temp. Sensor #1      75°F / 24°C     │
├──────────────────────────────────────────┤
│ 🌡 Temp. Sensor #2      75°F / 24°C     │
├──────────────────────────────────────────┤
│ 🌡 Temp. Sensor #3      75°F / 24°C     │
├──────────────────────────────────────────┤
│ 🌡 Temp. Sensor #4      75°F / 24°C     │
├──────────────────────────────────────────┤
│ 🌡 Temp. Sensor #5      75°F / 24°C     │
└──────────────────────────────────────────┘
```

---

### 10. TimerView

**Файл:** `TimerView.swift:12-80`

**Назначение:** Отображение времени последнего обновления данных.

**UI Structure:**
```
TimerView
    └── timeLabel ("Last Update: 2025/10/07 12:34:56")
```

**Методы:**
```swift
// Обновление времени
func updateTime(_ time: Date) {
    timeLabel.text = "Last Update: \(dateFormatter.string(from: time))"
}

// Скрытие/отображение
func setHidden(_ isHidden: Bool) {
    timeLabel.isHidden = isHidden
}
```

**Использование в HomeViewController:**
```swift
// Обновление времени при каждом updateUI
func updateUI(_ data: Zetara.Data.BMS) {
    timerView.updateTime(Date())  // ← Обновляем время
    // ...
}
```

**Визуализация:**
```
┌──────────────────────────────────────────┐
│  Last Update: 2025/10/07 12:34:56        │
└──────────────────────────────────────────┘
```

---

## ⚙️ CONFIGURATION И MOCK DATA

### Configuration структура

**Файл:** `Configuration.swift:10-48`

```swift
public struct Configuration {
    let identifiers: [Identifier]               // Bluetooth идентификаторы (v1, v2)
    let refreshBMSTimeInterval: TimeInterval    // Интервал обновления (5 сек)
    var mockData: Foundation.Data? = nil        // Мок-данные для отладки
    var mockSetModuleIdData: Foundation.Data?   // Мок-данные для установки Module ID
    var mockDeviceName: String? = nil           // Имя мок-устройства

    // Конфигурация по умолчанию
    public static let `default` = Configuration(
        identifiers: [.v2],
        refreshBMSTimeInterval: 4
    )
}
```

### Настройка в AppDelegate

**Файл:** `AppDelegate.swift:18-46`

```swift
func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    // Настраиваем конфигурацию ZetaraManager
    var mockDataForConfig: Foundation.Data? = nil
    var mockDeviceNameForConfig: String? = nil

    #if DEBUG
    // Включаем мок-данные только для отладочных сборок
    mockDataForConfig = Foundation.Data.mockCellTempsData
    mockDeviceNameForConfig = "Husky 2 (Mock)"
    #endif

    let config = Configuration(
        identifiers: [.v1, .v2],
        refreshBMSTimeInterval: 5,          // ← Интервал обновления 5 сек
        mockData: mockDataForConfig,        // ← Мок-данные для DEBUG
        mockDeviceName: mockDeviceNameForConfig
    )

    ZetaraManager.setup(config)

    return true
}
```

### Mock Data варианты

**Файл:** `Configuration.swift:85-98`

```swift
// 1. Нормальные данные
public static let mockNormalBMSData = Foundation.Data(hex:
    "01034e053200000cfe0cff0cff0d01000000000000000000000000000000000000000000000000000f00000010005d00640064005e00000000000000000003000015752a00101000000000000403e8000075da"
)

// 2. Данные при зарядке
public static let mockInChargingBMSData = Foundation.Data(hex:
    "01034E052D00690CEF0CEE0CED0CF300000000000000000000000000000000000000000000000000160016001500680000000000340001000000000000000100002AEA5400000000150015000407D00000F0C7"
)

// 3. Данные с 4 температурами
public static let mockCellTempsData = Foundation.Data(hex:
    "01034E0514FF6B0CB10CB40CB10CB200000000000000000000000000000000000000000000000000150015001B00650000000000330002000000000000000100002AEA5400E4E5E60004000407D0000000"
)
```

### Bluetooth Identifiers

**Файл:** `Configuration.swift:63-74`

```swift
extension Identifier {
    // Старая версия (v1)
    public static let v1 = Identifier(
        service: ZetaraService(uuidString: "1000"),
        writeCharacteristic: ZetaraCharacteristic(uuidString: "1001", service: .service1000),
        notifyCharacteristic: ZetaraCharacteristic(uuidString: "1002", service: .service1000)
    )

    // Новая версия (v2) ← Используется по умолчанию
    public static let v2 = Identifier(
        service: ZetaraService(uuidString: "1006"),
        writeCharacteristic: ZetaraCharacteristic(uuidString: "1008", service: .service1006),
        notifyCharacteristic: ZetaraCharacteristic(uuidString: "1007", service: .service1006)
    )
}
```

**Как работает Mock Data:**

```swift
// ZetaraManager.swift:448-454
func getBMSData() -> Maybe<Data.BMS> {
    // Проверяем наличие подключенного устройства
    let isDeviceConnected = (try? connectedPeripheralSubject.value()) != nil

    // Если НЕТ подключения и есть мок-данные → используем мок-данные
    if !isDeviceConnected, let mockBMSData = Self.configuration.mockData {
        print("!!! Используем мок-данные !!!")
        return Maybe.create { [weak self] observer in
            let bytes = [UInt8](mockBMSData)
            if let data = self?.bmsDataHandler.append(bytes) {
                observer(.success(data))
            }
            return Disposables.create {}
        }
    }

    // Если ЕСТЬ подключение → используем реальные данные
    // ...
}
```

**Преимущества Mock Data:**

✅ Разработка без физической батареи
✅ Тестирование разных сценариев (зарядка, разрядка)
✅ Отладка UI компонентов
✅ Демонстрация функционала

---

## 📊 ВИЗУАЛЬНЫЕ СХЕМЫ

### State Machine (Машина состояний)

```
                    ┌──────────────────┐
                    │   APP START      │
                    └────────┬─────────┘
                             ↓
                    ┌──────────────────┐
                    │  viewDidLoad()   │
                    │                  │
                    │ Mock Data: ON    │
                    │ Timer: NOT SET   │
                    └────────┬─────────┘
                             ↓
                  ┌──────────┴──────────┐
                  │                     │
          ┌───────▼────────┐    ┌──────▼────────┐
          │ Mock Data Mode │    │ Real Conn Mode│
          │                │    │                │
          │ Timer: ON ✅   │    │ Timer: OFF ❌ │
          │ Data: Mock     │    │ Wait Connect  │
          └───────┬────────┘    └──────┬────────┘
                  │                     │
                  │                     │
                  │             ┌───────▼────────┐
                  │             │ USER CONNECTS  │
                  │             │   DEVICE       │
                  │             └───────┬────────┘
                  │                     │
                  │             ┌───────▼────────┐
                  │             │ Timer: ON ✅   │
                  │             │ Data: Real     │
                  │             └───────┬────────┘
                  │                     │
          ┌───────▼──────────────────────▼────────┐
          │     DATA UPDATES (Every 5 sec)        │
          │                                       │
          │  getBMSData() → bmsDataSubject        │
          │      ↓                                │
          │  updateUI() → All Components          │
          └───────────────────────────────────────┘
```

### Data Flow (Поток данных) - Детальный

```
┌─────────────────────────────────────────────────────────────┐
│                    TIMER (Every 5 sec)                       │
│                                                              │
│  startRefreshBMSData() → Timer.scheduledTimer()             │
│                                                              │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ↓
┌─────────────────────────────────────────────────────────────┐
│                      getBMSData()                            │
│                                                              │
│  if NO connection && mockData exists:                       │
│     → Use Mock Data                                         │
│  else if connection exists:                                 │
│     → Request Real Data via Bluetooth                       │
│                                                              │
└────────────────────────────┬────────────────────────────────┘
                             │
                ┌────────────┴────────────┐
                ↓                         ↓
┌──────────────────────┐    ┌──────────────────────┐
│    MOCK DATA PATH    │    │   REAL DATA PATH     │
│                      │    │                      │
│ bytes = mockData     │    │ writeValue(cmd)      │
│    ↓                 │    │    ↓                 │
│ bmsDataHandler       │    │ observeValueUpdate() │
│ .append(bytes)       │    │    ↓                 │
│    ↓                 │    │ .crc16Verify() ✅    │
│ Data.BMS             │    │    ↓                 │
│                      │    │ bmsDataHandler       │
│                      │    │ .append(bytes)       │
│                      │    │    ↓                 │
│                      │    │ Data.BMS             │
└──────────┬───────────┘    └──────────┬───────────┘
           │                           │
           └───────────┬───────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│              bmsDataSubject.onNext(bmsData)                 │
│                                                              │
│  BehaviorSubject<Data.BMS> - RxSwift Observable             │
│                                                              │
└────────────────────────────┬────────────────────────────────┘
                             │
                             │ .subscribe { data in ... }
                             ↓
┌─────────────────────────────────────────────────────────────┐
│            HomeViewController.updateUI(data)                │
│                                                              │
│  if isDeviceActuallyConnected:                              │
│     → Show Real Data                                        │
│  else:                                                       │
│     → Show Dashes ("-- V", "-- A")                          │
│                                                              │
└────────────────────────────┬────────────────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        ↓                    ↓                    ↓
┌───────────────┐  ┌────────────────┐  ┌────────────────┐
│BatteryProgress│  │BatteryParameters│  │TabsContainer   │
│     View      │  │      View       │  │    View        │
│               │  │                 │  │                │
│level = 0.87   │  │V: 53.35V        │  │Summary Tab     │
│status =       │  │A: 0.35A         │  │CellVolt Tab    │
│ charging      │  │T: 24°C/75°F     │  │Temp Tab        │
└───────────────┘  └────────────────┘  └────────────────┘
```

### UI Hierarchy (Иерархия UI)

```
UIViewController (HomeViewController)
    │
    ├── view (UIView)
    │   │
    │   ├── backgroundImageView (фон)
    │   │
    │   ├── headerLogoView (шапка с логотипом)
    │   │
    │   └── scrollView (UIScrollView)
    │       │
    │       └── contentStackView (UIStackView, vertical, spacing: 16)
    │           │
    │           ├── bluetoothConnectionContainer
    │           │   └── BluetoothConnectionView
    │           │       ├── bluetoothImageView
    │           │       ├── deviceNameLabel
    │           │       └── addButton
    │           │
    │           ├── batteryContainer
    │           │   └── BatteryProgressView (350x350)
    │           │       ├── outerCircleLayer (CAShapeLayer)
    │           │       ├── progressLayer (CAShapeLayer)
    │           │       ├── huskyImageView
    │           │       ├── percentLabelContainer
    │           │       │   └── percentLabel
    │           │       ├── minLabel
    │           │       └── maxLabel
    │           │
    │           ├── batteryStatusContainer
    │           │   └── BatteryStatusView
    │           │       └── containerView
    │           │           └── statusLabel
    │           │
    │           ├── componentsContainer (height: 80)
    │           │   └── BatteryParametersView
    │           │       └── stackView (horizontal)
    │           │           ├── voltageComponentView
    │           │           ├── currentComponentView
    │           │           └── temperatureComponentView
    │           │
    │           ├── protocolsContainer (height: 86)
    │           │   └── ProtocolParametersView
    │           │       └── stackView (horizontal)
    │           │           ├── moduleIdBlock
    │           │           ├── canBlock
    │           │           └── rs485Block
    │           │
    │           ├── tabsContainer (height: 330)
    │           │   └── TabsContainerView
    │           │       ├── innerContainer
    │           │       │   ├── gradientView
    │           │       │   ├── tabButtonsStackView (horizontal)
    │           │       │   │   ├── "Summary" Button
    │           │       │   │   ├── "Cell Voltage" Button
    │           │       │   │   └── "Temperature" Button
    │           │       │   └── tabContentContainer
    │           │       │       ├── SummaryTabView
    │           │       │       │   ├── maxVoltageView
    │           │       │       │   ├── minVoltageView
    │           │       │       │   ├── voltageDiffView
    │           │       │       │   ├── powerView
    │           │       │       │   ├── internalTempView
    │           │       │       │   └── avgVoltageView
    │           │       │       │
    │           │       │       ├── CellVoltageTabView
    │           │       │       │   └── collectionView
    │           │       │       │       ├── Cell 1
    │           │       │       │       ├── Cell 2
    │           │       │       │       ├── ...
    │           │       │       │       └── Cell 16
    │           │       │       │
    │           │       │       └── TemperatureTabView
    │           │       │           └── tableView
    │           │       │               ├── Sensor 1 (PCB)
    │           │       │               ├── Sensor 2 (Env)
    │           │       │               ├── Sensor 3 (Cell 1)
    │           │       │               ├── Sensor 4 (Cell 2)
    │           │       │               └── Sensor 5 (Cell 3)
    │           │
    │           └── timerContainer
    │               └── TimerView
    │                   └── timeLabel
```

---

## ❓ FAQ И ПРИМЕРЫ

### Вопрос 1: Как работает обновление в реальном времени?

**Ответ:**

Обновление работает через Timer в ZetaraManager:

```swift
// 1. При подключении устройства запускается Timer
ZetaraManager.shared.connect(peripheral)
    .subscribe(onNext: {
        self.startRefreshBMSData()  // ← Запуск Timer
    })

// 2. Timer срабатывает каждые 5 секунд
func startRefreshBMSData() {
    self.timer = Timer.scheduledTimer(
        withTimeInterval: 5.0,  // ← Интервал
        repeats: true
    ) { [weak self] _ in
        self?.getBMSData()      // ← Запрос данных
    }
    self.timer?.fire()          // ← Первое обновление немедленно
}

// 3. Данные передаются через RxSwift Observable
getBMSData()
    .subscribe(onSuccess: { data in
        self.bmsDataSubject.onNext(data)  // ← Отправка данных
    })

// 4. HomeViewController получает данные и обновляет UI
ZetaraManager.shared.bmsDataSubject
    .subscribe { [weak self] data in
        self?.updateUI(data)  // ← Обновление UI
    }
```

**Итого:**
- Каждые **5 секунд** → getBMSData() → updateUI()
- Первое обновление **немедленно** через `.fire()`
- При отключении → Timer останавливается

---

### Вопрос 2: Что происходит при потере подключения?

**Ответ:**

При потере подключения автоматически запускается цепочка очистки:

```swift
// 1. Connection Monitor обнаруживает потерю (каждые 2 сек)
func verifyConnectionState() {
    if currentState != .connected {
        print("[CONNECTION] ⚠️ Phantom connection detected!")
        cleanConnection()  // ← Очистка
    }
}

// 2. cleanConnection() останавливает все процессы
func cleanConnection() {
    // Останавливаем мониторинг
    stopConnectionMonitor()

    // Останавливаем Timer обновления данных
    timer?.invalidate()
    timer = nil

    // Очищаем кэш протоколов
    cachedModuleIdData = nil
    cachedRS485Data = nil
    cachedCANData = nil

    // Очищаем Request Queue
    lastRequestTime = nil

    // Отправляем nil в connectedPeripheralSubject
    connectedPeripheralSubject.onNext(nil)
}

// 3. HomeViewController получает nil и обновляет UI
ZetaraManager.shared.connectedPeripheralSubject
    .subscribe { [weak self] peripheral in
        if peripheral == nil {
            // Показываем прочерки
            self?.batteryParametersView.updateVoltage("-- V")
            self?.batteryParametersView.updateCurrent("-- A")
            // ...
        }
    }
```

**Что происходит с UI:**
- ✅ Все значения заменяются на прочерки: "-- V", "-- A", "-- °C"
- ✅ BluetoothConnectionView показывает "Tap to Connect"
- ✅ TimerView скрывается
- ✅ Battery level = 0%
- ✅ Status = Standby

---

### Вопрос 3: Как работает Request Queue?

**Ответ:**

Request Queue обеспечивает последовательность запросов с минимальным интервалом 500ms:

**Пример использования:**
```swift
// На Settings экране загружаем 3 протокола подряд:

// 1. Module ID
ZetaraManager.shared.queuedRequest("getModuleId") {
    ZetaraManager.shared.getModuleId()
}
.subscribe(onSuccess: { data in
    // Обработка Module ID
})

// 2. RS485 (автоматически ждет 500ms после Module ID)
ZetaraManager.shared.queuedRequest("getRS485") {
    ZetaraManager.shared.getRS485()
}
.subscribe(onSuccess: { data in
    // Обработка RS485
})

// 3. CAN (автоматически ждет 500ms после RS485)
ZetaraManager.shared.queuedRequest("getCAN") {
    ZetaraManager.shared.getCAN()
}
.subscribe(onSuccess: { data in
    // Обработка CAN
})
```

**Что происходит:**
```
T=0ms:     [QUEUE] 📥 Request queued: getModuleId
T=0ms:     [QUEUE] 🚀 Executing getModuleId
T=320ms:   [QUEUE] ✅ getModuleId completed in 320ms

T=320ms:   [QUEUE] 📥 Request queued: getRS485
T=500ms:   [QUEUE] ⏳ Waiting 180ms before getRS485  ← Ждем до 500ms
T=500ms:   [QUEUE] 🚀 Executing getRS485
T=820ms:   [QUEUE] ✅ getRS485 completed in 320ms

T=820ms:   [QUEUE] 📥 Request queued: getCAN
T=1000ms:  [QUEUE] ⏳ Waiting 180ms before getCAN  ← Ждем до 500ms
T=1000ms:  [QUEUE] 🚀 Executing getCAN
T=1320ms:  [QUEUE] ✅ getCAN completed in 320ms
```

**Почему это важно:**
- ❌ Без Queue: Bluetooth может не справиться с множеством запросов
- ✅ С Queue: Гарантированная последовательность и интервалы

---

### Вопрос 4: Как использовать Mock Data для тестирования?

**Ответ:**

Mock Data автоматически активируются в DEBUG сборках:

**Настройка в AppDelegate:**
```swift
var mockDataForConfig: Foundation.Data? = nil

#if DEBUG
// Включаем мок-данные только для отладочных сборок
mockDataForConfig = Foundation.Data.mockCellTempsData
#endif

let config = Configuration(
    identifiers: [.v1, .v2],
    refreshBMSTimeInterval: 5,
    mockData: mockDataForConfig
)

ZetaraManager.setup(config)
```

**Выбор Mock Data:**
```swift
// Вариант 1: Нормальные данные
mockDataForConfig = Foundation.Data.mockNormalBMSData

// Вариант 2: Данные при зарядке
mockDataForConfig = Foundation.Data.mockInChargingBMSData

// Вариант 3: Данные с температурами
mockDataForConfig = Foundation.Data.mockCellTempsData
```

**Как это работает:**
```swift
func getBMSData() -> Maybe<Data.BMS> {
    // Проверяем наличие подключенного устройства
    let isDeviceConnected = ...

    // Если НЕТ подключения → используем Mock Data
    if !isDeviceConnected, let mockBMSData = Self.configuration.mockData {
        return Maybe.create { observer in
            let bytes = [UInt8](mockBMSData)
            if let data = self.bmsDataHandler.append(bytes) {
                observer(.success(data))  // ← Отправляем мок-данные
            }
        }
    }

    // Если ЕСТЬ подключение → используем реальные данные
    // ...
}
```

**Преимущества:**
- ✅ Разработка без физической батареи
- ✅ Тестирование разных сценариев (зарядка, разрядка, защита)
- ✅ Отладка UI компонентов
- ✅ Демонстрация функционала

**Отключение Mock Data:**
```swift
#if RELEASE
// Для релизных сборок мок-данные отключены
mockDataForConfig = nil
#endif
```

---

### Вопрос 5: Как добавить новый UI компонент на главный экран?

**Ответ:**

**Шаг 1: Создать новый компонент**
```swift
// NewComponentView.swift
class NewComponentView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    private func setupView() {
        // Настройка UI
    }

    func updateData(_ data: String) {
        // Обновление данных
    }
}
```

**Шаг 2: Добавить в HomeViewController**
```swift
// Свойство для компонента
private var newComponentView: NewComponentView!

// В setupHeaderView():
let newContainer = UIView()
contentStackView.addArrangedSubview(newContainer)

newComponentView = NewComponentView()
newComponentView.translatesAutoresizingMaskIntoConstraints = false
newContainer.addSubview(newComponentView)

newComponentView.snp.makeConstraints { make in
    make.edges.equalToSuperview()
}
```

**Шаг 3: Обновление в updateUI()**
```swift
func updateUI(_ data: Zetara.Data.BMS) {
    // ...

    // Обновляем новый компонент
    if isDeviceActuallyConnected {
        newComponentView.updateData("\(data.voltage)V")
    } else {
        newComponentView.updateData("-- V")
    }
}
```

**Готово!** Компонент будет автоматически обновляться каждые 5 секунд.

---

### Вопрос 6: Можно ли изменить интервал обновления данных?

**Ответ:**

Да, интервал настраивается в AppDelegate:

**Изменение интервала:**
```swift
// AppDelegate.swift
let config = Configuration(
    identifiers: [.v1, .v2],
    refreshBMSTimeInterval: 3,  // ← Меняем на 3 секунды (было 5)
    mockData: mockDataForConfig
)

ZetaraManager.setup(config)
```

**Рекомендации:**
- ⚡ **1-2 секунды:** Очень быстрое обновление, может нагружать батарею
- ✅ **3-5 секунд:** Оптимальный баланс (используется по умолчанию)
- 🐌 **10+ секунд:** Медленное обновление, данные могут устаревать

**Влияние на производительность:**
```
Интервал 1 сек:
  → 60 запросов в минуту
  → Высокая нагрузка на Bluetooth
  → Быстрее разряжается батарея устройства

Интервал 5 сек:
  → 12 запросов в минуту ✅
  → Оптимальная нагрузка на Bluetooth
  → Экономия энергии

Интервал 10 сек:
  → 6 запросов в минуту
  → Минимальная нагрузка
  → Данные могут устаревать
```

---

## 📁 СВЯЗАННЫЕ ФАЙЛЫ

### Главный контроллер

| Файл | Строки | Описание |
|------|--------|----------|
| **HomeViewController.swift** | 653 | Главный контроллер Home экрана |
| ├─ viewDidLoad | 92-130 | Инициализация, подписки на RxSwift |
| ├─ setupHeaderView | 202-459 | Создание всей структуры UI |
| ├─ setupObservers | 133-166 | RxSwift подписки на данные |
| ├─ updateUI | 461-590 | **ГЛАВНЫЙ МЕТОД** - обновление всех компонентов |
| ├─ updateTitle | 175-199 | Обновление имени устройства |
| └─ handleBluetoothConnectionTap | 168-172 | Переход на экран подключения |

### Bluetooth Manager

| Файл | Строки | Описание |
|------|--------|----------|
| **ZetaraManager.swift** | 643 | Менеджер Bluetooth коммуникации |
| ├─ init | 80-106 | Инициализация, подписки на AppDelegate events |
| ├─ setup | 112-123 | Настройка конфигурации |
| ├─ connect | 183-239 | Подключение к устройству |
| ├─ disconnect | 241-243 | Отключение от устройства |
| ├─ observeDisconnect | 279-293 | Отслеживание отключения |
| ├─ cleanConnection | 254-277 | **КРИТИЧНО** - очистка всех ресурсов |
| ├─ queuedRequest | 302-346 | **Request Queue** - очередь запросов (500ms) |
| ├─ startConnectionMonitor | 351-366 | Запуск мониторинга подключения (2 сек) |
| ├─ stopConnectionMonitor | 369-376 | Остановка мониторинга |
| ├─ verifyConnectionState | 379-399 | **КРИТИЧНО** - проверка phantom connections |
| ├─ isCacheValidForCurrentDevice | 402-409 | Проверка валидности кэша |
| ├─ startRefreshBMSData | 414-427 | **ЗАПУСК TIMER** - обновление каждые 5 сек |
| ├─ pauseRefreshBMSData | 429-432 | Остановка Timer (background) |
| ├─ resumeRefreshBMSData | 434-439 | Возобновление Timer (foreground) |
| ├─ getBMSData | 442-545 | **ГЛАВНЫЙ МЕТОД** - получение данных BMS |
| ├─ getModuleId | 547-549 | Получение Module ID |
| ├─ setModuleId | 551-555 | Установка Module ID |
| ├─ getRS485 | 557-559 | Получение RS485 протокола |
| ├─ setRS485 | 561-564 | Установка RS485 протокола |
| ├─ getCAN | 566-574 | Получение CAN протокола |
| ├─ setCAN | 576-579 | Установка CAN протокола |
| └─ writeControlData | 582-621 | Запись команды через Bluetooth |

### Структуры данных

| Файл | Строки | Описание |
|------|--------|----------|
| **Data.swift** | 296 | Структуры данных BMS |
| ├─ BMS | 12-141 | **ГЛАВНАЯ СТРУКТУРА** данных BMS |
| │  ├─ Index | 13-26 | Индексы полей в байтовом массиве |
| │  ├─ Constant | 28-31 | Константы (normalCellCount = 16) |
| │  ├─ FunctionCode | 33-51 | Функциональные коды (0x03, 0x04, 0x10) |
| │  ├─ Status | 53-84 | Статусы батареи (charging, discharging, etc.) |
| │  └─ init | 106-140 | Парсинг байтового массива в структуру |
| ├─ BMSDataHandler | 143-198 | Обработчик фрагментированных данных |
| │  ├─ append | 146-193 | Накопление фрагментов (frames) |
| │  └─ reset | 195-197 | Очистка временного хранилища |
| └─ Array extensions | 243-295 | Утилиты для работы с байтами |

| Файл | Строки | Описание |
|------|--------|----------|
| **ControlData.swift** | 204 | Структуры данных протоколов |
| ├─ ModuleIdControlData | 69-102 | Данные Module ID (1-16) |
| │  ├─ supportedIds | 72 | Array(1...16) |
| │  ├─ readableIds | 87-89 | ["ID 1", ..., "ID 16"] |
| │  ├─ readableId | 91-93 | "ID X" текущий |
| │  └─ **otherProtocolsEnabled** | 99-101 | **ЯДРО ЛОГИКИ** - moduleId == 1 |
| ├─ RS485ControlData | 104-139 | Данные RS485 протокола |
| │  ├─ readableProtocol | 123-125 | Текущий протокол |
| │  └─ readableProtocols | 136-138 | Список протоколов |
| ├─ CANControlData | 141-175 | Данные CAN протокола |
| │  ├─ readableProtocol | 159-161 | Текущий протокол |
| │  └─ readableProtocols | 172-174 | Список протоколов |
| └─ parseProtocols | 177-193 | Парсинг списка протоколов |

### UI Компоненты

| Файл | Строки | Описание |
|------|--------|----------|
| **BluetoothConnectionView.swift** | 137 | Плашка подключения Bluetooth |
| ├─ updateDeviceName | 133-135 | Обновление имени устройства |
| └─ onTap | 18 | Обработчик нажатия |

| Файл | Строки | Описание |
|------|--------|----------|
| **BatteryProgressView.swift** | 250 | Круговая диаграмма заряда |
| ├─ level | 78-86 | Установка уровня заряда (0.0-1.0) |
| ├─ updateProgress | 216-242 | Обновление прогресса с анимацией |
| └─ progressColor | 89-97 | Цвет прогресса (красный/оранжевый/зеленый) |

| Файл | Строки | Описание |
|------|--------|----------|
| **BatteryStatusView.swift** | 126 | Текстовый индикатор статуса |
| ├─ updateStatus | 106-110 | Обновление статуса |
| ├─ updateStatusAnimated | 114-124 | Обновление с анимацией |
| └─ updateStatusStyle | 76-100 | Обновление цветов фона |

| Файл | Строки | Описание |
|------|--------|----------|
| **BatteryParametersView.swift** | 151 | Напряжение, ток, температура |
| ├─ updateVoltage | 93-95 | Обновление напряжения |
| ├─ updateCurrent | 99-101 | Обновление тока |
| ├─ updateTemperature | 105-107 | Обновление температуры |
| └─ updateAllParameters | 114-118 | Обновление всех параметров |

| Файл | Строки | Описание |
|------|--------|----------|
| **ProtocolParametersView.swift** | 163 | Module ID, CAN, RS485 |
| ├─ updateValues | 58-90 | **Обновление из кэша ZetaraManager** |
| └─ ProtocolBlock | 96-162 | Блок для одного протокола |

| Файл | Строки | Описание |
|------|--------|----------|
| **TabsContainerView.swift** | 282 | Контейнер с табами |
| ├─ activateTab | 193-214 | Активация таба |
| ├─ getSummaryTabView | 225-227 | Получение Summary таба |
| ├─ getCellVoltageTabView | 231-233 | Получение CellVoltage таба |
| └─ getTemperatureTabView | 237-239 | Получение Temperature таба |

| Файл | Строки | Описание |
|------|--------|----------|
| **SummaryTabView.swift** | 357 | Сводка параметров (6 блоков) |
| ├─ updateAllParameters | 173-193 | Обновление всех параметров |
| ├─ ParameterView | 228-356 | Блок для одного параметра |
| └─ setup | 310-350 | Настройка блока (icon, title, value) |

| Файл | Строки | Описание |
|------|--------|----------|
| **CellVoltageTabView.swift** | 367 | Напряжения 16 ячеек (сетка 4x4) |
| ├─ updateCellVoltages | 121-128 | Обновление напряжений |
| ├─ CellVoltageCell | 190-366 | Ячейка коллекции |
| ├─ configure | 345-355 | Настройка ячейки |
| └─ configureDashes | 359-365 | Настройка с прочерками |

| Файл | Строки | Описание |
|------|--------|----------|
| **TemperatureTabView.swift** | 426 | Температуры 5 датчиков (список) |
| ├─ updateTemperatures | 118-175 | Обновление температур |
| ├─ TemperatureSensorCell | 261-425 | Ячейка таблицы |
| └─ configure | 412-424 | Настройка ячейки |

| Файл | Строки | Описание |
|------|--------|----------|
| **TimerView.swift** | 80 | Время последнего обновления |
| ├─ updateTime | 64-66 | Обновление времени |
| └─ setHidden | 76-78 | Скрытие/отображение |

| Файл | Строки | Описание |
|------|--------|----------|
| **HeaderLogoView.swift** | ~100 | Шапка с логотипом |

| Файл | Строки | Описание |
|------|--------|----------|
| **ComponentView.swift** | ~150 | Переиспользуемый компонент для параметров |

### Configuration

| Файл | Строки | Описание |
|------|--------|----------|
| **Configuration.swift** | 99 | Конфигурация приложения |
| ├─ Configuration struct | 10-48 | Структура конфигурации |
| ├─ default | 29 | Конфигурация по умолчанию |
| ├─ Identifier.v1 | 64-66 | Старая версия Bluetooth |
| ├─ Identifier.v2 | 67-69 | Новая версия Bluetooth (используется) |
| ├─ mockNormalBMSData | 88 | Мок-данные: нормальные |
| ├─ mockInChargingBMSData | 91 | Мок-данные: зарядка |
| └─ mockCellTempsData | 94 | Мок-данные: температуры |

| Файл | Строки | Описание |
|------|--------|----------|
| **AppDelegate.swift** | 92 | Инициализация приложения |
| ├─ didFinishLaunchingWithOptions | 18-46 | Настройка ZetaraManager |
| └─ setup Configuration | 32-42 | **Настройка Mock Data и интервала** |

### Extensions

| Файл | Строки | Описание |
|------|--------|----------|
| **Extensions.swift** | 126 | Утилиты для работы с данными |
| ├─ Array(hex:) | 12-49 | Парсинг hex строки в байты |
| ├─ toHexString() | 51-59 | Байты в hex строку |
| ├─ crc16Verify() | 74-95 | Проверка CRC16 |
| └─ crc16() | 97-123 | Вычисление CRC16 |

### Connectivity (подключение)

| Файл | Строки | Описание |
|------|--------|----------|
| **ConnectivityViewController.swift** | ~300 | Экран подключения к устройству |
| ├─ viewDidLoad | 41-102 | Настройка UI и подписок |
| ├─ didSelectRowAt | 122-158 | Подключение к выбранному устройству |
| └─ loadProtocolsViaQueue | 144-147 | **Загрузка протоколов после подключения** |

---

## 🔧 ТЕХНИЧЕСКАЯ СПРАВКА

### RxSwift Subjects

**BehaviorSubject:**
```swift
public var bmsDataSubject = BehaviorSubject<Data.BMS>(value: Data.BMS())
```

- Хранит последнее значение
- Новые подписчики получают последнее значение немедленно
- Используется для real-time данных BMS

**Subscription lifecycle:**
```swift
// Подписка
ZetaraManager.shared.bmsDataSubject
    .subscribe { data in
        // Обработка данных
    }
    .disposed(by: disposeBag)  // ← Автоматическая очистка

// Отправка новых данных
bmsDataSubject.onNext(newData)  // ← Все подписчики получают
```

### SnapKit Constraints

**Пример:**
```swift
view.snp.makeConstraints { make in
    make.top.equalTo(headerLogoView.bottomAnchor)
    make.leading.trailing.equalToSuperview()
    make.bottom.equalToSuperview()
}
```

**Модификация:**
```swift
view.snp.remakeConstraints { make in
    // Пересоздать все constraints
}

view.snp.updateConstraints { make in
    // Обновить существующие constraints
}
```

### Bluetooth Protocol

**Service и Characteristics:**
```
Service UUID: 1006
├── Write Characteristic: 1008 (команды к BMS)
└── Notify Characteristic: 1007 (данные от BMS)
```

**Пример команды:**
```swift
// Получение данных BMS
let data = Foundation.Data(hex: "01030000002705d0")
//                         ││││││││││└└─ CRC16
//                         ││││└└─ Length (39 bytes)
//                         ││└└─ Start address (0x0000)
//                         │└─ Function code (0x03)
//                         └─ Device address (0x01)

peripheral.writeValue(data, for: writeCharacteristic, type: .withResponse)
```

### Memory Management

**Weak Self:**
```swift
ZetaraManager.shared.bmsDataSubject
    .subscribe { [weak self] data in
        self?.updateUI(data)  // ← Предотвращает retain cycle
    }
```

**Dispose Bags:**
```swift
var disposeBag = DisposeBag()

// При viewWillDisappear:
override func viewWillDisappear(_ animated: Bool) {
    disposeBag = DisposeBag()  // ← Отменяет все подписки
}
```

---

## 📝 CHANGELOG

### Версия 1.0 (07.10.2025)
- Создана первая версия документации
- Добавлены все основные секции
- Детальный анализ кода с номерами строк
- Визуальные схемы и диаграммы
- FAQ и примеры использования
- Полное описание 10 UI компонентов
- Документация Request Queue и Connection Monitor
- Описание Mock Data и Configuration

---

## 🎯 СЛЕДУЮЩИЕ ШАГИ

Для разработчиков:

1. **При добавлении нового UI компонента:**
   - Создать новый компонент в `BatteryMonitorBL/Views/`
   - Добавить в `setupHeaderView()` в HomeViewController
   - Обновить в `updateUI()` для real-time обновления
   - Обновить эту документацию!

2. **При изменении интервала обновления:**
   - Изменить `refreshBMSTimeInterval` в AppDelegate
   - Проверить влияние на производительность
   - Тестировать на реальном устройстве

3. **При рефакторинге:**
   - Сохранить структуру RxSwift подписок
   - Обновить номера строк в документации
   - Проверить все цепочки вызовов
   - Тестировать с Mock Data и реальным устройством

4. **При добавлении новых параметров BMS:**
   - Обновить `Data.BMS` структуру в `Data.swift`
   - Добавить парсинг в `init(_ bytes: [UInt8])`
   - Обновить `updateUI()` в HomeViewController
   - Создать/обновить UI компонент для отображения

---

**Конец документа**

Эта документация должна избавить от необходимости каждый раз анализировать код для понимания логики Home экрана!
