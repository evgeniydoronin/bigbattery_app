# 📊 PROTOCOL BLOCKS (Selected ID / CAN / RS485) - Детальная логика работы

**Дата создания:** 07.10.2025
**Версия:** 2.0 (Рефакторинг)
**Последнее обновление:** 07.10.2025
**Автор:** Технический анализ кодовой базы

---

## 🔄 ВАЖНО: АРХИТЕКТУРНЫЕ ИЗМЕНЕНИЯ v2.0

**Дата рефакторинга:** 07.10.2025

### Что изменилось

В версии 2.0 была проведена **полная переработка архитектуры протокольных данных**. Документ содержит описание как новой (v2.0), так и старой архитектуры (v1.0) для справки.

#### ✅ Новая архитектура (v2.0) - ТЕКУЩАЯ

1. **ProtocolDataManager** - новый отдельный сервис для управления протокольными данными
   - Файл: `Zetara/Sources/ProtocolDataManager.swift`
   - RxSwift Subjects вместо простого кэша
   - Реактивное обновление UI
   - Error handling с retry логикой

2. **Реактивное обновление UI**
   - `ProtocolParametersView.bind(to:)` - подписка на Subjects
   - UI обновляется мгновенно при изменении данных
   - Нет избыточных обновлений каждые 5 секунд

3. **Упрощенная загрузка**
   - `protocolDataManager.loadAllProtocols()` - единый метод
   - Request Queue автоматически обеспечивает интервалы
   - Убраны hardcoded delays (600ms, 1200ms)

#### ❌ Старая архитектура (v1.0) - УСТАРЕЛА

<details>
<summary>Нажмите для просмотра старой архитектуры</summary>

1. **Простой кэш в ZetaraManager**
   - `cachedModuleIdData`, `cachedRS485Data`, `cachedCANData`
   - Нет реактивности
   - Tight coupling

2. **Избыточное обновление UI**
   - `protocolParametersView.updateValues()` вызывался каждые 5 секунд
   - Обновление вместе с BMS данными

3. **Hardcoded delays**
   - 600ms для RS485
   - 1200ms для CAN
   - Дублировали работу Request Queue

</details>

---

## 📋 СОДЕРЖАНИЕ

1. [⭐ Новая архитектура v2.0](#-новая-архитектура-v20)
2. [Обзор компонента](#обзор-компонента)
3. [Архитектура хранения данных (v1.0 - устарела)](#архитектура-хранения-данных)
4. [Цепочка вызовов](#цепочка-вызовов)
5. [Загрузка протоколов](#загрузка-протоколов)
6. [Обновление UI](#обновление-ui)
7. [Очистка при отключении](#очистка-при-отключении)
8. [Таймлайн событий](#таймлайн-событий)
9. [Request Queue механизм](#request-queue-механизм)
10. [📝 Логирование v3.0](#-логирование-v30)
11. [Важные детали](#важные-детали)
12. [Связанные файлы](#связанные-файлы)

---

## ⭐ НОВАЯ АРХИТЕКТУРА v2.0

### 1. ProtocolDataManager - отдельный сервис

**Файл:** `Zetara/Sources/ProtocolDataManager.swift`

```swift
public class ProtocolDataManager {
    // RxSwift Subjects для реактивного управления
    public let moduleIdSubject = BehaviorSubject<Data.ModuleIdControlData?>(value: nil)
    public let rs485Subject = BehaviorSubject<Data.RS485ControlData?>(value: nil)
    public let canSubject = BehaviorSubject<Data.CANControlData?>(value: nil)

    // Загрузка всех протоколов
    public func loadAllProtocols(afterDelay delay: TimeInterval = 1.5) {
        // Последовательная загрузка через Request Queue
        // Request Queue автоматически обеспечивает минимум 500ms между запросами
    }

    // Очистка данных
    public func clearProtocols() {
        moduleIdSubject.onNext(nil)
        rs485Subject.onNext(nil)
        canSubject.onNext(nil)
    }
}
```

### 2. Интеграция в ZetaraManager

**Файл:** `Zetara/Sources/ZetaraManager.swift:70-72`

```swift
// MARK: - Protocol Data Manager
/// Менеджер для управления протокольными данными (Module ID, CAN, RS485)
public let protocolDataManager = ProtocolDataManager()
```

**Инициализация:**

```swift
private override init() {
    super.init()

    // Устанавливаем ссылку на себя в protocolDataManager
    protocolDataManager.setZetaraManager(self)
    // ...
}
```

**Очистка при отключении:**

```swift
func cleanConnection() {
    // ...
    // Очищаем протокольные данные через ProtocolDataManager
    protocolDataManager.clearProtocols()
    // ...
}
```

### 3. Реактивное обновление UI

**Файл:** `BatteryMonitorBL/Views/ProtocolParametersView.swift`

#### Старая версия (v1.0):

```swift
// ❌ Вызывался каждые 5 секунд в updateUI()
func updateValues() {
    if let moduleIdData = ZetaraManager.shared.cachedModuleIdData {
        moduleIdBlock.setValue(moduleIdData.readableId())
    } else {
        moduleIdBlock.setValue("--")
    }
    // ... аналогично для CAN и RS485
}
```

#### Новая версия (v2.0):

```swift
// ✅ Подписка на Subjects - обновление только при изменении данных
func bind(to protocolDataManager: ProtocolDataManager) {
    // Module ID
    protocolDataManager.moduleIdSubject
        .observeOn(MainScheduler.instance)
        .subscribe(onNext: { [weak self] moduleIdData in
            if let data = moduleIdData {
                self?.moduleIdBlock.setValue(data.readableId())
            } else {
                self?.moduleIdBlock.setValue("--")
            }
        })
        .disposed(by: disposeBag)

    // Аналогично для CAN и RS485
}
```

### 4. Упрощенная загрузка протоколов

**Файл:** `BatteryMonitorBL/ConnectivityViewController.swift:236-243`

#### Старая версия (v1.0):

```swift
// ❌ 60 строк кода с hardcoded delays
private func loadProtocolsViaQueue() {
    // 1. Module ID - сразу
    ZetaraManager.shared.queuedRequest("getModuleId") { ... }

    // 2. RS485 - через 600ms
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { ... }

    // 3. CAN - через 1200ms
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { ... }
}
```

#### Новая версия (v2.0):

```swift
// ✅ Одна строка!
private func loadProtocolsViaQueue() {
    ZetaraManager.shared.protocolDataManager.loadAllProtocols(afterDelay: 1.5)
}
```

### 5. Привязка в HomeViewController

**Файл:** `BatteryMonitorBL/HomeViewController.swift`

#### Старая версия (v1.0):

```swift
// ❌ В setupHeaderView() - только создание
protocolParametersView = ProtocolParametersView()

// ❌ В updateUI() - вызов каждые 5 секунд (строка 507)
protocolParametersView.updateValues()
```

#### Новая версия (v2.0):

```swift
// ✅ В setupHeaderView() - создание + привязка (строка 454)
protocolParametersView = ProtocolParametersView()
protocolParametersView.bind(to: ZetaraManager.shared.protocolDataManager)

// ✅ В updateUI() - ничего! (строка 507 удалена)
// Обновление происходит автоматически через RxSwift
```

### 6. Преимущества новой архитектуры

| Аспект | v1.0 (Старая) | v2.0 (Новая) |
|--------|---------------|--------------|
| **Separation of Concerns** | ❌ Смешение в ZetaraManager | ✅ Отдельный ProtocolDataManager |
| **Реактивность** | ❌ Нет | ✅ RxSwift Subjects |
| **Обновление UI** | ❌ Каждые 5 секунд | ✅ Только при изменении |
| **Coupling** | ❌ Tight (прямой доступ к singleton) | ✅ Loose (dependency injection) |
| **Error handling** | ❌ Нет | ✅ Retry логика |
| **Hardcoded delays** | ❌ 600ms, 1200ms | ✅ Убраны |
| **Код** | ❌ ~100 строк | ✅ ~20 строк |

### 7. Миграция данных

**Удалено из ZetaraManager.swift:**
- `cachedModuleIdData: Data.ModuleIdControlData?`
- `cachedRS485Data: Data.RS485ControlData?`
- `cachedCANData: Data.CANControlData?`

**Добавлено:**
- `protocolDataManager: ProtocolDataManager`

**Сохранено (не удалено):**
- `cachedDeviceUUID: String?` - используется в `isCacheValidForCurrentDevice()` для проверки актуальности подключенного устройства

**Совместимость:**
- ✅ BMS данные (Temperature, Voltage, Current) не затронуты
- ✅ Все табы (Summary, Cell Voltage, Temperature) работают как прежде
- ✅ Request Queue механизм не изменен

---

> 💡 **Примечание:** Разделы ниже описывают как новую (v2.0), так и старую архитектуру (v1.0) для справки. Устаревшие части помечены соответствующими метками.

---

## 🎨 ОБЗОР КОМПОНЕНТА

### Назначение

**ProtocolParametersView** - это UI компонент на главном экране, который отображает **текущие настройки протоколов связи**:

- **Selected ID** - текущий Module ID (1-16)
- **Selected CAN** - текущий CAN протокол (PYLON, SMA, LG, etc.)
- **Selected RS485** - текущий RS485 протокол (Generic, Pylontech, etc.)

### Визуализация

```
┌──────────────────────────────────────────────────────┐
│ HomeViewController                                    │
│                                                       │
│  ┌───────────────────────────────────────────────┐  │
│  │ ProtocolParametersView                        │  │
│  │                                               │  │
│  │  ┌─────────┬─────────┬─────────┐            │  │
│  │  │  ID 1   │  PYLON  │ Generic │ ← valueLabel│  │
│  │  │         │         │         │            │  │
│  │  │Selected │Selected │Selected │ ← titleLabel│  │
│  │  │   ID    │   CAN   │  RS485  │            │  │
│  │  └─────────┴─────────┴─────────┘            │  │
│  │     ↑          ↑          ↑                  │  │
│  │  moduleId    canBlock   rs485Block           │  │
│  │   Block                                      │  │
│  └───────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────┘
```

### UI структура

**Файл:** `ProtocolParametersView.swift:14-91`

```swift
class ProtocolParametersView: UIView {
    // Горизонтальный стек
    private let stackView: UIStackView

    // 3 блока протоколов
    private let moduleIdBlock: ProtocolBlock  // "Selected ID"
    private let canBlock: ProtocolBlock       // "Selected CAN"
    private let rs485Block: ProtocolBlock     // "Selected RS485"

    // Главный метод - обновление значений
    func updateValues() {
        // Читает данные из кэша ZetaraManager
        // Обновляет UI блоков
    }
}
```

### ProtocolBlock - отдельный блок

**Файл:** `ProtocolParametersView.swift:96-162`

```swift
private class ProtocolBlock: UIView {
    private let titleLabel: UILabel   // "Selected ID"
    private let valueLabel: UILabel   // "ID 1" (большой, жирный)

    init(title: String, iconName: String) {
        // Формирование заголовка
        if title == "Module ID" {
            titleLabel.text = "Selected ID"
        } else {
            titleLabel.text = "Selected \(title)"  // "Selected CAN"
        }

        // Начальное значение - прочерки
        valueLabel.text = "--"
    }

    func setValue(_ value: String) {
        valueLabel.text = value  // Обновление значения
    }
}
```

**Стили:**

```swift
// Белый фон
backgroundColor = .white
layer.cornerRadius = 10

// Тень
layer.shadowColor = UIColor.black.cgColor
layer.shadowOpacity = 0.1
layer.shadowOffset = CGSize(width: 0, height: 2)
layer.shadowRadius = 4

// Layout: сначала значение (большое), потом заголовок (маленькое)
let stackView = UIStackView(arrangedSubviews: [valueLabel, titleLabel])
stackView.axis = .vertical
stackView.spacing = 8
```

---

## 💾 АРХИТЕКТУРА ХРАНЕНИЯ ДАННЫХ

### Кэш в ZetaraManager

**Файл:** `ZetaraManager.swift:70-76`

```swift
// MARK: - Cache для протоколов (для Home экрана)
public var cachedModuleIdData: Data.ModuleIdControlData?  // ← Module ID
public var cachedRS485Data: Data.RS485ControlData?        // ← RS485
public var cachedCANData: Data.CANControlData?            // ← CAN

// UUID текущего подключенного устройства (для проверки валидности кэша)
private var cachedDeviceUUID: String?
```

**Особенности кэша:**

1. **Singleton паттерн** - `ZetaraManager.shared` доступен из любого места
2. **Глобальное хранилище** - кэш переживает переходы между экранами
3. **Проверка валидности** - кэш привязан к UUID устройства
4. **Очистка при отключении** - кэш сбрасывается через `cleanConnection()`

### Типы данных

**Файл:** `ControlData.swift`

#### 1. ModuleIdControlData

```swift
public struct ModuleIdControlData: ControlData {
    public let moduleId: Int  // 1-16

    static let supportedIds = Array(1...16)

    public init?(_ bytes: [UInt8]) {
        guard bytes.count >= 3 else { return nil }

        switch bytes[1] {
            case .getModuleId, .setModuleId:
                self.moduleId = Int(bytes[3])  // ← Извлечение из байтов
            default:
                return nil
        }
    }

    public func readableId() -> String {
        return "ID \(moduleId)"  // "ID 1", "ID 2", etc.
    }

    public func readableId(at index: Int) -> String {
        return "ID \(Self.supportedIds[index])"
    }
}
```

**Пример данных:**

```
Байты от BMS: [0x10, 0x02, 0x01, 0x01, ...]
               ││   ││   ││   └─ moduleId = 1
               ││   ││   └─ length
               ││   └─ function code (getModuleId)
               └─ address

Результат: ModuleIdControlData(moduleId: 1)
           .readableId() → "ID 1"
```

#### 2. RS485ControlData

```swift
public struct RS485ControlData: ControlData {
    public let selectedIndex: Int      // Индекс выбранного протокола
    public let protocols: [[UInt8]]    // Список всех протоколов

    public init?(_ bytes: [UInt8]) {
        guard bytes.count > 3 else { return nil }

        switch bytes[1] {
            case .getRS485, .setRS485:
                self.selectedIndex = Int(bytes[3])
                self.protocols = Data.parseProtocols(bytes)  // ← Парсинг списка
            default:
                return nil
        }
    }

    public func readableProtocol() -> String {
        return readableProtocol(at: selectedIndex)
    }

    public func readableProtocol(at index: Int) -> String {
        guard index < self.protocols.count else { return "" }
        return self.protocols[index].parseFromASCII()  // ← Байты → строка
    }

    public func readableProtocols() -> [String] {
        return self.protocols.map { $0.parseFromASCII() }
    }
}
```

**Пример данных:**

```
Байты от BMS: [0x10, 0x03, 0x03, 0x00, 0x03,
               0x47, 0x65, 0x6E, 0x65, 0x72, 0x69, 0x63, 0x00, 0x00, 0x00,  // "Generic"
               0x50, 0x79, 0x6C, 0x6F, 0x6E, 0x74, 0x65, 0x63, 0x68, 0x00,  // "Pylontech"
               0x53, 0x4D, 0x41, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  // "SMA"
               ...]

Результат: RS485ControlData(
    selectedIndex: 0,
    protocols: [
        [0x47, 0x65, 0x6E, 0x65, 0x72, 0x69, 0x63],  // "Generic"
        [0x50, 0x79, 0x6C, 0x6F, 0x6E, 0x74, 0x65, 0x63, 0x68],  // "Pylontech"
        [0x53, 0x4D, 0x41]  // "SMA"
    ]
)
.readableProtocol() → "Generic" (selectedIndex = 0)
```

#### 3. CANControlData

```swift
public struct CANControlData: ControlData {
    public let selectedIndex: Int      // Индекс выбранного протокола
    public let protocols: [[UInt8]]    // Список всех протоколов

    // Идентичная структура с RS485ControlData
    // Отличается только function code (getCAN / setCAN)
}
```

**Пример данных:**

```
Байты от BMS: [0x10, 0x04, 0x03, 0x00, 0x05,
               0x50, 0x59, 0x4C, 0x4F, 0x4E, 0x00, 0x00, 0x00, 0x00, 0x00,  // "PYLON"
               0x53, 0x4D, 0x41, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  // "SMA"
               0x4C, 0x47, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  // "LG"
               0x42, 0x59, 0x44, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  // "BYD"
               0x53, 0x45, 0x50, 0x4C, 0x4F, 0x53, 0x00, 0x00, 0x00, 0x00,  // "SEPLOS"
               ...]

Результат: CANControlData(
    selectedIndex: 0,
    protocols: ["PYLON", "SMA", "LG", "BYD", "SEPLOS"]
)
.readableProtocol() → "PYLON" (selectedIndex = 0)
```

### Валидность кэша

**Файл:** `ZetaraManager.swift:402-409`

```swift
public func isCacheValidForCurrentDevice() -> Bool {
    guard let peripheral = try? connectedPeripheralSubject.value() else {
        return false
    }

    let currentUUID = peripheral.identifier.uuidString
    return cachedDeviceUUID == currentUUID
}
```

**Зачем нужна проверка?**

```
Сценарий:
1. Подключение к батарее A (UUID: AAA-BBB-CCC)
   → cachedModuleIdData = ID 1
   → cachedCANData = PYLON
   → cachedDeviceUUID = "AAA-BBB-CCC"

2. Отключение от батареи A
   → cleanConnection() → кэш очищен

3. Подключение к батарее B (UUID: XXX-YYY-ZZZ)
   → cachedModuleIdData загружается заново
   → cachedDeviceUUID = "XXX-YYY-ZZZ"

Без проверки:
  → Батарея B могла бы показать настройки батареи A ❌

С проверкой:
  → Кэш всегда соответствует текущему устройству ✅
```

---

## 🔄 ЦЕПОЧКА ВЫЗОВОВ

### Полная последовательность от подключения до отображения

```
┌─────────────────────────────────────────────────────────────────┐
│ ЭТАП 1: ПОЛЬЗОВАТЕЛЬ ПОДКЛЮЧАЕТСЯ К БАТАРЕЕ                     │
│                                                                  │
│  ConnectivityViewController                                     │
│    → tableView(didSelectRowAt:) // Пользователь нажал на батарею│
│    → ZetaraManager.shared.connect(peripheral)                  │
└────────────────────────────┬────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│ ЭТАП 2: ПОДКЛЮЧЕНИЕ УСПЕШНО                                     │
│                                                                  │
│  ZetaraManager.connect() → Observable<ConnectedPeripheral>     │
│                                                                  │
│  .subscribe(onNext: { connectedPeripheral in                   │
│      self?.state = .connected                                  │
│      self?.tableView.reloadData()                              │
│                                                                  │
│      // ⏰ ЗАДЕРЖКА 1.5 СЕКУНДЫ                                 │
│      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {   │
│          self?.loadProtocolsViaQueue()  ← ЗАГРУЗКА ПРОТОКОЛОВ  │
│      }                                                          │
│                                                                  │
│      // ⏰ ЗАДЕРЖКА 0.5 СЕКУНДЫ → ВОЗВРАТ НА HOME ЭКРАН         │
│      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {   │
│          self?.navigationController?.popViewController()        │
│      }                                                          │
│  })                                                             │
└────────────────────────────┬────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│ ЭТАП 3: ЗАГРУЗКА ПРОТОКОЛОВ (loadProtocolsViaQueue)            │
│                                                                  │
│  Файл: ConnectivityViewController.swift:237-294                │
│                                                                  │
│  private func loadProtocolsViaQueue() {                        │
│      print("[PROTOCOLS] Starting protocol loading...")         │
│                                                                  │
│      // 1️⃣ Module ID (немедленно)                              │
│      ZetaraManager.shared.queuedRequest("getModuleId") {       │
│          return ZetaraManager.shared.getModuleId()             │
│      }                                                          │
│      .subscribe(onSuccess: { moduleIdData in                   │
│          // ✅ Сохраняем в кэш                                  │
│          ZetaraManager.shared.cachedModuleIdData = moduleIdData│
│          print("✅ Module ID loaded: \(moduleIdData.readableId())")│
│      })                                                          │
│                                                                  │
│      // 2️⃣ RS485 (через 600ms)                                 │
│      DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {   │
│          ZetaraManager.shared.queuedRequest("getRS485") {      │
│              return ZetaraManager.shared.getRS485()            │
│          }                                                      │
│          .subscribe(onSuccess: { rs485Data in                  │
│              // ✅ Сохраняем в кэш                              │
│              ZetaraManager.shared.cachedRS485Data = rs485Data  │
│              print("✅ RS485 loaded: \(rs485Data.readableProtocol())")│
│          })                                                      │
│      }                                                          │
│                                                                  │
│      // 3️⃣ CAN (через 1200ms)                                  │
│      DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {   │
│          ZetaraManager.shared.queuedRequest("getCAN") {        │
│              return ZetaraManager.shared.getCAN()              │
│          }                                                      │
│          .subscribe(onSuccess: { canData in                    │
│              // ✅ Сохраняем в кэш                              │
│              ZetaraManager.shared.cachedCANData = canData      │
│              print("✅ CAN loaded: \(canData.readableProtocol())")│
│              print("🎉 All protocols loaded!")                 │
│          })                                                      │
│      }                                                          │
│  }                                                              │
└────────────────────────────┬────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│ ЭТАП 4: HOME ЭКРАН - ОБНОВЛЕНИЕ UI                             │
│                                                                  │
│  HomeViewController.updateUI() вызывается каждые 5 сек         │
│  Файл: HomeViewController.swift:506-507                        │
│                                                                  │
│  func updateUI(_ data: Zetara.Data.BMS) {                      │
│      timerView.updateTime(Date())                              │
│                                                                  │
│      let isDeviceActuallyConnected =                           │
│          ZetaraManager.shared.connectedPeripheral() != nil     │
│                                                                  │
│      if isDeviceActuallyConnected {                            │
│          // Обновляем все компоненты...                        │
│                                                                  │
│          // 🔑 КЛЮЧЕВОЙ МОМЕНТ - Обновление протоколов         │
│          protocolParametersView.updateValues()                 │
│      }                                                          │
│  }                                                              │
└────────────────────────────┬────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────────┐
│ ЭТАП 5: ОБНОВЛЕНИЕ ЗНАЧЕНИЙ (updateValues)                     │
│                                                                  │
│  ProtocolParametersView.updateValues()                         │
│  Файл: ProtocolParametersView.swift:58-90                     │
│                                                                  │
│  func updateValues() {                                         │
│      print("[PROTOCOLS VIEW] Updating values...")             │
│                                                                  │
│      // 1️⃣ Module ID                                           │
│      if let moduleIdData =                                     │
│         ZetaraManager.shared.cachedModuleIdData {              │
│          let value = moduleIdData.readableId()  // "ID 1"      │
│          print("[PROTOCOLS VIEW] Module ID: \(value)")         │
│          moduleIdBlock.setValue(value)          // ← Обновление│
│      } else {                                                   │
│          print("[PROTOCOLS VIEW] Module ID: no data")          │
│          moduleIdBlock.setValue("--")           // ← Прочерки  │
│      }                                                          │
│                                                                  │
│      // 2️⃣ CAN                                                  │
│      if let canData = ZetaraManager.shared.cachedCANData {    │
│          let value = canData.readableProtocol()  // "PYLON"    │
│          print("[PROTOCOLS VIEW] CAN: \(value)")               │
│          canBlock.setValue(value)                              │
│      } else {                                                   │
│          print("[PROTOCOLS VIEW] CAN: no data")                │
│          canBlock.setValue("--")                               │
│      }                                                          │
│                                                                  │
│      // 3️⃣ RS485                                                │
│      if let rs485Data =                                        │
│         ZetaraManager.shared.cachedRS485Data {                 │
│          let value = rs485Data.readableProtocol()  // "Generic"│
│          print("[PROTOCOLS VIEW] RS485: \(value)")             │
│          rs485Block.setValue(value)                            │
│      } else {                                                   │
│          print("[PROTOCOLS VIEW] RS485: no data")              │
│          rs485Block.setValue("--")                             │
│      }                                                          │
│  }                                                              │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📥 ЗАГРУЗКА ПРОТОКОЛОВ

### loadProtocolsViaQueue() - детальный разбор

**Файл:** `ConnectivityViewController.swift:237-294`

**Когда вызывается:**

Через 1.5 секунды после успешного подключения к батарее.

**Зачем задержка?**

Даем время Bluetooth стабилизироваться после подключения. Немедленные запросы могут привести к ошибкам.

### Последовательность запросов

#### 1. Module ID (T = 0ms)

```swift
// Запрос немедленно
ZetaraManager.shared.queuedRequest("getModuleId") { () -> Maybe<Zetara.Data.ModuleIdControlData> in
    return ZetaraManager.shared.getModuleId()
}
.subscribe(onSuccess: { (moduleIdData: Zetara.Data.ModuleIdControlData) in
    print("[PROTOCOLS] ✅ Module ID loaded: \(moduleIdData.readableId())")

    // Сохраняем в кэш
    ZetaraManager.shared.cachedModuleIdData = moduleIdData

}, onError: { error in
    print("[PROTOCOLS] ❌ Failed to load Module ID: \(error)")
})
.disposed(by: disposeBag)
```

**Bluetooth запрос:**

```
Write:  10 02 00 71 65
        ││ ││ ││ └└─ CRC16
        ││ ││ └─ length
        ││ └─ function (getModuleId)
        └─ address

Read:   10 02 01 01 ... CRC16
        ││ ││ ││ └─ moduleId = 1
        ││ ││ └─ length
        ││ └─ function
        └─ address

Результат: ModuleIdControlData(moduleId: 1)
```

#### 2. RS485 (T = 600ms)

```swift
// Запрос через 600ms после Module ID
DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
    guard let self = self else { return }

    ZetaraManager.shared.queuedRequest("getRS485") { () -> Maybe<Zetara.Data.RS485ControlData> in
        return ZetaraManager.shared.getRS485()
    }
    .subscribe(onSuccess: { (rs485Data: Zetara.Data.RS485ControlData) in
        print("[PROTOCOLS] ✅ RS485 loaded: \(rs485Data.readableProtocol())")

        // Сохраняем в кэш
        ZetaraManager.shared.cachedRS485Data = rs485Data

    }, onError: { error in
        print("[PROTOCOLS] ❌ Failed to load RS485: \(error)")
    })
    .disposed(by: self.disposeBag)
}
```

**Bluetooth запрос:**

```
Write:  10 03 00 70 F5
        ││ ││ ││ └└─ CRC16
        ││ ││ └─ length
        ││ └─ function (getRS485)
        └─ address

Read:   10 03 03 00 03 [протоколы...] CRC16
        ││ ││ ││ ││ └─ количество протоколов = 3
        ││ ││ ││ └─ selectedIndex = 0
        ││ ││ └─ length
        ││ └─ function
        └─ address

Результат: RS485ControlData(
    selectedIndex: 0,
    protocols: ["Generic", "Pylontech", "SMA"]
)
```

#### 3. CAN (T = 1200ms)

```swift
// Запрос через 1200ms после Module ID
DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
    guard let self = self else { return }

    ZetaraManager.shared.queuedRequest("getCAN") { () -> Maybe<Zetara.Data.CANControlData> in
        return ZetaraManager.shared.getCAN()
    }
    .subscribe(onSuccess: { (canData: Zetara.Data.CANControlData) in
        print("[PROTOCOLS] ✅ CAN loaded: \(canData.readableProtocol())")

        // Сохраняем в кэш
        ZetaraManager.shared.cachedCANData = canData

        print("[PROTOCOLS] 🎉 All protocols loaded successfully!")

    }, onError: { error in
        print("[PROTOCOLS] ❌ Failed to load CAN: \(error)")
    })
    .disposed(by: self.disposeBag)
}
```

**Bluetooth запрос:**

```
Write:  10 04 00 72 C5
        ││ ││ ││ └└─ CRC16
        ││ ││ └─ length
        ││ └─ function (getCAN)
        └─ address

Read:   10 04 03 00 05 [протоколы...] CRC16
        ││ ││ ││ ││ └─ количество протоколов = 5
        ││ ││ ││ └─ selectedIndex = 0
        ││ ││ └─ length
        ││ └─ function
        └─ address

Результат: CANControlData(
    selectedIndex: 0,
    protocols: ["PYLON", "SMA", "LG", "BYD", "SEPLOS"]
)
```

---

## 🔄 ОБНОВЛЕНИЕ UI

### updateValues() - детальный разбор

**Файл:** `ProtocolParametersView.swift:58-90`

**Когда вызывается:**

Каждые 5 секунд через `HomeViewController.updateUI()`.

**Почему каждые 5 секунд?**

Данные протоколов могут меняться! Если пользователь:
1. Зашел на Settings экран
2. Изменил Module ID с 1 на 2
3. Нажал Save
4. Вернулся на Home экран

→ Кэш обновится, и Home экран должен показать новое значение.

### Логика отображения

```swift
func updateValues() {
    print("[PROTOCOLS VIEW] Updating values...")

    // Module ID
    if let moduleIdData = ZetaraManager.shared.cachedModuleIdData {
        // ✅ ЕСТЬ КЭШ → Показываем значение
        let value = moduleIdData.readableId()
        print("[PROTOCOLS VIEW] Module ID: \(value)")
        moduleIdBlock.setValue(value)
    } else {
        // ❌ НЕТ КЭША → Показываем прочерки
        print("[PROTOCOLS VIEW] Module ID: no data, showing --")
        moduleIdBlock.setValue("--")
    }

    // CAN (аналогично)
    if let canData = ZetaraManager.shared.cachedCANData {
        let value = canData.readableProtocol()
        print("[PROTOCOLS VIEW] CAN: \(value)")
        canBlock.setValue(value)
    } else {
        print("[PROTOCOLS VIEW] CAN: no data, showing --")
        canBlock.setValue("--")
    }

    // RS485 (аналогично)
    if let rs485Data = ZetaraManager.shared.cachedRS485Data {
        let value = rs485Data.readableProtocol()
        print("[PROTOCOLS VIEW] RS485: \(value)")
        rs485Block.setValue(value)
    } else {
        print("[PROTOCOLS VIEW] RS485: no data, showing --")
        rs485Block.setValue("--")
    }
}
```

### Когда показываются прочерки ("--")?

**3 сценария:**

#### 1. При инициализации (viewDidLoad)

```
HomeViewController.viewDidLoad()
    ↓
setupHeaderView() → создание ProtocolParametersView
    ↓
ProtocolBlock.init() → valueLabel.text = "--"
    ↓
Кэш еще пустой (cachedModuleIdData = nil)
    ↓
┌──────────────────────────────┐
│  --    --    --              │
│Selected Selected Selected    │
│  ID      CAN     RS485       │
└──────────────────────────────┘
```

#### 2. В первые 2-3 секунды после подключения

```
T = 0.5s  → Подключение установлено
          → Возврат на HomeViewController
          → Кэш еще пустой
          → Блоки: "--"  "--"  "--"

T = 1.5s  → loadProtocolsViaQueue() начал работу

T = 1.8s  → Module ID загружен ✅
          → cachedModuleIdData != nil
          → updateValues() (следующий цикл Timer)
          → Блоки: "ID 1"  "--"  "--"

T = 2.4s  → RS485 загружен ✅
          → cachedRS485Data != nil
          → updateValues() (следующий цикл Timer)
          → Блоки: "ID 1"  "--"  "Generic"

T = 3.0s  → CAN загружен ✅
          → cachedCANData != nil
          → updateValues() (следующий цикл Timer)
          → Блоки: "ID 1"  "PYLON"  "Generic"  ✅
```

#### 3. При отключении от устройства

```
Устройство отключилось
    ↓
observeDisconnect() → cleanConnection()
    ↓
cachedModuleIdData = nil
cachedRS485Data = nil
cachedCANData = nil
    ↓
connectedPeripheralSubject.onNext(nil)
    ↓
HomeViewController получает nil
    ↓
updateTitle(nil) → "Tap to Connect"
    ↓
updateUI() вызывается
    ↓
isDeviceActuallyConnected = false
    ↓
Все параметры → прочерки
    ↓
protocolParametersView.updateValues()
    ↓
Блоки: "--"  "--"  "--"
```

---

## 🧹 ОЧИСТКА ПРИ ОТКЛЮЧЕНИИ

### cleanConnection() - детальный разбор

**Файл:** `ZetaraManager.swift:254-277`

```swift
func cleanConnection() {
    print("[CONNECTION] Cleaning connection state")

    // 1. Останавливаем мониторинг подключения
    stopConnectionMonitor()

    // 2. Очищаем Request Queue
    lastRequestTime = nil
    print("[QUEUE] Request queue cleared")

    // 3. Останавливаем Timer обновления BMS данных
    timer?.invalidate()
    timer = nil

    // 4. Отменяем Bluetooth subscriptions
    connectionDisposable?.dispose()

    // 🔴 5. ОЧИЩАЕМ КЭШ ПРОТОКОЛОВ
    cachedModuleIdData = nil   // ← Module ID = nil
    cachedRS485Data = nil      // ← RS485 = nil
    cachedCANData = nil        // ← CAN = nil
    cachedDeviceUUID = nil     // ← UUID = nil

    // 6. Отправляем nil в Observable
    connectedPeripheralSubject.onNext(nil)

    print("[CONNECTION] Connection state cleaned")
}
```

**Когда вызывается:**

1. **Отключение устройства** - `observeDisconnect()` обнаружило потерю связи
2. **Connection Monitor** - обнаружена "phantom connection"
3. **Ошибка запроса** - `getBMSData()` получил ошибку

**Цепочка событий после cleanConnection():**

```
cleanConnection()
    ↓
cachedModuleIdData = nil
cachedRS485Data = nil
cachedCANData = nil
    ↓
connectedPeripheralSubject.onNext(nil)
    ↓
HomeViewController получает уведомление через RxSwift
    ↓
.subscribe { peripheral in
    self?.updateTitle(peripheral)
}
    ↓
updateTitle(nil)
    ↓
timerView.setHidden(true)
bluetoothConnectionView.updateDeviceName(nil)
    ↓
BluetoothConnectionView показывает "Tap to Connect"
    ↓
Timer продолжает работать (каждые 5 сек)
    ↓
updateUI() вызывается
    ↓
isDeviceActuallyConnected = false
    ↓
Все компоненты → прочерки:
  - batteryParametersView: "-- V", "-- A", "-- °C"
  - protocolParametersView: "--", "--", "--"
  - summaryView: прочерки
  - cellVoltageView: прочерки
  - temperatureView: прочерки
    ↓
┌──────────────────────────────────────┐
│ 🔵 Tap to Connect           [+]     │ ← Нет подключения ✅
├──────────────────────────────────────┤
│   🔋 0%                             │ ← Сброшено ✅
│   -- V  -- A  -- °C                 │ ← ПРОЧЕРКИ! ✅
│                                      │
│   --    --    --                    │ ← Протоколы = прочерки ✅
│  Selected Selected Selected          │
│    ID      CAN     RS485             │
│                                      │
│  Status: Standby                    │ ← Standby ✅
└──────────────────────────────────────┘
```

---

## ⏱️ ТАЙМЛАЙН СОБЫТИЙ

### Полная последовательность с временными метками

```
┌────────────────────────────────────────────────────────────────┐
│                  TIMELINE ПОДКЛЮЧЕНИЯ                           │
└────────────────────────────────────────────────────────────────┘

T = 0.0 сек   ┌─────────────────────────────────────────────────┐
              │ Пользователь нажал "Connect" на ConnectivityVC │
              │ → ZetaraManager.connect() начал работу         │
              └─────────────────────────────────────────────────┘

T = 0.5 сек   ┌─────────────────────────────────────────────────┐
              │ Bluetooth подключение установлено ✅           │
              │ → connectedPeripheralSubject.onNext(peripheral)│
              │ → startRefreshBMSData() (Timer каждые 5 сек)  │
              │ → startConnectionMonitor() (проверка каждые 2с)│
              │ → navigationController?.popViewController()    │
              │ → Возврат на HomeViewController ✅             │
              └─────────────────────────────────────────────────┘

T = 1.5 сек   ┌─────────────────────────────────────────────────┐
              │ loadProtocolsViaQueue() начал работу           │
              │ → Request 1: getModuleId() через queuedRequest │
              └─────────────────────────────────────────────────┘

T = 1.8 сек   ┌─────────────────────────────────────────────────┐
              │ Request 1 завершен ✅                          │
              │ → cachedModuleIdData = ModuleIdControlData(1) │
              │ → print("✅ Module ID loaded: ID 1")          │
              └─────────────────────────────────────────────────┘

T = 2.1 сек   ┌─────────────────────────────────────────────────┐
              │ Request 2: getRS485() (задержка 600ms)        │
              │ → Request Queue добавляет 220ms wait           │
              └─────────────────────────────────────────────────┘

T = 2.4 сек   ┌─────────────────────────────────────────────────┐
              │ Request 2 завершен ✅                          │
              │ → cachedRS485Data = RS485ControlData(...)     │
              │ → print("✅ RS485 loaded: Generic")           │
              └─────────────────────────────────────────────────┘

T = 2.7 сек   ┌─────────────────────────────────────────────────┐
              │ Request 3: getCAN() (задержка 1200ms)         │
              │ → Request Queue добавляет 440ms wait           │
              └─────────────────────────────────────────────────┘

T = 3.0 сек   ┌─────────────────────────────────────────────────┐
              │ Request 3 завершен ✅                          │
              │ → cachedCANData = CANControlData(...)         │
              │ → print("✅ CAN loaded: PYLON")               │
              │ → print("🎉 All protocols loaded!")           │
              └─────────────────────────────────────────────────┘

T = 5.0 сек   ┌─────────────────────────────────────────────────┐
              │ Timer срабатывает (ПЕРВЫЙ РАЗ)                │
              │ → getBMSData() → bmsDataSubject.onNext()      │
              │ → updateUI(bmsData) вызывается                │
              │ → protocolParametersView.updateValues()       │
              │    ├─ Module ID: "ID 1" ✅                    │
              │    ├─ CAN: "PYLON" ✅                         │
              │    └─ RS485: "Generic" ✅                     │
              │ → ПЕРВОЕ ОТОБРАЖЕНИЕ В UI                     │
              └─────────────────────────────────────────────────┘

T = 10.0 сек  ┌─────────────────────────────────────────────────┐
              │ Timer срабатывает (ВТОРОЙ РАЗ)                │
              │ → updateUI() → updateValues()                 │
              │ → Блоки обновляются из кэша                   │
              └─────────────────────────────────────────────────┘

T = 15.0 сек  ┌─────────────────────────────────────────────────┐
              │ Timer срабатывает (ТРЕТИЙ РАЗ)                │
              │ → updateUI() → updateValues()                 │
              │ → ...и так далее каждые 5 секунд              │
              └─────────────────────────────────────────────────┘
```

---

## 🔧 REQUEST QUEUE МЕХАНИЗМ

### Зачем нужны задержки?

**Проблема:** Bluetooth не может обрабатывать множество одновременных запросов.

**Решение:** Request Queue + дополнительные задержки (`asyncAfter`).

### Request Queue

**Файл:** `ZetaraManager.swift:302-346`

```swift
public func queuedRequest<T>(_ requestName: String,
                             _ request: @escaping () -> Maybe<T>) -> Maybe<T> {
    return Maybe.create { observer in
        self.requestQueue.async {
            // Ждем если прошло < 500ms с последнего запроса
            if let lastTime = self.lastRequestTime {
                let elapsed = Date().timeIntervalSince(lastTime)
                if elapsed < self.minimumRequestInterval {  // 500ms
                    let waitTime = self.minimumRequestInterval - elapsed

                    print("[QUEUE] ⏳ Waiting \(Int(waitTime * 1000))ms before \(requestName)")

                    Thread.sleep(forTimeInterval: waitTime)
                }
            }

            // Обновляем время последнего запроса
            self.lastRequestTime = Date()

            print("[QUEUE] 🚀 Executing \(requestName)")

            // Выполняем запрос
            request().subscribe(...)
        }
    }
}
```

### asyncAfter задержки

```swift
// Module ID - немедленно (T = 0ms)
queuedRequest("getModuleId") { ... }

// RS485 - через 600ms (T = 600ms)
DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
    queuedRequest("getRS485") { ... }
}

// CAN - через 1200ms (T = 1200ms)
DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
    queuedRequest("getCAN") { ... }
}
```

### Расчет реального времени выполнения

```
┌────────────────────────────────────────────────────────────┐
│ Request 1: Module ID                                       │
│                                                            │
│ T=0ms:    Запуск queuedRequest("getModuleId")            │
│           → lastRequestTime = nil                         │
│           → Нет ожидания                                  │
│           → Немедленное выполнение                        │
│                                                            │
│ T=320ms:  Ответ получен ✅                                │
│           → lastRequestTime = T=320ms                     │
│           → cachedModuleIdData = ModuleIdControlData(1)   │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│ Request 2: RS485                                           │
│                                                            │
│ T=600ms:  asyncAfter сработал                             │
│           → Запуск queuedRequest("getRS485")              │
│           → Request Queue проверяет:                      │
│             elapsed = 600ms - 320ms = 280ms               │
│             elapsed < 500ms? ДА!                          │
│             waitTime = 500ms - 280ms = 220ms              │
│           → Thread.sleep(220ms) ⏳                        │
│                                                            │
│ T=820ms:  Начало выполнения (после ожидания)             │
│           → lastRequestTime = T=820ms                     │
│                                                            │
│ T=1140ms: Ответ получен ✅                                │
│           → cachedRS485Data = RS485ControlData(...)       │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│ Request 3: CAN                                             │
│                                                            │
│ T=1200ms: asyncAfter сработал                             │
│           → Запуск queuedRequest("getCAN")                │
│           → Request Queue проверяет:                      │
│             elapsed = 1200ms - 1140ms = 60ms              │
│             elapsed < 500ms? ДА!                          │
│             waitTime = 500ms - 60ms = 440ms               │
│           → Thread.sleep(440ms) ⏳                        │
│                                                            │
│ T=1640ms: Начало выполнения (после ожидания)             │
│           → lastRequestTime = T=1640ms                    │
│                                                            │
│ T=1960ms: Ответ получен ✅                                │
│           → cachedCANData = CANControlData(...)           │
│           → print("🎉 All protocols loaded!")             │
└────────────────────────────────────────────────────────────┘
```

**Итого:** Гарантированный интервал **минимум 500ms** между любыми запросами.

---

## 📋 ЛОГИРОВАНИЕ

### Пример логов успешной загрузки

```
[PROTOCOLS] Starting protocol loading after connection...

[QUEUE] 📥 Request queued: getModuleId
[QUEUE] 🚀 Executing getModuleId
getting bms data write data: 1002007165
[QUEUE] ✅ getModuleId completed in 320ms
[PROTOCOLS] ✅ Module ID loaded: ID 1

[QUEUE] 📥 Request queued: getRS485
[QUEUE] ⏳ Waiting 220ms before getRS485
[QUEUE] 🚀 Executing getRS485
getting bms data write data: 10030070F5
[QUEUE] ✅ getRS485 completed in 320ms
[PROTOCOLS] ✅ RS485 loaded: Generic

[QUEUE] 📥 Request queued: getCAN
[QUEUE] ⏳ Waiting 440ms before getCAN
[QUEUE] 🚀 Executing getCAN
getting bms data write data: 10040072C5
[QUEUE] ✅ getCAN completed in 320ms
[PROTOCOLS] ✅ CAN loaded: PYLON
[PROTOCOLS] 🎉 All protocols loaded successfully!

[PROTOCOLS VIEW] Updating values...
[PROTOCOLS VIEW] Module ID: ID 1
[PROTOCOLS VIEW] CAN: PYLON
[PROTOCOLS VIEW] RS485: Generic
```

### Пример логов при отключении

```
[CONNECTION] ⚠️ Phantom connection detected!
[CONNECTION] Device: Husky Battery X
[CONNECTION] Expected state: connected
[CONNECTION] Actual state: disconnected
[CONNECTION] Action: Cleaning connection automatically

[CONNECTION] Cleaning connection state
[CONNECTION] Connection monitor stopped
[QUEUE] Request queue cleared
[CONNECTION] Connection state cleaned

[PROTOCOLS VIEW] Updating values...
[PROTOCOLS VIEW] Module ID: no data, showing --
[PROTOCOLS VIEW] CAN: no data, showing --
[PROTOCOLS VIEW] RS485: no data, showing --
```

---

## 🔍 ВАЖНЫЕ ДЕТАЛИ

### 1. Почему задержка 1.5 сек перед загрузкой?

```swift
// ConnectivityViewController.swift:145-147
DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
    self?.loadProtocolsViaQueue()
}
```

**Причины:**

1. **Стабилизация Bluetooth** - после `connect()` Bluetooth соединению нужно время
2. **Discovery characteristics** - нужно время на обнаружение write/notify characteristics
3. **Предотвращение ошибок** - немедленные запросы могут привести к timeout

**Альтернатива:** Можно было бы слушать события Bluetooth, но это сложнее.

### 2. Почему updateValues() вызывается каждые 5 сек?

**Причина:** Данные протоколов **могут измениться** на Settings экране!

**Сценарий:**

```
1. Home экран показывает "ID 1", "PYLON", "Generic" ✅

2. Пользователь открывает Settings экран
   → Видит текущие настройки

3. Пользователь меняет Module ID с 1 на 2
   → setModuleId(2) отправляет команду BMS
   → Батарея сохраняет новое значение

4. Пользователь нажимает Save
   → Settings экран обновляет кэш:
     cachedModuleIdData = ModuleIdControlData(moduleId: 2)

5. Пользователь возвращается на Home экран
   → Следующий updateUI() (через макс 5 сек)
   → updateValues() читает из кэша
   → Блоки показывают "ID 2" ✅ (обновлено!)
```

**Без регулярного обновления:**

```
Home экран продолжал бы показывать "ID 1" ❌ (устаревшие данные)
```

### 3. Проверка валидности кэша

```swift
// ZetaraManager.swift:402-409
public func isCacheValidForCurrentDevice() -> Bool {
    guard let peripheral = try? connectedPeripheralSubject.value() else {
        return false
    }

    let currentUUID = peripheral.identifier.uuidString
    return cachedDeviceUUID == currentUUID
}
```

**Когда используется:** (В текущей реализации не используется активно, но есть для будущего)

**Зачем нужна:**

Если пользователь:
1. Подключился к батарее A (UUID: AAA-BBB-CCC)
2. Отключился без вызова `cleanConnection()` (редко, но возможно)
3. Подключился к батарее B (UUID: XXX-YYY-ZZZ)

→ Без проверки батарея B показывала бы настройки батареи A ❌

→ С проверкой можно обнаружить несоответствие и перезагрузить протоколы ✅

### 4. Почему не показываем Loading индикатор?

**Причина:** Протоколы загружаются **в фоне** пока пользователь смотрит на BMS данные.

**Таймлайн:**

```
T = 0.5s  → Возврат на Home экран
          → Пользователь видит батарею, напряжение, ток
          → Блоки протоколов: "--"  "--"  "--" (не критично)

T = 3.0s  → Протоколы загружены
          → Блоки постепенно заполняются

T = 5.0s  → Первое отображение
          → Пользователь видит: "ID 1", "PYLON", "Generic"
```

**Преимущество:** Пользователь не ждет, сразу видит важные данные (заряд, напряжение).

---

## 📁 СВЯЗАННЫЕ ФАЙЛЫ

### UI Компонент

| Файл | Строки | Описание |
|------|--------|----------|
| **ProtocolParametersView.swift** | 163 | Компонент для отображения протоколов |
| ├─ updateValues | 58-90 | **ГЛАВНЫЙ МЕТОД** - обновление значений из кэша |
| ├─ ProtocolBlock | 96-162 | Отдельный блок для одного протокола |
| ├─ init | 115-129 | Инициализация блока, установка начального "--" |
| └─ setValue | 159-161 | Обновление значения в блоке |

### Загрузка протоколов

| Файл | Строки | Описание |
|------|--------|----------|
| **ConnectivityViewController.swift** | 314 | Контроллер подключения к устройству |
| ├─ didSelectRowAt | 122-158 | Обработка нажатия на устройство |
| ├─ connect | 140-156 | Подключение к устройству, запуск загрузки |
| └─ loadProtocolsViaQueue | 237-294 | **ЗАГРУЗКА ПРОТОКОЛОВ** - 3 последовательных запроса |

### Bluetooth Manager

| Файл | Строки | Описание |
|------|--------|----------|
| **ZetaraManager.swift** | 643 | Менеджер Bluetooth коммуникации |
| ├─ cachedModuleIdData | 71 | Кэш Module ID |
| ├─ cachedRS485Data | 72 | Кэш RS485 |
| ├─ cachedCANData | 73 | Кэш CAN |
| ├─ cachedDeviceUUID | 76 | UUID устройства для валидации кэша |
| ├─ cleanConnection | 254-277 | **ОЧИСТКА КЭША** при отключении |
| ├─ isCacheValidForCurrentDevice | 402-409 | Проверка валидности кэша |
| ├─ getModuleId | 547-549 | Запрос Module ID через Bluetooth |
| ├─ getRS485 | 557-559 | Запрос RS485 через Bluetooth |
| ├─ getCAN | 566-574 | Запрос CAN через Bluetooth |
| └─ queuedRequest | 302-346 | **Request Queue** - очередь с 500ms интервалом |

### Структуры данных

| Файл | Строки | Описание |
|------|--------|----------|
| **ControlData.swift** | 204 | Структуры данных протоколов |
| ├─ ModuleIdControlData | 69-102 | Данные Module ID (1-16) |
| │  ├─ moduleId | 70 | Текущий Module ID |
| │  ├─ supportedIds | 72 | Array(1...16) |
| │  ├─ readableId | 91-93 | "ID X" текущий |
| │  └─ init | 74-85 | Парсинг байтов → структура |
| ├─ RS485ControlData | 104-139 | Данные RS485 протокола |
| │  ├─ selectedIndex | 106 | Индекс выбранного протокола |
| │  ├─ protocols | 107 | Список всех протоколов |
| │  ├─ readableProtocol | 123-125 | Текущий протокол |
| │  └─ init | 109-121 | Парсинг байтов → структура |
| ├─ CANControlData | 141-175 | Данные CAN протокола |
| │  ├─ selectedIndex | 142 | Индекс выбранного протокола |
| │  ├─ protocols | 143 | Список всех протоколов |
| │  ├─ readableProtocol | 159-161 | Текущий протокол |
| │  └─ init | 145-157 | Парсинг байтов → структура |
| └─ parseProtocols | 177-193 | Парсинг списка протоколов из байтов |

### Home Controller

| Файл | Строки | Описание |
|------|--------|----------|
| **HomeViewController.swift** | 653 | Главный контроллер Home экрана |
| ├─ protocolParametersView | 82 | Ссылка на компонент протоколов |
| ├─ setupHeaderView | 202-459 | Создание UI, включая protocolParametersView |
| └─ updateUI | 461-590 | **ОБНОВЛЕНИЕ UI** - вызов updateValues() (строка 507) |

---

## 📝 ЛОГИРОВАНИЕ v3.0

**Дата добавления:** 07.10.2025
**Причина:** Обеспечить удаленную диагностику протоколов без подключения через Xcode

### Проблема

После рефакторинга v2.0 была удалена избыточная система логирования (AppLogger, ZetaraLogger), которая генерировала 109KB логов за 2 минуты (231 событие).

**НО:** Разработчик не имеет физического доступа к батарее и не может подключиться через Xcode для просмотра print() логов в console.

**Требуется:** Минимальное целевое логирование для удаленной диагностики через email (JSON файл из DiagnosticsViewController).

### Решение: Легковесное логирование

#### 1. Массив логов в ProtocolDataManager

**Файл:** `Zetara/Sources/ProtocolDataManager.swift`

```swift
// Хранение последних 30 событий
private var protocolLogs: [String] = []
private let maxLogs = 30

public func logProtocolEvent(_ message: String) {
    let timestamp = dateFormatter.string(from: Date())
    let logEntry = "[\(timestamp)] \(message)"

    protocolLogs.insert(logEntry, at: 0) // Новые сверху
    if protocolLogs.count > maxLogs {
        protocolLogs.removeLast()
    }

    print(logEntry) // Также в Xcode console
}

public func getProtocolLogs() -> [String] {
    return protocolLogs
}
```

#### 2. Что логируется

**В ProtocolDataManager:**
- ✅ Успешная загрузка: `[PROTOCOL MANAGER] ✅ Module ID loaded: ID 1`
- ❌ Ошибка: `[PROTOCOL MANAGER] ❌ Failed to load Module ID after retry: timeout`
- 🎉 Завершение: `[PROTOCOL MANAGER] 🎉 All protocols loaded successfully!`
- 🧹 Очистка: `[PROTOCOL MANAGER] Clearing all protocols`

**В ZetaraManager (Request Queue):**
- 📥 Запрос добавлен: `[QUEUE] 📥 Request queued: getModuleId`
- ⏳ Ожидание: `[QUEUE] ⏳ Waiting 200ms before getModuleId`
- 🚀 Выполнение: `[QUEUE] 🚀 Executing getModuleId`
- ✅ Успех: `[QUEUE] ✅ getModuleId completed in 234ms`
- ❌ Ошибка: `[QUEUE] ❌ getModuleId failed in 5000ms: timeout`

**В ZetaraManager (Connection Monitor):**
- ⚠️ Phantom: `[CONNECTION] ⚠️ Phantom connection detected! Device: BB-..., State: disconnected`

#### 3. Интеграция в DiagnosticsViewController

**Файл:** `BatteryMonitorBL/DiagnosticsViewController.swift`

```swift
private func createProtocolInfo() -> [String: Any] {
    // Получаем текущие значения
    var moduleId = "--"
    var canProtocol = "--"
    var rs485Protocol = "--"

    if let moduleIdData = try? ZetaraManager.shared.protocolDataManager.moduleIdSubject.value() {
        moduleId = moduleIdData.readableId()
    }
    // ... аналогично для CAN и RS485

    // Получаем логи
    let protocolLogs = ZetaraManager.shared.protocolDataManager.getProtocolLogs()

    // Статистика
    let errorLogs = protocolLogs.filter { $0.contains("❌") }
    let successLogs = protocolLogs.filter { $0.contains("✅") }
    let warningLogs = protocolLogs.filter { $0.contains("⚠️") }

    return [
        "currentValues": [
            "moduleId": moduleId,
            "canProtocol": canProtocol,
            "rs485Protocol": rs485Protocol
        ],
        "recentLogs": protocolLogs,
        "statistics": [
            "totalLogs": protocolLogs.count,
            "errors": errorLogs.count,
            "successes": successLogs.count,
            "warnings": warningLogs.count
        ],
        "lastUpdateTime": dateFormatter.string(from: Date())
    ]
}
```

#### 4. Структура JSON секции protocolInfo

```json
{
  "protocolInfo": {
    "currentValues": {
      "moduleId": "ID 1",
      "canProtocol": "PYLON",
      "rs485Protocol": "Modbus"
    },
    "recentLogs": [
      "[11:19:32] [PROTOCOL MANAGER] 🎉 All protocols loaded successfully!",
      "[11:19:32] [PROTOCOL MANAGER] ✅ CAN loaded: PYLON",
      "[11:19:31] [QUEUE] ✅ getCAN completed in 234ms",
      "[11:19:31] [QUEUE] 🚀 Executing getCAN",
      "[11:19:31] [QUEUE] ⏳ Waiting 200ms before getCAN",
      "[11:19:31] [PROTOCOL MANAGER] ✅ RS485 loaded: Modbus",
      "[11:19:30] [QUEUE] ✅ getRS485 completed in 187ms",
      "[11:19:30] [QUEUE] 🚀 Executing getRS485",
      "[11:19:30] [PROTOCOL MANAGER] ✅ Module ID loaded: ID 1",
      "[11:19:29] [QUEUE] ✅ getModuleId completed in 156ms",
      "[11:19:29] [QUEUE] 🚀 Executing getModuleId",
      "[11:19:29] [QUEUE] 📥 Request queued: getCAN",
      "[11:19:29] [QUEUE] 📥 Request queued: getRS485",
      "[11:19:29] [QUEUE] 📥 Request queued: getModuleId",
      "[11:19:27] [PROTOCOL MANAGER] Starting protocol loading after 1.5s delay..."
    ],
    "statistics": {
      "totalLogs": 15,
      "errors": 0,
      "successes": 4,
      "warnings": 0
    },
    "lastUpdateTime": "11:19:32 07.10.2025"
  }
}
```

### Преимущества нового логирования

| Критерий | Старое (AppLogger) | Новое (v3.0) |
|----------|-------------------|--------------|
| **Размер** | 109KB (231 событие) | ~2-3KB (30 событий) |
| **Избыточность** | 90% дублирования | 0% дублирования |
| **Фокус** | Все события всех экранов | Только протоколы |
| **Удаленная диагностика** | ✅ Да (через JSON) | ✅ Да (через JSON) |
| **Xcode console** | ❌ Нет | ✅ Да (print остались) |
| **Память** | Все в памяти | Только последние 30 |
| **Сложность кода** | Высокая (AppLogger + ZetaraLogger) | Низкая (один массив) |

### Что видит разработчик удаленно

**В JSON файле (email attachment):**
1. ✅ Текущие значения протоколов (Module ID, CAN, RS485)
2. ✅ Последние 30 событий с timestamp
3. ✅ Статистику (errors/successes/warnings)
4. ✅ Timing каждого запроса (completed in Xms)
5. ✅ Phantom connection события
6. ✅ Retry attempts

**Этого достаточно для:**
- Диагностики timeout проблем
- Проверки что Request Queue работает
- Обнаружения phantom connections
- Понимания какой протокол не загружается

### Пример реального лога (с ошибками)

```json
{
  "recentLogs": [
    "[11:18:09] [PROTOCOL MANAGER] ❌ Failed to load CAN after retry: timeout",
    "[11:18:09] [QUEUE] ❌ getCAN failed in 10000ms: timeout",
    "[11:17:59] [PROTOCOL MANAGER] ❌ Failed to load RS485 after retry: timeout",
    "[11:17:59] [QUEUE] ❌ getRS485 failed in 10000ms: timeout",
    "[11:17:49] [PROTOCOL MANAGER] ❌ Failed to load Module ID after retry: timeout",
    "[11:17:49] [QUEUE] ❌ getModuleId failed in 10000ms: timeout",
    "[11:17:39] [QUEUE] 🚀 Executing getCAN",
    "[11:17:39] [QUEUE] 🚀 Executing getRS485",
    "[11:17:39] [QUEUE] 🚀 Executing getModuleId",
    "[11:17:39] [PROTOCOL MANAGER] Starting protocol loading after 1.5s delay..."
  ],
  "statistics": {
    "totalLogs": 10,
    "errors": 6,
    "successes": 0,
    "warnings": 0
  }
}
```

**Диагноз:** Все 3 протокола timeout после 10 секунд → проблема с Bluetooth соединением или батарея не отвечает.

---

## 🎯 РЕЗЮМЕ

### Как работают блоки протоколов:

✅ **Загрузка:**
При подключении → через 1.5 сек → `loadProtocolsViaQueue()` → 3 последовательных запроса с задержками (0ms, 600ms, 1200ms) → сохранение в кэш ZetaraManager

✅ **Отображение:**
Каждые 5 сек `updateUI()` → `protocolParametersView.updateValues()` → чтение из кэша → обновление UI блоков

✅ **Очистка:**
При отключении `cleanConnection()` → кэш = nil → блоки показывают "--"

### Ключевые моменты:

- **Кэш в ZetaraManager** - глобальное хранилище данных протоколов
- **Request Queue** - гарантированный интервал 500ms между запросами
- **asyncAfter задержки** - дополнительные интервалы 600ms и 1200ms
- **updateValues() каждые 5 сек** - синхронизация с возможными изменениями на Settings
- **Прочерки ("--")** - показываются при отсутствии кэша (инициализация, загрузка, отключение)

### Таймлайн:

- **T=0.5s** - Подключение установлено, возврат на Home
- **T=1.5s** - Начало загрузки протоколов
- **T=3.0s** - Все протоколы загружены в кэш
- **T=5.0s** - Первое отображение в UI
- **T=10s, 15s, ...** - Обновление каждые 5 сек

### Важные файлы:

- `ProtocolParametersView.swift` - UI компонент
- `ConnectivityViewController.swift:237-294` - Загрузка протоколов
- `HomeViewController.swift:506-507` - Вызов updateValues()
- `ZetaraManager.swift:70-76` - Кэш данных
- `ZetaraManager.swift:268-272` - Очистка кэша
- `ControlData.swift` - Структуры данных

---

**Конец документа**

Эта документация должна помочь понять полную логику работы блоков Selected ID / CAN / RS485 на главном экране! 🎯
