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

## Quick Reference

| Issue | File | Method/Line | Solution |
|-------|------|-------------|----------|
| Threading Error | SettingsViewController.swift | setModuleId:915 | `.observe(on: MainScheduler.instance)` |
| DisposeBag Leak | SettingsViewController.swift | viewWillDisappear:359 | `disposeBag = DisposeBag()` |
| Timeout Not Working | ZetaraManager.swift | writeControlData | Internal timeout only |
| Reconnection Fails | ZetaraManager.swift | cleanConnection | Reset cachedDeviceUUID |
| Protocol Save Fails | SettingsViewController.swift | setModuleId/RS485/CAN | Use `queuedRequest()` |
| Duplicate Value Error | SettingsViewController.swift | performSave:713-757 | Check current value first |

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

**Последнее обновление:** 2025-10-10
