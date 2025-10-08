# Fix: Protocol Request Timeout Not Working

**Date:** October 8, 2025
**Author:** Development Team
**Severity:** Critical
**Status:** Fixed

## Client Complaint

Client Joshua reported multiple issues:
1. "Unable to select module ID number or able to touch any protocols"
2. "No save button prompted when selecting an ID number"
3. "When disconnecting battery, app fails to recognize it's no longer connected"

## Problem Analysis

### Evidence from Logs
Client provided log file: `bigbattery_logs_20251008_091910.json`

**Critical Finding:**
```json
"recentLogs": [
  "[09:17:50] [QUEUE] 🚀 Executing getModuleId",
  // NO completion logged - request hung indefinitely
]
```

**Timeline:**
- getModuleId request started: 09:17:50
- Log file sent by client: 09:19:10
- **Actual duration: 80+ seconds** (should have timed out after 10 seconds)

**Impact:**
- All protocol values showed "--" (not loaded)
- Settings screen remained unusable
- Save button never appeared
- User unable to configure device

### Root Cause

**The timeout operator was applied at the WRONG level in the RxSwift chain.**

#### What We Did Wrong (Before):
```swift
// ProtocolDataManager.swift
manager.queuedRequest("getModuleId") {
    return manager.getModuleId()
}
.timeout(.seconds(10), scheduler: MainScheduler.instance) // ❌ DIDN'T WORK!
.retry(1)
```

**Why It Didn't Work:**
1. `queuedRequest()` executes the request inside `requestQueue.async { }`
2. The timeout operator was applied to the outer `Maybe` that gets queued
3. By the time the timeout operator saw the `Maybe`, it was already inside an async block
4. The actual Bluetooth observation stream (`observeValueUpdateAndSetNotification`) was nested inside
5. The external timeout **never reached** the actual waiting/observation code
6. Result: Request could hang forever, no timeout occurred

#### Architecture Problem:
```
[Timeout Operator]              ← Applied here (WRONG!)
    ↓
[queuedRequest async block]
    ↓
[getModuleId()]
    ↓
[writeControlData()]
    ↓
[observeValueUpdateAndSetNotification] ← Actually waits here!
```

The timeout needs to be **inside** the observation stream, not outside the async wrapper.

## Solution

### Fix 1: Move Timeout Inside Observable Chain

**ZetaraManager.swift (lines 634-670)**

```swift
return Maybe.create { observer in
    peripheral.observeValueUpdateAndSetNotification(for: notifyCharacteristic)
        .compactMap { $0.value }
        .map { [UInt8]($0) }
        .filter { Data.isControlData($0) }
        .do { print("receive control data: \($0.toHexString())") }
        .take(1) // NEW: Take only first response
        .timeout(.seconds(10), scheduler: MainScheduler.instance) // ✅ INSIDE!
        .observeOn(MainScheduler.instance)
        .subscribeOn(MainScheduler.instance)
        .subscribe { event in
            switch event {
                case .next(let _data):
                    observer(.success(_data))
                case .error(let error):
                    return observer(.error(error)) // Propagate timeout error
                default:
                    return observer(.error(ZetaraManager.Error.writeControlDataError))
            }
        }

    return Disposables.create { [weak self] in
        self?.moduleIdDisposeBag = nil
    }
}
```

**Key Changes:**
1. Added `.take(1)` to ensure only first response is processed
2. Moved `.timeout()` **INSIDE** the Observable chain where actual waiting happens
3. Timeout now applies directly to the Bluetooth observation stream
4. Error propagates correctly to ProtocolDataManager

### Fix 2: Remove External Timeout

**ProtocolDataManager.swift (lines 114-136, 138-160, 162-185)**

Removed `.timeout(.seconds(10), scheduler: MainScheduler.instance)` from:
- `loadModuleId()`
- `loadRS485()`
- `loadCAN()`

**Reason:** External timeout is now redundant since timeout is applied inside `writeControlData()` where it actually works.

**Kept:** Timeout detection in error handlers:
```swift
onError: { [weak self] error in
    if case RxError.timeout = error {
        self?.logProtocolEvent("[PROTOCOL MANAGER] ⏱️ Module ID timeout after 10s")
    } else {
        self?.logProtocolEvent("[PROTOCOL MANAGER] ❌ Failed to load Module ID after retry: \(error)")
    }
    self?.moduleIdSubject.onNext(nil)
}
```

### Fix 3: Remove Duplicate Logging

**ZetaraManager.swift cleanConnection() (lines 262-291)**

**Before:**
```swift
print("[CONNECTION] Cleaning connection state")
protocolDataManager.logProtocolEvent("[CONNECTION] Cleaning connection state")
```

**After:**
```swift
protocolDataManager.logProtocolEvent("[CONNECTION] Cleaning connection state")
```

Removed duplicate `print()` statements throughout `cleanConnection()`, kept only `logProtocolEvent()` for consistency.

### Fix 4: Make isCleaningConnection Thread-Safe

**ZetaraManager.swift (lines 70-74, 262-281)**

**Added serial queue:**
```swift
private let cleanConnectionQueue = DispatchQueue(label: "com.zetara.cleanConnection")
```

**Atomic flag checking:**
```swift
let shouldProceed = cleanConnectionQueue.sync { () -> Bool in
    guard !isCleaningConnection else {
        return false
    }
    isCleaningConnection = true
    return true
}

guard shouldProceed else {
    protocolDataManager.logProtocolEvent("[CONNECTION] ⚠️ Skipping duplicate cleanConnection call")
    return
}

defer {
    cleanConnectionQueue.sync {
        isCleaningConnection = false
    }
}
```

**Reason:** Multiple sources call `cleanConnection()` concurrently:
- Connection Monitor (every 2 seconds)
- `observeDisconnect` callback
- SceneDelegate app lifecycle events

Serial queue ensures atomic read-modify-write of the flag.

## Expected Behavior After Fix

1. **Protocol loading with timeout:**
   - Request starts executing
   - If device doesn't respond within 10 seconds → timeout error
   - Logged: `[PROTOCOL MANAGER] ⏱️ Module ID timeout after 10s`
   - UI can show appropriate error state

2. **Settings screen:**
   - If protocol loads successfully → protocol values populate
   - If timeout occurs → error state after 10s, user can retry
   - Save button appears/disappears based on valid state

3. **No indefinite hangs:**
   - Maximum wait time: 10 seconds per protocol request
   - Retry happens automatically (1 retry)
   - Total maximum time: ~20 seconds for one request

## Testing Checklist

- [ ] Connect to device with good signal → protocols load successfully
- [ ] Connect to device with poor signal → timeout after 10s, proper error logged
- [ ] Multiple rapid disconnects/reconnects → no crashes, cleanConnection atomic
- [ ] Settings screen → can select Module ID after timeout recovery
- [ ] Verify logs show timeout events correctly

## Related Files

- `/Zetara/Sources/ZetaraManager.swift` (lines 634-670, 262-291, 70-74)
- `/Zetara/Sources/ProtocolDataManager.swift` (lines 114-185)
- Log file: `docs/fix-history/logs/bigbattery_logs_20251008_091910.json`

## Lessons Learned

1. **RxSwift timeout placement is critical:**
   - Must be applied INSIDE the Observable chain where actual waiting occurs
   - External timeout on Maybe/Single doesn't reach nested async operations

2. **Async queue operators change timeout semantics:**
   - When using custom queue operators (like `queuedRequest`), timeout must be inside
   - Verify timeout works by testing actual hanging scenarios

3. **Thread-safe flag patterns:**
   - Simple Bool flags are not thread-safe
   - Use serial DispatchQueue for atomic read-modify-write operations
   - Multiple concurrent callers require synchronization

4. **Logging consistency:**
   - Use single logging mechanism (ProtocolDataManager.logProtocolEvent)
   - Avoid duplicate print() and logProtocolEvent() calls
   - Centralized logs are easier to export and analyze

## Prevention

- Test timeout behavior in integration tests with simulated delays
- Document where timeout operators should be placed in custom RxSwift operators
- Use serial queues for all shared mutable state
- Regular log review with clients to catch issues early
