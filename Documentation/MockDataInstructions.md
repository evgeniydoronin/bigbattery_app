# Инструкции по использованию фейковых данных в приложении BatteryMonitorBL

Для тестирования приложения без реального устройства мы добавили поддержку фейковых данных. Это позволяет увидеть, как приложение будет выглядеть и работать с разными типами данных от батареи.

## Текущая настройка

В настоящее время приложение настроено на использование набора фейковых данных `mockNormalBMSData`, который имитирует нормальное состояние батареи. Эта настройка находится в файле `BatteryMonitorBL/App/AppDelegate.swift`.

## Доступные наборы фейковых данных

В приложении есть несколько предопределенных наборов фейковых данных, которые можно использовать для тестирования разных состояний:

1. `mockNormalBMSData` - нормальные данные батареи
2. `mockInChargingBMSData` - данные батареи во время зарядки
3. `mockCellTempsData` - данные с четырьмя температурами ячеек
4. `mockBMSData1` - данные с отрицательными температурами

## Как переключаться между наборами данных

Чтобы переключиться на другой набор данных, отредактируйте файл `BatteryMonitorBL/App/AppDelegate.swift` и измените параметр `mockData` в конфигурации:

```swift
let config = Configuration(identifiers: [.v1, .v2],
                           refreshBMSTimeInterval: 2,
                           mockData: Foundation.Data.mockInChargingBMSData) // Измените на нужный набор данных
ZetaraManager.setup(config)
```

Доступные варианты:
- `Foundation.Data.mockNormalBMSData`
- `Foundation.Data.mockInChargingBMSData`
- `Foundation.Data.mockCellTempsData`
- `Foundation.Data.mockBMSData1`

После изменения перезапустите приложение, чтобы увидеть результат.

## Создание собственных наборов данных

Если вам нужно создать собственный набор фейковых данных, вы можете добавить новую константу в файл `Zetara/Sources/Configuration.swift`:

```swift
extension Foundation.Data {
    public static let mockCustomData = Foundation.Data(hex: "ваши_шестнадцатеричные_данные")
}
```

Затем используйте эту константу в конфигурации:

```swift
let config = Configuration(identifiers: [.v1, .v2],
                           refreshBMSTimeInterval: 2,
                           mockData: Foundation.Data.mockCustomData)
```

## Отключение фейковых данных

Если вы хотите вернуться к использованию реальных данных от устройства, просто удалите параметр `mockData` из конфигурации:

```swift
let config = Configuration(identifiers: [.v1, .v2],
                           refreshBMSTimeInterval: 2)
ZetaraManager.setup(config)
```

После этого приложение будет пытаться подключиться к реальному устройству через Bluetooth.
