# Fix History: Proactive Disconnect Detection (Multi-Layer Defense)

**Date:** October 21, 2025
**Author:** Development Team
**Severity:** 🔴 Critical
**Status:** ⏳ Testing (waiting for client results)
**Affected Component:** Connection state monitoring
**Related Thread:** [THREAD-001](../issue-threads/THREAD-001_invalid-device-reconnection.md)

---

## Context

### Previous Attempt Failed (Oct 20, 2025)

**Attempt #1 (Global Disconnect Handler):**
- **Hypothesis:** observeDisconect subscription cancelled by ViewController lifecycle
- **Solution:** Moved disconnect handler to ZetaraManager singleton
- **Expected:** Disconnect events caught globally from any screen
- **Result:** ❌ **FAILED** - No [DISCONNECT] events in logs after testing

### Client Test Results (Oct 21, 2025)

**Joshua tested Build 28** (with global disconnect handler) across 3 scenarios:
- ❌ Scenario 1: Change protocols → Restart → "Unable to reconnect" + error 4
- ❌ Scenario 2: Disconnect while on different screen → "app thinking connectivity is still ongoing"
- ❌ Scenario 3: Quick reconnect → "connection error" + error 4

**Diagnostic Logs:**
- `docs/fix-history/logs/bigbattery_logs_20251021_104425.json` (Scenario 1)
- `docs/fix-history/logs/bigbattery_logs_20251021_104710.json` (Scenario 2)
- `docs/fix-history/logs/bigbattery_logs_20251021_104922.json` (Scenario 3)

**Critical Finding:**
ALL 3 logs completely MISSING `[DISCONNECT]` events. Global disconnect handler exists in code but iOS CoreBluetooth is NOT generating disconnect events for physical power off!

---

## Root Cause Analysis (Updated)

### The Fundamental Flaw

**Previous understanding:**
> "observeDisconect subscription gets cancelled → move it to global scope → problem solved"

**WRONG!** The real problem:
> "iOS CoreBluetooth does NOT generate disconnect events for physical power off"

### iOS CoreBluetooth Disconnect Event Behavior

**Disconnect events ARE generated for:**
1. ✅ App calls `cancelPeripheralConnection()` (manual disconnect)
2. ✅ Peripheral sends graceful disconnect command
3. ✅ Connection timeout after failed communication attempts (delayed, not immediate)

**Disconnect events are NOT generated for:**
1. ❌ Physical power off (battery turned off at power button)
2. ❌ Device suddenly moves out of BLE range
3. ❌ Sudden connection loss (interference, obstacles)

### Why This Matters for BigBattery

**Common user workflow:**
1. User connects to battery via Bluetooth
2. User changes protocol settings (RS485: GRW → LUX)
3. User taps "Save"
4. **Battery firmware REQUIRES restart** to apply new settings
5. User **physically powers off battery** (not app-initiated disconnect!)
6. Battery restarts
7. User attempts reconnection

**At step 5:** iOS sees peripheral.state change from .connected → .disconnected, BUT does NOT fire observeDisconnect() event because it was physical power loss!

**Result:**
- Our global disconnect handler NEVER called
- `cleanConnection()` NEVER executed
- Stale peripheral references remain
- Connection attempt with stale peripheral → BluetoothError error 4

---

## Solution: Proactive State Monitoring (Multi-Layer Defense)

### Strategy Shift: Reactive → Proactive

**OLD (Reactive):**
```swift
// Wait for iOS to tell us about disconnect
observeDisconnect().subscribe {
    cleanConnection()  // Never fires for physical power off!
}
```

**NEW (Proactive):**
```swift
// Actively check peripheral.state ourselves
// Don't wait for events that may never come
```

### Three Layers of Defense

#### Layer 1: viewWillAppear State Check

**File:** `BatteryMonitorBL/ConnectivityViewController.swift` (lines 116-142)

**Purpose:** Catch stale peripherals when user returns to Bluetooth screen

**Implementation:**
```swift
override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    // Proactive check every time screen appears
    protocolDataManager.logProtocolEvent("[CONNECTIVITY] viewWillAppear - checking peripheral state")

    if let peripheral = ZetaraManager.shared.connectedPeripheralSubject.value {
        let peripheralState = peripheral.state
        protocolDataManager.logProtocolEvent("[CONNECTIVITY] Peripheral state: \(peripheralState.rawValue)")

        if peripheralState != .connected {
            // NOT connected - force cleanup
            protocolDataManager.logProtocolEvent("[CONNECTIVITY] ⚠️ Peripheral state is \(peripheralState.rawValue), not connected - forcing cleanup")
            ZetaraManager.shared.cleanConnection()
            scannedPeripherals = []
        } else {
            protocolDataManager.logProtocolEvent("[CONNECTIVITY] ✅ Peripheral state is connected")
        }
    } else {
        protocolDataManager.logProtocolEvent("[CONNECTIVITY] No connected peripheral - clearing scanned list")
        scannedPeripherals = []
    }
}
```

**Why this works:**
- Executes EVERY time user opens Bluetooth screen
- Checks actual `peripheral.state` (not events)
- Immediate cleanup if state != .connected
- User sees fresh, accurate Bluetooth list

**Expected logs:**
```
[CONNECTIVITY] viewWillAppear - checking peripheral state
[CONNECTIVITY] Peripheral state: 0  ← 0 = .disconnected
[CONNECTIVITY] ⚠️ Peripheral state is 0, not connected - forcing cleanup
[CONNECTION] Cleaning connection state
[CONNECTION] Scanned peripherals cleared
```

---

#### Layer 2: Pre-Flight Check

**File:** `Zetara/Sources/ZetaraManager.swift` (lines 220-229)

**Purpose:** Diagnose stale connection attempts with detailed logging

**Implementation:**
```swift
public func connect(_ peripheral: Peripheral) -> Observable<ConnectedPeripheral> {
    // ... existing logging ...

    // Pre-flight peripheral state check
    let peripheralState = peripheral.state
    protocolDataManager.logProtocolEvent("[CONNECT] Pre-flight check: Peripheral state = \(peripheralState.rawValue)")

    // Warn if attempting connection with stale peripheral
    if peripheralState == .disconnected || peripheralState == .disconnecting {
        protocolDataManager.logProtocolEvent("[CONNECT] ⚠️ WARNING: Attempting connection with stale peripheral (state: \(peripheralState.rawValue))")
        protocolDataManager.logProtocolEvent("[CONNECT] This peripheral reference may be invalid - connection likely to fail with error 4")
    }

    // Always cleanup before new connection
    cleanConnection()
    // ... rest of connection logic ...
}
```

**Why this helps:**
- Doesn't PREVENT connection attempt (still tries)
- BUT logs WARNING if peripheral is stale
- Helps us diagnose in logs WHY connection failed
- "Connection failed with error 4" + "[CONNECT] ⚠️ WARNING" = clear root cause

**Expected logs (stale peripheral):**
```
[CONNECT] Pre-flight check: Peripheral state = 0
[CONNECT] ⚠️ WARNING: Attempting connection with stale peripheral (state: 0)
[CONNECT] This peripheral reference may be invalid - connection likely to fail with error 4
... (connection attempt) ...
[CONNECTIVITY] Connection failed: BluetoothError error 4  ← Expected!
```

---

#### Layer 3: Periodic Health Monitor

**File:** `Zetara/Sources/ZetaraManager.swift` (lines 124-150)

**Purpose:** Active background monitoring - detect disconnect even without events

**Implementation:**
```swift
// In ZetaraManager.init(), after global disconnect handler
Observable<Int>.interval(.seconds(3), scheduler: MainScheduler.instance)
    .subscribe(onNext: { [weak self] tick in
        guard let self = self else { return }
        guard let peripheral = self.connectedPeripheralSubject.value else { return }

        let currentState = peripheral.state

        // Log periodic health check every 30 seconds
        if tick % 10 == 0 {
            self.protocolDataManager.logProtocolEvent("[HEALTH] Periodic check (tick \(tick)) - Peripheral state: \(currentState.rawValue)")
        }

        // If peripheral.state != .connected, connection was lost!
        if currentState != .connected {
            self.protocolDataManager.logProtocolEvent("[HEALTH] ⚠️ DETECTED: Peripheral state changed to \(currentState.rawValue)")
            self.protocolDataManager.logProtocolEvent("[HEALTH] Connection lost without disconnect event - forcing cleanup")

            // Trigger cleanup
            self.cleanConnection()
        }
    })
    .disposed(by: disposeBag)

protocolDataManager.logProtocolEvent("[INIT] ✅ Connection health monitor started (3s interval)")
```

**Why this works:**
- Runs every 3 seconds (background monitoring)
- Checks `peripheral.state` actively
- Detects disconnect even if iOS didn't fire event
- Triggers cleanup within 3 seconds of physical power off
- Logs health checks every 30 seconds (not spammy)

**Expected logs (disconnect detected):**
```
[INIT] ✅ Connection health monitor started (3s interval)
... (user changes protocols, battery disconnects) ...
[HEALTH] ⚠️ DETECTED: Peripheral state changed to 0
[HEALTH] Connection lost without disconnect event - forcing cleanup
[CONNECTION] Cleaning connection state
[CONNECTION] Scanned peripherals cleared
```

---

## Expected Behavior After Fix

### Timeline: Change Protocols → Restart → Reconnect

```
T+0.0s: App launched
[INIT] ✅ Connection health monitor started (3s interval)

T+10s: User connects to battery "BB-51.2V100Ah-0855"
[CONNECT] Attempting connection
[CONNECT] Pre-flight check: Peripheral state = 2  ← .connected
[CONNECT] Services discovered: 1
[CONNECTION] ✅ Characteristics configured

T+30s: [HEALTH] Periodic check (tick 10) - Peripheral state: 2  ← healthy

T+60s: User changes protocols GRW → LUX, taps Save
[SETTINGS] ✅ RS485 Protocol set successfully
[SETTINGS] ✅ CAN Protocol set successfully

T+65s: User powers off battery (physical disconnect)
[Within 3 seconds, health monitor detects state change]

T+67s: [HEALTH] ⚠️ DETECTED: Peripheral state changed to 0
[HEALTH] Connection lost without disconnect event - forcing cleanup
[CONNECTION] Cleaning connection state
[CONNECTION] Scanned peripherals cleared
[CONNECTION] All Bluetooth characteristics cleared

T+90s: User returns to Connectivity screen (viewWillAppear)
[CONNECTIVITY] viewWillAppear - checking peripheral state
[CONNECTIVITY] No connected peripheral - clearing scanned list

T+100s: Battery powered back on, user taps "Scan"
[SCAN] Found peripheral: BB-51.2V100Ah-0855  ← FRESH peripheral!

T+105s: User taps battery to reconnect
[CONNECT] Pre-flight check: Peripheral state = 0  ← disconnected (fresh from scan)
[CONNECT] Attempting connection
[CONNECT] Services discovered: 1
[CONNECTION] ✅ Characteristics configured
✅ CONNECTION SUCCESS!
```

---

## Testing Checklist

### Scenario 1: Change Protocols → Restart
- [ ] Connect to battery
- [ ] Navigate to Settings
- [ ] Change protocols (GRW → LUX)
- [ ] Tap Save
- [ ] Power off battery physically
- [ ] Wait 10 seconds
- [ ] Power battery back on
- [ ] Return to Connectivity screen
- [ ] Click battery to reconnect

**Expected Results:**
- [ ] Logs show `[HEALTH] ⚠️ DETECTED` within 3s of power off
- [ ] Logs show `[CONNECTIVITY] viewWillAppear` check when returning
- [ ] Battery list shows FRESH scan results
- [ ] Connection succeeds (NO error 4)
- [ ] Protocol values show new settings (P02-LUX)

### Scenario 2: Disconnect While on Different Screen
- [ ] Connect to battery
- [ ] Navigate to Home or Details tab (NOT Connectivity)
- [ ] Power off battery physically
- [ ] Wait 5 seconds
- [ ] Navigate to Connectivity screen

**Expected Results:**
- [ ] Logs show `[HEALTH] ⚠️ DETECTED` within 3s (even though not on Connectivity screen!)
- [ ] Logs show `[CONNECTIVITY] viewWillAppear` check
- [ ] Connectivity screen shows "Available devices" (not stale battery)
- [ ] Battery list is EMPTY or shows fresh scan
- [ ] NO "app thinking connectivity is still ongoing"

### Scenario 3: Quick Reconnect
- [ ] Connect to battery
- [ ] Power off battery
- [ ] IMMEDIATELY power battery back on (< 2 seconds)
- [ ] Go to Connectivity screen

**Expected Results:**
- [ ] Either: Health monitor catches it within 3s, OR
- [ ] viewWillAppear catches stale state on screen return
- [ ] Fresh scan discovers battery
- [ ] Connection succeeds

---

## Files Modified

1. **BatteryMonitorBL/ConnectivityViewController.swift**
   - Added `viewWillAppear()` method (lines 116-142)
   - Proactive peripheral state check
   - Clear scannedPeripherals if state != .connected

2. **Zetara/Sources/ZetaraManager.swift**
   - Added pre-flight check in `connect()` (lines 220-229)
   - Logs WARNING if connecting with stale peripheral
   - Added periodic health monitor in `init()` (lines 124-150)
   - Checks peripheral.state every 3 seconds
   - Logs health status every 30 seconds

3. **docs/issue-threads/** (NEW directory structure)
   - `README.md` - Thread system documentation
   - `THREAD-TEMPLATE.md` - Template for new issues
   - `THREAD-001_invalid-device-reconnection.md` - Full history of this issue

4. **docs/fix-validation-checklist.md** (NEW)
   - Structured process for analyzing test results
   - Compare expected vs reality
   - Update metrics and thread timeline

5. **docs/START-HERE.md**
   - Added "ШАГ 2.5: Issue Thread Context Check"
   - Updated Quick Reference table
   - Added Thread system workflow

6. **docs/fix-history/logs/** (3 new diagnostic logs)
   - `bigbattery_logs_20251021_104425.json` (Scenario 1 test)
   - `bigbattery_logs_20251021_104710.json` (Scenario 2 test)
   - `bigbattery_logs_20251021_104922.json` (Scenario 3 test)

---

## Metrics

| Metric | Before (Attempt #1) | Target (Attempt #2) |
|--------|---------------------|---------------------|
| Disconnect detected | 0% (never) | 100% (within 3s) |
| [HEALTH] or [CONNECTIVITY] logs visible | No | Yes |
| Error 4 frequency | 100% | 0% |
| Successful reconnect rate | 0% | 100% |

**Success criteria:**
- ✅ Disconnect detected in logs (via [HEALTH] or [CONNECTIVITY])
- ✅ All 3 test scenarios pass
- ✅ No "BluetoothError error 4"
- ✅ Client confirms fix works

---

## Lessons Learned

### 1. Don't Trust Framework Events Blindly

**Lesson:** iOS CoreBluetooth disconnect events are unreliable for physical disconnects.

**Why it matters:** We assumed iOS would fire events. Built entire solution around event-driven architecture. When events don't fire, entire system fails.

**Impact:** Always have backup detection mechanism. Don't rely on single source of truth.

### 2. Proactive > Reactive (for critical state)

**Lesson:** Reactive patterns (`.subscribe(onNext:)`) assume events will occur. Proactive patterns (polling/checking) work even when events don't fire.

**Why it matters:** Connection state is CRITICAL. Can't afford to miss disconnect.

**Impact:** For critical state:
- Primary: Reactive (efficient when events DO fire)
- Backup: Proactive (reliable when events DON'T fire)

### 3. Multi-Layer Defense is Essential

**Lesson:** Single point of failure is risky. If Layer 3 health monitor fails to start, Layer 1 viewWillAppear catches it. If Layer 1 missed, Layer 2 logs diagnostic info.

**Why it matters:** Different scenarios trigger different layers:
- Layer 1: User returns to screen
- Layer 2: User attempts connection
- Layer 3: Background monitoring

**Impact:** No single layer is perfect. Combined, they provide comprehensive coverage.

### 4. Thread System Prevents Repeated Mistakes

**Lesson:** Without Thread system, we would have:
- Repeated "wait for events" pattern again
- Not realized Attempt #1 failed until client reported
- Lost context between sessions

**Why it matters:** Thread system shows:
- Failed attempts (what NOT to do)
- Evolution of understanding
- Metrics (what improved/worsened)

**Impact:** Future sessions start with full context, not from zero.

### 5. Test with REAL Scenarios

**Lesson:** Simulator disconnect (`cancelPeripheralConnection()`) generates events. Physical power off does NOT.

**Why it matters:** Testing must match real-world usage. BigBattery users ALWAYS physically power off batteries.

**Impact:** Always test:
- ✅ Physical battery power off (realistic)
- ✅ User navigation between screens (realistic)
- ❌ Don't rely only on simulator

---

## Prevention Guidelines

### For Future BLE Implementations

**Pattern to follow:**

```swift
class BLEManager {
    private let disposeBag = DisposeBag()

    init() {
        // Layer 1: Reactive - handle events when they DO fire
        centralManager.observeDisconnect()
            .subscribe(onNext: { [weak self] peripheral, error in
                self?.handleDisconnect()
            })
            .disposed(by: disposeBag)

        // Layer 2: Proactive - detect when events DON'T fire
        Observable<Int>.interval(.seconds(3), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                guard let peripheral = self?.connectedPeripheral else { return }
                if peripheral.state != .connected {
                    self?.handleDisconnect()
                }
            })
            .disposed(by: disposeBag)
    }
}

class MyViewController {
    override func viewWillAppear(_ animated: Bool) {
        // Layer 3: UI-level check when screen appears
        if let peripheral = BLEManager.shared.connectedPeripheral {
            if peripheral.state != .connected {
                BLEManager.shared.cleanup()
            }
        }
    }
}
```

### Code Review Checklist

For any BLE connection code:
- [ ] Is disconnect detection event-driven only? (risky!)
- [ ] Is there proactive state monitoring? (3-5s interval)
- [ ] Does UI check state on viewWillAppear?
- [ ] Are there logs for diagnostic purposes?
- [ ] Has this been tested with PHYSICAL disconnect?

---

## Related Documentation

**This Thread:**
- [THREAD-001](../issue-threads/THREAD-001_invalid-device-reconnection.md)

**Previous Fixes:**
- `2025-10-10_reconnection-after-restart-bug.md` - Stale peripherals
- `2025-10-20_invalid-device-after-restart-regression.md` - Global disconnect handler

**Process Documentation:**
- `docs/issue-threads/README.md` - Thread system overview
- `docs/fix-validation-checklist.md` - How to validate fix results
- `docs/START-HERE.md` - Updated workflow with Thread context check

**Apple Documentation:**
- [CBPeripheralState](https://developer.apple.com/documentation/corebluetooth/cbperipheralstate)
- [Core Bluetooth Best Practices](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/BestPracticesForInteractingWithARemotePeripheralDevice/BestPracticesForInteractingWithARemotePeripheralDevice.html)

---

## Status

⏳ **Testing** - Build deployed, waiting for Joshua's test results

**Next Steps:**
1. Joshua tests all 3 scenarios
2. Analyze diagnostic logs using `fix-validation-checklist.md`
3. Update THREAD-001 with results
4. Update metrics table
5. If success: Mark thread as RESOLVED
6. If failed: Analyze why, plan Attempt #3

---

**Created:** 2025-10-21
**Last Updated:** 2025-10-21
