# Build 43: Fix PHANTOM Detection Cleanup

**Date:** 2025-11-25
**Status:** TESTING (awaiting results)
**Attempt:** #13

**Navigation:**
- Previous: [Build 42](build-42.md)
- Next: [Build 44](build-44.md)
- Main: [../THREAD-001.md](../THREAD-001.md)

---

## Build 42 Test Results Summary:

| Test | Result | Issue |
|------|--------|-------|
| Test 1 (Mid-session) | FAILED | Does not reconnect, stuck in disconnection status |
| Test 2 (Settings nav) | FAILED | Same as test 1 |
| Test 3 (Cross-session) | SUCCESS | ID takes time to show, works after Settings |

**Build 42 fix worked** - no cleanup after getBMSData error.
**But PHANTOM detection** still calls cleanConnection() and destroys UUID.

---

## Root Cause Analysis:

### What is PHANTOM Detection?

Code in `verifyConnectionState()` that detects orphan state:
- BMS timer running but no peripheral connected
- Peripheral exists but state != connected

### Where is the code?

`ZetaraManager.swift`:
- **Line 961:** "No peripheral but BMS timer running" → `cleanConnection()`
- **Line 985:** "Phantom connection detected" (state != connected) → `cleanConnection()`

### Timeline showing the problem:

```
00:00 - Battery disconnects
00:01 - getBMSData() → "No peripheral" → returns error (Build 42: no cleanup)
00:02 - PHANTOM detection runs
00:02 - Sees "No peripheral but BMS timer running!"
00:02 - Calls cleanConnection() → UUID DESTROYED
00:03 - Health monitor can't auto-reconnect (no UUID)
```

---

## All cleanConnection() Call Sites - Status After Build 43

| # | Location | Line | Status |
|---|----------|------|--------|
| 1 | Global disconnect handler | 149 | FIXED (Build 38) |
| 2 | Health monitor | 185 | FIXED (Build 40) |
| 3 | viewWillAppear | 133 | FIXED (Build 41) |
| 4 | writeControlData() | 1201 | FIXED (Build 42) |
| 5 | getBMSData() | 1102 | FIXED (Build 42) |
| 6 | PHANTOM detection #1 | 961 | **FIXED (Build 43)** |
| 7 | PHANTOM detection #2 | 985 | **FIXED (Build 43)** |
| 8 | connect() pre-cleanup | 364 | NOT FIXED (LOW) |
| 9 | refreshPeripheral | 773 | NOT FIXED (LOW) |
| 10 | Bluetooth OFF handler | 124 | NOT FIXED (LOW) |

**HIGH priority items: 7/7 FIXED after Build 43**

---

## Build 43 Solution:

### FIX 1: PHANTOM detection #1 (line 961)

```swift
// BEFORE:
if peripheral == nil && bmsTimerActive {
    protocolDataManager.logProtocolEvent("[CONNECTION] ⚠️ PHANTOM: No peripheral but BMS timer running!")
    cleanConnection()  // DESTROYS UUID!
    return
}

// AFTER:
if peripheral == nil && bmsTimerActive {
    protocolDataManager.logProtocolEvent("[CONNECTION] ⚠️ PHANTOM: No peripheral but BMS timer running!")
    // Build 43: Use partial cleanup to preserve UUID for auto-reconnect
    cleanConnectionPartial()
    // Trigger auto-reconnect if UUID available
    if autoReconnectEnabled, let uuid = cachedDeviceUUID {
        protocolDataManager.logProtocolEvent("[PHANTOM] Triggering auto-reconnect with UUID: \(uuid)")
        attemptAutoReconnect(peripheralUUID: uuid)
    }
    return
}
```

### FIX 2: PHANTOM detection #2 (line 985)

```swift
// BEFORE:
if currentState != .connected {
    protocolDataManager.logProtocolEvent("[CONNECTION] ⚠️ Phantom connection detected!")
    cleanConnection()  // DESTROYS UUID!
}

// AFTER:
if currentState != .connected {
    protocolDataManager.logProtocolEvent("[CONNECTION] ⚠️ Phantom connection detected!")
    // Build 43: Use partial cleanup to preserve UUID for auto-reconnect
    cleanConnectionPartial()
    // Trigger auto-reconnect if UUID available
    if autoReconnectEnabled, let uuid = cachedDeviceUUID {
        protocolDataManager.logProtocolEvent("[PHANTOM] Triggering auto-reconnect with UUID: \(uuid)")
        attemptAutoReconnect(peripheralUUID: uuid)
    }
}
```

### Version Update:

```
CURRENT_PROJECT_VERSION = 43;
```

---

## Why This Should Work:

**Timeline with Fix:**
```
00:00 - Battery disconnects
00:01 - getBMSData() → "No peripheral" → returns error (no cleanup)
00:02 - PHANTOM detection runs
00:02 - Sees "No peripheral but BMS timer running!"
00:02 - Calls cleanConnectionPartial() → UUID PRESERVED ✅
00:02 - Calls attemptAutoReconnect() → Persistent request created ✅
00:?? - Battery powers back on
00:?? - iOS auto-connects via persistent request
00:?? - SUCCESS!
```

---

## Files Modified:

1. `Zetara/Sources/ZetaraManager.swift`:
   - Line 961: PHANTOM detection #1 → partial cleanup + auto-reconnect
   - Line 985: PHANTOM detection #2 → partial cleanup + auto-reconnect

2. `BatteryMonitorBL.xcodeproj/project.pbxproj`:
   - Version 42 → 43

---

## Test Plan for Joshua (3 tests):

| Test | Build 42 | Build 43 Expected |
|------|----------|-------------------|
| Test 1 (Mid-session) | FAILED | PASS |
| Test 2 (Settings nav) | FAILED | PASS |
| Test 3 (Cross-session) | SUCCESS | SUCCESS |

---

## Success Criteria:

**Build 43 = SUCCESS if:**
- Tests 1, 2 now PASS
- Test 3 still PASS (no regression)
- Logs show `[PHANTOM] Triggering auto-reconnect with UUID:`
- Logs show NO `[CLEANUP] 🔴 Full cleanup` after PHANTOM detection

**Build 43 = FAILED if:**
- Tests 1, 2 still fail
- UUID still being destroyed by remaining LOW priority items

---

## What's Left (LOW Priority):

If Build 43 fails, only these remain:
- connect() pre-cleanup (line 364)
- refreshPeripheral (line 773)
- Bluetooth OFF handler (line 124)

---

**Navigation:**
- Previous: [Build 42](build-42.md)
- Next: [Build 44](build-44.md)
- Main: [../THREAD-001.md](../THREAD-001.md)
