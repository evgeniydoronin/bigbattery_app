# Regression Timeline - Break/Fix History

Хронология всех значимых break и fix событий в обратном порядке (новые → старые).

**Last Updated:** 2025-11-17
**Latest Event:** Build 37 - Connection Stability Fix FAILED

---

## 2025-11-14: Build 37 - Connection Stability Fix FAILED ❌

**Event Type:** FAILED FIX ATTEMPT
**Impact:** LOW - No regression, but no improvement either

### What Was Attempted
Fix auto-reconnection when battery restarts without app restart (Scenario 2 from Build 36).

**Hypothesis:** iOS caches peripheral instances with stale characteristic handles → need to force cache release with `cancelPeripheralConnection()`.

### Why It Failed

**Root Cause:** Code placement error - fix placed AFTER pre-flight validation abort point.

**Code Flow:**
```
Lines 252-279: Pre-flight validation (Build 31)
    └─ If peripheral not in scan list → Observable.error() → RETURN
Lines 282-297: Build 37 fix (cancelPeripheralConnection) ← UNREACHABLE!
```

**Evidence:**
- Test logs contain ZERO instances of "Build 37: Forcing release"
- Test 1: "[CONNECT] ❌ ABORT: Peripheral not found in current scan list"
- Test 2: "[CONNECT] Connection failed: Please scan again to reconnect"
- Build 37 fix code never executed in either test

### What Actually Happened

**Scenario Flow:**
1. Battery disconnects (restart OR settings save)
2. Cleanup triggered → `scannedPeripheralsSubject` cleared
3. UI TableView still shows old peripheral (cached in UI layer)
4. User clicks old peripheral (reasonable action)
5. Pre-flight check: "Peripheral not in scan list" → ABORT (correct behavior)
6. Function returns → Build 37 code never reached

**Real Problem Identified:** Not iOS peripheral caching, but **scan list clearing + UI state mismatch**.

### Test Results (2025-11-14)

**Test 1: Battery Restart**
- ❌ Connection failed, error 4 present
- ❌ Build 37 fix never ran

**Test 2: Settings Save**
- ✅ NO crash (DiagnosticsViewController fix works!)
- ❌ Unable to reconnect (Build 37 fix never ran)

**Success Rate:** 0% on PRIMARY objective, 100% on SECONDARY objective

### Impact

**❌ What Got WORSE:** Nothing (no regression)

**✅ What Got BETTER:** DiagnosticsViewController crash eliminated

**➡️ What Stayed SAME:** Connection stability (0% → 0%)

### Positive Outcome

**DiagnosticsViewController Crash Fix WORKS** ✅

**Problem:** UITableView crash when saving settings:
```
Invalid batch updates: sections/rows inconsistent
```

**Solution:** Changed `reloadSections()` to `reloadData()` in `addEvent()` method

**File:** `BatteryMonitorBL/DiagnosticsViewController.swift` (line 274)

**Result:** No crashes in Test 2 when saving settings

### Evidence

- **Commit:** d1bb7a1
- **Tag:** `build-37`
- **Test Logs:** 2 tests, 0 PRIMARY success, 1 SECONDARY success
- **Thread:** THREAD-001 Attempt #7

### Lessons Learned

1. **Code placement is critical** - Placing fix AFTER early return = unreachable code
2. **Pre-flight validation working TOO well** - Blocks stale peripherals AND fix attempts
3. **Real problem is UX not Bluetooth** - UI showing old peripheral while scan list empty
4. **Don't fight good protection** - Pre-flight doing its job correctly
5. **Fix in right layer** - UI problem needs UI solution, not Bluetooth layer fix
6. **Test assumptions** - We assumed iOS caching problem, but it was UI/scan list mismatch

### Recommendation for Build 38

**DO:**
- Auto-trigger scan when scan list cleared (UI layer solution)
- Keep pre-flight validation (it's protecting us)
- Keep all existing fixes untouched

**DON'T:**
- Move Build 37 fix before pre-flight (would disable protection)
- Try to "fix" stale peripherals (pre-flight correctly rejects them)
- Touch Bluetooth logic (working correctly)

**Proposed Solution:**
```swift
// In ConnectivityViewController
scannedPeripheralsSubject.subscribe(onNext: { [weak self] peripherals in
    if peripherals.isEmpty && self?.wasConnected == true {
        self?.startScanning()  // Auto-scan after cleanup
    }
})
```

---

## 2025-11-07: Build 36 - Settings Display RESOLVED ✅

**Event Type:** FIX
**Impact:** HIGH - Critical UX issue resolved

### What Was Fixed
Settings screen now displays Module ID, RS485, and CAN protocols correctly after battery reconnect.

### Root Cause
`disposeBag = DisposeBag()` in `SettingsViewController.viewWillDisappear` destroyed RxSwift subscriptions to protocol subjects from `ProtocolDataManager`.

**Technical Details:**
- `ProtocolDataManager` publishes protocol updates via BehaviorSubjects
- `SettingsViewController` subscribes to these subjects in `viewDidLoad`
- When user navigated away, `viewWillDisappear` called `disposeBag = DisposeBag()`
- This destroyed all subscriptions including protocol subscriptions
- When user returned, Settings had no active subscriptions → displayed "--"

### Solution
Removed `disposeBag = DisposeBag()` from `viewWillDisappear` to keep subscriptions alive throughout ViewController lifecycle.

**File:** `BatteryMonitorBL/SettingsViewController.swift` (line 359)

### Impact Before Fix
- Settings showed "--" for all protocol fields after reconnect
- User couldn't see current protocol configuration
- Confusing UX - protocols were loaded but not displayed

### Impact After Fix
- ✅ Settings displays protocols correctly (Scenario 1)
- ✅ Protocols update when changed (Scenario 2.1: LUX → GRW)
- ✅ Protocols persist when navigating away and back (Scenario 3)

### Evidence
- **Commit:** c5db5fe
- **Tag:** `build-36`
- **Test Logs:** 4 scenarios, 3 SUCCESS
- **Thread:** THREAD-001 Attempt #6

### Lesson Learned
DisposeBag lifecycle management in ViewControllers:
- Recreating disposeBag in `viewWillDisappear` = destroys ALL subscriptions
- For subscriptions that should live with ViewController, keep same disposeBag
- Only create new disposeBag if you intentionally want to cancel subscriptions

---

## 2025-11-03: Build 35 - Settings Display REGRESSION ❌

**Event Type:** REGRESSION
**Impact:** HIGH - Settings stopped displaying protocols

### What Broke
Settings screen started showing "--" for Module ID, RS485, CAN protocols after reconnect.

### Why It Broke
Not directly caused by Build 35 code changes (disconnect crash fix unrelated to Settings).

**Likely Cause:**
- Pre-existing issue in `SettingsViewController` (disposeBag recreation in `viewWillDisappear`)
- Became visible after Build 34's reconnection fix enabled reliable reconnections
- Users now reconnecting more often → issue exposed

### Impact
- Settings showed "--" instead of actual protocol values
- Protocols were loaded (verified in logs) but not displayed in UI
- User confusion - couldn't verify protocol configuration

### Fixed In
Build 36 (2025-11-07)

### Commit
**Build 35 commit:** b4ba427 (introduced disconnect guard, not Settings issue)
**Settings regression:** Pre-existing, exposed by increased reconnections

### Evidence
- **Thread:** THREAD-001 Build 35 analysis
- User tested Settings after reconnect → "--" displayed

### Lesson Learned
Regressions can be pre-existing issues that become visible after enabling new scenarios:
- Build 34 enabled reliable reconnections
- This made Settings screen used more frequently after reconnect
- Exposed pre-existing disposeBag bug

---

## 2025-11-03: Build 35 - Disconnect Crash FIXED ✅

**Event Type:** FIX
**Impact:** CRITICAL - App stability improved

### What Was Fixed
App no longer crashes when battery disconnected.

### Root Cause
`refreshPeripheralInstanceIfNeeded()` was called during `.disconnecting` state, causing race condition:
1. Battery disconnects → peripheral.state = `.disconnecting`
2. Health monitor or foreground return triggers `refreshPeripheralInstanceIfNeeded()`
3. Function tries to access peripheral during invalid state
4. Race condition → crash

### Solution
Added guard to skip refresh if peripheral is disconnecting:

```swift
public func refreshPeripheralInstanceIfNeeded() {
    // Build 35: Guard against refresh during disconnect
    if let currentPeripheral = try? connectedPeripheralSubject.value(),
       currentPeripheral.state == .disconnecting {
        return  // Skip if disconnecting
    }
    // ... rest of refresh logic
}
```

**File:** `Zetara/Sources/ZetaraManager.swift` (lines 450-455)

### Impact Before Fix
- App crashed when user disconnected battery
- Crash during peripheral state transitions
- Unsafe to disconnect

### Impact After Fix
- ✅ Safe to disconnect battery at any time
- ✅ No crashes during disconnect
- ✅ Clean state transitions

### Evidence
- **Commit:** b4ba427
- **Tag:** `build-35`
- **Thread:** THREAD-001 Attempt #5

### Lesson Learned
Always guard against invalid states when accessing peripherals:
- `.disconnecting` state = peripheral is transitioning
- Operations during transitions can cause race conditions
- Check state before attempting refresh or operations

---

## 2025-10-30: Build 34 - Disconnect Crash INTRODUCED ❌

**Event Type:** REGRESSION
**Impact:** CRITICAL - App crashes on disconnect

### What Broke
App started crashing when battery disconnected.

### Why It Broke
Build 34 introduced `refreshPeripheralInstanceIfNeeded()` called at:
1. App launch (`AppDelegate.didFinishLaunchingWithOptions`)
2. Foreground return (`AppDelegate.applicationWillEnterForeground`)

**Race Condition:**
- User disconnects battery → peripheral.state transitions to `.disconnecting`
- If app returns to foreground during disconnect → calls `refreshPeripheralInstanceIfNeeded()`
- Function tries to access peripheral during `.disconnecting` state
- iOS doesn't allow operations on disconnecting peripherals → crash

### Impact
- App crashed when battery disconnected in certain timing windows
- Made disconnect unsafe
- User couldn't reliably disconnect battery

### Fixed In
Build 35 (2025-11-03)

### Commit
**Build 34 commit:** 749a187 (introduced launch-time refresh)

### Evidence
- **Thread:** THREAD-001 Build 34 analysis
- Crash logs showing race condition during disconnect

### Lesson Learned
When adding proactive operations (like refresh), must guard against ALL peripheral states:
- `.connected` = safe to operate
- `.disconnecting` = NOT safe (transitioning)
- `.disconnected` = safe to cleanup
- Always check state before operations

---

## 2025-10-30: Build 34 - Reconnection RESOLVED ✅

**Event Type:** FIX
**Impact:** CRITICAL - Major breakthrough in error 4 issue

### What Was Fixed
Error 4 (invalid handle) completely eliminated. Reconnection now works reliably.

### Root Cause (Final Understanding)
iOS CoreBluetooth caches peripheral instances AND their characteristic handles. When battery disconnects:
1. Peripheral disconnects (iOS may or may not fire event)
2. Characteristic handles become invalid (stale)
3. App tries to use cached peripheral with stale handles
4. iOS rejects operations → error 4

**Key Insight:**
`retrievePeripherals(withIdentifiers:)` returns iOS's cached instance, which may have stale characteristics. Need to proactively retrieve fresh instance BEFORE user attempts reconnection.

### Solution
Proactively retrieve fresh peripheral instance at:
- **App launch** (`didFinishLaunchingWithOptions`) - catches stale peripherals from previous session
- **Foreground return** (`applicationWillEnterForeground`) - catches stale peripherals after backgrounding

```swift
public func refreshPeripheralInstanceIfNeeded() {
    guard let cachedUUID = cachedDeviceUUID,
          let uuidObj = UUID(uuidString: cachedUUID) else {
        return
    }

    let freshPeripherals = manager.retrievePeripherals(withIdentifiers: [uuidObj])

    guard let freshPeripheral = freshPeripherals.first else {
        cleanConnection()
        return
    }

    connectedPeripheralSubject.onNext(freshPeripheral)
}
```

**Files:**
- `Zetara/Sources/ZetaraManager.swift` (lines 450-488)
- `BatteryMonitor/AppDelegate.swift` (lines 48, 56)

### Impact Before Fix
- Error 4 occurred 75-100% of time on reconnection attempts
- User had to restart app to reconnect
- Reconnection essentially broken

### Impact After Fix
- ✅ Error 4 frequency: 0%
- ✅ Reconnection works reliably
- ✅ No app restart needed

### Evidence
- **Commit:** 749a187
- **Tag:** `build-34`
- **Thread:** THREAD-001 Attempt #4

### Why Build 34 Succeeded vs Build 33
**Build 33:** Refreshed in `connect()` method
- ❌ Problem: User doesn't call `connect()` during reconnect
- ❌ Fix never executed

**Build 34:** Refresh at launch/foreground
- ✅ Proactive: Runs before user attempts anything
- ✅ Catches stale peripherals early

### Lesson Learned
Proactive is better than reactive for peripheral staleness:
- Don't wait for connection attempt to refresh
- Refresh at app lifecycle events (launch, foreground)
- This catches stale peripherals before any operations

---

## 2025-10-29: Build 33 - Fresh Peripheral Fix FAILED ❌

**Event Type:** FAILED FIX ATTEMPT
**Impact:** HIGH - No improvement in error 4

### What Was Attempted
Added fresh peripheral retrieval to `connect()` method to get clean instance before connecting.

```swift
public func connect(_ peripheral: CBPeripheral) -> Observable<ConnectedPeripheral> {
    // ... pre-flight validation ...

    // Build 33: Retrieve fresh peripheral instance
    let peripheralUUID = peripheral.identifier
    let freshPeripherals = manager.retrievePeripherals(withIdentifiers: [peripheralUUID])

    guard let freshPeripheral = freshPeripherals.first else {
        return Observable.error(Error.peripheralNotFound)
    }

    // Use freshPeripheral for connection
    self.connectionDisposable = freshPeripheral.establishConnection()
    // ...
}
```

### Why It Failed
**Critical Flaw:** User doesn't call `connect()` in reconnection scenario!

**Reconnection Flow:**
1. User previously connected → cached peripheral in memory
2. Battery disconnects
3. User stays on previously connected screen (doesn't navigate to Bluetooth screen)
4. BMS timer tries to read data using cached peripheral
5. `connect()` method NEVER CALLED → fix never runs
6. Error 4 occurs with stale characteristics

### Impact
- No improvement - error 4 still occurred 100% of time
- Wasted effort - fix in wrong location
- Need different approach

### Fixed In
Build 34 (2025-10-30) - launch-time refresh

### Commit
**Build 33 commit:** 1625dae

### Evidence
- **Thread:** THREAD-001 Attempt #3 Reflection

### Lesson Learned
Understanding user flow is critical:
- Don't assume user will call specific methods
- Reconnection ≠ new connection (user may stay on same screen)
- Fix must run proactively, not reactively on user action

---

## 2025-10-28: Build 32 - Error 4 Pattern SHIFTED ⚠️

**Event Type:** MAJOR REGRESSION
**Impact:** CRITICAL - Error 4 pattern changed dangerously

### What Changed
Error 4 pattern shifted from pre-flight phase to post-characteristics-configured phase.

**Build 31 Pattern (SAFE):**
- Error 4 detected during PRE-FLIGHT (before connection attempt)
- Pre-flight validation caught stale peripheral
- Connection prevented → user sees "Please scan again"
- Safe - no partial connection state

**Build 32 Pattern (DANGEROUS):**
- Connection appears to succeed ✅
- Characteristics discovered and configured ✅
- When trying to WRITE to characteristics → error 4 ❌
- Dangerous - partial connection state

### Why This Matters
**Partial connection state is more dangerous:**
- App thinks it's connected (peripheral.state = .connected)
- UI shows connected
- But writes fail silently or with errors
- Harder to detect and recover from

### Root Cause
Not caused by Build 32 code changes (UITableView fix unrelated to Bluetooth).

**Possible Causes:**
1. Timing change made stale characteristics visible later in flow
2. Pre-existing issue that timing masked before
3. iOS behavior change

### Impact
- Error 4 frequency: 75% (regression from Build 31's 0%)
- Connection "succeeds" but operations fail
- Confusing error state

### Fixed In
Build 33-34 (fresh peripheral approaches)

### Commit
**Build 32 commit:** 6426b1e (UITableView crashes fix)

### Evidence
- **Thread:** THREAD-001 Build 32 analysis
- Logs showing error 4 after characteristics configured

### Lesson Learned
Indirect regressions happen:
- Code change in one area (UITableView) can expose issues elsewhere (Bluetooth)
- Timing changes can shift when symptoms appear
- Always monitor all critical paths after ANY change

---

## 2025-10-28: Build 32 - UITableView Crashes FIXED ✅

**Event Type:** FIX
**Impact:** MEDIUM - App stability improved

### What Was Fixed
UITableView crashes when opening Settings screen eliminated.

### Root Cause
Data source inconsistencies during table view updates. (Specific technical details not documented in THREAD-001)

### Solution
Fixed UITableView data source management in Settings screen.

### Impact Before Fix
- App crashed when opening Settings
- Crash during cell dequeue
- Settings screen unusable

### Impact After Fix
- ✅ Settings screen opens reliably
- ✅ No table view crashes
- ✅ Stable UI

### Evidence
- **Commit:** 6426b1e
- **Tag:** `build-32`
- **Thread:** THREAD-001 Build 32 mention

### Lesson Learned
Table view data source must stay consistent:
- Cell counts must match data source
- Reloads must happen after data updates
- Guard against async data updates during reloads

---

## 2025-10-27: Build 31 - Pre-flight Validation FIXED ✅

**Event Type:** FIX (Recovery from Build 30 catastrophe)
**Impact:** CRITICAL - Connections working again

### What Was Fixed
Pre-flight validation now correctly distinguishes fresh vs stale peripherals.

### Root Cause (Build 30 Mistake)
Build 30 used `peripheral.state` to detect stale peripherals:
```swift
// WRONG: Build 30 approach
if peripheral.state == .connected {
    // Assumed this means "stale cached peripheral"
    return Observable.error(Error.stalePeripheralError)
}
```

**Why This Failed:**
- `peripheral.state` reflects iOS's connection tracking, not cache status
- Fresh peripherals from scan can have `state = .connected`
- Rejected ALL peripherals including valid ones

### Solution (Build 31)
Validate against scan list instead:
```swift
// CORRECT: Build 31 approach
guard scannedPeripheralsSubject.value().contains(where: { $0.identifier == peripheral.identifier }) else {
    return Observable.error(Error.stalePeripheralError)
}
```

**Logic:**
- Peripheral in recent scan list → fresh ✅
- Peripheral NOT in scan list → stale, reject ❌

### Impact Before Fix (Build 30)
- 0% connection success rate
- ALL connections blocked
- App unusable for Bluetooth operations

### Impact After Fix
- ✅ 100% connection success for fresh peripherals
- ✅ Stale peripherals correctly detected and rejected
- ✅ User sees "Please scan again to reconnect" for stale peripherals

### Evidence
- **Commit:** 6588e52
- **Tag:** `build-31`
- **Thread:** THREAD-001 Attempt #3

### Lesson Learned
Don't rely on peripheral.state for staleness detection:
- `peripheral.state` = iOS's view of connection status
- Doesn't indicate whether peripheral is cached/stale
- Use scan list membership instead

---

## 2025-10-27: Build 30 - CATASTROPHIC FAILURE 💥

**Event Type:** CATASTROPHIC REGRESSION
**Impact:** CRITICAL - All connections blocked (0% success)

### What Broke
ALL Bluetooth connections rejected, including freshly scanned peripherals.

### Root Cause
Flawed pre-flight validation logic used `peripheral.state` to detect stale peripherals:

```swift
// Build 30 WRONG logic
if peripheral.state == .connected {
    // Incorrectly assumed: state=.connected means "stale cached"
    return Observable.error(Error.stalePeripheralError)
}
```

**Why This Was Catastrophically Wrong:**
- iOS can set `peripheral.state = .connected` for FRESH peripherals if it has them cached
- Fresh peripherals from scan can have connected state
- Logic rejected EVERY peripheral including valid ones
- 0% connection success rate

### Impact
- App completely broken for Bluetooth operations
- No connections possible
- User sees "Please scan again" for everything
- Production-blocking severity

### Duration
Less than 4 hours (discovered and reverted same day)

### Fixed In
Build 31 (2025-10-27) - scan list validation

### Commit
**Build 30 commit:** 6588e52 (includes both Build 30 failure and Build 31 fix)

### Evidence
- **Thread:** THREAD-001 Attempt #3 Analysis

### Lesson Learned
**Critical:**  Never use peripheral.state for cache/freshness detection:
- `peripheral.state` indicates connection status, not cache status
- No reliable way to distinguish "cached but connected" vs "freshly scanned and connected"
- Must use application-level tracking (scan list) not iOS-level state

**Process:**
- Test core functionality immediately after major logic changes
- Have rollback plan ready
- Document catastrophic failures for future reference

---

## 2025-10-25: Build 29 - Monitoring Implemented ⚠️

**Event Type:** PARTIAL FIX ATTEMPT
**Impact:** LOW - Detection works but doesn't prevent issue

### What Was Implemented
Two-layer monitoring system to detect when peripheral becomes invalid:

**Layer 1 - Global Disconnect Handler:**
```swift
manager.observeDisconnect()
    .subscribe(onNext: { [weak self] peripheral in
        self?.cleanConnection()
    })
```

**Layer 3 - Health Monitor:**
```swift
Observable<Int>.interval(.seconds(3), scheduler: MainScheduler.instance)
    .subscribe(onNext: { [weak self] _ in
        guard let peripheral = try? self.connectedPeripheralSubject.value() else { return }

        if peripheral.state != .connected {
            self.cleanConnection()
        }
    })
```

### Why It Was Insufficient
**Reactive, not Proactive:**
- Detects AFTER peripheral becomes stale
- Doesn't PREVENT using stale peripheral
- User can still trigger error 4 before detection runs

**Layer 1 Limitation:**
- iOS does NOT fire `didDisconnectPeripheral` for physical power-off
- Only fires for programmatic disconnects or iOS-detected disconnects
- Battery restart = no event

**Layer 3 Limitation:**
- 3-second interval = may miss quick reconnect attempts
- Reactive cleanup = runs after problem already visible

### Impact
- Error 4 still occurred 100% of time
- But cleaner state after detection
- Foundation for future fixes

### Evidence
- **Commit:** a1953a6
- **Tag:** `build-29`
- **Thread:** THREAD-001 Attempt #2

### Lesson Learned
Detection ≠ Prevention:
- Monitoring helps with cleanup but doesn't solve root cause
- Need proactive approach (catch before use) not reactive (cleanup after failure)
- iOS disconnect events unreliable for physical power events

---

## 📊 Regression Statistics

### By Type
- **Fixes:** 6 (Builds 29, 31, 32, 34, 35, 36)
- **Regressions:** 4 (Build 30 catastrophic, Build 32 error 4, Build 34 crash, Build 35 Settings)
- **Failed Attempts:** 2 (Build 29 partial, Build 33 wrong location)

### By Severity
- **Critical (Production-blocking):** 2 (Build 30 all connections, Build 34 crashes)
- **High (Major UX impact):** 4 (Build 32 error 4, Build 33 reconnection, Build 35 Settings, Build 36 Settings)
- **Medium:** 1 (Build 32 UITableView)
- **Low:** 1 (Build 29 monitoring)

### Fix Success Rate
- **Full Success:** 4 (Builds 31, 32 UITable, 35, 36)
- **Partial Success:** 2 (Builds 29, 34)
- **Failed:** 1 (Build 33)

### Time to Fix
- **Immediate (<1 day):** Build 30 → Build 31
- **Short (1-3 days):** Build 34 crash → Build 35
- **Medium (4-7 days):** Build 35 Settings → Build 36
- **Long (>7 days):** Build 29-34 error 4 saga

---

## 🔍 Pattern Analysis

### Common Regression Causes

1. **Lifecycle/Timing Issues** (3 occurrences)
   - Build 34: Refresh during disconnect state
   - Build 32: Error 4 pattern shift
   - Build 35: Settings subscriptions destroyed

2. **Wrong Approach** (2 occurrences)
   - Build 30: State-based validation
   - Build 33: Fix in wrong location

3. **Indirect/Exposure** (2 occurrences)
   - Build 32: UITableView fix exposed error 4 pattern
   - Build 35: Reconnection fix exposed Settings issue

### Success Patterns

1. **Proactive > Reactive** (Build 34 success)
   - Launch-time refresh beats on-demand refresh

2. **Application-level Tracking > System State** (Build 31 success)
   - Scan list validation beats peripheral.state checking

3. **Lifecycle Guards** (Build 35 success)
   - Check state before operations prevents crashes

4. **Persistent Subscriptions** (Build 36 success)
   - Keep disposeBag alive for ViewController-lifetime subscriptions

---

## 📚 Related Documentation

- **BUILD-TRACKING.md:** Full feature status per build
- **STABLE-BUILDS.md:** Last known good builds
- **THREAD-001:** Deep technical analysis of each attempt
- **Git Tags:** `git tag -l "build-*"` to see all builds

---

## 🔄 Update History

- **2025-11-10:** Initial creation - Build 29-36 timeline
- **2025-11-07:** Build 36 Settings fix documented
