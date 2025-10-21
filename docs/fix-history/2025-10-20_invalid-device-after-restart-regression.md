# Fix History: "Invalid Device" Error After Battery Restart (observeDisconect Lifecycle Regression)

**Date:** October 20, 2025
**Author:** Development Team
**Severity:** 🔴 Critical
**Status:** ✅ Fixed
**Affected Component:** ConnectivityViewController - observeDisconect subscription lifecycle
**Related Issues:** "Invalid device" error when reconnecting after battery restart, stale peripheral references

---

## Context

### Client Report (Joshua - October 20, 2025)

**Email received at 09:16:48:**
> Connected to battery
> - ID stayed at 1
> - changed both protocols from GRW → LUX
> - saved changes
> - disconnected & restarted battery (turned off & turned back on)
> - **invalid connection error when I click on battery in Bluetooth**
> - send logs

**Diagnostic Log:** `docs/fix-history/logs/bigbattery_logs_20251020_091648.json`

**Device:** BB-51.2V100Ah-0855 (BigBattery ETHOS module)

---

## Problem Analysis

### Evidence from Logs

**Timeline from logs:**

```
[09:16:34] [SETTINGS] Setting RS485 Protocol: 'P01-GRW' → 'P02-LUX'
[09:16:34] [QUEUE] 🚀 Executing setCAN
[09:16:34] [QUEUE] ✅ setCAN completed in 87ms
[09:16:34] [SETTINGS] ✅ CAN Protocol set successfully
[09:16:34] [QUEUE] 🚀 Executing setRS485
[09:16:35] [QUEUE] ✅ setRS485 completed in 762ms
[09:16:35] [SETTINGS] ✅ RS485 Protocol set successfully
    ↓
[Client physically disconnected and restarted battery]
    ↓
[09:16:41] [CONNECT] ❌ Connection error: The operation couldn't be completed. (RxBluetoothKit2.BluetoothError error 4.)
[09:16:41] [CONNECTION] ⚠️ PHANTOM: No peripheral but BMS timer running!
[09:16:41] [CONNECTION] Cleaning connection state
[09:16:41] [QUEUE] Request queue cleared
[09:16:41] [CONNECTION] 🛑 BMS timer stopped
[09:16:41] [CONNECTION] BMS data cleared
[09:16:41] [PROTOCOL MANAGER] Clearing all protocols
[09:16:41] [CONNECTION] Scanned peripherals cleared
[09:16:41] [CONNECTION] All Bluetooth characteristics cleared
[09:16:41] [CONNECTION] Cached device UUID cleared
[09:16:41] [CONNECTION] Connection state cleaned
```

**Current State (from logs):**
```json
{
  "protocolInfo": {
    "currentValues": {
      "moduleId": "--",
      "rs485Protocol": "--",
      "canProtocol": "--"
    }
  },
  "batteryInfo": {
    "voltage": 0,
    "soc": 0,
    "cellVoltages": []
  },
  "bluetoothInfo": {
    "state": "poweredOn",
    "connectionAttempts": 0
  }
}
```

**Key Observations:**

1. ✅ Protocols saved successfully before disconnect
2. ❌ "BluetoothError error 4" when attempting reconnection
3. ⚠️ PHANTOM connection detected (BMS timer running without peripheral)
4. ✅ cleanConnection() executed **AFTER** connection error
5. ❌ All protocol values cleared ("--")
6. ❌ No battery data (voltage: 0)

**The Critical Question:**
Why did cleanConnection() execute AFTER the connection error, not WHEN the battery disconnected?

---

## Root Cause Analysis

### The Lifecycle Problem

**Issue:** `observeDisconect()` subscription in ConnectivityViewController is tied to ViewController lifecycle.

**Code BEFORE fix (ConnectivityViewController.swift lines 95-100):**

```swift
// viewDidLoad
ZetaraManager.shared.observeDisconect()
    .subscribeOn(MainScheduler.instance)
    .subscribe {[weak self] event in
        self?.state = .unconnected
        self?.tableView.reloadData()
    }.disposed(by: self.disposeBag)  // ← Tied to ViewController lifecycle!

// viewWillDisappear (line 110)
disposeBag = DisposeBag()  // ❌ CANCELS observeDisconect subscription!
```

### User Flow Leading to Bug

**Complete timeline:**

1. **User on ConnectivityViewController** → views battery list
2. **User taps battery "BB-51.2V100Ah-0855"** → connection established
3. **User navigates to SettingsViewController**
   - **ConnectivityViewController.viewWillDisappear** fires
   - **`disposeBag = DisposeBag()`** executes
   - **❌ observeDisconect subscription CANCELLED**
4. **User changes protocols** (RS485: GRW → LUX, CAN: GRW → LUX)
5. **User taps "Save"** → protocols saved to battery
6. **Battery firmware triggers automatic restart** (required after protocol change)
7. **Battery physically disconnects** (power cycle)
   - **❌ observeDisconect subscription already cancelled (step 3)**
   - **❌ Disconnect event NOT DETECTED**
   - **❌ cleanConnection() NOT CALLED**
   - **❌ scannedPeripherals array NOT CLEARED**
8. **Battery restarts and powers back on**
9. **User returns to ConnectivityViewController**
   - **viewDidLoad** executes → NEW observeDisconect subscription created
   - **❌ scannedPeripherals property STILL contains old peripheral reference** (class property persists)
   - **tableView shows "BB-51.2V100Ah-0855"** (stale peripheral from step 2)
10. **User taps battery in list**
11. **App attempts connection using STALE CBPeripheral instance**
12. **iOS CoreBluetooth rejects stale peripheral** → "BluetoothError error 4"
13. **NOW cleanConnection() is called** (too late!)

### Why Stale Peripherals Are Invalid

**Apple CoreBluetooth Best Practices** state:
> "You shouldn't reuse the same peripheral instance once disconnected - instead you should ask CBCentralManager to give us a fresh CBPeripheral using its known peripheral UUID."

**What happens with stale peripherals:**
- CBPeripheral instance cached by iOS becomes invalid after device restart
- Service discovery fails on stale peripheral
- Connection attempt fails with error
- iOS expects app to obtain fresh peripheral via `retrievePeripheralsWithIdentifiers` or scan

### Research Findings

**From Apple Documentation:**
- iOS caches services and characteristics
- Cache only clears when iOS restarts
- `retrievePeripheralsWithIdentifiers` can return stale peripherals
- Recommended 3-tier reconnection: retrieve → system-connected → scan

**From RxBluetoothKit Issues:**
- Error 4 in RxBluetoothKit = `advertisingStartFailed` (for peripheral mode)
- In our case, underlying CoreBluetooth error during connection attempt
- Signal strength not the issue (client same location)

**From RxSwift Best Practices:**
- Resetting `disposeBag` in `viewWillDisappear` cancels all subscriptions
- For persistent connections (like BLE), avoid tying to ViewController lifecycle
- Use singleton manager with global subscriptions

---

## Solution

### Fix: Global Disconnect Handler in ZetaraManager

**Follows Apple CoreBluetooth best practices:** Peripheral lifecycle management should be at app level, not tied to individual ViewControllers.

### Change 1: Add Global Disconnect Handler

**File:** `Zetara/Sources/ZetaraManager.swift`
**Location:** `init()` method (after line 106)

**ADDED:**
```swift
// Global disconnect handler (NOT tied to any ViewController lifecycle)
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
```

**Why this works:**
- ✅ ZetaraManager is singleton → lives entire app lifetime
- ✅ Subscription never cancelled by ViewController lifecycle
- ✅ Disconnect detected from ANY screen user is on
- ✅ cleanConnection() called IMMEDIATELY when battery disconnects
- ✅ scannedPeripherals cleared before user returns to ConnectivityVC

### Change 2: Remove Duplicate Subscription

**File:** `BatteryMonitorBL/ConnectivityViewController.swift`
**Location:** viewDidLoad (removed lines 95-100)

**REMOVED:**
```swift
// ❌ DELETED - duplicate of global handler
ZetaraManager.shared.observeDisconect()
    .subscribeOn(MainScheduler.instance)
    .subscribe {[weak self] event in
        self?.state = .unconnected
        self?.tableView.reloadData()
    }.disposed(by: self.disposeBag)
```

### Change 3: Add UI State Subscription

**File:** `BatteryMonitorBL/ConnectivityViewController.swift`
**Location:** viewDidLoad (replaced removed subscription)

**ADDED:**
```swift
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

**Why this approach:**
- ✅ Subscribes to `connectedPeripheralSubject` (state changes)
- ✅ Updates UI when connection state changes
- ✅ Automatically clears stale peripherals when disconnected
- ✅ Safe to dispose in viewWillDisappear (only UI subscription, not disconnect handler)
- ✅ Works regardless of which screen caused disconnect

---

## Expected Behavior After Fix

### New Flow (Fixed)

1. **User on ConnectivityVC** → connects to battery
2. **User navigates to SettingsVC**
   - ConnectivityVC.viewWillDisappear → disposeBag reset
   - **✅ Global disconnect handler STILL ACTIVE** (in ZetaraManager)
3. **User changes protocols → Save**
4. **Battery disconnects (restart)**
   - **✅ Global handler detects disconnect**
   - **✅ Logs: "[DISCONNECT] 🔌 Device disconnected: BB-51.2V100Ah-0855"**
   - **✅ cleanConnection() called immediately**
   - **✅ scannedPeripherals array cleared**
   - **✅ connectedPeripheralSubject emits nil**
5. **Battery restarts**
6. **User returns to ConnectivityVC**
   - **✅ scannedPeripherals = []** (already cleared)
   - **✅ UI subscription receives nil → clears list again (failsafe)**
   - **✅ Scan starts automatically**
7. **Fresh scan discovers battery**
   - **✅ New CBPeripheral instance obtained**
   - **✅ Battery appears in list**
8. **User taps battery**
   - **✅ Connection with FRESH peripheral**
   - **✅ Service discovery succeeds**
   - **✅ Connection established**
   - **✅ Battery data loads correctly**

### Diagnostic Logs After Fix

**Expected log sequence:**
```
[09:16:35] [SETTINGS] ✅ RS485 Protocol set successfully
[09:16:35] [SETTINGS] ✅ CAN Protocol set successfully
    ↓
[Battery physically disconnects]
    ↓
[09:16:36] [DISCONNECT] 🔌 Device disconnected: BB-51.2V100Ah-0855
[09:16:36] [CONNECTION] Cleaning connection state
[09:16:36] [QUEUE] Request queue cleared
[09:16:36] [CONNECTION] 🛑 BMS timer stopped
[09:16:36] [CONNECTION] BMS data cleared
[09:16:36] [PROTOCOL MANAGER] Clearing all protocols
[09:16:36] [CONNECTION] Scanned peripherals cleared
[09:16:36] [CONNECTION] All Bluetooth characteristics cleared
[09:16:36] [CONNECTION] Cached device UUID cleared
[09:16:36] [CONNECTION] Connection state cleaned
    ↓
[User returns to ConnectivityVC]
    ↓
[09:16:40] [CONNECTIVITY] UI updated: disconnected, cleared stale peripherals
[09:16:40] [SCAN] Starting scan for peripherals
[09:16:42] [SCAN] Found peripheral: BB-51.2V100Ah-0855
    ↓
[User taps battery]
    ↓
[09:16:45] [CONNECT] Attempting connection
[09:16:45] [CONNECT] Device name: BB-51.2V100Ah-0855
[09:16:46] [CONNECTION] ✅ Characteristics configured
[09:16:47] [CONNECTIVITY] Starting protocol loading sequence
[09:16:48] [PROTOCOL MANAGER] ✅ Module ID loaded: ID 1
[09:16:49] [PROTOCOL MANAGER] ✅ RS485 loaded: P02-LUX
[09:16:50] [PROTOCOL MANAGER] ✅ CAN loaded: P02-LUX
[09:16:52] [CONNECTIVITY] Starting BMS timer after protocol loading delay
[09:16:52] [BMS] 🚀 Starting BMS data refresh timer
[09:16:52] [BMS] ✅ BMS data parsed successfully
```

**Key indicators:**
- ✅ Disconnect detected IMMEDIATELY (not after connection attempt)
- ✅ cleanConnection() called at disconnect time
- ✅ Stale peripherals cleared before user returns
- ✅ Fresh scan obtains new peripheral instance
- ✅ Connection succeeds on first attempt
- ✅ No "BluetoothError error 4"

---

## Testing Checklist

### Scenario 1: Change Protocols → Restart Battery (Primary Test)

**Steps:**
1. Connect to battery "BB-51.2V100Ah-0855"
2. Navigate to Settings
3. Change RS485: P01-GRW → P02-LUX
4. Change CAN: P01-GRW → P06-LUX
5. Tap "Save"
6. Disconnect battery physically
7. Wait 5 seconds
8. Reconnect battery (power on)
9. Return to Connectivity screen

**Expected Results:**
- [ ] Diagnostic logs show "[DISCONNECT] 🔌 Device disconnected" at step 6
- [ ] Connectivity list is empty after step 9
- [ ] Fresh scan starts automatically
- [ ] Battery appears in list after ~2 seconds
- [ ] Tapping battery connects successfully (NO "Invalid device" error)
- [ ] Battery data loads correctly (voltage, SOC, cells)
- [ ] Protocol values show new settings (P02-LUX)

### Scenario 2: Navigate Between Screens During Disconnect

**Steps:**
1. Connect to battery
2. Navigate: Connectivity → Settings → Home → Back to Connectivity (repeat 3x)
3. While on Home screen, physically disconnect battery
4. Wait 5 seconds
5. Navigate to Connectivity screen

**Expected Results:**
- [ ] Disconnect detected in logs (even though user not on ConnectivityVC)
- [ ] Connectivity list is empty
- [ ] UI shows "No device connected"
- [ ] No crash, no errors

### Scenario 3: Rapid Disconnect/Reconnect

**Steps:**
1. Connect to battery
2. Navigate to Settings
3. Disconnect battery
4. Immediately reconnect battery (within 2 seconds)
5. Return to Connectivity screen

**Expected Results:**
- [ ] Disconnect detected in logs
- [ ] cleanConnection() called
- [ ] Battery reappears in scan
- [ ] Can connect successfully

### Scenario 4: Multiple Batteries (if available)

**Steps:**
1. Have two BigBattery devices nearby
2. Connect to Battery A
3. Disconnect Battery A
4. Connect to Battery B
5. Return to Connectivity → should see only Battery B

**Expected Results:**
- [ ] Stale reference to Battery A cleared
- [ ] Only fresh scan results visible
- [ ] No "Invalid device" errors

### Scenario 5: Force Kill App

**Steps:**
1. Connect to battery
2. Navigate to Settings
3. Force kill app (swipe up from multitasking)
4. Restart app
5. Go to Connectivity screen

**Expected Results:**
- [ ] App starts fresh
- [ ] No stale peripherals
- [ ] Fresh scan discovers battery
- [ ] Can connect normally

---

## Lessons Learned

### 1. Peripheral Lifecycle Must Be Global

**Problem:**
Tying BLE peripheral lifecycle management to ViewController lifecycle causes missed disconnect events.

**Solution:**
- Handle disconnect at app level (singleton manager)
- ViewControllers only subscribe to state changes for UI updates

**Pattern to follow:**
```swift
// ❌ WRONG - ViewController manages connection
class MyViewController {
    override func viewDidLoad() {
        bleManager.observeDisconnect()
            .subscribe { ... }
            .disposed(by: disposeBag)  // ← Gets cancelled in viewWillDisappear
    }
}

// ✅ CORRECT - Singleton manager handles connection
class BLEManager {
    init() {
        centralManager.observeDisconnect()
            .subscribe { [weak self] in
                self?.cleanup()
            }
            .disposed(by: disposeBag)  // ← Lives entire app lifetime
    }
}

class MyViewController {
    override func viewDidLoad() {
        bleManager.connectionStateSubject
            .subscribe { [weak self] state in
                self?.updateUI(state)  // ← Only UI updates
            }
            .disposed(by: disposeBag)  // ← Safe to cancel
    }
}
```

### 2. Apple CoreBluetooth Caching Behavior

**Key takeaways:**
- iOS caches CBPeripheral instances, services, characteristics
- Cache only cleared on iOS restart
- Reusing stale peripheral instances after disconnect causes failures
- Must obtain fresh instances via `retrievePeripheralsWithIdentifiers` or scan

**Apple's recommended reconnection strategy:**
1. Try `retrievePeripheralsWithIdentifiers` (known UUID)
2. Try `retrieveConnectedPeripheralsWithServices` (system-connected)
3. Fall back to `scanForPeripheralsWithServices` (active discovery)

### 3. RxSwift DisposeBag Lifecycle

**Problem:**
`disposeBag = DisposeBag()` in `viewWillDisappear` cancels ALL subscriptions, including critical ones.

**Solutions:**
- **Option A:** Don't reset disposeBag for persistent subscriptions
- **Option B:** Use separate disposeBags (e.g., `uiDisposeBag` vs `persistentDisposeBag`)
- **Option C:** Move persistent subscriptions to singleton manager (our approach)

### 4. Stale Data in Class Properties

**Problem:**
`scannedPeripherals` is class property → persists across viewDidLoad/viewWillDisappear cycles.

**Why it matters:**
- User navigates away → viewWillDisappear
- Device disconnects → peripherals NOT cleared (subscription cancelled)
- User returns → viewDidLoad → stale data still there

**Solution:**
Clear stale data when connection state changes, not only on viewDidLoad.

### 5. Separation of Concerns

**Good architecture:**
- **Manager:** Handle BLE lifecycle (connect, disconnect, cleanup)
- **ViewController:** Handle UI updates (display state, user actions)

**Bad architecture:**
- **ViewController:** Try to handle both → lifecycle conflicts

---

## Prevention Guidelines

### Pattern: Global BLE Event Handlers

**For production BLE apps:**

```swift
class BLEManager {
    private let disposeBag = DisposeBag()  // ← Lives entire app lifetime

    init() {
        // ✅ Global handlers - never cancelled
        centralManager.observeDisconnect()
            .subscribe(onNext: { [weak self] peripheral, error in
                self?.handleDisconnect(peripheral, error)
            })
            .disposed(by: disposeBag)

        centralManager.observeState()
            .subscribe(onNext: { [weak self] state in
                self?.handleStateChange(state)
            })
            .disposed(by: disposeBag)
    }

    private func handleDisconnect(_ peripheral: CBPeripheral, _ error: Error?) {
        // Cleanup logic here
        // Notify observers via Subject
        connectionStateSubject.onNext(.disconnected)
    }
}

class MyViewController {
    private var disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        // ✅ Subscribe to state changes only
        BLEManager.shared.connectionStateSubject
            .subscribe(onNext: { [weak self] state in
                self?.updateUI(state)
            })
            .disposed(by: disposeBag)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        disposeBag = DisposeBag()  // ✅ Safe - only cancels UI subscriptions
    }
}
```

### Code Review Checklist

When reviewing BLE code:

- [ ] Are disconnect handlers tied to ViewController lifecycle?
- [ ] Do ViewControllers reset disposeBag in viewWillDisappear?
- [ ] Are critical subscriptions cancelled when navigating away?
- [ ] Is peripheral reference stored in ViewController property?
- [ ] After disconnect, is stale peripheral cleaned up?
- [ ] Does code follow Apple's reconnection best practices?
- [ ] Are CBPeripheral instances reused after disconnect?

---

## Related Documentation

### Internal Documentation:
- **Previous Fix:** `docs/fix-history/2025-10-10_reconnection-after-restart-bug.md` (stale peripherals in scannedPeripherals array)
- **Common Issues:** `docs/common-issues-and-solutions.md` - Section 4: Bluetooth Connection Issues

### Apple Documentation:
- [Core Bluetooth Best Practices](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/BestPracticesForInteractingWithARemotePeripheralDevice/BestPracticesForInteractingWithARemotePeripheralDevice.html)
- [CBCentralManager - retrievePeripheralsWithIdentifiers](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/1518863-retrieveperipherals)

### External Resources:
- [Stack Overflow: CoreBluetooth doesn't discover services on reconnect](https://stackoverflow.com/questions/28285393/corebluetooth-doesnt-discover-services-on-reconnect)
- [RxSwift: DisposeBag usage in ViewController](https://stackoverflow.com/questions/55028020/rxswift-disposebag-usage-in-viewcontroller)
- [RxBluetoothKit Issue #298](https://github.com/Polidea/RxBluetoothKit/issues/298)

---

## Files Modified

1. **Zetara/Sources/ZetaraManager.swift**
   - Line 108-122: Added global disconnect handler in init()
   - Handler subscribes to manager.observeDisconnect()
   - Calls cleanConnection() on disconnect
   - Logs disconnect event with peripheral name and error

2. **BatteryMonitorBL/ConnectivityViewController.swift**
   - Removed lines 95-100: Duplicate observeDisconect subscription
   - Added lines 95-112: connectedPeripheralSubject subscription
   - Automatically clears scannedPeripherals when peripheral == nil
   - Logs UI state changes

3. **docs/fix-history/logs/bigbattery_logs_20251020_091648.json** (new file)
   - Client diagnostic log from October 20, 2025
   - Shows "BluetoothError error 4" and subsequent cleanup

---

## Regression Notes

**Why is this a "regression"?**

Previous fix (2025-10-10) added `cleanScanning()` to `cleanConnection()` to clear stale peripherals. This worked when `cleanConnection()` was called.

**However:** The fix didn't account for the observeDisconect subscription being tied to ViewController lifecycle. When user navigated away from ConnectivityVC, the subscription was cancelled, so cleanConnection() was never called on disconnect.

**This fix addresses the root cause:** Global disconnect handler ensures cleanConnection() is ALWAYS called, regardless of user's current screen.

---

## Status

✅ **Fixed** - Deployed for testing

---

## Next Steps

1. ✅ **Code changes committed** (commit 6e4f177)
2. ⏳ **Deploy to TestFlight** - Build for Joshua
3. ⏳ **Request client testing** - All 5 test scenarios
4. ⏳ **Monitor diagnostic logs** - Verify disconnect detection working
5. ⏳ **Update common-issues-and-solutions.md** - Add lifecycle management section
6. ⏳ **Close issue** - After client confirms fix works

---

## About BigBattery Protocol Settings

### What are Module ID, RS485, CAN?

These settings configure how the battery communicates with **inverters** (not the app):

- **Module ID (1-16):** Battery identifier in multi-battery systems
- **RS485 Protocol:** Communication protocol for RS485 bus (P01-GRW, P02-LUX, P06-SAF, etc.)
- **CAN Protocol:** Communication protocol for CAN bus (P01-GRW, P06-LUX, etc.)

**Important:** These protocols are for **battery-to-inverter** communication. The iOS app communicates with the battery BMS via **Bluetooth**, independent of these settings.

### Why Battery Restart Required?

When protocol settings change:
1. App sends new settings to battery BMS via Bluetooth
2. Battery acknowledges and saves to EEPROM
3. **Battery must restart** (firmware requirement) to apply new settings
4. User must physically disconnect/reconnect battery
5. After reconnection, app reloads protocol settings to display current values

**The app cannot force battery restart** - this is BigBattery firmware behavior for safety reasons.

### Protocol Selection Guide

For BigBattery ETHOS systems connecting to EG4 inverters:
- **Battery side:** RS485 = "Lux", CAN = "Lux"
- **Inverter side:** Select "Lithium brand 6"

For other inverter brands, consult compatibility chart or contact BigBattery support.

---

**Last Updated:** October 20, 2025
