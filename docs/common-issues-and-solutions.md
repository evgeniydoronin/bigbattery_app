# Common Issues and Solutions

База знаний типичных ошибок iOS/RxSwift и их решений для BigBattery проекта.

**Цель:** Перестать повторять одни и те же ошибки. Перед началом работы ВСЕГДА проверяй эту базу.

---

## Категории проблем:

1. [Threading Errors](#1-threading-errors)
2. [DisposeBag Issues](#2-disposebag-issues)
3. [Timeout Issues](#3-timeout-issues)
4. [Bluetooth Connection Issues](#4-bluetooth-connection-issues)
5. [Protocol Save Issues](#5-protocol-save-issues)
6. [Alert/UI Update Issues](#6-alertui-update-issues)
7. [BMS Timer Timing Issues](#7-bms-timer-timing-issues)

---

## 1. Threading Errors

### 🔴 Симптомы:

**Runtime crash:**
```
Thread 6: "Modifications to the layout engine must not be performed from a background thread after it has been accessed from the main thread."
```

**Когда возникает:**
- При клике на кнопку Save
- При обновлении UI из RxSwift callback
- При вызове `Alert.show()` или `Alert.hide()` из background thread

**Где искать в логах:**
- Crash происходит сразу при попытке update UI
- Thread number ≠ 1 (main thread)

### ⚙️ Root Cause:

RxSwift `.subscribe()` callbacks выполняются на том же thread, что и Observable.

**Если Observable работает на background thread → callback тоже на background thread.**

**Пример проблемного кода:**
```swift
ZetaraManager.shared.queuedRequest("setModuleId") {
    ZetaraManager.shared.setModuleId(moduleNumber)
}
.subscribe(  // ❌ NO .observe(on:) - callback runs on background thread!
    onSuccess: { [weak self] success in
        // ❌ UI update on background thread!
        self?.moduleIdSettingItemView?.label = ...
        // ❌ Alert.hide() on background thread!
        completion?() // → calls Alert.hide()
    }
)
```

**Почему это crash:**
- `queuedRequest()` returns Maybe on background thread
- `.subscribe()` callback executes on same thread
- Callback updates UI (`label`, `Alert.hide()`)
- iOS forbids UI updates from background threads → CRASH

### ✅ Решение:

**Добавить `.observe(on: MainScheduler.instance)` ПЕРЕД `.subscribe()`**

```swift
ZetaraManager.shared.queuedRequest("setModuleId") {
    ZetaraManager.shared.setModuleId(moduleNumber)
}
.observe(on: MainScheduler.instance)  // ✅ Force callbacks to main thread
.subscribe(
    onSuccess: { [weak self] success in
        // ✅ Now executes on main thread - safe for UI updates
        self?.moduleIdSettingItemView?.label = ...
        completion?()  // ✅ Alert.hide() now on main thread
    }
)
```

### 📋 Checklist для проверки:

Перед коммитом проверь ВСЕ `.subscribe()` вызовы:

- [ ] Есть ли `.observe(on: MainScheduler.instance)` перед `.subscribe()`?
- [ ] Обновляется ли UI внутри callback? (labels, buttons, alerts)
- [ ] Вызываются ли completion handlers, которые могут update UI?
- [ ] Если ДА на любой из вопросов → ОБЯЗАТЕЛЬНО `.observe(on:)`!

### 📚 Где применять:

**Файл:** `BatteryMonitorBL/SettingsViewController.swift`

**Методы, которые УЖЕ исправлены:**
- `setModuleId()` - line 915
- `setRS485()` - line 949
- `setCAN()` - line 982
- `setupDisconnectHandler()` - line 770

**Проверь аналогичные паттерны в:**
- Любые `.subscribe()` после `queuedRequest()`
- Любые `.subscribe()` с UI updates
- Любые `.subscribe()` с `Alert.show/hide()`

### 🔗 Related Fixes:

- `docs/fix-history/2025-10-10_protocol-save-and-crash-bug.md` (ADDITIONAL FIX section)
- `docs/fix-history/2025-10-13_double-main-thread-dispatch-crash.md` (Double dispatch pattern)

---

### 🔴 Проблема 2: Double Main Thread Dispatch

**Симптомы:**
- App crashes when handling disconnect/UI events
- Crash occurs даже если `.observe(on: MainScheduler.instance)` используется
- Delay между event и UI update
- No crash logs visible (crash happens before UI can respond)

**Когда возникает:**
- При disconnect battery после save
- При любом RxSwift callback с UI operations
- Когда используется `.observe(on:)` + `DispatchQueue.main.async`

**Crash message:**
```
Thread 6: Signal SIGABRT
или просто app crash без detailed message
```

### ⚙️ Root Cause:

**Комбинирование `.observe(on: MainScheduler.instance)` с `DispatchQueue.main.async`:**

```swift
// ❌ НЕПРАВИЛЬНО - двойной dispatch на main thread
ZetaraManager.shared.connectedPeripheralSubject
    .observe(on: MainScheduler.instance)  // ← Callback УЖЕ на main thread
    .subscribe(onNext: {
        DispatchQueue.main.async {  // ← ВТОРОЙ dispatch на main!
            Alert.hide()
            self?.showAlert()
        }
    })
```

**Почему это breaks:**
1. `.observe(on: MainScheduler.instance)` гарантирует callback на main thread ✅
2. `DispatchQueue.main.async` добавляет ВТОРОЙ dispatch в main queue ❌
3. Создается **delay** между event и action
4. За этот delay app может войти в invalid state
5. UI operations выполняются в неправильном порядке → CRASH

**Пример из реального кода:**

```swift
// ❌ BEFORE (BROKEN):
private func setupDisconnectHandler() {
    disconnectHandlerDisposable = ZetaraManager.shared.connectedPeripheralSubject
        .subscribeOn(MainScheduler.instance)
        .observe(on: MainScheduler.instance)  // Already main thread!
        .filter { $0 == nil }
        .take(1)
        .subscribe(onNext: { [weak self] _ in
            DispatchQueue.main.async {  // ❌ Double dispatch!
                Alert.hide()
                self?.showBatteryRestartingMessage()
            }
        })
}
```

**What happens:**
- Battery disconnects → event fired
- `.observe(on:)` schedules callback on main thread (queue position: A)
- Inside callback: `DispatchQueue.main.async` schedules UI operations (queue position: B)
- Between A and B: other main thread operations can execute
- App may enter invalid state → UI operations fail → CRASH

### ✅ Решение:

**Remove `DispatchQueue.main.async` - оно не нужно!**

```swift
// ✅ ПРАВИЛЬНО
private func setupDisconnectHandler() {
    disconnectHandlerDisposable = ZetaraManager.shared.connectedPeripheralSubject
        .subscribeOn(MainScheduler.instance)
        .observe(on: MainScheduler.instance)
        .filter { $0 == nil }
        .take(1)
        .subscribe(onNext: { [weak self] _ in
            // Already on main thread - no dispatch needed!
            Alert.hide()
            self?.showBatteryRestartingMessage()
        })
}
```

**Why this works:**
- `.observe(on: MainScheduler.instance)` гарантирует main thread
- NO additional dispatch → NO delay
- UI operations execute immediately
- App stays in consistent state → NO CRASH

### 📋 Checklist для проверки:

Перед коммитом проверь ALL RxSwift subscriptions:

- [ ] Есть `.observe(on: MainScheduler.instance)` перед `.subscribe()`?
- [ ] Если ДА → NEVER use `DispatchQueue.main.async` inside callback!
- [ ] Если НЕТ `.observe(on:)` → THEN use `DispatchQueue.main.async` for UI
- [ ] Test disconnect/reconnect scenarios (не только happy path!)

**Rule of thumb:**

```swift
// Choose ONE, not BOTH:

// Option 1: Use .observe(on:)
.observe(on: MainScheduler.instance)
.subscribe(onNext: {
    Alert.hide()  // ✅ Direct call
})

// Option 2: Use DispatchQueue (if NO .observe(on:))
.subscribe(onNext: {
    DispatchQueue.main.async {
        Alert.hide()  // ✅ Manual dispatch
    }
})

// ❌ NEVER: .observe(on:) + DispatchQueue
.observe(on: MainScheduler.instance)
.subscribe(onNext: {
    DispatchQueue.main.async {  // ❌❌❌
        Alert.hide()
    }
})
```

### 📚 Где применять:

**Файл:** `BatteryMonitorBL/SettingsViewController.swift`

**Метод исправлен:**
- `setupDisconnectHandler()` - line 765-784

**Проверь аналогичные паттерны в:**
- Любые `.subscribe()` с `.observe(on:)` + UI operations
- Disconnect handlers
- Connection state observers
- Alert show/hide operations

### 🔗 Related Fixes:

- `docs/fix-history/2025-10-13_double-main-thread-dispatch-crash.md` - Full documentation
- `docs/fix-history/2025-10-10_protocol-save-and-crash-bug.md` - Original disconnect handler implementation

### ⚠️ Prevention:

**Code Review Checklist:**

When reviewing RxSwift code with UI operations:

1. Search for `.observe(on: MainScheduler.instance)`
2. For each occurrence, check inside `.subscribe()` callback
3. If found `DispatchQueue.main.async` → **RED FLAG!**
4. Remove redundant `DispatchQueue.main.async`
5. Add comment: `// Already on main thread thanks to .observe(on:)`

**Testing:**

- [ ] Test disconnect scenarios (not just save/reconnect)
- [ ] Test manual battery power off
- [ ] Test connection timeout
- [ ] Check diagnostic logs show proper event order
- [ ] Verify NO crashes on disconnect

---

## 2. DisposeBag Issues

### 🔴 Симптомы:

**Проблема 1: Phantom Connections**
```
[CONNECTION] ⚠️ PHANTOM: No peripheral but BMS timer running!
```

**Проблема 2: Memory Leaks**
- App becomes slower over time
- Memory usage grows
- Subscriptions never disposed

**Проблема 3: Multiple Subscriptions**
- Same data loaded multiple times
- Duplicate callbacks firing
- Race conditions

### ⚙️ Root Cause:

**DisposeBag НЕ отменяет subscriptions автоматически при пересоздании!**

**Проблемный паттерн:**

```swift
class MyViewController: UIViewController {
    var disposeBag = DisposeBag()  // Property

    override func viewWillAppear(_ animated: Bool) {
        // ❌ Каждый раз создаём НОВУЮ subscription
        someObservable
            .subscribe(onNext: { ... })
            .disposed(by: disposeBag)  // ← старая не отменилась!
    }
}
```

**Что происходит:**
- 1-й раз: subscription добавлена в disposeBag
- 2-й раз: НОВАЯ subscription добавлена, старая ВСЁ ЕЩЁ РАБОТАЕТ
- 3-й раз: Ещё одна subscription...
- Результат: N subscriptions работают одновременно!

### ✅ Решение 1: Пересоздать DisposeBag

**Когда использовать:** `viewWillDisappear()`, cleanup методы

```swift
override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    // ✅ Пересоздаём DisposeBag - отменяет ВСЕ subscriptions
    disposeBag = DisposeBag()
}
```

### ✅ Решение 2: Guard с флагом

**Когда использовать:** Subscriptions которые должны быть созданы ОДИН раз

```swift
private var hasSetupObservers = false

func setupObservers() {
    // ✅ Защита от дублирования
    guard !hasSetupObservers else {
        print("Observers already set up, skipping")
        return
    }

    hasSetupObservers = true

    // Setup subscriptions...
}
```

### ✅ Решение 3: takeUntil для auto-dispose

**Когда использовать:** Subscriptions привязанные к lifecycle

```swift
let viewWillDisappear = PublishSubject<Void>()

override func viewDidLoad() {
    someObservable
        .takeUntil(viewWillDisappear)  // ✅ Auto-dispose when view disappears
        .subscribe(onNext: { ... })
        .disposed(by: disposeBag)
}

override func viewWillDisappear(_ animated: Bool) {
    viewWillDisappear.onNext(())  // Trigger disposal
}
```

### 📋 Checklist для проверки:

- [ ] `viewWillDisappear()` пересоздаёт DisposeBag?
- [ ] Setup методы защищены guard флагом?
- [ ] Нет duplicate subscriptions при повторном открытии?
- [ ] Memory не растёт при многократном open/close?

### 📚 Где применять:

**Файлы:**
- `BatteryMonitorBL/SettingsViewController.swift` - line 359 (viewWillDisappear)
- `BatteryMonitorBL/ConnectivityViewController.swift` - line 110 (viewWillDisappear)
- `BatteryMonitorBL/SettingsViewController.swift` - line 341 (hasSetupObservers guard)

### 🔗 Related Fixes:

- `docs/fix-history/2025-10-08_timeout-fix-ATTEMPT2.md` (DisposeBag fixes)
- `docs/fix-history/2025-10-09_settings-direct-call-bug.md`

---

## 3. Timeout Issues

### 🔴 Симптомы:

**Проблема:** Requests hang forever, timeout не срабатывает

**Логи:**
```
[QUEUE] 🚀 Executing getModuleId
... (15 seconds pass)
... (nothing happens)
```

**Где проявляется:**
- Protocol requests hang
- Loading screen never disappears
- App appears frozen

### ⚙️ Root Cause:

**External timeout НЕ работает с RxSwift Maybe:**

```swift
// ❌ НЕПРАВИЛЬНО - external timeout
ZetaraManager.shared.getModuleId()
    .timeout(.seconds(3), scheduler: MainScheduler.instance)  // ← НЕ РАБОТАЕТ!
    .subscribe(...)
```

**Почему не работает:**
- Maybe completes after first emission
- Timeout operator ждёт completion
- Maybe уже completed → timeout никогда не fires

### ✅ Решение: Internal timeout внутри Observable

**Timeout MUST be INSIDE writeControlData:**

```swift
// ✅ ПРАВИЛЬНО - internal timeout
func writeControlData(_ data: Data) -> Observable<Data> {
    return Observable.create { observer in
        // Write data...

        // ✅ Internal timeout
        let timeoutTimer = DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            observer.onError(BluetoothError.timeout)
        }

        // Handle response...
        cancelTimer()
        observer.onNext(responseData)
        observer.onCompleted()

        return Disposables.create { cancelTimer() }
    }
}
```

### 📋 Checklist для проверки:

- [ ] Нет external `.timeout()` на Maybe/Observable?
- [ ] Timeout реализован INSIDE writeControlData/queuedRequest?
- [ ] Timeout value = 10 seconds (не 3, не 5)?
- [ ] Timeout properly cleaned up при успехе?

### 📚 Где применять:

**Файл:** `Zetara/Sources/ZetaraManager.swift`

**Методы:**
- `writeControlData()` - internal 10s timeout
- `queuedRequest()` - uses writeControlData timeout

**НЕ использовать external timeout в:**
- `getModuleId()`, `getRS485()`, `getCAN()`
- `setModuleId()`, `setRS485()`, `setCAN()`
- Любые вызовы через `queuedRequest()`

### 🔗 Related Fixes:

- `docs/fix-history/2025-10-08_timeout-fix-ATTEMPT2.md`
- `docs/fix-history/2025-10-10_protocol-save-and-crash-bug.md` (Lesson #3)

---

## 4. Bluetooth Connection Issues

### 🔴 Симптомы:

**Проблема 1: "INVALID DEVICE" после reconnect**
```
Alert: "Invalid device"
```

**Проблема 2: Reconnection fails after battery restart**

**Логи:**
```
[CONNECT] Attempting connection
[CONNECT] Cached UUID: <some-uuid>  ← Проблема!
... connection fails
```

### ⚙️ Root Cause:

**Stale Bluetooth state not cleared:**

```swift
// ❌ НЕПРАВИЛЬНО - не очищаем state
func cleanConnection() {
    connectedPeripheralSubject.onNext(nil)
    // ← cachedDeviceUUID NOT cleared!
    // ← writeCharacteristic NOT cleared!
    // ← notifyCharacteristic NOT cleared!
}
```

**Что происходит:**
- Battery restarts → UUID may change
- App still has old cachedDeviceUUID
- App tries to connect with stale UUID
- Connection fails → "INVALID DEVICE"

### ✅ Решение: Complete state cleanup

```swift
// ✅ ПРАВИЛЬНО - полная очистка state
func cleanConnection() {
    // Clear protocol data
    protocolDataManager.clearProtocols()

    // ✅ Reset ALL Bluetooth states
    writeCharacteristic = nil
    notifyCharacteristic = nil
    identifier = nil
    cachedDeviceUUID = nil  // ← Критично!

    connectedPeripheralSubject.onNext(nil)

    protocolDataManager.logProtocolEvent("[CONNECTION] All Bluetooth characteristics cleared")
    protocolDataManager.logProtocolEvent("[CONNECTION] Cached device UUID cleared")
}
```

### 📋 Checklist для проверки:

- [ ] `cleanConnection()` сбрасывает `cachedDeviceUUID = nil`?
- [ ] `cleanConnection()` сбрасывает `writeCharacteristic = nil`?
- [ ] `cleanConnection()` сбрасывает `notifyCharacteristic = nil`?
- [ ] `cleanConnection()` сбрасывает `identifier = nil`?
- [ ] Reconnection работает после battery restart?

### 📚 Где применять:

**Файл:** `Zetara/Sources/ZetaraManager.swift`

**Метод:** `cleanConnection()` - line ~350

**Когда вызывается:**
- Before new connection attempt (`connect()`)
- On disconnect
- On connection error

### 🔗 Related Fixes:

- Текущий fix (2025-10-10) - reconnection bug

---

###  Проблема 3: Stale Peripheral References After Battery Restart

**Симптомы:**
- "Invalid BigBattery device" при reconnect после battery restart
- PHANTOM error в логах: `[CONNECTION] ⚠️ PHANTOM: No peripheral but BMS timer running!`
- После cleanConnection() и попытки переподключения → "INVALID DEVICE"
- В логах diagnostics отсутствуют peripheralName и peripheralIdentifier

**Root Cause:**

**Stale peripheral objects in scannedPeripherals:**

```swift
// ❌ НЕПРАВИЛЬНО - не очищаем scannedPeripherals
func cleanConnection() {
    // Clean BMS data ✅
    cleanData()

    // Clean protocol data ✅
    protocolDataManager.clearProtocols()

    // Reset Bluetooth states ✅
    writeCharacteristic = nil
    notifyCharacteristic = nil
    cachedDeviceUUID = nil

    // ❌ scannedPeripherals НЕ очищается!
    // Старые peripheral объекты остаются в списке
}
```

**Что происходит:**
1. Батарея перезагружается (после сохранения настроек или power cycle)
2. PHANTOM monitor обнаруживает проблему → `cleanConnection()` вызывается
3. Bluetooth state очищен НО `scannedPeripherals` содержит СТАРЫЕ peripheral объекты
4. Пользователь пытается переподключиться, кликая на батарею в списке
5. Приложение пытается подключиться к СТАРОМУ peripheral объекту
6. iOS BLE stack: старый peripheral больше не валиден (батарея перезагрузилась)
7. Service discovery fails → не находит services → `notZetaraPeripheralError` → "Invalid BigBattery device"

**Доказательства из логов:**
```json
// До restart - успешное подключение
"bluetoothInfo": {
  "peripheralName": "BB-51.2V100Ah-0855",
  "peripheralIdentifier": "1997B63E-02F2-BB1F-C0DE-63B68D347427"
}

// После restart - подключение failed
"bluetoothInfo": {
  "state": "poweredOn"
  // peripheralName отсутствует
  // peripheralIdentifier отсутствует
}
```

### ✅ Решение: Clear scannedPeripherals in cleanConnection()

```swift
// ✅ ПРАВИЛЬНО - очищаем scannedPeripherals
func cleanConnection() {
    // ...existing cleanup...

    // Очищаем протокольные данные
    protocolDataManager.clearProtocols()

    // ✅ Очищаем список сканированных устройств (stale peripherals)
    cleanScanning()
    protocolDataManager.logProtocolEvent("[CONNECTION] Scanned peripherals cleared")

    // Reset Bluetooth states
    writeCharacteristic = nil
    notifyCharacteristic = nil
    identifier = nil
    cachedDeviceUUID = nil

    connectedPeripheralSubject.onNext(nil)
}
```

**Почему это работает:**
- `cleanScanning()` очищает `scannedPeripheralsSubject` и dispose scan
- Старые peripheral объекты удалены из списка
- При открытии Connectivity screen запускается НОВОЕ сканирование
- Батарея найдена заново с НОВЫМ peripheral объектом
- Новый peripheral объект валиден для service discovery
- Подключение успешно ✅

### 📋 Checklist для проверки:

- [ ] `cleanConnection()` вызывает `cleanScanning()`?
- [ ] Логи показывают "Scanned peripherals cleared"?
- [ ] После PHANTOM cleanup можно переподключиться?
- [ ] "INVALID DEVICE" НЕ появляется после battery restart?

### 📚 Где применять:

**Файл:** `Zetara/Sources/ZetaraManager.swift`

**Метод:** `cleanConnection()` - lines 277-333

**Изменения:**
```swift
// Line 318-320: Added cleanScanning() call
cleanScanning()
protocolDataManager.logProtocolEvent("[CONNECTION] Scanned peripherals cleared")
```

**Также добавлено детальное логирование в `connect()`:**
```swift
// Lines 211-217: Log discovered services
.do(onNext: { [weak self] services in
    self?.protocolDataManager.logProtocolEvent("[CONNECT] Services discovered: \(services.count)")
    services.forEach { service in
        self?.protocolDataManager.logProtocolEvent("[CONNECT] Service UUID: \(service.uuid.uuidString)")
    }
})

// Lines 231-235: Log connection errors
if case ZetaraManager.Error.notZetaraPeripheralError = error {
    self?.protocolDataManager.logProtocolEvent("[CONNECT] ❌ Service UUID not recognized (not a valid BigBattery device)")
}
```

### 🔗 Related Fixes:

- `docs/fix-history/2025-10-10_reconnection-after-restart-bug.md` - полная документация

---

### Проблема 4: Missing BMS Data After Reconnect (Insufficient Diagnostic Logging)

**Симптомы:**
- После reconnect батареи протоколы загружаются успешно ✅
- НО battery data = all zeros (voltage: 0, soc: 0, cellVoltages: [])
- Connection status показывает "connected"
- НО нет активного статуса на homepage
- В diagnostic logs НЕ видно BMS requests/responses

**Когда возникает:**
- После save protocol settings → disconnect battery → reconnect
- После battery restart (power cycle)
- After 20-30 seconds connection established but no BMS data appears

**Логи diagnostics:**
```json
{
  "batteryInfo": {
    "voltage": 0,
    "soc": 0,
    "cellVoltages": [],
    "status": "Standby"
  },
  "rawDataInfo": {
    "lastReceivedPacket": "0000000000000000000000000000000000000000000000000000"
  }
}
```

### ⚙️ Root Cause:

**Недостаточное diagnostic logging в BMS data flow:**

`getBMSData()` method имеет только `print()` statements, которые видны только в Xcode console. НО:
- Client не имеет доступа к Xcode console
- Diagnostic logs экспортируются без console logs
- Невозможно диагностировать BMS flow remotely

**Почему это проблема:**
- BMS timer запускается каждые 5 секунд
- Если timer работает НО данные не приходят - мы не знаем почему:
  - Timer не запустился?
  - `getBMSData()` не вызывается?
  - BMS request не отправляется?
  - Battery не отвечает?
  - CRC validation failed?
  - Parse failed?

**Примеры print() которые НЕ попадают в diagnostics:**
```swift
func getBMSData() -> Maybe<Data.BMS> {
    print("!!! МЕТОД getBMSData() ВЫЗВАН !!!")  // ❌ Only in Xcode console
    // ...
    print("getting bms data write data: \(data.toHexString())")  // ❌ Only in Xcode console
    print("recevie bms data: \($0.toHexString())")  // ❌ Only in Xcode console
}
```

### ✅ Решение: Add protocolDataManager.logProtocolEvent() throughout BMS flow

```swift
func getBMSData() -> Maybe<Data.BMS> {
    // ✅ Visible in diagnostic logs
    protocolDataManager.logProtocolEvent("[BMS] 📡 getBMSData() called")

    let isDeviceConnected = ...
    protocolDataManager.logProtocolEvent("[BMS] Device connected: \(isDeviceConnected)")

    if !isDeviceConnected, let mockBMSData = ... {
        protocolDataManager.logProtocolEvent("[BMS] 🧪 Using mock data (no device connected)")
        // ...
    }

    guard let peripheral = ... else {
        protocolDataManager.logProtocolEvent("[BMS] ❌ No peripheral/characteristics available")
        // ...
    }

    protocolDataManager.logProtocolEvent("[BMS] ✅ Using real device data")

    let data = Foundation.Data.getBMSData
    protocolDataManager.logProtocolEvent("[BMS] 📤 Writing BMS request: \(data.toHexString())")

    // In Observable chain:
    .do { [weak self] data in
        self?.protocolDataManager.logProtocolEvent("[BMS] 📥 Received BMS response: \(data.toHexString())")
    }
    .filter { [weak self] bytes in
        let crcValid = bytes.crc16Verify()
        let isBMS = Data.BMS.isBMSData(bytes)
        self?.protocolDataManager.logProtocolEvent("[BMS] Validation - CRC: \(crcValid), isBMSData: \(isBMS)")
        return crcValid && isBMS
    }
    .compactMap { [weak self] _bytes in
        let result = self?.bmsDataHandler.append(_bytes)
        if result != nil {
            self?.protocolDataManager.logProtocolEvent("[BMS] ✅ BMS data parsed successfully")
        } else {
            self?.protocolDataManager.logProtocolEvent("[BMS] ⚠️ Failed to parse BMS data")
        }
        return result
    }
}

func startRefreshBMSData() {
    protocolDataManager.logProtocolEvent("[BMS] 🚀 Starting BMS data refresh timer (interval: \(Self.configuration.refreshBMSTimeInterval)s)")
    // ...
}
```

**Why this works:**
- `protocolDataManager.logProtocolEvent()` logs are captured in diagnostic exports
- Client can send diagnostic logs remotely
- We can see EXACTLY where BMS flow fails:
  - Timer started? ✅
  - getBMSData() called? ✅
  - Device connected? ✅
  - BMS request sent? ✅
  - Response received? ❌ → battery not responding
  - CRC valid? ❌ → corrupted data
  - Parse succeeded? ❌ → protocol mismatch

### 📋 Checklist для проверки:

- [ ] `startRefreshBMSData()` logs when BMS timer starts?
- [ ] `getBMSData()` logs when called?
- [ ] Device connection status logged?
- [ ] BMS request hex logged?
- [ ] BMS response hex logged?
- [ ] CRC and isBMSData validation logged?
- [ ] Parse success/failure logged?
- [ ] ALL key points visible in exported diagnostics?

### 📚 Где применять:

**Файл:** `Zetara/Sources/ZetaraManager.swift`

**Методы исправлены:**
- `startRefreshBMSData()` - line 506
- `getBMSData()` - lines 541, 548, 552, 602, 609, 616, 626, 633, 639, 641

**Logging points added:**
1. BMS timer start
2. getBMSData() call
3. Device connection check
4. Mock data path
5. No peripheral error
6. Using real device
7. Writing BMS request
8. Receiving BMS response
9. CRC and isBMSData validation
10. Parse success/failure

### 🔗 Related Fixes:

- `docs/fix-history/2025-10-14_missing-bms-data-after-reconnect.md` - полная документация

### ⚠️ Prevention:

**Pattern to follow:**

Для ВСЕХ critical Bluetooth operations:
- Use BOTH `print()` (for console) AND `protocolDataManager.logProtocolEvent()` (for diagnostics)
- Log entry point
- Log device/connection state
- Log data being sent (hex format)
- Log data received (hex format)
- Log validation results
- Log success/failure

**Example:**
```swift
func criticalBluetoothOperation() {
    print("[DEBUG] Operation started")  // ✅ Console
    protocolDataManager.logProtocolEvent("[OPERATION] Started")  // ✅ Diagnostics

    // ... operation code ...

    print("[DEBUG] Data sent: \(data.toHexString())")  // ✅ Console
    protocolDataManager.logProtocolEvent("[OPERATION] 📤 Sent: \(data.toHexString())")  // ✅ Diagnostics
}
```

**Code Review:**
- [ ] Check for operations with ONLY `print()` statements
- [ ] Add `protocolDataManager.logProtocolEvent()` parallel logging
- [ ] Verify diagnostic exports include the new logs
- [ ] Test with client to ensure logs are useful

---

### Проблема 5: "Invalid Device" After Restart (observeDisconect Lifecycle Issue)

**Симптомы:**
- Protocols saved successfully ✅
- Battery disconnected and restarted ✅
- Return to Connectivity screen
- Battery appears in list (stale peripheral)
- **Click battery → "BluetoothError error 4" / "Invalid device"**
- Logs show disconnect NOT detected until connection attempt

**Когда возникает:**
- User changes protocol settings → Save
- User on Settings or Home screen (NOT on Connectivity screen)
- Battery disconnects/restarts
- User returns to Connectivity screen → clicks battery → error

**Diagnostic Logs Pattern:**
```
[09:16:35] ✅ RS485 Protocol set successfully
[09:16:35] ✅ CAN Protocol set successfully
    ↓
[Battery physically disconnected - NOT DETECTED!]
    ↓
[09:16:41] ❌ Connection error: BluetoothError error 4
[09:16:41] ⚠️ PHANTOM: No peripheral but BMS timer running!
[09:16:41] Cleaning connection state  ← TOO LATE!
```

**Key indicator:** Disconnect NOT logged WHEN it happened, only cleanup logged AFTER connection attempt failed.

### ⚙️ Root Cause:

**observeDisconect() tied to ViewController lifecycle:**

```swift
// ❌ НЕПРАВИЛЬНО - ConnectivityViewController.swift
class ConnectivityViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // Subscribe to disconnect events
        ZetaraManager.shared.observeDisconect()
            .subscribe { [weak self] event in
                self?.state = .unconnected
                self?.tableView.reloadData()
            }.disposed(by: self.disposeBag)  // ← Tied to ViewController lifecycle!
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        disposeBag = DisposeBag()  // ❌ CANCELS observeDisconect subscription!
    }
}
```

**Timeline of bug:**
1. User on ConnectivityVC → connects → navigates to SettingsVC
2. **ConnectivityVC.viewWillDisappear** → **disposeBag reset** → **observeDisconect CANCELLED**
3. User changes protocols → Save → Battery restarts
4. **Battery disconnects** → **observeDisconect NOT FIRING** (subscription cancelled!)
5. **cleanConnection() NOT CALLED** → stale peripherals NOT cleared
6. User returns to ConnectivityVC → sees stale "BB-51.2V100Ah-0855"
7. User clicks → connection attempt with STALE CBPeripheral → **BluetoothError error 4**

**Apple CoreBluetooth says:**
> "You shouldn't reuse the same peripheral instance once disconnected - instead you should ask CBCentralManager to give us a fresh CBPeripheral using its known peripheral UUID."

**Our app violated this:** Tried to connect with stale peripheral instance stored in scannedPeripherals array.

### ✅ Решение: Global Disconnect Handler in ZetaraManager

**Move disconnect handling to app-level (singleton), NOT ViewController-level:**

**Change 1: Add global handler in ZetaraManager.init():**

```swift
// ✅ ПРАВИЛЬНО - Zetara/Sources/ZetaraManager.swift
private override init() {
    super.init()

    // ... existing init code ...

    // ✅ Global disconnect handler (NOT tied to any ViewController lifecycle)
    // Follows Apple CoreBluetooth best practices for peripheral lifecycle management
    manager.observeDisconnect()
        .subscribe(onNext: { [weak self] (peripheral, error) in
            let peripheralName = peripheral.name ?? "Unknown"
            self?.protocolDataManager.logProtocolEvent("[DISCONNECT] 🔌 Device disconnected: \(peripheralName)")

            if let error = error {
                self?.protocolDataManager.logProtocolEvent("[DISCONNECT] Reason: \(error.localizedDescription)")
            }

            // Автоматическая очистка при отключении
            self?.cleanConnection()
        })
        .disposed(by: disposeBag)  // ← Tied to ZetaraManager lifecycle (singleton, never dies)

    // ... rest of init ...
}
```

**Change 2: Remove duplicate subscription from ConnectivityViewController:**

```swift
// ❌ DELETE these lines (95-100 in ConnectivityViewController.swift)
ZetaraManager.shared.observeDisconect()
    .subscribeOn(MainScheduler.instance)
    .subscribe {[weak self] event in
        self?.state = .unconnected
        self?.tableView.reloadData()
    }.disposed(by: self.disposeBag)
```

**Change 3: Subscribe to connectedPeripheralSubject for UI updates:**

```swift
// ✅ ADD in ConnectivityViewController.viewDidLoad (replace removed subscription)
// Subscribe to connection state changes for UI updates
// Global disconnect handler in ZetaraManager.init() handles actual disconnection logic
ZetaraManager.shared.connectedPeripheralSubject
    .subscribeOn(MainScheduler.instance)
    .observe(on: MainScheduler.instance)
    .subscribe(onNext: { [weak self] connectedPeripheral in
        self?.state = connectedPeripheral == nil ? .unconnected : .connected
        self?.tableView.reloadData()

        if connectedPeripheral == nil {
            // Device disconnected, clear stale peripherals
            self?.scannedPeripherals = []
            ZetaraManager.shared.protocolDataManager.logProtocolEvent("[CONNECTIVITY] UI updated: disconnected, cleared stale peripherals")
        } else {
            ZetaraManager.shared.protocolDataManager.logProtocolEvent("[CONNECTIVITY] UI updated: connected")
        }
    })
    .disposed(by: disposeBag)
```

**Why this works:**
- ✅ Global handler in ZetaraManager (singleton) → lives entire app lifetime
- ✅ Disconnect detected from ANY screen (Connectivity, Settings, Home)
- ✅ cleanConnection() called IMMEDIATELY when battery disconnects
- ✅ scannedPeripherals cleared before user returns to Connectivity screen
- ✅ UI subscription in ViewController safe to cancel (only updates UI, doesn't handle disconnect logic)

**New log sequence (FIXED):**
```
[09:16:35] ✅ RS485 Protocol set successfully
[09:16:35] ✅ CAN Protocol set successfully
    ↓
[Battery physically disconnected]
    ↓
[09:16:36] [DISCONNECT] 🔌 Device disconnected: BB-51.2V100Ah-0855  ← IMMEDIATE!
[09:16:36] [CONNECTION] Cleaning connection state
[09:16:36] [CONNECTION] Scanned peripherals cleared
    ↓
[User returns to Connectivity screen]
    ↓
[09:16:40] [CONNECTIVITY] UI updated: disconnected, cleared stale peripherals
[09:16:40] [SCAN] Starting scan for peripherals
[09:16:42] [SCAN] Found peripheral: BB-51.2V100Ah-0855  ← FRESH peripheral!
    ↓
[User clicks battery]
    ↓
[09:16:45] [CONNECT] Attempting connection  ← SUCCESS!
```

### 📋 Checklist для проверки:

- [ ] Global disconnect handler added in ZetaraManager.init()?
- [ ] Duplicate observeDisconect subscription removed from ConnectivityViewController?
- [ ] UI subscription to connectedPeripheralSubject added?
- [ ] Disconnect detected in logs IMMEDIATELY when battery disconnects (not on connection attempt)?
- [ ] cleanConnection() called BEFORE user returns to Connectivity screen?
- [ ] Stale peripherals cleared automatically?
- [ ] No "BluetoothError error 4" when reconnecting after restart?

### 📚 Где применять:

**Files modified:**

1. **Zetara/Sources/ZetaraManager.swift**
   - Line 108-122: Added global disconnect handler in init()

2. **BatteryMonitorBL/ConnectivityViewController.swift**
   - Removed lines 95-100: Duplicate observeDisconect subscription
   - Added lines 95-112: connectedPeripheralSubject subscription for UI

### 🔗 Related Fixes:

- `docs/fix-history/2025-10-20_invalid-device-after-restart-regression.md` - full documentation
- `docs/fix-history/2025-10-10_reconnection-after-restart-bug.md` - previous stale peripherals fix

### ⚠️ Prevention:

**Pattern to follow for BLE apps:**

```swift
// ❌ WRONG - ViewController manages peripheral lifecycle
class MyViewController {
    override func viewDidLoad() {
        bleManager.observeDisconnect()
            .subscribe { ... }
            .disposed(by: disposeBag)  // ← Gets cancelled in viewWillDisappear
    }

    override func viewWillDisappear(_ animated: Bool) {
        disposeBag = DisposeBag()  // ❌ Cancels critical subscriptions!
    }
}

// ✅ CORRECT - Singleton manager handles peripheral lifecycle
class BLEManager {
    private let disposeBag = DisposeBag()  // ← Lives entire app lifetime

    init() {
        // Global handlers - never cancelled
        centralManager.observeDisconnect()
            .subscribe { [weak self] peripheral, error in
                self?.handleDisconnect(peripheral, error)
                // Notify observers via Subject
                self?.connectionStateSubject.onNext(.disconnected)
            }
            .disposed(by: disposeBag)
    }
}

class MyViewController {
    private var disposeBag = DisposeBag()

    override func viewDidLoad() {
        // Subscribe to state changes ONLY
        BLEManager.shared.connectionStateSubject
            .subscribe { [weak self] state in
                self?.updateUI(state)  // ← Only UI updates
            }
            .disposed(by: disposeBag)  // ← Safe to cancel
    }
}
```

**Code Review Checklist:**

When reviewing BLE code:
- [ ] Are disconnect handlers tied to ViewController lifecycle?
- [ ] Do ViewControllers reset disposeBag in viewWillDisappear?
- [ ] Are critical subscriptions (disconnect, state changes) cancelled when navigating away?
- [ ] Is peripheral lifecycle managed at app level (singleton)?
- [ ] Does code follow Apple CoreBluetooth best practices?

---

## 5. Protocol Save Issues

### 🔴 Симптомы:

**Проблема 1: Только Module ID сохраняется, RS485/CAN игнорируются**

**Логи:**
```
[09:04:38] [BLUETOOTH] 📤 Writing control data: 100701023574  ← setModuleId
[09:04:38] [BLUETOOTH] 📤 Writing control data: 100601052576  ← setRS485
[09:04:38] [BLUETOOTH] 📤 Writing control data: 10050101d4b5  ← setCAN
```
↑ **ВСЕ 3 с ОДИНАКОВЫМ timestamp!**

**Проблема 2: Error 0x01 при повторном сохранении тех же значений**

**Логи:**
```
[BLUETOOTH] 📥 Received notification: 10050101d4b5
```
↑ `bytes[3] = 0x01` = error

### ⚙️ Root Cause:

**Root Cause 1: Simultaneous execution**

```swift
// ❌ НЕПРАВИЛЬНО - прямой вызов, не через queue
func setModuleId(...) {
    ZetaraManager.shared.setModuleId(...)  // ← Executed immediately
        .subscribe(...)
}

func performSave() {
    setModuleId(...)  // ← All 3 executed
    setRS485(...)     // ← at SAME time!
    setCAN(...)       // ← Battery ignores 2 & 3
}
```

**Battery can process ONLY ONE control request at a time!**

**Root Cause 2: Duplicate values not checked**

```swift
// ❌ НЕПРАВИЛЬНО - не проверяем current value
func performSave() {
    setModuleId(newValue)  // ← Even if newValue == currentValue
}
```

Battery returns error 0x01 when trying to set value that's already set.

### ✅ Решение 1: Use queuedRequest for sequential execution

```swift
// ✅ ПРАВИЛЬНО - через queuedRequest
func setModuleId(at index: Int, completion: (() -> Void)? = nil) {
    ZetaraManager.shared.queuedRequest("setModuleId") {  // ← Queued!
        ZetaraManager.shared.setModuleId(moduleNumber)
    }
    .observe(on: MainScheduler.instance)
    .subscribe(...)
}
```

**Execution:**
```
setModuleId() → queuedRequest → [09:04:38.000]
    ↓ (wait 500ms)
setRS485()    → queuedRequest → [09:04:38.500]
    ↓ (wait 500ms)
setCAN()      → queuedRequest → [09:04:39.000]
```

### ✅ Решение 2: Check current value before sending

```swift
// ✅ ПРАВИЛЬНО - проверяем перед отправкой
if let pendingIndex = pendingModuleIdIndex {
    // Check if value already set
    if let currentModuleId = moduleIdData?.moduleId, (currentModuleId - 1) == pendingIndex {
        // Skip - already set
        ZetaraManager.shared.protocolDataManager.logProtocolEvent(
            "[SETTINGS] ⏭️ Skipping Module ID - already set to ID \(pendingIndex + 1)"
        )
        checkCompletion()
    } else {
        // Send command
        setModuleId(at: pendingIndex, completion: checkCompletion)
    }
}
```

### 📋 Checklist для проверки:

- [ ] Все set методы используют `queuedRequest()`?
- [ ] НЕТ прямых вызовов `ZetaraManager.setModuleId()`?
- [ ] Current value проверяется перед отправкой?
- [ ] Логи показывают sequential execution (500ms interval)?
- [ ] Error 0x01 не появляется при re-save?

### 📚 Где применять:

**Файл:** `BatteryMonitorBL/SettingsViewController.swift`

**Методы:**
- `setModuleId()` - uses queuedRequest
- `setRS485()` - uses queuedRequest
- `setCAN()` - uses queuedRequest
- `performSave()` - checks current values before calling set methods

### 🔗 Related Fixes:

- `docs/fix-history/2025-10-10_protocol-save-and-crash-bug.md`
- Текущий fix (2025-10-10) - duplicate values check

---

## 6. Alert/UI Update Issues

### 🔴 Симптомы:

**Проблема:** Alert shows/hides from background thread

**Crash:**
```
Thread 5: "UIView setNeedsLayout called from background thread"
```

### ⚙️ Root Cause:

Same as Threading Errors (#1) - UI updates from background thread.

**Specific to Alerts:**

```swift
// ❌ НЕПРАВИЛЬНО
someObservable
    .subscribe(onNext: {
        Alert.show("...")    // ← May execute on background thread
    })
```

### ✅ Решение:

**Option 1: observe(on: MainScheduler)**
```swift
someObservable
    .observe(on: MainScheduler.instance)
    .subscribe(onNext: {
        Alert.show("...")  // ✅ Safe - main thread
    })
```

**Option 2: DispatchQueue.main.async**
```swift
someObservable
    .subscribe(onNext: {
        DispatchQueue.main.async {
            Alert.show("...")  // ✅ Safe - explicitly main thread
        }
    })
```

**Option 3: subscribeOn + observeOn**
```swift
someObservable
    .subscribeOn(MainScheduler.instance)
    .observe(on: MainScheduler.instance)
    .subscribe(onNext: {
        Alert.show("...")  // ✅ Safe - guaranteed main thread
    })
```

### 📋 Checklist для проверки:

- [ ] Все `Alert.show()` вызовы на main thread?
- [ ] Все `Alert.hide()` вызовы на main thread?
- [ ] Completion handlers с Alert имеют `.observe(on:)`?

### 📚 Где применять:

**Файлы:**
- `BatteryMonitorBL/SettingsViewController.swift`
  - `performSave()` - Alert.show/hide
  - `setupDisconnectHandler()` - Alert.hide in callback
  - All set methods - completion → Alert.hide

---

## 7. BMS Timer Timing Issues

### 🔴 Симптомы:

**Проблема:** Battery data не загружается после reconnection (voltage: 0, SOC: 0, cell voltages: empty)

**Когда возникает:**
- После save protocol settings → disconnect battery → reconnect
- После battery restart (power cycle)
- After 20-30 seconds connection established but no BMS data appears
- User must restart entire app to see battery data

**Логи diagnostics:**
```json
{
  "batteryInfo": {
    "voltage": 0,
    "soc": 0,
    "cellVoltages": [],
    "cellCount": 0
  },
  "protocolInfo": {
    "recentLogs": [
      "[09:04:42] [SETTINGS] ✅ RS485 Protocol set successfully",
      "[09:04:42] [BLUETOOTH] ✅ Got control data response"
    ]
  }
}
```

↑ Protocols loaded successfully ✅, but battery data = zeros ❌

### ⚙️ Root Cause:

**BMS timer starts TOO EARLY - before protocol loading completes:**

```swift
// ❌ НЕПРАВИЛЬНО - ZetaraManager.swift connect() method
public func connect(_ peripheral: Peripheral) -> Observable<ConnectedPeripheral> {
    // ... connection logic ...

    observer.onNext(peripheral)

    // Запускаем мониторинг подключения
    self?.startConnectionMonitor()

    // ❌ BMS timer starts IMMEDIATELY!
    self?.startRefreshBMSData()
}
```

**Timeline of events (BEFORE FIX):**
```
T+0.0s: Connection established
T+0.0s: startRefreshBMSData() called  ← TOO EARLY!
T+0.0s: First BMS request sent
T+1.5s: Protocol loading begins (in ConnectivityViewController)
T+1.5s: getModuleId() sent
T+2.1s: getRS485() sent
T+2.7s: getCAN() sent
T+5.0s: Second BMS request sent
```

**Что происходит:**
- BMS requests execute SIMULTANEOUSLY with protocol queries
- Battery firmware can only process ONE request at a time
- Battery receives mixed commands: `getBMSData()` + `getModuleId()` + `getRS485()` + `getCAN()`
- Battery gets confused and sends wrong responses to wrong requests
- Protocol queries may get BMS responses
- BMS requests may get protocol responses
- Observable filtering (`isBMSData: false`) discards protocol responses in BMS stream
- **Result:** BMS data never reaches UI → voltage/SOC remain zeros

**Evidence from logs:**

Protocols load successfully:
```
[09:04:42] [SETTINGS] ✅ RS485 Protocol set successfully
[09:04:42] [QUEUE] ✅ setRS485 completed in 618ms
```

But BMS data never appears → indicating timing conflict between BMS requests and protocol queries.

### ✅ Решение: Delay BMS timer start until AFTER protocol loading

**Change 1:** Remove `startRefreshBMSData()` from `ZetaraManager.connect()`:

```swift
// ✅ ПРАВИЛЬНО - ZetaraManager.swift
public func connect(_ peripheral: Peripheral) -> Observable<ConnectedPeripheral> {
    // ... connection logic ...

    observer.onNext(peripheral)

    // Запускаем мониторинг подключения
    self?.startConnectionMonitor()

    // NOTE: startRefreshBMSData() НЕ вызывается здесь!
    // BMS timer запускается ПОСЛЕ protocol loading в ConnectivityViewController
    // чтобы избежать смешивания BMS requests с protocol queries
}
```

**Change 2:** Add `startRefreshBMSData()` call in `ConnectivityViewController` with delay:

```swift
// ✅ ПРАВИЛЬНО - ConnectivityViewController.swift
.subscribe { [weak self] (connectedPeripheral: ZetaraManager.ConnectedPeripheral) in
    self?.state = .connected
    self?.tableView.reloadData()

    // Загружаем протоколы через 1.5 сек после подключения
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        ZetaraManager.shared.protocolDataManager.logProtocolEvent("[CONNECTIVITY] Triggering protocol loading after connection")
        self?.loadProtocolsViaQueue()
    }

    // ✅ Запускаем BMS timer через 5 секунд после подключения
    // (это гарантирует что protocol loading завершится ДО первого BMS request)
    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
        ZetaraManager.shared.protocolDataManager.logProtocolEvent("[CONNECTIVITY] Starting BMS timer after protocol loading delay")
        ZetaraManager.shared.startRefreshBMSData()
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        self?.navigationController?.popViewController(animated: true)
    }
}
```

**Change 3:** Make `startRefreshBMSData()` public:

```swift
// ✅ ПРАВИЛЬНО - ZetaraManager.swift
public func startRefreshBMSData() {  // ← Changed from internal to public
    protocolDataManager.logProtocolEvent("[BMS] 🚀 Starting BMS data refresh timer (interval: \(Self.configuration.refreshBMSTimeInterval)s)")
    // ...
}
```

**Timeline of events (AFTER FIX):**
```
T+0.0s: Connection established
T+1.5s: Protocol loading begins
T+1.5s: getModuleId() sent
T+2.1s: getRS485() sent  (500ms interval via Request Queue)
T+2.7s: getCAN() sent    (500ms interval via Request Queue)
T+3.5s: Protocol loading complete ✅
T+5.0s: startRefreshBMSData() called ✅
T+5.0s: First BMS request sent → NO CONFLICTS!
T+10.0s: Second BMS request sent
```

**Why this works:**
- Protocol loading completes BEFORE BMS timer starts
- NO overlapping requests between protocol queries and BMS requests
- Battery processes each request cleanly
- BMS data loads successfully
- User sees data WITHOUT restarting app

### 📋 Checklist для проверки:

- [ ] `ZetaraManager.connect()` НЕ вызывает `startRefreshBMSData()`?
- [ ] `ConnectivityViewController` вызывает `startRefreshBMSData()` с delay 5s?
- [ ] `startRefreshBMSData()` объявлен как `public`?
- [ ] Protocol loading начинается T+1.5s?
- [ ] BMS timer начинается T+5.0s (ПОСЛЕ protocol loading)?
- [ ] Battery data загружается корректно после reconnect?
- [ ] User НЕ нужно рестартовать app для просмотра данных?

### 📚 Где применять:

**Файлы:**
- `Zetara/Sources/ZetaraManager.swift`
  - `connect()` method (line 261-263) - Remove `startRefreshBMSData()` call
  - `startRefreshBMSData()` (line 512) - Change to `public`
  - `cleanConnection()` (lines 326-330) - Add explicit BMS timer stop

- `BatteryMonitorBL/ConnectivityViewController.swift`
  - `didSelectRowAt` method (lines 150-155) - Add `startRefreshBMSData()` with 5s delay

**Why 5 Second Delay?**

- Protocol loading starts at T+1.5s
- Each protocol query takes ~600ms (Request Queue enforces 500ms minimum interval)
- 3 protocol queries = ~1.8 seconds total
- Safety margin: 1.7 seconds
- Total: 1.5s + 1.8s + 1.7s = 5.0s

### 🔗 Related Fixes:

- `docs/fix-history/2025-10-16_bms-data-not-loading-after-reconnect.md` - полная документация этого fix

### ⚠️ Prevention:

**Pattern to follow:**

Для Bluetooth operations с timing dependencies:

```swift
// ❌ НЕПРАВИЛЬНО - все operations запускаются одновременно
func connect() {
    establishConnection()
    startDataPolling()      // ← TOO EARLY!
    loadConfiguration()     // ← Conflict with polling!
}

// ✅ ПРАВИЛЬНО - sequential with explicit delays
func connect() {
    establishConnection()

    // Let caller control timing
}

// In ViewController:
manager.connect()
    .subscribe { connected in
        // First: Load configuration
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            manager.loadConfiguration()
        }

        // Then: Start polling AFTER config loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            manager.startDataPolling()
        }
    }
```

**Code Review Checklist:**

When reviewing connection/initialization code:

- [ ] Are Bluetooth operations sequential (not parallel)?
- [ ] Is there adequate delay between connection and data polling?
- [ ] Can operations conflict if executed simultaneously?
- [ ] Are timing dependencies explicit (not hidden in internal methods)?
- [ ] Does battery firmware support simultaneous requests? (Answer: NO!)

**Testing:**

- [ ] Test reconnection after protocol settings change
- [ ] Verify battery data appears WITHOUT app restart
- [ ] Check diagnostic logs show correct timing sequence
- [ ] Verify NO overlapping BMS requests and protocol queries

---

## Quick Reference

| Issue | File | Method/Line | Solution |
|-------|------|-------------|----------|
| Threading Error | SettingsViewController.swift | setModuleId:915 | `.observe(on: MainScheduler.instance)` |
| DisposeBag Leak | SettingsViewController.swift | viewWillDisappear:359 | `disposeBag = DisposeBag()` |
| Timeout Not Working | ZetaraManager.swift | writeControlData | Internal timeout only |
| Reconnection Fails | ZetaraManager.swift | cleanConnection | Reset cachedDeviceUUID |
| Stale Peripherals | ZetaraManager.swift | cleanConnection | Call `cleanScanning()` |
| Missing BMS Data | ZetaraManager.swift | getBMSData/startRefreshBMSData | Add `logProtocolEvent()` logging |
| Protocol Save Fails | SettingsViewController.swift | setModuleId/RS485/CAN | Use `queuedRequest()` |
| Duplicate Value Error | SettingsViewController.swift | performSave:713-757 | Check current value first |
| BMS Data Not Loading After Reconnect | ZetaraManager.swift, ConnectivityViewController.swift | connect:261, didSelectRowAt:150-155 | Delay BMS timer start 5s after connection |
| Invalid Device After Restart (Lifecycle) | ZetaraManager.swift, ConnectivityViewController.swift | init:108-122, viewDidLoad:95-112 | Global disconnect handler in ZetaraManager.init() |

---

## Добавление новых проблем

Когда исправляешь НОВУЮ проблему:

1. Добавь секцию в этот документ
2. Используй тот же формат:
   - 🔴 Симптомы
   - ⚙️ Root Cause
   - ✅ Решение
   - 📋 Checklist
   - 📚 Где применять
   - 🔗 Related Fixes

3. Update Quick Reference table
4. Commit изменения

**Следующий раз эта проблема решится за 5 минут!**

---

**Последнее обновление:** 2025-10-20
