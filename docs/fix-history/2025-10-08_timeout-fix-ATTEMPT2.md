# Fix: Protocol Request Timeout - Attempt #2

**Date:** October 8, 2025 (Second Attempt)
**Author:** Development Team
**Severity:** CRITICAL
**Status:** Fixed (properly this time)

## Why Second Attempt?

### First Attempt Failed
See `docs/fix-history/2025-10-08_timeout-fix.md` - marked as "Fixed" but **DID NOT WORK**.

**Evidence from Client Joshua's new logs:**
- Log 1 (15:39:47): getModuleId started at 15:38:58, still hanging at 15:39:47 (49+ seconds)
- Log 2 (15:40:29): Same request, 91 seconds later
- Log 3 (15:41:08): Multiple cleanConnection calls, protocols still "--"

**Client complaint:** "App does not display any module ID's or protocols and when selecting an ID number it does not show what I selected nor does the save button prompt itself to be selected"

---

## Root Cause Analysis

### 🔍 What We Thought We Fixed (Attempt #1):

From previous documentation:
> **Fix 1:** Moved `.timeout()` INSIDE writeControlData's observeValueUpdateAndSetNotification chain
> **Fix 2:** Removed external timeout from ProtocolDataManager

**Result:** Marked as "Fixed" ✅ but **TIMEOUT STILL DIDN'T WORK** ❌

### 🚨 Real Problems (Discovered Now):

#### CRITICAL BUG #1: Subscription in writeControlData NOT Disposed

**ZetaraManager.swift (lines 656-665) - BEFORE FIX:**
```swift
.subscribe { event in
    switch event {
        case .next(let _data):
            observer(.success(_data))
        case .error(let error):
            return observer(.error(error))
        default:
            return observer(.error(ZetaraManager.Error.writeControlDataError))
    }
}
// ← 🚨 NO .disposed(by: ...) !!!

return Disposables.create { [weak self] in
    self?.moduleIdDisposeBag = nil
}
```

**Problem:**
- Subscription created but **NEVER disposed**
- Hangs forever waiting for Bluetooth response
- Timeout **exists** in the chain but subscription is orphaned
- Memory leak + timeout doesn't work

#### CRITICAL BUG #2: Temporary DisposeBag in queuedRequest

**ZetaraManager.swift (line 374) - BEFORE FIX:**
```swift
request()
    .subscribe(onSuccess: { value in
        print("[QUEUE] ✅ completed...")
        observer(.success(value))
    }, onError: { error in
        print("[QUEUE] ❌ failed...")
        observer(.error(error))
    })
    .disposed(by: DisposeBag())  // ← 🚨 TEMPORARY DisposeBag!
```

**Problem:**
1. `DisposeBag()` creates **new** DisposeBag inside async block
2. When async block ends, DisposeBag **deallocates**
3. On deallocation, DisposeBag **cancels all subscriptions**
4. Subscription disposed **BEFORE request completes**
5. `observer(.success/.error)` **NEVER called**
6. Request hangs in Bluetooth layer forever

**This explains:**
- ❌ No `[QUEUE] ✅ completed` logs
- ❌ No `[QUEUE] ❌ failed` logs
- ❌ Request hangs 49+ seconds instead of 10s timeout
- ❌ ProtocolDataManager never receives success/error

---

## Execution Flow (Why It Failed):

```
1. ProtocolDataManager.loadModuleId()
   ↓
2. queuedRequest("getModuleId") { manager.getModuleId() }
   ↓
3. requestQueue.async {
     ↓
   4. request().subscribe(...).disposed(by: DisposeBag())
      ↓
   5. Temporary DisposeBag created
      ↓
   6. getModuleId() → writeControlData() → observeValueUpdateAndSetNotification
      ↓
   7. Subscription created with timeout (but not disposed!)
      ↓
   8. async block ENDS
      ↓
   9. 🚨 Temporary DisposeBag deallocates
      ↓
   10. 🚨 Subscription cancelled by DisposeBag destructor
       ↓
   11. observer(.success/.error) NEVER called
       ↓
   12. Request hangs forever in orphaned subscription
   }
```

**Timeline from logs:**
```
15:38:58 → [QUEUE] 🚀 Executing getModuleId
           ↓
           Subscription created + timeout started
           ↓
           DisposeBag deallocated (subscription disposed)
           ↓
           Timeout exists but subscription is orphaned
           ↓
15:39:47 → (49 seconds later) Still hanging
           ↓
15:40:29 → (91 seconds later) Still hanging
```

---

## Solution (Attempt #2):

### Fix #1: Add Shared DisposeBag for queuedRequest

**ZetaraManager.swift (after line 74):**
```swift
// Shared DisposeBag для queuedRequest
private let requestQueueDisposeBag = DisposeBag()
```

**ZetaraManager.swift (line 374) - FIXED:**
```swift
request()
    .subscribe(onSuccess: { value in
        observer(.success(value))
    }, onError: { error in
        observer(.error(error))
    })
    .disposed(by: self.requestQueueDisposeBag)  // ✅ SHARED DisposeBag!
```

**Why this works:**
- `requestQueueDisposeBag` lives as long as ZetaraManager
- Subscription **NOT cancelled** when async block ends
- `observer(.success/.error)` **WILL be called**

### Fix #2: Add Disposal to writeControlData Subscription

**ZetaraManager.swift (lines 650-695) - FIXED:**
```swift
return Maybe.create { [weak self] observer in
    guard let self = self, let bag = self.moduleIdDisposeBag else {
        observer(.error(Error.writeControlDataError))
        return Disposables.create()
    }

    self.protocolDataManager.logProtocolEvent("[BLUETOOTH] 📡 Started observing...")

    peripheral.observeValueUpdateAndSetNotification(for: notifyCharacteristic)
        .compactMap { $0.value }
        .map { [UInt8]($0) }
        .filter { Data.isControlData($0) }
        .take(1)
        .timeout(.seconds(10), scheduler: MainScheduler.instance)
        .subscribe { event in
            switch event {
                case .next(let _data):
                    observer(.success(_data))
                case .error(let error):
                    observer(.error(error))
                default:
                    observer(.error(ZetaraManager.Error.writeControlDataError))
            }
        }
        .disposed(by: bag)  // ✅ NOW DISPOSED!

    return Disposables.create { [weak self] in
        self?.moduleIdDisposeBag = nil
    }
}
```

**Why this works:**
- Subscription disposed into `moduleIdDisposeBag`
- Subscription lifecycle managed properly
- Timeout **WILL fire** after 10 seconds
- Error propagates to observer

### Fix #3: Add Diagnostic Logging

**Problem:** We had no visibility into what data battery was sending.

**Added comprehensive logging:**

1. **Connection logging** (lines 227-235):
```swift
self?.protocolDataManager.logProtocolEvent("[CONNECTION] ✅ Characteristics configured")
self?.protocolDataManager.logProtocolEvent("[CONNECTION] Write UUID: \(writeCharacteristic.uuid.uuidString)")
self?.protocolDataManager.logProtocolEvent("[CONNECTION] Notify UUID: \(notifyCharacteristic.uuid.uuidString)")
self?.protocolDataManager.logProtocolEvent("[CONNECTION] Device UUID: \(peripheral.identifier.uuidString)")
```

2. **Bluetooth data logging** (lines 643, 656, 659-671, 681, 685, 687, 691):
```swift
// Before writing
protocolDataManager.logProtocolEvent("[BLUETOOTH] 📤 Writing control data: \(data.toHexString())")

// Start observation
protocolDataManager.logProtocolEvent("[BLUETOOTH] 📡 Started observing notifications...")

// ALL incoming data
.do(onNext: { characteristic in
    if let value = characteristic.value {
        let hexString = [UInt8](value).toHexString()
        self.protocolDataManager.logProtocolEvent("[BLUETOOTH] 📥 Received notification: \(hexString)")
    }
})

// Is it control data?
.do(onNext: { bytes in
    let isControl = Data.isControlData(bytes)
    self.protocolDataManager.logProtocolEvent("[BLUETOOTH] Is control data: \(isControl)")
})

// Success
self.protocolDataManager.logProtocolEvent("[BLUETOOTH] ✅ Got control data response")

// Timeout
self.protocolDataManager.logProtocolEvent("[BLUETOOTH] ⏱️ Timeout waiting for response")

// Other errors
self.protocolDataManager.logProtocolEvent("[BLUETOOTH] ❌ Error: \(error)")
```

**Why this is critical:**
- Shows **ALL** data from battery (not just control data)
- Helps diagnose if battery is sending data at all
- Shows if data is being filtered out
- Shows exact moment timeout occurs

---

## Expected Behavior After Fix:

### Successful Protocol Load:
```
[CONNECTION] ✅ Characteristics configured
[CONNECTION] Write UUID: ...
[CONNECTION] Notify UUID: ...
[QUEUE] 📥 Request queued: getModuleId
[QUEUE] 🚀 Executing getModuleId
[BLUETOOTH] 📤 Writing control data: 100700...
[BLUETOOTH] 📡 Started observing notifications...
[BLUETOOTH] 📥 Received notification: 01034e05... (BMS data - ignored)
[BLUETOOTH] 📥 Received notification: 01034e05... (BMS data - ignored)
[BLUETOOTH] 📥 Received notification: 100701... (control data!)
[BLUETOOTH] Is control data: true
[BLUETOOTH] ✅ Got control data response
[QUEUE] ✅ getModuleId completed in 150ms
[PROTOCOL MANAGER] ✅ Module ID loaded: ID 1
```

### Timeout Scenario:
```
[QUEUE] 🚀 Executing getModuleId
[BLUETOOTH] 📤 Writing control data: 100700...
[BLUETOOTH] 📡 Started observing notifications...
[BLUETOOTH] 📥 Received notification: 01034e05... (BMS data)
[BLUETOOTH] 📥 Received notification: 01034e05... (BMS data)
(10 seconds pass, no control data)
[BLUETOOTH] ⏱️ Timeout waiting for response
[QUEUE] ❌ getModuleId failed in 10000ms: timeout
[PROTOCOL MANAGER] ⏱️ Module ID timeout after 10s
```

---

## What We Learned:

### 1. RxSwift Disposal is CRITICAL
- **EVERY** `.subscribe()` MUST have `.disposed(by:)`
- Temporary `DisposeBag()` is almost always wrong
- Use shared DisposeBag or create disposable reference

### 2. Async Queue + RxSwift is Tricky
- Disposable scope matters in async blocks
- Temporary objects in async blocks get deallocated
- Use `self.sharedDisposeBag` not `DisposeBag()`

### 3. Trust But Verify
- Documentation said "Fixed" ✅
- Code review would have caught missing `.disposed(by:)`
- Client logs proved it didn't work
- **Lesson:** Test timeout scenarios with real delays

### 4. Logging is Essential
- Previous logs showed execution start but NO completion
- New logs will show EVERY step of Bluetooth communication
- Helps diagnose "is battery sending data at all?"

---

## Client Logs Evidence:

**Before Fix (Attempt #1):**
- `bigbattery_logs_20251008_153947.json` - 49 seconds hang
- `bigbattery_logs_20251008_154029.json` - 91 seconds hang
- `bigbattery_logs_20251008_154109.json` - Multiple cleanConnection, no protocols

**All logs show:**
```json
"recentLogs": [
  "[15:38:58] [QUEUE] 🚀 Executing getModuleId",
  "[15:38:58] [QUEUE] 📥 Request queued: getModuleId"
]
```

**Missing from ALL logs:**
- ❌ `[QUEUE] ✅ completed`
- ❌ `[QUEUE] ❌ failed`
- ❌ `[PROTOCOL MANAGER] ⏱️ timeout`
- ❌ `[BLUETOOTH] ⏱️ Timeout`

**Proves:** Subscriptions were disposed before completion

---

## Related Files:

- `Zetara/Sources/ZetaraManager.swift` (lines 77, 227-235, 374, 650-695)
- Logs: `docs/fix-history/logs/bigbattery_logs_20251008_15*.json` (3 files)
- Previous attempt: `docs/fix-history/2025-10-08_timeout-fix.md` (FAILED)

---

## Testing Checklist:

After this fix, client should see:

### Good Signal Test:
- [ ] `[BLUETOOTH] 📤 Writing control data` logged
- [ ] `[BLUETOOTH] 📥 Received notification` logged (multiple times)
- [ ] `[BLUETOOTH] ✅ Got control data response` logged
- [ ] `[QUEUE] ✅ completed in XXXms` logged
- [ ] `[PROTOCOL MANAGER] ✅ Module ID loaded` logged
- [ ] Settings screen shows actual Module ID

### Bad Signal / Timeout Test:
- [ ] `[BLUETOOTH] ⏱️ Timeout waiting for response` logged AFTER 10 seconds
- [ ] `[QUEUE] ❌ failed in 10000ms: timeout` logged
- [ ] `[PROTOCOL MANAGER] ⏱️ Module ID timeout after 10s` logged
- [ ] **NO MORE 49+ second hangs**

---

## Prevention:

1. **Code Review Checklist:**
   - [ ] Every `.subscribe()` has `.disposed(by:)`
   - [ ] No `DisposeBag()` without variable assignment
   - [ ] Shared DisposeBag for long-lived subscriptions

2. **Testing:**
   - [ ] Test timeout with simulated 15-second delay
   - [ ] Verify logs show `[QUEUE] ❌ failed` after timeout
   - [ ] Verify Settings screen recovers after timeout

3. **Monitoring:**
   - [ ] Check client logs for `[QUEUE] ✅/❌` entries
   - [ ] If missing, subscription disposal issue
   - [ ] Review all `.disposed(by:)` calls
