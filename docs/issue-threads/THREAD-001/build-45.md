# Build 45: Fix Module ID Not Loading After Reconnect

**Date:** 2025-12-15
**Status:** Ready for testing
**Attempt:** #15

**Navigation:**
- Previous: [Build 44](build-44.md)
- Next: [Build 46](build-46.md)
- Main: [../THREAD-001.md](../THREAD-001.md)

---

## Build 44 Test Results Summary:

| Test | Result | Module ID |
|------|--------|-----------|
| Test 1 (Fresh Connection) | PASS | ID 1 |
| Test 2 (Mid-Session Reconnect) | PASS | "--" |
| Test 3 (Cross-Session Reconnect) | PASS | "--" |
| Test 5 (Protocol Change) | PASS | "--" |

**Build 44 SUCCESS:** Auto-reconnect issue (THREAD-001) is RESOLVED.
**NEW ISSUE:** Module ID shows "--" after any reconnect scenario.

---

## Root Cause Analysis:

### The Bug: Shared DisposeBag Cancellation

In `ZetaraManager.swift`, the `writeControlData()` function used a **shared class-level** `moduleIdDisposeBag` for all BLE control data requests.

**Problem:**
```swift
var moduleIdDisposeBag: DisposeBag?  // Shared by ALL requests!

func writeControlData(...) {
    moduleIdDisposeBag = DisposeBag()  // Creates NEW bag, disposes OLD one!
    // ... subscription disposed by this bag
}
```

### Timeline Showing the Bug:

```
T=0ms:     getModuleId starts, moduleIdDisposeBag created
           Module ID request sent to battery

T=500ms:   getRS485 starts (Request Queue adds 500ms delay)
           NEW moduleIdDisposeBag created
           OLD bag disposed -> Module ID subscription CANCELLED!

T=916ms:   RS485 response arrives -> SUCCESS (subscription still active)

T=~900ms:  Module ID response arrives from battery
           BUT subscription was cancelled at T=500ms!
           Response is IGNORED -> moduleIdSubject never updated!

T=1000ms:  getCAN starts
           NEW moduleIdDisposeBag created
           OLD bag disposed (RS485 already completed, no issue)

T=1336ms:  CAN response arrives -> SUCCESS
```

**Why RS485/CAN succeed but Module ID fails:**
- Module ID takes ~900-1000ms, but only gets 500ms before cancellation
- RS485 takes ~400-500ms actual request time (916ms total includes queue wait)
- RS485 completes before CAN starts at T=1000ms
- CAN is last, so nothing cancels it

---

## Build 45 Solution:

### FIX: Use Dictionary of DisposeBags per Request

**File:** `Zetara/Sources/ZetaraManager.swift`

```swift
// BEFORE (Build 44 - BUG):
var moduleIdDisposeBag: DisposeBag?  // Shared, gets overwritten

func writeControlData(_ data: Foundation.Data) -> Maybe<[UInt8]> {
    moduleIdDisposeBag = DisposeBag()  // Cancels previous request!
    // ...
}

// AFTER (Build 45 - FIX):
var controlDataDisposeBags: [UUID: DisposeBag] = [:]  // Each request has own bag

func writeControlData(_ data: Foundation.Data) -> Maybe<[UInt8]> {
    let requestId = UUID()
    let disposeBag = DisposeBag()
    controlDataDisposeBags[requestId] = disposeBag  // Store, don't replace!

    // ... subscriptions use disposeBag

    return Maybe.create { ...
        return Disposables.create {
            // Cleanup only THIS request's bag when done
            self?.controlDataDisposeBags.removeValue(forKey: requestId)
        }
    }
}
```

### Timeline with Fix:

```
T=0ms:     getModuleId starts, disposeBag[uuid1] created
           Module ID request sent to battery

T=500ms:   getRS485 starts
           NEW disposeBag[uuid2] created (doesn't affect uuid1!)
           Module ID subscription STILL ACTIVE

T=916ms:   RS485 response -> SUCCESS, disposeBag[uuid2] cleaned up

T=~900ms:  Module ID response arrives
           Subscription active! -> moduleIdSubject.onNext(data) -> SUCCESS!

T=1000ms:  getCAN starts, disposeBag[uuid3] created

T=1336ms:  CAN response -> SUCCESS
```

---

## Files Modified:

1. `Zetara/Sources/ZetaraManager.swift`:
   - Line 1213-1217: Replaced `moduleIdDisposeBag` with `controlDataDisposeBags` dictionary
   - Line 1229-1232: Create unique DisposeBag per request
   - Line 1288-1291: Cleanup only this request's bag on completion

2. `BatteryMonitorBL.xcodeproj/project.pbxproj`:
   - Version 44 -> 45

---

## Test Plan (1 test):

| Test | Build 44 | Build 45 Expected |
|------|----------|-------------------|
| Test 1 (Mid-Session Reconnect) | "--" | ID 1 |

**FOCUS:** Module ID loading after reconnect ONLY.

---

## Success Criteria:

**Build 45 = SUCCESS if:**
- Module ID shows "ID 1" (or correct ID) after reconnect
- Logs show `[PROTOCOL MANAGER] Module ID loaded: ID X`
- All three protocols load (Module ID, RS485, CAN)

**Build 45 = FAILED if:**
- Module ID still shows "--" after reconnect
- Module ID timeout or cancellation errors in logs

---

## Diagnostic Logs:

- Build 44 Test 2 (FAILED): `docs/fix-history/logs/bigbattery_logs_20251211_144112.json`
- Build 44 Test 3 (FAILED): `docs/fix-history/logs/bigbattery_logs_20251211_144213.json`
- Build 45 Test: (pending)

---

**Navigation:**
- Previous: [Build 44](build-44.md)
- Next: [Build 46](build-46.md)
- Main: [../THREAD-001.md](../THREAD-001.md)
