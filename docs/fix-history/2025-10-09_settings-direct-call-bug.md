# Fix: Settings Screen Bypassing ProtocolDataManager

**Date:** October 9, 2025
**Author:** Development Team
**Severity:** HIGH
**Status:** Fixed

## Context

After fixing timeout issues in Attempt #2 (see `2025-10-08_timeout-fix-ATTEMPT2.md`), client Joshua reported mixed results:
- ✅ Protocol requests complete successfully (95ms instead of 49+ seconds)
- ✅ Timeout mechanism works properly (10 seconds)
- ❌ **Protocol values still show "--" in Settings screen**
- ❌ **Phantom connection issue - app shows connected after battery disconnected**

## Problem Analysis

### Evidence from New Logs

**Log 1: `/Users/evgeniydoronin/Downloads/bigbattery_logs_20251009_110805.json`**

```json
"protocolInfo": {
  "recentLogs": [
    "[11:07:50] [QUEUE] ✅ getModuleId completed in 95ms",
    "[11:07:50] [BLUETOOTH] ✅ Got control data response",
    "[11:07:50] [BLUETOOTH] Is control data: true",
    "[11:07:50] [BLUETOOTH] 📥 Received notification: 100201016574"
  ],
  "currentValues": {
    "canProtocol": "--",
    "moduleId": "--",
    "rs485Protocol": "--"
  }
}
```

**Analysis:**
- Request completes successfully ✅
- Battery responds with control data ✅
- **BUT** currentValues remain "--" ❌

**Why?** Settings screen calls `getModuleId()` directly, bypassing `ProtocolDataManager`:
- Request succeeds and Settings gets data locally
- `ProtocolDataManager.moduleIdSubject` never updates
- DiagnosticsViewController reads from `moduleIdSubject` → sees `nil` → shows "--"

**Log 2: `/Users/evgeniydoronin/Downloads/bigbattery_logs_20251009_110843.json`**

```json
"events": [
  {
    "timestamp": "11:08:42 09.10.2025",
    "message": "No device connected"
  }
]
```

But BMS data continues updating, indicating phantom connection.

---

## Root Cause

### Issue 1: Settings Bypasses ProtocolDataManager

**BatteryMonitorBL/SettingsViewController.swift (lines 726-789) - BEFORE:**

```swift
func getAllSettings() {
    self.getModuleId().subscribe { [weak self] idData in
        self?.moduleIdData = idData  // ← Stores LOCALLY
        self?.moduleIdSettingItemView?.label = idData.readableId()
        // ...
    }
}

func getModuleId() -> Maybe<Zetara.Data.ModuleIdControlData> {
    return ZetaraManager.shared.queuedRequest("getModuleId") {
        ZetaraManager.shared.getModuleId()
    }
    .timeout(.seconds(3), scheduler: MainScheduler.instance)  // ← External timeout
    .subscribeOn(MainScheduler.instance)
}
```

**Problem:**
1. Settings calls `ZetaraManager.getModuleId()` directly
2. Settings gets data and stores in `self.moduleIdData` (local variable)
3. `ProtocolDataManager.moduleIdSubject` never updates
4. Other screens read from `moduleIdSubject` → see `nil` → show "--"

### Issue 2: No Diagnostic Logging in ConnectivityViewController

**BatteryMonitorBL/ConnectivityViewController.swift (lines 237-243) - BEFORE:**

```swift
private func loadProtocolsViaQueue() {
    print("[PROTOCOLS] Starting protocol loading after connection...")
    ZetaraManager.shared.protocolDataManager.loadAllProtocols(afterDelay: 1.5)
}
```

**Problem:**
- Uses `print()` instead of `protocolDataManager.logProtocolEvent()`
- Logs not visible in diagnostics exports
- Can't verify if protocol loading triggered after connection

### Issue 3: BMS Data Not Cleared on Disconnect

**Zetara/Sources/ZetaraManager.swift (lines 301-310) - BEFORE:**

```swift
func cleanConnection() {
    // ...
    connectionDisposable?.dispose()
    timer?.invalidate()
    timer = nil

    // Очищаем протокольные данные через ProtocolDataManager
    protocolDataManager.clearProtocols()

    connectedPeripheralSubject.onNext(nil)
}
```

**Problem:**
- Timer invalidated but BMS data not cleared
- `bmsDataSubject` retains old values
- UI shows stale battery data after disconnect (phantom connection)

---

## Solution

### Fix 1: Refactor Settings to Use ProtocolDataManager Subjects

**BatteryMonitorBL/SettingsViewController.swift (lines 726-806) - AFTER:**

```swift
func getAllSettings() {
    // Настраиваем подписки на ProtocolDataManager subjects
    // Теперь Settings просто слушает изменения, а не запрашивает данные напрямую
    let protocolManager = ZetaraManager.shared.protocolDataManager

    // Подписываемся на Module ID updates
    protocolManager.moduleIdSubject
        .observe(on: MainScheduler.instance)
        .subscribe(onNext: { [weak self] moduleIdData in
            guard let self = self else { return }

            if let data = moduleIdData {
                self.moduleIdData = data
                self.moduleIdSettingItemView?.label = data.readableId()
                // ...
            } else {
                self.moduleIdSettingItemView?.label = "--"
            }
        })
        .disposed(by: disposeBag)

    // Similar subscriptions for RS485 and CAN...
}
```

**Updated viewDidLoad (lines 282-303):**

```swift
override func viewDidLoad() {
    // ...

    // Настраиваем подписки на ProtocolDataManager один раз
    getAllSettings()

    self.rx.isVisible.subscribe { [weak self] (visible: Bool) in
        if visible {
            ZetaraManager.shared.pauseRefreshBMSData()

            // Загружаем протоколы если подключено и данные пустые
            let deviceConnected = (try? ZetaraManager.shared.connectedPeripheralSubject.value()) != nil
            let protocolDataIsEmpty = (self?.canData == nil || self?.rs485Data == nil || self?.moduleIdData == nil)
            if deviceConnected && protocolDataIsEmpty {
                ZetaraManager.shared.protocolDataManager.logProtocolEvent("[SETTINGS] Loading protocols via ProtocolDataManager")
                self?.isLoadingData = true
                ZetaraManager.shared.protocolDataManager.loadAllProtocols(afterDelay: 0.5)
            }
        } else {
            ZetaraManager.shared.resumeRefreshBMSData()
        }
    }.disposed(by: disposeBag)
}
```

**Updated viewWillAppear (lines 329-344):**

```swift
override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    // Загружаем протоколы если подключено и данные пустые
    if ZetaraManager.shared.connectedPeripheral() != nil {
        let protocolDataIsEmpty = (canData == nil || rs485Data == nil || moduleIdData == nil)
        if protocolDataIsEmpty {
            ZetaraManager.shared.protocolDataManager.logProtocolEvent("[SETTINGS] Loading protocols via ProtocolDataManager in viewWillAppear")
            isLoadingData = true
            ZetaraManager.shared.protocolDataManager.loadAllProtocols(afterDelay: 0.5)
        }
    }
}
```

**Removed direct protocol methods:**
- `getModuleId() -> Maybe<Zetara.Data.ModuleIdControlData>`
- `getRS485() -> Maybe<Zetara.Data.RS485ControlData>`
- `getCAN() -> Maybe<Zetara.Data.CANControlData>`

**Why this works:**
1. Settings subscribes to `ProtocolDataManager` subjects once in `viewDidLoad`
2. When Settings screen appears, triggers `loadAllProtocols()` if data is empty
3. `ProtocolDataManager.loadModuleId()` updates `moduleIdSubject`
4. Settings UI updates automatically via subscription
5. Other screens (Diagnostics) also read from same `moduleIdSubject` → see actual values

### Fix 2: Add Diagnostic Logging in ConnectivityViewController

**BatteryMonitorBL/ConnectivityViewController.swift (lines 144-148) - AFTER:**

```swift
// Загружаем протоколы через 1.5 сек после подключения (Этап 3.1)
DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
    ZetaraManager.shared.protocolDataManager.logProtocolEvent("[CONNECTIVITY] Triggering protocol loading after connection")
    self?.loadProtocolsViaQueue()
}
```

**BatteryMonitorBL/ConnectivityViewController.swift (lines 237-244) - AFTER:**

```swift
private func loadProtocolsViaQueue() {
    ZetaraManager.shared.protocolDataManager.logProtocolEvent("[CONNECTIVITY] Starting protocol loading sequence")

    // Загружаем все протоколы через ProtocolDataManager
    ZetaraManager.shared.protocolDataManager.loadAllProtocols(afterDelay: 1.5)
}
```

**Why this is important:**
- All logs now visible in diagnostics exports
- Can verify protocol loading triggered after connection
- Helps diagnose issues like "did connection trigger protocol loading?"

### Fix 3: Clear BMS Data on Disconnect

**Zetara/Sources/ZetaraManager.swift (lines 301-315) - AFTER:**

```swift
func cleanConnection() {
    // ...
    connectionDisposable?.dispose()
    timer?.invalidate()
    timer = nil

    // Очищаем BMS данные
    cleanData()
    protocolDataManager.logProtocolEvent("[CONNECTION] BMS data cleared")

    // Очищаем протокольные данные через ProtocolDataManager
    protocolDataManager.clearProtocols()

    connectedPeripheralSubject.onNext(nil)

    protocolDataManager.logProtocolEvent("[CONNECTION] Connection state cleaned")
}
```

**Why this works:**
- `cleanData()` calls `bmsDataSubject.onNext(Data.BMS())` (empty BMS data)
- UI immediately shows empty state (no phantom connection)
- `observeDisconnect()` already calls `cleanConnection()`, so both paths covered

---

## Expected Behavior After Fix

### Scenario 1: Settings Screen Opens (Device Connected)

```
[SETTINGS] Loading protocols via ProtocolDataManager
[PROTOCOL MANAGER] Starting protocol loading after 0.5s delay...
[QUEUE] 📥 Request queued: getModuleId
[QUEUE] 🚀 Executing getModuleId
[BLUETOOTH] 📤 Writing control data: 1002007165
[BLUETOOTH] 📥 Received notification: 100201016574
[BLUETOOTH] Is control data: true
[BLUETOOTH] ✅ Got control data response
[QUEUE] ✅ getModuleId completed in 95ms
[PROTOCOL MANAGER] ✅ Module ID loaded: ID 1
```

**Settings UI:**
- Shows "ID 1" (not "--")
- RS485 and CAN protocols also loaded and displayed

**Diagnostics screen currentValues:**
```json
"currentValues": {
  "moduleId": "ID 1",
  "rs485Protocol": "RS485 Protocol Name",
  "canProtocol": "CAN Protocol Name"
}
```

### Scenario 2: Connection → Protocol Loading

```
[CONNECTION] ✅ Characteristics configured
[CONNECTIVITY] Triggering protocol loading after connection
[CONNECTIVITY] Starting protocol loading sequence
[PROTOCOL MANAGER] Starting protocol loading after 1.5s delay...
[QUEUE] 🚀 Executing getModuleId
[BLUETOOTH] ✅ Got control data response
[QUEUE] ✅ getModuleId completed in 95ms
[PROTOCOL MANAGER] ✅ Module ID loaded: ID 1
```

**Now visible in diagnostics logs!**

### Scenario 3: Disconnect

```
[CONNECTION] 🔌 Device disconnected: BB-51.2V100Ah-0855
[CONNECTION] Cleaning connection state
[QUEUE] Request queue cleared
[CONNECTION] BMS data cleared
[PROTOCOL MANAGER] Clearing all protocols
[CONNECTION] Connection state cleaned
```

**UI state:**
- BMS data: Empty (no voltage/current/SOC shown)
- Protocol values: "--"
- Connection status: "No device connected"
- No phantom connection

---

## Testing Checklist

### Test 1: Settings Screen Protocol Loading

**Steps:**
1. Connect to battery
2. Open Settings screen
3. Check protocol values displayed

**Expected:**
- [ ] `[SETTINGS] Loading protocols via ProtocolDataManager` in logs
- [ ] Module ID shows actual value (e.g., "ID 1") not "--"
- [ ] RS485 shows actual protocol name
- [ ] CAN shows actual protocol name

### Test 2: Diagnostics Shows Same Protocol Values

**Steps:**
1. After Test 1, open Diagnostics screen
2. Send diagnostic logs
3. Check `currentValues` in JSON

**Expected:**
```json
"currentValues": {
  "moduleId": "ID 1",
  "rs485Protocol": "Actual Protocol Name",
  "canProtocol": "Actual Protocol Name"
}
```

NOT:
```json
"currentValues": {
  "moduleId": "--",
  "rs485Protocol": "--",
  "canProtocol": "--"
}
```

### Test 3: Connection Triggers Protocol Loading

**Steps:**
1. Connect to battery via Connectivity screen
2. Immediately send diagnostic logs (within 3 seconds)
3. Check logs for connection flow

**Expected in logs:**
- [ ] `[CONNECTIVITY] Triggering protocol loading after connection`
- [ ] `[CONNECTIVITY] Starting protocol loading sequence`
- [ ] `[PROTOCOL MANAGER] Starting protocol loading after 1.5s delay...`

### Test 4: Disconnect Clears BMS Data

**Steps:**
1. Connect to battery
2. Verify BMS data displays (voltage, SOC, etc.)
3. Disconnect battery using power button
4. Observe UI state

**Expected:**
- [ ] Connection banner shows "No device connected"
- [ ] BMS data cleared (no voltage/current/SOC)
- [ ] Protocol values show "--"
- [ ] `[CONNECTION] BMS data cleared` in logs
- [ ] NO phantom connection (battery data not updating)

---

## Architecture Changes

### Before: Settings Direct Call Pattern

```
Settings Screen
    ↓ (calls directly)
ZetaraManager.getModuleId()
    ↓
Battery responds
    ↓
Settings.moduleIdData = data (LOCAL)
    ↓
ProtocolDataManager.moduleIdSubject = nil (NEVER UPDATED!)
    ↓
Diagnostics reads moduleIdSubject → nil → shows "--"
```

### After: Centralized ProtocolDataManager Pattern

```
Settings/Connectivity triggers
    ↓
ProtocolDataManager.loadAllProtocols()
    ↓
ZetaraManager.getModuleId()
    ↓
Battery responds
    ↓
ProtocolDataManager.moduleIdSubject.onNext(data) (CENTRALIZED UPDATE)
    ↓
Settings subscribes → UI updates automatically
Diagnostics subscribes → shows actual values
```

**Benefits:**
- ✅ Single source of truth for protocol data
- ✅ All screens see same data
- ✅ Reactive updates (no manual refresh needed)
- ✅ Proper timeout handling (10s from writeControlData)
- ✅ Centralized logging visible in diagnostics

---

## Related Files

### Modified Files:

1. **BatteryMonitorBL/SettingsViewController.swift**
   - Lines 282-303: Updated viewDidLoad to setup subscriptions and trigger loadAllProtocols
   - Lines 329-344: Updated viewWillAppear to trigger loadAllProtocols
   - Lines 726-806: Refactored getAllSettings to subscribe to ProtocolDataManager subjects
   - Removed: getModuleId/getRS485/getCAN methods (lines 850-874 deleted)

2. **BatteryMonitorBL/ConnectivityViewController.swift**
   - Lines 144-148: Added logging before loadProtocolsViaQueue call
   - Lines 237-244: Updated loadProtocolsViaQueue to use protocolDataManager.logProtocolEvent

3. **Zetara/Sources/ZetaraManager.swift**
   - Lines 305-307: Added cleanData() call in cleanConnection

### Referenced Files:

- `Zetara/Sources/ProtocolDataManager.swift` - Centralized protocol data management
- `docs/fix-history/2025-10-08_timeout-fix-ATTEMPT2.md` - Previous fix that made timeout work

---

## Lessons Learned

### 1. Single Source of Truth is Critical

**Problem:** Settings bypassed ProtocolDataManager, creating two separate data flows.

**Lesson:** Always use centralized data managers for shared state. If multiple screens need same data, they should all subscribe to same source.

### 2. Reactive Architecture Requires Consistent Pattern

**Problem:** Settings used direct calls while other screens used subjects.

**Lesson:** Stick to one pattern throughout app. If using RxSwift subjects for reactive updates, ALL screens should subscribe, not make direct calls.

### 3. Diagnostic Logging Must Use Central Logger

**Problem:** ConnectivityViewController used `print()`, logs not visible in diagnostics.

**Lesson:** Always use `protocolDataManager.logProtocolEvent()` for protocol-related logs. This ensures they're captured in diagnostic exports.

### 4. Phantom Connection Requires Complete State Cleanup

**Problem:** Timer invalidated but BMS data not cleared.

**Lesson:** Disconnect cleanup must clear ALL state:
- Timer (done ✅)
- Connection disposables (done ✅)
- Protocol data (done ✅)
- **BMS data** (added ✅)

### 5. External Timeouts Don't Work with RxSwift

**Problem:** Settings used `.timeout(.seconds(3))` externally.

**Lesson:** Timeout must be INSIDE the Observable chain (done in Attempt #2). External timeouts on Maybe don't propagate properly.

---

## Prevention Checklist

**For Future Protocol-Related Features:**

1. **Data Flow:**
   - [ ] Use ProtocolDataManager for ALL protocol requests
   - [ ] Never call ZetaraManager.getModuleId/getRS485/getCAN directly
   - [ ] Subscribe to ProtocolDataManager subjects, don't make direct calls

2. **Logging:**
   - [ ] Use `protocolDataManager.logProtocolEvent()` for protocol logs
   - [ ] Never use `print()` for protocol-related events
   - [ ] Verify logs visible in diagnostic exports

3. **Timeout Handling:**
   - [ ] Timeout INSIDE Observable chain (in writeControlData)
   - [ ] No external timeouts on Maybe
   - [ ] Verify timeout actually fires (test with 15s delay)

4. **Disconnect Cleanup:**
   - [ ] Clear connection disposables
   - [ ] Invalidate timers
   - [ ] Clear protocol data (via ProtocolDataManager.clearProtocols)
   - [ ] Clear BMS data (via cleanData)
   - [ ] Verify UI shows empty state

---

## Commit Message

```
fix: Fix Settings screen bypassing ProtocolDataManager causing "--" values

Root Cause:
- Settings called getModuleId/getRS485/getCAN directly, bypassing ProtocolDataManager
- Settings stored data locally, ProtocolDataManager subjects never updated
- Other screens read from subjects → saw nil → showed "--"
- BMS data not cleared on disconnect (phantom connection)

Changes:
1. Refactored Settings.getAllSettings to subscribe to ProtocolDataManager subjects
2. Removed Settings.getModuleId/getRS485/getCAN direct call methods
3. Added loadAllProtocols calls in Settings.viewWillAppear and rx.isVisible
4. Added diagnostic logging in ConnectivityViewController
5. Added cleanData() call in ZetaraManager.cleanConnection

Result:
- Settings now triggers ProtocolDataManager.loadAllProtocols
- All screens subscribe to same subjects (single source of truth)
- Protocol values display correctly in Settings and Diagnostics
- BMS data cleared immediately on disconnect (no phantom connection)
- All protocol logs visible in diagnostic exports

Files Modified:
- BatteryMonitorBL/SettingsViewController.swift
- BatteryMonitorBL/ConnectivityViewController.swift
- Zetara/Sources/ZetaraManager.swift
```
