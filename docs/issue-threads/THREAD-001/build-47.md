# Build 47: Fix Module ID - Add Notification Setup Delay

**Date:** 2025-12-16
**Status:** Ready for testing
**Attempt:** #17

**Navigation:**
- Previous: [Build 46](build-46.md)
- Next: [Build 48](build-48.md)
- Main: [../THREAD-001.md](../THREAD-001.md)

---

## Build 46 Test Results:

| Test | Result | Module ID | RS485 | CAN |
|------|--------|-----------|-------|-----|
| Mid-Session Reconnect | FAILED | "--" | P02-LUX | P06-LUX |

**Build 46 FAILED:** Observation-before-write fix didn't solve the issue.

---

## Root Cause Analysis:

### Build 46 Fixed: Observation Before Write
Build 46 correctly moved observation setup before writeValue.

### Build 47 Issue: Async Notification Setup

**The Real Problem:**
`observeValueUpdateAndSetNotification` is **ASYNCHRONOUS** - it needs time to:
1. Send BLE command to peripheral to enable notifications
2. Wait for peripheral ACK (~50-200ms)
3. Only THEN can we receive notifications

In Build 46, writeValue is called immediately (0ms delay) after observation setup:

```swift
// Build 46 (problematic timing):
peripheral.observeValueUpdateAndSetNotification(...)  // ASYNC!
    .subscribe(...)
    .disposed(by: disposeBag)

// Called immediately - NO DELAY!
peripheral.writeValue(...)
```

**Race Condition:**
```
T=0ms:     observeValueUpdateAndSetNotification starts
T=0ms:     writeValue() sends request (TOO FAST!)
T=10ms:    Device responds
T=50ms:    Notifications finally enabled (TOO LATE!)
```

Device responds BEFORE notifications are enabled - response is MISSED!

---

## Build 47 Solution:

### FIX: Add 100ms delay before writing

**File:** `Zetara/Sources/ZetaraManager.swift`

```swift
// Build 47 (with delay):
peripheral.observeValueUpdateAndSetNotification(...)
    .subscribe(...)
    .disposed(by: disposeBag)

// Wait for notification setup to complete
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
    guard let self = self else { return }
    self.protocolDataManager.logProtocolEvent("[BLUETOOTH] Now writing request (after 100ms delay)...")
    peripheral.writeValue(data, for: writeCharacteristic, type: writeCharacteristic.writeType)
        .subscribe()
        .disposed(by: disposeBag)
}
```

**Timeline with Fix:**
```
T=0ms:     observeValueUpdateAndSetNotification starts
T=0-100ms: iOS enables notifications on characteristic
T=100ms:   writeValue() sends request (after delay)
T=150ms:   Device responds - observation is READY to catch it!
```

---

## Files Modified:

1. `Zetara/Sources/ZetaraManager.swift`:
   - Line 1213-1216: Added Build 47 comment
   - Line 1285-1293: Wrapped writeValue in 100ms delay

2. `BatteryMonitorBL.xcodeproj/project.pbxproj`:
   - Version 46 -> 47

---

## Expected Log Output (if fix works):

```
[BLUETOOTH] Preparing control data: 1002007165
[BLUETOOTH] Setting up notification observation...
[BLUETOOTH] Now writing request (after 100ms delay)...
[BLUETOOTH] Received notification: 1002...
[BLUETOOTH] Is control data: true
[BLUETOOTH] Got control data response
[PROTOCOL MANAGER] Module ID loaded: ID 1
```

---

## Test Plan (1 test):

**FOCUS:** Module ID loading after reconnect ONLY.

| Test | Build 46 | Build 47 Expected |
|------|----------|-------------------|
| Mid-Session Reconnect | "--" | ID 1 |

**Steps:**
1. Connect to battery
2. Verify Module ID = "ID 1"
3. Walk away (disconnect)
4. Return (reconnect)
5. Verify Module ID = "ID 1" (not "--")

---

## Success Criteria:

**Build 47 = SUCCESS if:**
- Module ID shows "ID 1" after reconnect
- Logs show `[PROTOCOL MANAGER] Module ID loaded: ID X`

**Build 47 = FAILED if:**
- Module ID still shows "--" after reconnect

---

## Diagnostic Logs:

- Build 46 Test (FAILED): `docs/fix-history/logs/bigbattery_logs_20251215_135021.json`
- Build 47 Test: (pending)

---

**Navigation:**
- Previous: [Build 46](build-46.md)
- Next: [Build 48](build-48.md)
- Main: [../THREAD-001.md](../THREAD-001.md)
