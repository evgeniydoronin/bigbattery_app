# 🎨 UI DESIGN SPECIFICATION
## BigBattery Husky 2 - Полная спецификация дизайна

**Дата создания**: 06.10.2025  
**Цель**: Сохранение всех дизайнерских элементов перед откатом к коммиту f31a1aa  
**Файлы**: ProtocolParametersView.swift, SettingsViewController.swift

---

## 📱 HOME SCREEN - ProtocolParametersView

### Общее описание
Компонент для отображения 3 блоков с активными протоколами на главном экране.

### Расположение
- **Позиция**: Под карточками Voltage/Current/Temperature
- **Отступы**: Leading/Trailing 16pt
- **Высота контейнера**: 70pt + 8pt bottom offset = 78pt total

### Layout структура
```swift
UIStackView (horizontal)
├── ComponentView (Module ID)
├── ComponentView (CAN Protocol)  
└── ComponentView (RS485 Protocol)
```

### Параметры StackView
```swift
axis: .horizontal
distribution: .fillEqually
spacing: 10pt
translatesAutoresizingMaskIntoConstraints: false
```

### Стили блоков (каждый ComponentView)

#### Background & Border
```swift
backgroundColor: UIColor.white
layer.cornerRadius: 10pt
layer.masksToBounds: false // Для отображения тени
layer.borderWidth: 1pt
layer.borderColor: UIColor.black.withAlphaComponent(0.1).cgColor
```

#### Shadow
```swift
layer.shadowColor: UIColor.black.cgColor
layer.shadowOffset: CGSize(width: 0, height: 2)
layer.shadowOpacity: 0.1
layer.shadowRadius: 4
```

#### Typography
```swift
// Value (верхний текст)
font: .systemFont(ofSize: 18, weight: .bold)
textColor: #000000
textAlignment: .center

// Title (нижний текст)
font: .systemFont(ofSize: 12, weight: .medium)
textColor: #666666 (примерно)
textAlignment: .center
```

#### Layout внутри блока
```swift
// Value label
top: 12pt from top
centerX: superview

// Title label
top: 8pt from valueLabel.bottom
leading/trailing: 8pt inset
bottom: 12pt from bottom
centerX: superview
```

### Содержимое блоков

#### Блок 1: Selected ID
```swift
title: "Selected ID"
value: "--" (по умолчанию) или "ID 1", "ID 2", etc.
icon: НЕТ (скрыт)
```

#### Блок 2: Selected CAN
```swift
title: "Selected CAN"
value: "--" (по умолчанию) или "P06-LUX", etc.
icon: НЕТ (скрыт)
```

#### Блок 3: Selected RS485
```swift
title: "Selected RS485"
value: "--" (по умолчанию) или "P02-LUX", etc.
icon: НЕТ (скрыт)
```

### Tap Gestures
```swift
// Каждый блок имеет UITapGestureRecognizer
moduleIdComponentView.isUserInteractionEnabled = true
canProtocolComponentView.isUserInteractionEnabled = true
rs485ProtocolComponentView.isUserInteractionEnabled = true

// Callbacks
onModuleIdTap: (() -> Void)?
onCanProtocolTap: (() -> Void)?
onRS485ProtocolTap: (() -> Void)?
```

### Constraints (SnapKit)
```swift
stackView.snp.makeConstraints { make in
    make.top.equalToSuperview().offset(0)
    make.leading.equalToSuperview().offset(16)
    make.trailing.equalToSuperview().offset(-16)
    make.bottom.equalToSuperview().offset(-8)
    make.height.equalTo(70)
}
```

### Методы обновления
```swift
func updateModuleId(_ value: String)
func updateCanProtocol(_ value: String)
func updateRS485Protocol(_ value: String)
func updateAllParameters(moduleId: String, canProtocol: String, rs485Protocol: String)
```

---

## ⚙️ SETTINGS SCREEN - SettingsViewController

### Общая структура
```
ScrollView
└── UIStackView (vertical, spacing: 16pt)
    ├── Connection Status Banner
    ├── "Protocol Settings" Header
    ├── Note Label
    ├── Spacer (8pt)
    ├── Module ID Container
    │   ├── SettingItemView
    │   └── Status Label
    ├── CAN Protocol Container
    │   ├── SettingItemView
    │   └── Status Label
    ├── RS485 Protocol Container
    │   ├── SettingItemView
    │   └── Status Label
    ├── "Application Information" Header
    ├── Version SettingItemView
    ├── Spacer (flexible)
    ├── Save Button
    └── Information Banner
```

---

## 1️⃣ HEADER (Logo)

### Описание
Белая шапка с логотипом BigBattery (идентична Home экрану)

### Параметры
```swift
// Header View
backgroundColor: .white
translatesAutoresizingMaskIntoConstraints: false

// Constraints
topAnchor: view.topAnchor
leadingAnchor: view.leadingAnchor
trailingAnchor: view.trailingAnchor
bottomAnchor: view.safeAreaLayoutGuide.topAnchor + 60pt
```

### Logo
```swift
// Image
image: R.image.headerLogo()
contentMode: .scaleAspectFit

// Constraints
centerX: headerView.centerX
centerY: view.safeAreaLayoutGuide.topAnchor + 30pt
width: 200pt
height: 60pt
```

---

## 2️⃣ SCROLL VIEW & MAIN STACK VIEW

### ScrollView
```swift
showsVerticalScrollIndicator: true
alwaysBounceVertical: true

// Constraints
leading/trailing: superview
top: view.safeAreaLayoutGuide.top + 75pt // Отступ под header
bottom: view.safeAreaLayoutGuide.bottom
```

### Main StackView
```swift
axis: .vertical
distribution: .fill
alignment: .fill
spacing: 16pt

// Constraints (внутри ScrollView)
edges: superview.inset(top: 0, left: 20, bottom: 20, right: 20)
width: scrollView.width - 40pt
```

---

## 3️⃣ CONNECTION STATUS BANNER

### Описание
Баннер показывающий статус подключения батареи

### Параметры
```swift
backgroundColor: UIColor.white
layer.cornerRadius: 12pt
layer.borderWidth: 2pt
layer.borderColor: UIColor.red.cgColor // Красный когда не подключено
height: 40pt
```

### Состояния

#### Not Connected (по умолчанию)
```swift
layer.borderColor: UIColor.red.cgColor
backgroundColor: UIColor.red.withAlphaComponent(0.1)
statusLabel.text: "Not Connected"
statusLabel.textColor: .black
```

#### Connected
```swift
layer.borderColor: UIColor.systemGreen.cgColor
backgroundColor: UIColor.white
statusLabel.text: "Connected"
statusLabel.textColor: .black
```

### Layout
```swift
// Bluetooth Icon
image: R.image.homeBluetooth()
contentMode: .scaleAspectFit
tintColor: .systemBlue
size: 32x32pt
leading: 16pt
centerY: superview

// Status Label
font: .systemFont(ofSize: 18, weight: .medium)
textAlignment: .center
leading: bluetoothIcon.trailing + 16pt
centerY: superview
trailing: ≤ superview - 16pt
```

---

## 4️⃣ SECTION HEADERS

### "Protocol Settings" Header
```swift
text: "Protocol Settings"
font: .systemFont(ofSize: 24, weight: .bold)
textColor: .black
textAlignment: .left
height: 30pt
leading: 4pt inset
```

### "Application Information" Header
```swift
text: "Application Information"
font: .systemFont(ofSize: 24, weight: .bold)
textColor: .black
textAlignment: .left
height: 30pt
leading: 4pt inset
top: 10pt offset (дополнительный отступ сверху)
```

---

## 5️⃣ NOTE LABEL

### Текст
```
Note: The battery connected directly to the inverter or meter via the communication cable must be set to ID1. All other batteries should be assigned unique IDs (ID2, ID3, etc.).
```

### Форматирование
```swift
// Базовые атрибуты
font: .systemFont(ofSize: 12)
foregroundColor: UIColor(red: 0x80/255.0, green: 0x80/255.0, blue: 0x80/255.0, alpha: 1.0)
numberOfLines: 0
lineBreakMode: .byWordWrapping
textAlignment: .left

// Жирные слова
"Note:" - font: .systemFont(ofSize: 12, weight: .bold)
"ID1" - font: .systemFont(ofSize: 12, weight: .bold)
```

### Spacer после Note
```swift
height: 8pt
```

---

## 6️⃣ SETTING ITEM VIEWS (Карточки настроек)

### Общие параметры SettingItemView
```swift
backgroundColor: #E8E8E8
layer.cornerRadius: 12pt
height: 60pt
```

### Module ID Setting
```swift
title: "Module ID"
subtitle: "BMS module identifier"
icon: SF Symbol "gearshape.fill"
iconColor: UIColor(hex: "#165EA0") // Синий
iconSize: 32pt
valueColor: UIColor(hex: "#165EA0") // Синий
label: "--" (по умолчанию) или "ID 1", "ID 2", etc.
options: ["ID 1", "ID 2", "ID 3", "ID 4", "ID 5", "ID 6", "ID 7", "ID 8"]
chevron: Стрелка вниз (когда enabled)
```

### CAN Protocol Setting
```swift
title: "CAN Protocol"
subtitle: "Controller area network protocol"
icon: SF Symbol "gearshape.fill"
iconColor: UIColor(hex: "#12C04C") // Зеленый
iconSize: 32pt
valueColor: UIColor(hex: "#12C04C") // Зеленый
label: "--" (по умолчанию) или "P06-LUX", etc.
options: Загружаются динамически с устройства
chevron: Стрелка вниз (когда enabled)
```

### RS485 Protocol Setting
```swift
title: "RS485 Protocol"
subtitle: "Serial communication protocol"
icon: SF Symbol "gearshape.fill"
iconColor: UIColor(hex: "#ED1000") // Красный
iconSize: 32pt
valueColor: UIColor(hex: "#ED1000") // Красный
label: "--" (по умолчанию) или "P02-LUX", etc.
options: Загружаются динамически с устройства
chevron: Стрелка вниз (когда enabled)
```

### Version Setting (без контейнера)
```swift
title: "App Version"
subtitle: "BigBattery Husky 2"
icon: R.image.homeBluetooth()
iconColor: .systemBlue
iconSize: 32pt
label: "1.4.1(15)" (динамически из Bundle)
options: [] // Пустой массив - скрывает chevron
height: 60pt
```

---

## 7️⃣ STATUS INDICATORS (Индикаторы под настройками)

### Описание
Текстовые лейблы под каждой настройкой, показывающие выбранное значение

### Параметры
```swift
font: .systemFont(ofSize: 14, weight: .medium)
textColor: UIColor(hex: "#808080") // Серый
numberOfLines: 2
textAlignment: .left
isHidden: true // По умолчанию скрыты
```

### Текст
```swift
"Selected: [VALUE] - Click 'Save' below, then restart the battery and reconnect to the app to verify changes."
```

### Layout в контейнере
```swift
// Контейнер = SettingItemView + Status Label
top: settingView.bottom + 8pt
leading/trailing: 4pt inset
bottom: superview
```

### Анимация появления
```swift
label.alpha = 0
UIView.animate(withDuration: 0.3) {
    label.alpha = 1
    self.view.layoutIfNeeded()
}
```

---

## 8️⃣ SAVE BUTTON

### Параметры
```swift
title: "Save"
titleLabel.font: .systemFont(ofSize: 18, weight: .semibold)
layer.cornerRadius: 12pt
clipsToBounds: true
height: 50pt
```

### Shadow
```swift
layer.shadowColor: UIColor.black.cgColor
layer.shadowOffset: CGSize(width: 0, height: 2)
layer.shadowOpacity: 0.1
layer.shadowRadius: 4
layer.masksToBounds: false
```

### Состояния

#### Active (hasUnsavedChanges = true)
```swift
isEnabled: true
backgroundColor: UIColor.systemBlue
titleColor: .white
alpha: 1.0
```

#### Inactive (hasUnsavedChanges = false)
```swift
isEnabled: false
backgroundColor: UIColor.lightGray.withAlphaComponent(0.3)
titleColor: .white
alpha: 1.0
```

### Action
```swift
@objc func saveButtonTapped()
// Показывает UIAlertController с сообщением
// После подтверждения: hasUnsavedChanges = false, hideAllStatusIndicators()
```

---

## 9️⃣ INFORMATION BANNER

### Описание
Белый баннер внизу экрана с инструкцией о перезагрузке

### Параметры
```swift
backgroundColor: UIColor.white.withAlphaComponent(0.95)
layer.cornerRadius: 12pt
clipsToBounds: true
height: 60pt
```

### Shadow
```swift
layer.shadowColor: UIColor.black.cgColor
layer.shadowOffset: CGSize(width: 0, height: -2)
layer.shadowOpacity: 0.15
layer.shadowRadius: 4
layer.masksToBounds: false
```

### Message Label
```swift
text: "You must restart the battery using the power button after saving, then reconnect to the app to verify changes."
textAlignment: .center
numberOfLines: 0
font: .systemFont(ofSize: 12, weight: .medium)
textColor: .black
```

### Layout
```swift
messageLabel.center: superview
messageLabel.leading/trailing: 16pt inset
```

---

## 🔟 SPACER (Flexible)

### Описание
Пустой UIView для отталкивания нижних элементов (Save + Banner)

### Параметры
```swift
setContentHuggingPriority(.defaultLow, for: .vertical)
setContentCompressionResistancePriority(.defaultLow, for: .vertical)
```

---

## 📐 CONSTRAINTS SUMMARY

### ScrollView
```swift
leading/trailing: superview
top: safeArea.top + 75pt
bottom: safeArea.bottom
```

### Main StackView
```swift
edges: scrollView.inset(20pt left/right, 0pt top, 20pt bottom)
width: scrollView.width - 40pt
```

### Setting Containers
```swift
// SettingItemView
top/leading/trailing: superview
height: 60pt

// Status Label
top: settingView.bottom + 8pt
leading/trailing: 4pt inset
bottom: superview
```

---

## 🎨 COLOR PALETTE

### Primary Colors
```swift
Module ID Icon: #165EA0 (Синий)
CAN Icon: #12C04C (Зеленый)
RS485 Icon: #ED1000 (Красный)
```

### UI Colors
```swift
Background: UIColor.white
Setting Card Background: #E8E8E8
Border (subtle): UIColor.black.withAlphaComponent(0.1)
Text Primary: .black
Text Secondary: #808080
Text Tertiary: #666666
```

### Status Colors
```swift
Connected Border: UIColor.systemGreen
Disconnected Border: UIColor.red
Disconnected Background: UIColor.red.withAlphaComponent(0.1)
```

### Button Colors
```swift
Save Active: UIColor.systemBlue
Save Inactive: UIColor.lightGray.withAlphaComponent(0.3)
```

---

## 📝 KEY METHODS TO PRESERVE

### SettingsViewController

#### setupLogoHeader()
```swift
// Создает белую шапку с логотипом BigBattery
// Идентична HomeViewController
```

#### setupMainStackView()
```swift
// Создает ScrollView + UIStackView
// Настраивает constraints
```

#### populateStackView()
```swift
// Заполняет StackView всеми элементами в правильном порядке:
// 1. Connection Status Banner
// 2. Protocol Settings Header
// 3. Note Label
// 4. Spacer (8pt)
// 5. Module ID Container
// 6. CAN Container
// 7. RS485 Container
// 8. Application Info Header
// 9. Version View
// 10. Flexible Spacer
// 11. Save Button
// 12. Information Banner
```

#### createSettingContainer(settingView:statusLabel:)
```swift
// Создает контейнер для настройки + индикатора
// Возвращает UIView с правильными constraints
```

#### setupConnectionStatusBannerForStackView()
```swift
// Создает баннер статуса подключения
// Настраивает Bluetooth иконку + текст
```

#### updateConnectionStatus(isConnected:)
```swift
// Обновляет цвета баннера в зависимости от статуса
// Анимация 0.3 секунды
```

#### setupSectionHeaders()
```swift
// Создает заголовки "Protocol Settings" и "Application Information"
// Создает Note Label с форматированием
```

#### showStatusIndicatorWithStackView(label:selectedValue:)
```swift
// Показывает индикатор с анимацией
// Автоматически перестраивает layout
```

#### updateSaveButtonState()
```swift
// Обновляет состояние кнопки Save
// Active (синяя) / Inactive (серая)
```

---

## 🔧 DEPENDENCIES

### Frameworks
```swift
import UIKit
import SnapKit // Для constraints
import RswiftResources // Для R.image
```

### Custom Components
```swift
SettingItemView // Карточка настройки с иконкой, title, subtitle, value, chevron
ComponentView // Блок для отображения параметра (используется в ProtocolParametersView)
```

---

## 📦 ASSETS

### Images
```swift
R.image.headerLogo() // Логотип BigBattery для header
R.image.homeBluetooth() // Иконка Bluetooth для Version и Connection Status
R.image.background() // Фоновое изображение
```

### SF Symbols
```swift
"gearshape.fill" // Иконка шестеренки для настроек
"number.circle" // Иконка для Module ID (не используется, скрыта)
"wifi" // Иконка для CAN (не используется, скрыта)
"cable.connector" // Иконка для RS485 (не используется, скрыта)
```

---

## ⚠️ IMPORTANT NOTES

### 1. StackView Layout
Весь Settings экран построен на UIStackView для гибкости:
- Автоматическое перестроение при показе/скрытии элементов
- Анимации работают автоматически через `view.layoutIfNeeded()`
- Не нужно вручную пересчитывать constraints

### 2. Status Indicators
Индикаторы статуса находятся в контейнерах вместе с SettingItemView:
- Показываются только после изменения значения
- Скрываются после нажатия Save
- Анимация появления/исчезновения 0.3 секунды

### 3. Save Button State
Кнопка Save активируется только при наличии несохраненных изменений:
- `hasUnsavedChanges = true` → синяя активная кнопка
- `hasUnsavedChanges = false` → серая неактивная кнопка

### 4. Connection Status
Баннер статуса обновляется автоматически через подписку на:
```swift
ZetaraManager.shared.connectedPeripheralSubject
```

### 5. Auto-Layout
Все constraints настроены через SnapKit для читаемости:
```swift
view.snp.makeConstraints { make in
    make.leading.trailing.equalToSuperview().inset(16)
    make.height.equalTo(60)
}
```

---

## 🚀 IMPLEMENTATION CHECKLIST

После отката к f31a1aa, для восстановления UI:

### Home Screen
- [ ] Создать `ProtocolParametersView.swift`
- [ ] Скопировать все стили из спецификации
- [ ] Добавить в HomeViewController под карточками параметров
- [ ] Настроить callbacks для tap gestures
- [ ] Подключить к данным из ZetaraManager cache

### Settings Screen
- [ ] Создать header с логотипом (метод `setupLogoHeader()`)
- [ ] Создать ScrollView + StackView (метод `setupMainStackView()`)
- [ ] Создать Connection Status Banner
- [ ] Создать заголовки секций с Note
- [ ] Настроить 3 карточки настроек с цветными иконками
- [ ] Добавить индикаторы статуса под каждой настройкой
- [ ] Создать Save кнопку с логикой active/inactive
- [ ] Создать информационный баннер
- [ ] Реализовать метод `populateStackView()`
- [ ] Настроить все callbacks и subscriptions

### Testing
- [ ] Проверить отображение всех элементов
- [ ] Проверить анимации (индикаторы, Save button)
- [ ] Проверить responsive layout (разные размеры экранов)
- [ ] Проверить состояния (connected/disconnected)
- [ ] Проверить tap gestures на Home
- [ ] Проверить picker'ы в Settings

---

**Конец спецификации**

**Автор**: Claude Code Assistant  
**Дата**: 06.10.2025  
**Версия**: 1.0  
**Статус**: Готов к использованию для восстановления UI
