# Build 42: Fix writeControlData/getBMSData Cleanup (Minimal Approach)

**Date:** 2025-11-25
**Status:** TESTING (awaiting results)
**Attempt:** #12

**Navigation:**
- Previous: [Build 41](build-41.md)
- Next: [Build 43](build-43.md)
- Main: [../THREAD-001.md](../THREAD-001.md)

---

## Build 41 Test Results Summary:

| Test | Result | Issue |
|------|--------|-------|
| Test 1 (Battery restart) | FAILED | Full cleanup triggered, UUID destroyed |
| Test 2 (Settings navigation) | FAILED | Full cleanup triggered, protocols "--" |
| Test 3 (App restart) | SUCCESS | Cross-session reconnect works |
| Test 4 (Walk away) | Observation | "tap to connect" appears correctly |

**Pattern:** Mid-session reconnect still broken, startup reconnect works.

---

## Root Cause Analysis:

### Discovery Process:

**Build 41 logs showed:**
```
[BLUETOOTH] No peripheral for writeControlData
[CLEANUP] Full cleanup requested (MANUAL disconnect)
[CLEANUP] Cleared persistent UUID from storage (auto-reconnect disabled)
```

**Build 41 fixed viewWillAppear correctly, BUT:**
- `writeControlData()` and `getBMSData()` call `cleanConnection()` when peripheral is nil
- This destroys the UUID before health monitor (3-sec interval) can detect disconnect
- Auto-reconnect becomes impossible

### All cleanConnection() Call Sites in ZetaraManager.swift:

**ALREADY FIXED (use partial cleanup):**
1. Line 149 - Global disconnect handler (Build 38)
2. Line 185 - Health monitor (Build 40)
3. Line 133 - viewWillAppear (Build 41)

**NOT FIXED (still use FULL cleanup):**
1. Line 1201 - writeControlData() - **HIGH PRIORITY (Build 42)**
2. Line 1102 - getBMSData() - **HIGH PRIORITY (Build 42)**
3. Line 961, 985 - Phantom detection - MEDIUM (future build)
4. Line 364 - connect() pre-cleanup - LOW (future build)
5. Line 773 - refreshPeripheral - LOW (future build)
6. Line 124 - Bluetooth OFF handler - LOW (future build)

---

## Build 42 Solution (Minimal Approach):

Following "ONE PROBLEM = ONE BUILD" rule from CLAUDE.md.

### What We Fix in Build 42:

| Location | Line | Before | After |
|----------|------|--------|-------|
| writeControlData() | 1201 | cleanConnection() | Just return error |
| getBMSData() | 1102 | cleanConnection() | Just return error |

### What We DON'T Fix (future builds):

- Phantom detection (lines 961, 985)
- connect() pre-cleanup (line 364)
- refreshPeripheral (line 773)
- Bluetooth OFF handler (line 124)

---

## Changes Made:

### FIX 1: writeControlData() (ZetaraManager.swift)

**Lines 1195-1203:**

```swift
// BEFORE:
guard let peripheral = try? connectedPeripheralSubject.value(),
      let writeCharacteristic = writeCharacteristic,
      let notifyCharacteristic = notifyCharacteristic else {
    print("send data error. no connected peripheral")
    protocolDataManager.logProtocolEvent("[BLUETOOTH] No peripheral for writeControlData")
    cleanConnection()  // DESTROYS UUID!
    return Maybe.error(Error.writeControlDataError)
}

// AFTER:
guard let peripheral = try? connectedPeripheralSubject.value(),
      let writeCharacteristic = writeCharacteristic,
      let notifyCharacteristic = notifyCharacteristic else {
    print("send data error. no connected peripheral")
    protocolDataManager.logProtocolEvent("[BLUETOOTH] No peripheral for writeControlData")
    // Build 42: Don't call cleanConnection() here - let health monitor handle auto-reconnect
    return Maybe.error(Error.writeControlDataError)
}
```

### FIX 2: getBMSData() (ZetaraManager.swift)

**Lines 1095-1103:**

```swift
// BEFORE:
guard let peripheral = try? connectedPeripheralSubject.value(),
      let writeCharacteristic = writeCharacteristic,
      let notifyCharacteristic = notifyCharacteristic else {
    protocolDataManager.logProtocolEvent("[BMS] No peripheral/characteristics available")
    print("!!! No connected device !!!")
    // Clean connection state
    cleanConnection()  // DESTROYS UUID!
    return Maybe.error(ZetaraManager.Error.connectionError)
}

// AFTER:
guard let peripheral = try? connectedPeripheralSubject.value(),
      let writeCharacteristic = writeCharacteristic,
      let notifyCharacteristic = notifyCharacteristic else {
    protocolDataManager.logProtocolEvent("[BMS] No peripheral/characteristics available")
    print("!!! No connected device !!!")
    // Build 42: Don't call cleanConnection() here - let health monitor handle auto-reconnect
    return Maybe.error(ZetaraManager.Error.connectionError)
}
```

### Version Update:

**File:** `BatteryMonitorBL.xcodeproj/project.pbxproj`

```
CURRENT_PROJECT_VERSION = 42;
```

**Build Status:** Compiled successfully

---

## Why This Works:

**Timeline with Fix:**
```
00:00 - Battery disconnects physically
00:01 - writeControlData/getBMSData try to work -> peripheral nil
00:01 - NOW: Return error (no cleanup) -> UUID preserved
00:03 - Health monitor (3-sec interval): Detects disconnect
00:03 - Triggers partial cleanup + auto-reconnect
00:?? - Battery reconnects automatically
```

**Key Insight:**
The health monitor already handles disconnect detection and auto-reconnect properly.
We just need to stop writeControlData/getBMSData from destroying UUID before health monitor can act.

---

## Files Modified:

1. `Zetara/Sources/ZetaraManager.swift`:
   - Line 1201: Removed cleanConnection() from writeControlData()
   - Line 1102: Removed cleanConnection() from getBMSData()

2. `BatteryMonitorBL.xcodeproj/project.pbxproj`:
   - Version 41 -> 42

---

## Test Plan for Joshua (3 tests, ~7 min):

| Test | Description | Build 41 | Build 42 Expected |
|------|-------------|----------|-------------------|
| 1 | Mid-session reconnect (battery restart) | FAILED | PASS |
| 2 | Settings navigation reconnect | FAILED | PASS |
| 3 | Cross-session reconnect (regression) | SUCCESS | SUCCESS |

---

## Success Criteria:

**Build 42 = SUCCESS if:**
- Tests 1, 2 now PASS (were FAILED in Build 41)
- Test 3 still PASS (no regression)
- Logs show NO `[CLEANUP] Full cleanup` after writeControlData error
- Logs show health monitor triggering auto-reconnect instead

**Build 42 = FAILED if:**
- Tests 1, 2 still fail
- Test 3 regresses
- UUID still being destroyed by other sources

---

## Risk Assessment:

- LOW risk: Only removing 2 cleanup calls
- Health monitor already handles detection and auto-reconnect
- Minimal change = easy to track and rollback if needed

---

**Navigation:**
- Previous: [Build 41](build-41.md)
- Next: [Build 43](build-43.md)
- Main: [../THREAD-001.md](../THREAD-001.md)
