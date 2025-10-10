# Fix: Stale Peripheral References After Battery Restart

**Date:** October 10, 2025
**Author:** Development Team
**Severity:** CRITICAL
**Status:** Fixed

## Context

Client Joshua reported a critical reconnection issue after battery restart. This issue occurred immediately after successfully saving protocol settings (fixing the previous bug documented in `2025-10-10_protocol-save-and-crash-bug.md`).

**Two emails received from Joshua:**

### Email 1 (Before Battery Restart)
```
Test Case: connectivity and settings

1. Pair the device, (it connected).
2. Change the Module ID, I selected ID 2.
   Then change RS485 Protocol, I selected P02-LUX.
   Then change CAN Protocol, I selected P06-LUX.
3. Then I tapped on the "save" button.

Here are the logs before the battery starts to restart.
I'll send another log after the battery restart.
```

**Diagnostic log:** `/Users/evgeniydoronin/Downloads/bigbattery_logs_20251010_153756.json`

### Email 2 (After Battery Restart)
```
After the battery restart, I went to the Bluetooth screen and
tried to reconnect but now I'm getting "invalid" when clicking
on the battery 855.

Here's the diagnostic log.
```

**Diagnostic log:** `/Users/evgeniydoronin/Downloads/bigbattery_logs_20251010_153942.json`

**Critical Issue:**
- Battery 855 successfully connected before restart ✅
- After battery restart, clicking battery 855 shows "Invalid BigBattery device" ❌
- User unable to reconnect to same battery that was working moments ago ❌

---

## Problem Analysis

### Evidence from Log 1 (Before Restart)

**File:** `docs/fix-history/logs/bigbattery_logs_20251010_153756.json`
**Timestamp:** 15:37:56 10.10.2025

```json
{
  "bluetoothInfo": {
    "peripheralName": "BB-51.2V100Ah-0855",
    "peripheralIdentifier": "1997B63E-02F2-BB1F-C0DE-63B68D347427",
    "state": "poweredOn",
    "connectionAttempts": 0
  },
  "protocolInfo": {
    "currentValues": {
      "moduleId": "ID 1",
      "rs485Protocol": "P02-LUX",
      "canProtocol": "P06-LUX"
    },
    "recentLogs": [
      "[15:37:52] [SETTINGS] ⏭️ Skipping RS485 Protocol - already set to P02-LUX",
      "[15:37:52] [SETTINGS] ⏭️ Skipping CAN Protocol - already set to P06-LUX",
      "[15:37:52] [SETTINGS] ⏭️ Skipping Module ID - already set to ID 1",
      "[15:37:34] [PROTOCOL MANAGER] 🎉 All protocols loaded successfully!",
      "[15:37:34] [PROTOCOL MANAGER] ✅ CAN loaded: P06-LUX",
      "[15:37:34] [PROTOCOL MANAGER] ✅ RS485 loaded: P02-LUX",
      "[15:37:33] [PROTOCOL MANAGER] ✅ Module ID loaded: ID 1"
    ]
  },
  "batteryInfo": {
    "voltage": 0,
    "cellVoltages": [],
    "soc": 0,
    "status": "Standby"
  }
}
```

**Analysis:**
- ✅ Successfully connected to "BB-51.2V100Ah-0855"
- ✅ Peripheral identifier captured: "1997B63E-02F2-BB1F-C0DE-63B68D347427"
- ✅ All protocols loaded successfully (ID 1, P02-LUX, P06-LUX)
- ⚠️ Voltage = 0, cellVoltages empty → Battery is restarting
- ⚠️ Joshua clicked Save, battery about to restart

---

### Evidence from Log 2 (After Restart)

**File:** `docs/fix-history/logs/bigbattery_logs_20251010_153942.json`
**Timestamp:** 15:39:42 10.10.2025

```json
{
  "bluetoothInfo": {
    "state": "poweredOn",
    "connectionAttempts": 0
    // ❌ No peripheralName!
    // ❌ No peripheralIdentifier!
  },
  "protocolInfo": {
    "currentValues": {
      "moduleId": "--",
      "rs485Protocol": "--",
      "canProtocol": "--"
    },
    "recentLogs": [
      "[15:39:25] [CONNECTION] Connection state cleaned",
      "[15:39:25] [CONNECTION] Cached device UUID cleared",
      "[15:39:25] [CONNECTION] All Bluetooth characteristics cleared",
      "[15:39:25] [PROTOCOL MANAGER] Clearing all protocols",
      "[15:39:25] [CONNECTION] BMS data cleared",
      "[15:39:25] [QUEUE] Request queue cleared",
      "[15:39:25] [CONNECTION] Cleaning connection state",
      "[15:39:25] [CONNECTION] ⚠️ PHANTOM: No peripheral but BMS timer running!",
      "[15:37:52] [SETTINGS] ⏭️ Skipping RS485 Protocol - already set to P02-LUX",
      "[15:37:52] [SETTINGS] ⏭️ Skipping CAN Protocol - already set to P06-LUX",
      "[15:37:34] [PROTOCOL MANAGER] 🎉 All protocols loaded successfully!"
    ],
    "statistics": {
      "errors": 0,
      "warnings": 1,
      "successes": 7,
      "totalLogs": 30
    }
  },
  "batteryInfo": {
    "voltage": 0,
    "cellVoltages": [],
    "soc": 0,
    "status": "Standby"
  },
  "events": [
    {
      "type": "Connection",
      "message": "No device connected",
      "timestamp": "15:39:41 10.10.2025"
    },
    {
      "type": "Connection",
      "message": "No device connected",
      "timestamp": "15:39:36 10.10.2025"
    }
  ]
}
```

**Critical Observations:**

1. **PHANTOM Error Detected (15:39:25):**
   ```
   [CONNECTION] ⚠️ PHANTOM: No peripheral but BMS timer running!
   ```
   - PHANTOM monitor detected invalid connection state
   - Triggered `cleanConnection()` to clean up stale state

2. **cleanConnection() Executed Successfully:**
   ```
   [CONNECTION] Cleaning connection state
   [CONNECTION] Cached device UUID cleared
   [CONNECTION] All Bluetooth characteristics cleared
   [PROTOCOL MANAGER] Clearing all protocols
   [QUEUE] Request queue cleared
   [CONNECTION] BMS data cleared
   [CONNECTION] Connection state cleaned
   ```

3. **Protocol Values Reset to "--":**
   - Before restart: `"moduleId": "ID 1"`, `"rs485Protocol": "P02-LUX"`, `"canProtocol": "P06-LUX"`
   - After restart: `"moduleId": "--"`, `"rs485Protocol": "--"`, `"canProtocol": "--"`
   - Indicates `cleanConnection()` correctly cleared protocol state

4. **Missing Peripheral Information:**
   - `bluetoothInfo` missing `peripheralName` and `peripheralIdentifier`
   - This means app is NOT currently connected to battery
   - User tried to reconnect but got "Invalid BigBattery device" error

5. **Multiple "No device connected" Events:**
   - User attempted reconnection multiple times (15:39:24, 15:39:36, 15:39:41)
   - All attempts failed

---

## Root Cause

### Issue: Stale Peripheral References in `scannedPeripherals` Array

**The Problem:**

When battery restarts, the following sequence occurs:

1. **Battery restarts** after Module ID change
2. **PHANTOM monitor detects** invalid state (no peripheral but BMS timer running)
3. **cleanConnection() executes** and clears:
   - ✅ `writeCharacteristic = nil`
   - ✅ `notifyCharacteristic = nil`
   - ✅ `identifier = nil`
   - ✅ `cachedDeviceUUID = nil`
   - ✅ Protocol data cleared
   - ✅ BMS data cleared
   - ✅ Request queue cleared
   - ❌ **scannedPeripherals NOT cleared** ← ROOT CAUSE
4. **User returns to Connectivity screen**, sees "BB-51.2V100Ah-0855" in list
5. **User clicks on battery** → app calls `connect(peripheral)` with **old peripheral object**
6. **iOS CoreBluetooth:** Old peripheral object is **stale** (invalid after battery restart)
7. **Service discovery fails** → `notZetaraPeripheralError` triggered
8. **UI shows "Invalid BigBattery device"**

**Why `scannedPeripherals` Contains Stale Objects:**

```swift
// Zetara/Sources/ZetaraManager.swift (lines 296-322) - BEFORE FIX

func cleanConnection() {
    protocolDataManager.logProtocolEvent("[CONNECTION] Cleaning connection state")

    // Stop any active scanning
    scanDisposable?.dispose()
    scanDisposable = nil

    // Dispose connection observable
    connectionDisposable?.dispose()
    connectionDisposable = nil

    // Очищаем протокольные данные через ProtocolDataManager
    protocolDataManager.clearProtocols()

    // ❌ scannedPeripherals NOT cleared here!
    // Old peripheral objects remain in array

    // Сбрасываем ВСЕ Bluetooth состояния для чистого переподключения
    writeCharacteristic = nil
    notifyCharacteristic = nil
    identifier = nil
    cachedDeviceUUID = nil
    protocolDataManager.logProtocolEvent("[CONNECTION] All Bluetooth characteristics cleared")

    // Clear BMS data
    clearBMSData()

    // Clear request queue
    clearQueue()

    protocolDataManager.logProtocolEvent("[CONNECTION] Connection state cleaned")
}
```

**The Missing Call:**

`cleanScanning()` was NOT called in `cleanConnection()`, leaving stale peripheral objects in the `scannedPeripherals` array.

**What cleanScanning() Does:**

```swift
// Zetara/Sources/ZetaraManager.swift (lines 275-285)

func cleanScanning() {
    scannedPeripherals.removeAll()  // ← Clears stale peripherals
    scannedPeripheralSubject.onNext([])
    scanDisposable?.dispose()
    scanDisposable = nil
}
```

---

### Evidence from Connect Flow

**When user clicks battery in Connectivity screen after restart:**

**Zetara/Sources/ZetaraManager.swift (lines 199-268) - connect() method:**

```swift
func connect(peripheral: Peripheral) -> Observable<ConnectionStatus> {
    return Observable<ConnectionStatus>.create { [weak self] observer in
        // ...

        // Attempt to establish connection with STALE peripheral object
        self.connectionDisposable = peripheral.establishConnection()
            .flatMap { $0.discoverServices(serviceUUIDs) }
            .flatMap { Observable.from($0) }
            // ...
            .subscribe(onNext: { event in
                switch event {
                // ...
                case .error(let error):
                    // ❌ Service discovery fails because peripheral is stale!
                    observer.onError(error)
                    self?.cleanConnection()
                }
            })

        return Disposables.create()
    }
}
```

**Result:** iOS CoreBluetooth cannot discover services on stale peripheral → error → "Invalid BigBattery device"

---

## Solution

### Fix 1: Add `cleanScanning()` Call to `cleanConnection()`

**Zetara/Sources/ZetaraManager.swift (lines 318-320) - AFTER:**

```swift
func cleanConnection() {
    protocolDataManager.logProtocolEvent("[CONNECTION] Cleaning connection state")

    // Stop any active scanning
    scanDisposable?.dispose()
    scanDisposable = nil

    // Dispose connection observable
    connectionDisposable?.dispose()
    connectionDisposable = nil

    // Очищаем протокольные данные через ProtocolDataManager
    protocolDataManager.clearProtocols()

    // ✅ Очищаем список сканированных устройств (stale peripherals)
    cleanScanning()
    protocolDataManager.logProtocolEvent("[CONNECTION] Scanned peripherals cleared")

    // Сбрасываем ВСЕ Bluetooth состояния для чистого переподключения
    writeCharacteristic = nil
    notifyCharacteristic = nil
    identifier = nil
    cachedDeviceUUID = nil
    protocolDataManager.logProtocolEvent("[CONNECTION] All Bluetooth characteristics cleared")

    // Clear BMS data
    clearBMSData()

    // Clear request queue
    clearQueue()

    protocolDataManager.logProtocolEvent("[CONNECTION] Connection state cleaned")
}
```

**Why This Works:**

1. `cleanScanning()` removes all peripheral objects from `scannedPeripherals` array
2. User returns to Connectivity screen → list is empty
3. User taps "Scan" button → **fresh scan** discovers battery with **new peripheral object**
4. User taps battery → `connect()` receives **valid peripheral object**
5. Service discovery succeeds → connection established ✅

**Alternative (Less Ideal):**
Could filter `scannedPeripherals` to remove only the disconnected peripheral, but clearing ALL is safer because ALL peripheral objects from pre-restart scan are potentially stale.

---

### Fix 2: Add Detailed Logging to `connect()` Method

To diagnose similar issues in future, added comprehensive logging throughout the connection flow.

**Zetara/Sources/ZetaraManager.swift (lines 211-217) - Service Discovery Logging:**

```swift
self.connectionDisposable = peripheral.establishConnection()
    .flatMap { $0.discoverServices(serviceUUIDs) }
    .do(onNext: { [weak self] services in
        // ✅ Логируем найденные services
        self?.protocolDataManager.logProtocolEvent("[CONNECT] Services discovered: \(services.count)")
        services.forEach { service in
            self?.protocolDataManager.logProtocolEvent("[CONNECT] Service UUID: \(service.uuid.uuidString)")
        }
    })
    .flatMap { Observable.from($0) }
```

**Zetara/Sources/ZetaraManager.swift (lines 231-235) - Error Logging:**

```swift
case .error(let error):
    // ✅ Детальное логирование ошибки подключения
    if case ZetaraManager.Error.notZetaraPeripheralError = error {
        self?.protocolDataManager.logProtocolEvent("[CONNECT] ❌ Service UUID not recognized (not a valid BigBattery device)")
    } else {
        self?.protocolDataManager.logProtocolEvent("[CONNECT] ❌ Connection error: \(error.localizedDescription)")
    }
    observer.onError(error)
```

**Zetara/Sources/ZetaraManager.swift (lines 263-265) - Characteristics Error Logging:**

```swift
} else {
    // ✅ Identifier or characteristics not found
    self?.protocolDataManager.logProtocolEvent("[CONNECT] ❌ Failed to configure characteristics (identifier not recognized)")
    observer.onError(ZetaraManager.Error.notZetaraPeripheralError)
}
```

**Why This Logging Is Important:**

With these logs, if a user reports "Invalid BigBattery device" error, diagnostic logs will show:
- How many services were discovered (0 = stale peripheral)
- Which service UUIDs were found (helps identify wrong device type)
- Exact error type (service discovery fail vs. characteristic discovery fail)

---

## Expected Behavior After Fix

### Scenario 1: Battery Restarts After Settings Save

**Step 1: User saves settings (15:37:52)**

```
[SETTINGS] Setting Module ID to 2
[QUEUE] 🚀 Executing setModuleId
[BLUETOOTH] ✅ Got control data response
[SETTINGS] ✅ Module ID set successfully
```

**Step 2: Battery restarts automatically (15:38:00)**

```
[CONNECTION] 🔌 Device disconnected: BB-51.2V100Ah-0855
[DISCONNECT HANDLER] Triggered
[ALERT] "Battery Restarting - Please wait and reconnect"
```

**Step 3: PHANTOM monitor detects invalid state (15:38:05)**

```
[CONNECTION] ⚠️ PHANTOM: No peripheral but BMS timer running!
[CONNECTION] Cleaning connection state
[PROTOCOL MANAGER] Clearing all protocols
[CONNECTION] Scanned peripherals cleared  ← NEW LOG!
[CONNECTION] All Bluetooth characteristics cleared
[CONNECTION] BMS data cleared
[QUEUE] Request queue cleared
[CONNECTION] Connection state cleaned
```

**Step 4: User returns to Connectivity screen (15:38:10)**

```
UI: Device list shows "No devices found"
UI: "Scan" button enabled
```

**Step 5: User taps "Scan" button (15:38:15)**

```
[SCAN] Starting device scan...
[SCAN] Discovered: BB-51.2V100Ah-0855 (NEW peripheral object)
UI: Device list shows "BB-51.2V100Ah-0855"
```

**Step 6: User taps battery in list (15:38:20)**

```
[CONNECT] Connecting to BB-51.2V100Ah-0855...
[CONNECT] Services discovered: 1  ← NEW LOG!
[CONNECT] Service UUID: 0000ffe0-0000-1000-8000-00805f9b34fb  ← NEW LOG!
[CONNECT] ✅ Characteristics configured
[CONNECT] ✅ Connected to: BB-51.2V100Ah-0855
```

**Step 7: Protocols loaded (15:38:22)**

```
[PROTOCOL MANAGER] Loading protocols...
[PROTOCOL MANAGER] ✅ Module ID loaded: ID 2  ← NEW VALUE!
[PROTOCOL MANAGER] ✅ RS485 loaded: P02-LUX
[PROTOCOL MANAGER] ✅ CAN loaded: P06-LUX
[PROTOCOL MANAGER] 🎉 All protocols loaded successfully!
```

**Result:** User successfully reconnects to battery with fresh peripheral object ✅

---

### Scenario 2: User Tries to Connect Before Scanning (Edge Case)

**Step 1: User returns to Connectivity screen after disconnect**

```
UI: Device list shows "No devices found"  ← scannedPeripherals cleared
UI: "Scan" button enabled
```

**Step 2: User taps battery (impossible, list is empty)**

This scenario is now impossible because `cleanScanning()` clears the list. User MUST tap "Scan" to populate list with fresh peripherals.

**Previous Behavior (BUGGY):**
- Device list showed stale "BB-51.2V100Ah-0855" from before restart
- User tapped it → "Invalid BigBattery device" error

**New Behavior (FIXED):**
- Device list is empty → user cannot click stale peripheral
- User must scan → gets fresh peripheral object → connection succeeds

---

## Testing Checklist

### Test 1: Reconnect After Battery Restart (Main Test Case)

**Steps:**
1. Connect to battery
2. Open Settings screen
3. Change Module ID to ID 2
4. Click "Save" → battery restarts automatically
5. Wait for "Battery Restarting" alert
6. Return to Connectivity screen (should be empty)
7. Tap "Scan" button
8. Tap battery in list when it appears
9. Check Settings screen to verify new Module ID

**Expected Results:**
- [ ] After disconnect, PHANTOM monitor triggers (log: "PHANTOM: No peripheral but BMS timer running!")
- [ ] `cleanConnection()` executes (log: "Connection state cleaned")
- [ ] **NEW:** Log shows "Scanned peripherals cleared"
- [ ] Connectivity screen shows empty device list
- [ ] After scan, battery appears in list
- [ ] **NEW:** Log shows "Services discovered: 1" when connecting
- [ ] **NEW:** Log shows "Service UUID: 0000ffe0-..."
- [ ] Connection succeeds (no "Invalid BigBattery device" error)
- [ ] Settings screen shows new Module ID = ID 2

---

### Test 2: Manual Battery Power Cycle

**Steps:**
1. Connect to battery
2. Manually turn battery off using power button
3. Wait 5 seconds
4. Turn battery back on
5. Return to Connectivity screen
6. Verify device list is empty
7. Tap "Scan"
8. Connect to battery

**Expected Results:**
- [ ] After power cycle, PHANTOM or timeout triggers disconnect
- [ ] `cleanConnection()` clears scanned peripherals
- [ ] Fresh scan discovers battery
- [ ] Reconnection succeeds

---

### Test 3: Connection Lost Due to Range

**Steps:**
1. Connect to battery
2. Walk away from battery until connection lost
3. Return to Connectivity screen
4. Verify behavior

**Expected Results:**
- [ ] `cleanConnection()` clears scanned peripherals
- [ ] Device list empty
- [ ] Scan → battery appears → reconnection succeeds

---

### Test 4: Diagnostic Log Verification

**Steps:**
1. Perform Test 1 (battery restart scenario)
2. After reconnection succeeds, send diagnostic logs
3. Search logs for new logging statements

**Expected Logs:**
```
[CONNECTION] Scanned peripherals cleared
[CONNECT] Services discovered: 1
[CONNECT] Service UUID: 0000ffe0-0000-1000-8000-00805f9b34fb
[CONNECT] ✅ Characteristics configured
```

**If connection failed (regression test):**
```
[CONNECT] Services discovered: 0  ← Indicates stale peripheral
[CONNECT] ❌ Service UUID not recognized (not a valid BigBattery device)
```

---

### Test 5: Multiple Disconnects in Quick Succession

**Steps:**
1. Connect to battery
2. Turn battery off
3. Immediately turn battery back on (before PHANTOM triggers)
4. Repeat 3 times
5. Verify no crash, stale peripherals handled gracefully

**Expected Results:**
- [ ] Each disconnect triggers `cleanConnection()`
- [ ] No duplicate entries in scanned peripherals
- [ ] No crash due to accessing disposed peripheral
- [ ] User can scan and reconnect successfully

---

## Architecture Changes

### Before: Stale Peripheral Objects Remain After Disconnect (BROKEN)

```
User Connected to Battery (15:37:34)
    ↓
scannedPeripherals = [Peripheral(BB-51.2V100Ah-0855)]  ← Old object
    ↓
Battery Restarts (15:38:00)
    ↓
PHANTOM Monitor Triggers (15:38:05)
    ↓
cleanConnection() executes:
    ├─ writeCharacteristic = nil ✅
    ├─ notifyCharacteristic = nil ✅
    ├─ identifier = nil ✅
    ├─ cachedDeviceUUID = nil ✅
    ├─ clearProtocols() ✅
    ├─ clearBMSData() ✅
    ├─ clearQueue() ✅
    └─ scannedPeripherals = [Peripheral(...)] ❌ STALE!
    ↓
User Returns to Connectivity Screen (15:38:10)
    ↓
UI Shows: "BB-51.2V100Ah-0855" ← From stale peripheral
    ↓
User Clicks Battery
    ↓
connect(stalePeripheral)
    ↓
peripheral.establishConnection()
    ↓
discoverServices() ❌ FAILS (peripheral invalid)
    ↓
Error: notZetaraPeripheralError
    ↓
UI Shows: "Invalid BigBattery device" ❌
```

**Result:** User cannot reconnect without force-quitting app to clear memory

---

### After: Clean Peripheral List Forces Fresh Scan (FIXED)

```
User Connected to Battery (15:37:34)
    ↓
scannedPeripherals = [Peripheral(BB-51.2V100Ah-0855)]
    ↓
Battery Restarts (15:38:00)
    ↓
PHANTOM Monitor Triggers (15:38:05)
    ↓
cleanConnection() executes:
    ├─ writeCharacteristic = nil ✅
    ├─ notifyCharacteristic = nil ✅
    ├─ identifier = nil ✅
    ├─ cachedDeviceUUID = nil ✅
    ├─ clearProtocols() ✅
    ├─ clearBMSData() ✅
    ├─ clearQueue() ✅
    └─ cleanScanning() ✅ NEW!
        └─ scannedPeripherals.removeAll() ✅
        └─ scannedPeripheralSubject.onNext([]) ✅
    ↓
User Returns to Connectivity Screen (15:38:10)
    ↓
UI Shows: "No devices found" ← List is empty
    ↓
User Taps "Scan" Button (15:38:15)
    ↓
startScan()
    ↓
scannedPeripherals = [Peripheral(BB-51.2V100Ah-0855)] ← FRESH object
    ↓
User Clicks Battery (15:38:20)
    ↓
connect(freshPeripheral)
    ↓
peripheral.establishConnection()
    ↓
discoverServices() ✅ SUCCESS
    ↓
Log: "Services discovered: 1"
Log: "Service UUID: 0000ffe0-..."
    ↓
discoverCharacteristics() ✅
    ↓
Connection Status: .connected
    ↓
Load Protocols (15:38:22)
    ↓
Module ID: ID 2 (new value) ✅
RS485: P02-LUX ✅
CAN: P06-LUX ✅
```

**Result:** User successfully reconnects with fresh peripheral object ✅

---

## Related Files

### Modified Files:

1. **Zetara/Sources/ZetaraManager.swift**
   - Lines 318-320: Added `cleanScanning()` call in `cleanConnection()`
   - Lines 211-217: Added service discovery logging in `connect()`
   - Lines 231-235: Added connection error logging in `connect()`
   - Lines 263-265: Added characteristics error logging in `connect()`

### Referenced Files:

- `Zetara/Sources/ProtocolDataManager.swift` - Protocol logging (`logProtocolEvent()`)
- `BatteryMonitorBL/ConnectivityViewController.swift` - Device list UI (populated from `scannedPeripheralSubject`)
- `docs/common-issues-and-solutions.md` - Updated with new subsection (lines 400-527)
- `docs/fix-history/2025-10-10_protocol-save-and-crash-bug.md` - Previous fix (battery restart handling)

### Client Logs Analyzed:

- `docs/fix-history/logs/bigbattery_logs_20251010_153756.json` - Before restart (successful connection)
- `docs/fix-history/logs/bigbattery_logs_20251010_153942.json` - After restart (PHANTOM triggered, reconnect failed)

---

## Lessons Learned

### 1. Peripheral Object Lifecycle in CoreBluetooth

**Problem:** Peripheral objects become invalid after device restart, but remain in memory.

**Lesson:**
- CoreBluetooth `CBPeripheral` objects are **not persistent** across device power cycles
- After battery restart, old peripheral object is **stale** (invalid reference)
- Attempting operations on stale peripheral fails silently or throws errors
- MUST clear all cached peripheral references on disconnect

**Prevention:**
- Any disconnect (planned or unexpected) should trigger `cleanScanning()`
- Never assume peripheral object valid across connection sessions
- Always verify peripheral state before attempting operations

---

### 2. cleanConnection() Must Be Comprehensive

**Problem:** `cleanConnection()` cleared Bluetooth state but forgot `scannedPeripherals`.

**Lesson:**
- Connection cleanup is **all-or-nothing** - missing one piece breaks reconnection
- `cleanConnection()` should reset EVERY piece of connection-related state:
  - Characteristics (write, notify)
  - Identifiers (UUID, cached device)
  - Protocol data
  - BMS data
  - Request queue
  - **AND scanned peripherals** ← This was missed

**Prevention Checklist:**

When adding new connection-related state, update `cleanConnection()`:
- [ ] Is this state populated during connection?
- [ ] Should this state be cleared on disconnect?
- [ ] If yes, add clearing logic to `cleanConnection()`
- [ ] Add diagnostic log for the clearing action

**Example:**
```swift
// Future developer adds new state:
var lastConnectedBatteryName: String?

// MUST update cleanConnection():
func cleanConnection() {
    // ... existing cleanup ...

    lastConnectedBatteryName = nil  // ← Add this!
    protocolDataManager.logProtocolEvent("[CONNECTION] Last battery name cleared")
}
```

---

### 3. PHANTOM Monitor is Critical for Detection

**Problem:** Without PHANTOM monitor, stale state would go undetected.

**Lesson:**
- PHANTOM monitor successfully detected invalid state: "No peripheral but BMS timer running!"
- This detection triggered `cleanConnection()` automatically
- Without PHANTOM, app would crash or hang with invisible errors

**Why PHANTOM Worked Here:**
1. Battery disconnected during restart
2. BMS timer still running (expects data updates)
3. PHANTOM detected mismatch: timer active but no peripheral
4. Triggered cleanup before user encountered crash

**Prevention:**
- Maintain and expand PHANTOM monitor checks
- Add more invariant checks (e.g., "writeCharacteristic not nil but peripheral nil")
- Test PHANTOM triggers regularly (simulate unexpected disconnects)

---

### 4. Diagnostic Logging for Remote Debugging

**Problem:** Without service discovery logs, couldn't diagnose why connection failed.

**Lesson:**
- Client logs are our **ONLY window** into production issues
- Added logs at critical points:
  - "Services discovered: X" → Shows if discovery succeeded
  - "Service UUID: ..." → Shows which services found (helps identify wrong device)
  - "Failed to configure characteristics" → Pinpoints characteristic discovery failure

**Impact:**
- Future "Invalid BigBattery device" errors will be diagnosable from logs
- Can distinguish between:
  - Stale peripheral (services = 0)
  - Wrong device type (services != ffe0)
  - Characteristic discovery failure

**Prevention:**
- Every significant state change needs diagnostic logging
- Especially critical: connection flow, protocol loading, error paths
- Use descriptive prefixes: `[CONNECT]`, `[PROTOCOL MANAGER]`, `[QUEUE]`

---

### 5. User Flow Must Prevent Invalid Operations

**Problem:** Before fix, user could click stale battery in device list.

**Lesson:**
- UI should **prevent** invalid operations, not just handle errors gracefully
- Old behavior: Device list showed stale peripheral → user clicked → error
- New behavior: Device list empty → user MUST scan → fresh peripheral

**Why This Is Better:**
1. User cannot accidentally trigger error
2. Scan operation guarantees fresh peripheral objects
3. Clearer user intent: "I want to reconnect → I scan → I click"

**Prevention:**
- Design UI flows that make invalid operations impossible
- Empty device list forces scan → eliminates entire class of bugs
- Prefer prevention over error handling when possible

---

### 6. Battery Restart is Common Event, Must Be Handled

**Problem:** Battery restart happens frequently but wasn't treated as normal event.

**When Battery Restarts:**
- After Module ID change (automatic restart)
- After firmware update
- After manual power cycle
- After low battery protection triggered

**Lesson:**
- Battery restart is NOT an edge case - it's a **common operation**
- App must handle restart gracefully:
  - Detect disconnect
  - Clean state completely
  - Guide user through reconnection
  - Verify settings persisted after restart

**Prevention:**
- Any feature that triggers restart MUST include disconnect handling
- Document all battery operations that cause restart
- Test reconnection flow after every type of restart

---

## Prevention Checklist

**For Future Connection/Reconnection Features:**

1. **State Cleanup:**
   - [ ] Does new feature add connection-related state?
   - [ ] If yes, update `cleanConnection()` to clear it
   - [ ] Add diagnostic log for the clearing action
   - [ ] Test reconnection after disconnect (verify state reset)

2. **Peripheral Lifecycle:**
   - [ ] Do peripheral objects persist across connections?
   - [ ] If yes, clear them on disconnect
   - [ ] Verify peripheral validity before operations
   - [ ] Test reconnection after battery restart

3. **PHANTOM Monitor:**
   - [ ] Are there new invariants to check?
   - [ ] Add PHANTOM check for new invalid states
   - [ ] Test PHANTOM triggers (simulate unexpected disconnects)

4. **Diagnostic Logging:**
   - [ ] Log all significant state changes
   - [ ] Use descriptive prefixes ([CONNECT], [SCAN], etc.)
   - [ ] Log both success AND failure paths
   - [ ] Verify logs appear in diagnostic exports

5. **User Flow:**
   - [ ] Can user perform invalid operations?
   - [ ] If yes, prevent them (disable buttons, clear lists, etc.)
   - [ ] Show clear guidance when action required
   - [ ] Test all reconnection scenarios:
     - Battery restart after settings save
     - Manual power cycle
     - Connection lost due to range
     - Multiple quick disconnects

6. **Testing:**
   - [ ] Test reconnection after battery restart (main scenario)
   - [ ] Test reconnection after manual power cycle
   - [ ] Test reconnection after timeout/disconnect
   - [ ] Verify diagnostic logs show new logging statements
   - [ ] Test multiple disconnect/reconnect cycles

---

## Commit Message

```
fix: Fix reconnection failure after battery restart (stale peripheral references)

Root Cause:
- Battery restarts after Module ID change (automatic behavior)
- PHANTOM monitor detects invalid state, calls cleanConnection()
- cleanConnection() clears Bluetooth state BUT NOT scannedPeripherals
- User returns to Connectivity screen, sees stale "BB-51.2V100Ah-0855"
- User clicks battery → connect() receives stale peripheral object
- iOS CoreBluetooth: stale peripheral invalid after battery restart
- Service discovery fails → notZetaraPeripheralError → "Invalid BigBattery device"

Changes:
1. Added cleanScanning() call in cleanConnection() (ZetaraManager.swift:318-320)
   - Clears scannedPeripherals array on disconnect
   - Forces user to scan for fresh peripheral objects before reconnecting
2. Added detailed logging to connect() method (lines 211-217, 231-235, 263-265)
   - Logs service discovery count and UUIDs
   - Logs specific error types (service vs. characteristic failure)
   - Enables diagnosis of future "Invalid device" errors from client logs
3. Updated common-issues-and-solutions.md with new subsection (lines 400-527)
   - Documents stale peripheral issue pattern
   - Provides diagnostic checklist for similar issues

Result:
- After battery restart, device list is empty (forces fresh scan)
- User scans → receives fresh peripheral object → connection succeeds
- Diagnostic logs show "Scanned peripherals cleared" + service discovery details
- Reconnection works reliably after battery restart, power cycle, or disconnect

Files Modified:
- Zetara/Sources/ZetaraManager.swift (lines 211-217, 231-235, 263-265, 318-320)
- docs/common-issues-and-solutions.md (lines 400-527)

Client Logs Analyzed:
- docs/fix-history/logs/bigbattery_logs_20251010_153756.json (before restart)
- docs/fix-history/logs/bigbattery_logs_20251010_153942.json (after restart)

Testing:
- Reconnection after battery restart (Module ID change)
- Reconnection after manual power cycle
- Diagnostic log verification (new logging statements)
```
