# Build Tracking - Feature Status Matrix

Feature × Build matrix показывающий что работает/не работает в каждом билде.

**Last Updated:** 2025-11-17
**Current Build:** Build 37 (FAILED - Build 36 still recommended)

---

## 📊 Quick Overview Table

| Build | Date | Status | Key Achievement | Major Issues |
|-------|------|--------|----------------|--------------|
| **37** | 2025-11-10 | ❌ **FAILED** | DiagnosticsViewController crash fixed | Fix code never executed (pre-flight blocks) |
| **36** | 2025-11-07 | ✅ **STABLE** | Settings display fixed | Connection stability (separate issue) |
| **35** | 2025-11-03 | ⚠️ PARTIAL | Crash fixed | Settings shows "--" |
| **34** | 2025-10-30 | ⚠️ PARTIAL | Reconnection resolved | Crash on disconnect |
| **33** | 2025-10-29 | ❌ FAILED | Fresh peripheral attempt | Fix never ran (wrong location) |
| **32** | 2025-10-28 | ⚠️ REGRESSION | UITableView crashes fixed | Error 4 moved to post-connect phase |
| **31** | 2025-10-27 | ✅ SUCCESS | Pre-flight validation works | Error 4 pre-flight eliminated |
| **30** | 2025-10-27 | 💥 CATASTROPHIC | N/A | All connections blocked (reverted) |
| **29** | 2025-10-25 | ⚠️ PARTIAL | Layer 1 detection works | Doesn't prevent connection |

---

## Build 37 (2025-11-10) ❌ FAILED

**Status:** ❌ **FAILED** - PRIMARY objective not met, fix code never executed

### Feature Status

| Feature | Status | Evidence | Notes |
|---------|--------|----------|-------|
| **Connection (Battery Restart)** | ❌ FAILED | Test 1 connection error | PRIMARY goal completely failed |
| **Reconnection After Settings Save** | ❌ FAILED | Test 2 unable to reconnect | User must manually scan |
| **Build 37 Fix Execution** | ❌ NEVER RAN | 0% - blocked by pre-flight | Code unreachable due to placement |
| **DiagnosticsViewController Crash** | ✅ FIXED | Test 2 - NO crash | **ONLY positive outcome** |
| **Settings Protocol Display** | ⬜ NOT TESTED | N/A | Likely still works (Build 36 fix untouched) |
| **Pre-flight Validation** | ✅ WORKS | Tests 1 & 2 - correctly rejects stale | Working as designed |
| **Error 4** | ⚠️ STILL PRESENT | Test 1: 09:14:10, 09:14:52 | Not eliminated |
| **BMS Data Loading** | ⬜ NOT TESTED | N/A | Likely works |

### What Was Attempted in Build 37

**Problem:** Connection stability when battery restarts without app restart (Scenario 2 from Build 36)

**Hypothesis:** iOS caches peripheral instances with stale characteristic handles → need to force cache release

**Solution Attempted:**
- Call `cancelPeripheralConnection()` before `retrievePeripherals()`
- Add Thread.sleep(0.1) to allow iOS to process cancellation
- Force iOS CoreBluetooth to release cached peripheral references

**File Changed:** `Zetara/Sources/ZetaraManager.swift` (lines 282-297)

**Secondary Fix:** DiagnosticsViewController crash
- Changed `reloadSections()` to `reloadData()` (line 274)
- **This fix WORKS** ✅

### Why Build 37 Failed

**Critical Finding:** Build 37 fix code **NEVER EXECUTED** in either test.

**Root Cause:** Code placement error

**Code Flow in connect() method:**
```
Lines 252-279: Pre-flight validation (Build 31)
    └─ If peripheral not in scan list → Return Observable.error() → EXITS

Lines 282-297: Build 37 fix (cancelPeripheralConnection) ← UNREACHABLE!
```

**What Actually Happened:**
1. Battery disconnect → cleanup → scan list cleared
2. UI still shows old peripheral (cached in TableView)
3. User clicks old peripheral
4. Pre-flight check: "Peripheral not in scan list" → ABORT (correct behavior)
5. Function returns before line 282 → Build 37 code NEVER REACHED

**Evidence:**
- **ZERO** instances of "Build 37: Forcing release of cached peripheral" in logs
- Test 1: "[CONNECT] ❌ ABORT: Peripheral not found in current scan list"
- Test 2: "[CONNECT] Connection failed: Please scan again to reconnect"

### Real Problem Identified

**What we thought:**
- iOS peripheral caching causing stale characteristic handles
- Need to force cache release with cancelPeripheralConnection()

**What actually happens:**
- Scan list cleared after disconnect (correct)
- UI still shows old peripheral (UI layer issue)
- Pre-flight correctly rejects stale peripheral (working as designed)
- **Gap:** UI state mismatch, not Bluetooth caching

**The UX Problem:**
```
User sees peripheral in UI → User clicks → Pre-flight rejects → "Scan again" error
→ User confused: "But I SEE the battery right there!"
```

### Test Results

**Test 1: Battery Restart Without App Restart**
- Status: ❌ FAILED
- Log: `bigbattery_logs_20251114_091457.json`
- Connection error, error 4 present
- Build 37 fix never ran

**Test 2: Settings Save (Crash Verification)**
- Status: ✅/❌ PARTIAL
- Log: `bigbattery_logs_20251114_095054.json`
- ✅ NO crash (DiagnosticsViewController fix works!)
- ❌ Unable to reconnect (Build 37 fix never ran)

### Comparison with Build 36

| Metric | Build 36 | Build 37 | Change |
|--------|----------|----------|--------|
| Connection success (Scenario 2) | 0% | 0% | NO CHANGE |
| Error 4 frequency | Some | Some | NO CHANGE |
| Settings display | ✅ Works | Not tested (likely works) | SAME |
| DiagnosticsViewController crash | N/A | ✅ FIXED | **IMPROVEMENT** |
| User experience (reconnection) | Manual scan required | Manual scan required | NO CHANGE |

**Success Rate:** 0% on PRIMARY objective, 100% on SECONDARY objective

### Git Information

**Commit:** d1bb7a1
**Tag:** `build-37`
**Branch:** feature/fix-protocols-and-connection

**View this build:**
```bash
git show build-37
git checkout build-37
```

### Test Logs

- `docs/fix-history/logs/bigbattery_logs_20251114_091457.json` (Test 1 - Battery Restart)
- `docs/fix-history/logs/bigbattery_logs_20251114_095054.json` (Test 2 - Settings Save)

### Lessons Learned

1. **Code placement matters** - Fix placed AFTER early return = unreachable code
2. **Pre-flight validation working TOO well** - Blocks stale peripherals AND fix attempts
3. **Real problem is UX not Bluetooth** - UI/scan list mismatch, not iOS caching
4. **Don't fight good protection** - Pre-flight doing its job correctly
5. **Fix in right layer** - UI problem needs UI solution, not Bluetooth fix

### Recommendations for Build 38

**DO:**
- Auto-trigger scan when scan list cleared (UI layer solution)
- Keep pre-flight validation working (it's protecting us)
- Keep all existing fixes (Build 31, 36, 37 crash fix)
- ONE PROBLEM = ONE BUILD (only auto-scan)

**DON'T:**
- Move Build 37 fix before pre-flight (would disable protection)
- Try to "fix" stale peripherals (pre-flight correctly rejects them)
- Touch Bluetooth logic (ZetaraManager working correctly)

**Proposed Solution for Build 38:**
```swift
// In ConnectivityViewController
scannedPeripheralsSubject.subscribe(onNext: { [weak self] peripherals in
    if peripherals.isEmpty && self?.wasConnected == true {
        self?.startScanning()  // Auto-scan after disconnect cleanup
    }
})
```

### Thread Reference

**THREAD-001** - Attempt #7 (Build 37 section)
Lines 1321-1569: Build 37 test results and analysis
Lines 1678-1805: ROOT CAUSE EVOLUTION - Build 37 understanding

---

## Build 36 (2025-11-07) - ✅ STABLE (RECOMMENDED)

**Status:** ✅ **RECOMMENDED** - All critical features working

### Feature Status

| Feature | Status | Evidence | Notes |
|---------|--------|----------|-------|
| **Connection (First time)** | ✅ WORKS | Scenario 1 SUCCESS | Baseline working |
| **Reconnection** | ✅ WORKS | Scenario 2.1, 3 SUCCESS | Works after app restart |
| **Settings Protocol Display** | ✅ WORKS | Build 36 SUCCESS - VERIFIED | **FIXED IN THIS BUILD** |
| **Settings Persistence** | ✅ WORKS | Scenario 3 SUCCESS | Protocols persist after navigation |
| **Crash on Disconnect** | ✅ FIXED | Build 35 fix still working | No regressions |
| **UITableView Crashes** | ✅ FIXED | Build 32 fix still working | No regressions |
| **BMS Data Loading** | ✅ WORKS | Scenarios 1, 2.1, 3 show data | Timer starts correctly |
| **Connection Stability** | ⚠️ SOME ISSUES | Scenario 2 connection error | **Separate issue, not addressed by Build 36** |

### What Was Fixed in Build 36

**Problem:** Settings screen showed "--" for Module ID, RS485, CAN protocols after battery reconnect

**Root Cause:** `disposeBag = DisposeBag()` in `SettingsViewController.viewWillDisappear` destroyed RxSwift subscriptions to protocol subjects

**Solution:** Removed disposeBag recreation - keep subscriptions alive throughout ViewController lifecycle

**File Changed:** `BatteryMonitorBL/SettingsViewController.swift` (line 359)

**Test Results:**
- ✅ Scenario 1: First connection → protocols display (P02-LUX, P06-LUX)
- ❌ Scenario 2: Battery restart → connection error (separate issue)
- ✅ Scenario 2.1: App restart → protocols display AND UPDATE (LUX → GRW) **KEY SUCCESS**
- ✅ Scenario 3: Navigate away and back → protocols persist **PROVES FIX WORKS**

### Git Information

**Commit:** c5db5fe
**Tag:** `build-36`
**Branch:** feature/fix-protocols-and-connection

**View this build:**
```bash
git show build-36
git checkout build-36
```

### Test Logs

- `docs/fix-history/logs/bigbattery_logs_20251107_090816.json` (Scenario 1)
- `docs/fix-history/logs/bigbattery_logs_20251107_091116.json` (Scenario 2)
- `docs/fix-history/logs/bigbattery_logs_20251107_091240.json` (Scenario 2.1 - CRITICAL SUCCESS)
- `docs/fix-history/logs/bigbattery_logs_20251107_091457.json` (Scenario 3)

### Known Issues

**Connection Stability (Scenario 2):**
- Battery restart → connection error
- This is a SEPARATE issue NOT addressed by Build 36
- Build 36 focused ONLY on Settings display
- Following "ONE PROBLEM = ONE BUILD" rule
- Will be addressed in Build 37

### Thread Reference

**THREAD-001** - Attempt #6 (Build 36 section)
Lines 973-1040: Implementation details
Lines 1041-1105: Test results analysis

---

## Build 35 (2025-11-03) ⚠️ PARTIAL

**Status:** ⚠️ PARTIAL SUCCESS - Crash fixed but Settings regression

### Feature Status

| Feature | Status | Evidence | Notes |
|---------|--------|----------|-------|
| **Connection (First time)** | ✅ WORKS | Build 34 fix still working | No change |
| **Reconnection** | ⚠️ PARTIAL | Build 34 fix + crash guard | Works but some scenarios fail |
| **Settings Protocol Display** | ❌ SHOWS "--" | **REGRESSION IN THIS BUILD** | DisposeBag destroyed subscriptions |
| **Crash on Disconnect** | ✅ FIXED | **FIXED IN THIS BUILD** | Guard prevents refresh during disconnect |
| **UITableView Crashes** | ✅ FIXED | Build 32 fix still working | No regressions |
| **BMS Data Loading** | ✅ WORKS | Build 34 fix still working | No change |

### What Was Fixed in Build 35

**Problem:** App crashed when battery disconnected during reconnect attempt

**Root Cause:** `refreshPeripheralInstanceIfNeeded()` tried to refresh peripheral while `.disconnecting` state, causing race condition

**Solution:** Added guard to skip refresh if `peripheral.state == .disconnecting`

**File Changed:** `Zetara/Sources/ZetaraManager.swift` (lines 450-455)

### What Broke in Build 35

**Regression:** Settings screen started showing "--" for protocols after reconnect

**Why:** Not directly caused by Build 35 code - was pre-existing issue in Settings ViewController that became visible after Build 34's reconnection fix enabled reliable reconnections

**Fixed In:** Build 36

### Git Information

**Commit:** b4ba427
**Tag:** `build-35`

**View this build:**
```bash
git show build-35
git diff build-34..build-35
```

### Thread Reference

**THREAD-001** - Attempt #5 (Build 35 section)
Lines 852-972: Implementation and test results

---

## Build 34 (2025-10-30) ⚠️ PARTIAL

**Status:** ⚠️ PARTIAL SUCCESS - Reconnection resolved but crash introduced

### Feature Status

| Feature | Status | Evidence | Notes |
|---------|--------|----------|-------|
| **Connection (First time)** | ✅ WORKS | Build 31 fix still working | No change |
| **Reconnection** | ✅ **RESOLVED** | Build 34 SUCCESS | **MAJOR FIX - error 4 eliminated** |
| **Fresh Peripheral at Launch** | ✅ IMPLEMENTED | **NEW IN THIS BUILD** | Launch-time + foreground refresh |
| **Crash on Disconnect** | ❌ NEW ISSUE | **REGRESSION IN THIS BUILD** | Race condition during disconnect |
| **UITableView Crashes** | ✅ FIXED | Build 32 fix still working | No regressions |
| **BMS Data Loading** | ✅ WORKS | Timer starts correctly | Working |
| **Error 4 Frequency** | ✅ 0% | Build 34 eliminated it | **KEY ACHIEVEMENT** |

### What Was Fixed in Build 34

**Problem:** Error 4 (invalid handle) occurred when reconnecting after battery disconnect

**Root Cause:** iOS CoreBluetooth caches peripheral instances AND their characteristics. When battery disconnected, cached characteristics became stale (invalid handles).

**Solution:** Proactively retrieve fresh peripheral instance at:
1. App launch (`AppDelegate.didFinishLaunchingWithOptions`)
2. Foreground return (`AppDelegate.applicationWillEnterForeground`)

This catches stale peripherals BEFORE any operations.

**Files Changed:**
- `Zetara/Sources/ZetaraManager.swift` (lines 450-488) - `refreshPeripheralInstanceIfNeeded()`
- `BatteryMonitor/AppDelegate.swift` (lines 48, 56) - Call refresh at launch/foreground

**Innovation:** Build 33's approach (refresh in `connect()`) was too narrow - only ran if user called connect(). Build 34's launch-time approach catches stale peripherals earlier.

### What Broke in Build 34

**Problem:** App crashed when battery disconnected

**Root Cause:** `refreshPeripheralInstanceIfNeeded()` called during `.disconnecting` state caused race condition

**Fixed In:** Build 35

### Git Information

**Commit:** 749a187
**Tag:** `build-34`

**View this build:**
```bash
git show build-34
git diff build-33..build-34
```

### Test Logs

- `docs/fix-history/logs/bigbattery_logs_20251027_174646.json` (Build 31 test - for comparison)

### Thread Reference

**THREAD-001** - Attempt #4 (Build 34 section)
Lines 635-851: Implementation and root cause evolution

---

## Build 33 (2025-10-29) ❌ FAILED

**Status:** ❌ FAILED - Fix implemented in wrong location

### Feature Status

| Feature | Status | Evidence | Notes |
|---------|--------|----------|-------|
| **Connection (First time)** | ✅ WORKS | Build 31 fix still working | No change |
| **Reconnection** | ❌ FAILED | Fix never executed | **Error 4 still occurs 100%** |
| **Fresh Peripheral Retrieval** | ⚠️ IMPLEMENTED BUT NOT CALLED | In `connect()` method | User doesn't call connect() |
| **UITableView Crashes** | ✅ FIXED | Build 32 fix still working | No regressions |
| **Error 4 Frequency** | ❌ 100% | Fix didn't run | No improvement |

### What Was Attempted in Build 33

**Approach:** Add fresh peripheral retrieval to `connect()` method

**Implementation:**
```swift
// In ZetaraManager.connect()
let freshPeripherals = manager.retrievePeripherals(withIdentifiers: [peripheralUUID])
guard let freshPeripheral = freshPeripherals.first else {
    return Observable.error(Error.peripheralNotFound)
}
```

**Why It Failed:**
- Fix was in correct conceptual location (before connection)
- BUT User doesn't actually call `connect()` in reconnection scenario!
- User stays on previously connected peripheral
- BMS timer tries to use cached peripheral with stale characteristics
- `connect()` method never executes → fix never runs

**Key Learning:** Need to catch stale peripherals BEFORE user even interacts, not during connection attempt

### Git Information

**Commit:** 1625dae
**Tag:** `build-33`

**View this build:**
```bash
git show build-33
```

### Thread Reference

**THREAD-001** - Attempt #3 Reflection (Build 33 section)
Lines 582-634: Why the fix didn't work

---

## Build 32 (2025-10-28) ⚠️ REGRESSION

**Status:** ⚠️ MIXED - UITableView fixed BUT error 4 regressed

### Feature Status

| Feature | Status | Evidence | Notes |
|---------|--------|----------|-------|
| **Connection (First time)** | ⚠️ WORKS | Success rate reduced | No changes to connection code |
| **Reconnection** | ⚠️ DEGRADED | 25% success only | **ERROR 4 REGRESSION** |
| **UITableView Crashes** | ✅ **FIXED** | **FIXED IN THIS BUILD** | Crashes eliminated |
| **Error 4 Pattern** | ❌ **SHIFTED** | Now happens AFTER characteristics configured | Used to be pre-flight |
| **Error 4 Frequency** | ❌ 75% | Regressed from Build 31 | Significant regression |

### What Was Fixed in Build 32

**Problem:** UITableView crashes when Settings screen loaded/reloaded

**Root Cause:** Data source inconsistencies during table view updates

**Solution:** Fixed UITableView data source management

**Files Changed:** (Specific files not documented in THREAD-001)

### What Broke in Build 32 (Major Regression)

**Problem:** Error 4 pattern changed dramatically

**Build 31 Pattern:**
- Error 4 happened during PRE-FLIGHT (before connection attempt)
- Pre-flight check caught it → prevented connection → safe

**Build 32 Pattern:**
- Error 4 NOW happens AFTER characteristics configured ❌
- Connection appears successful
- Writing to characteristics fails with error 4
- More dangerous - partial connection state

**Why This Happened:**
Not caused by Build 32 code changes (UITableView fix unrelated to Bluetooth).
Likely: Pre-existing timing issue that became more visible, OR iOS behavior change.

**Key Finding from THREAD-001:**
> "Error 4 location has SHIFTED from Layer 2 (pre-flight) to Layer 4 (after characteristics configured). This is MORE DANGEROUS because connection appears successful but writes fail."

### Git Information

**Commit:** 6426b1e
**Tag:** `build-32`

**View this build:**
```bash
git show build-32
```

### Test Results

**Success Rate:** 25% (1 of 4 test scenarios worked)
- Scenarios with error 4: 75%
- Working scenarios: 25%

### Thread Reference

**THREAD-001** - Build 32 analysis
Lines 510-581: Error 4 regression analysis

---

## Build 31 (2025-10-27) ✅ SUCCESS

**Status:** ✅ SUCCESS - Pre-flight validation working correctly

### Feature Status

| Feature | Status | Evidence | Notes |
|---------|--------|----------|-------|
| **Connection (First time)** | ✅ WORKS | 100% success rate | Normal connections work |
| **Reconnection** | ⚠️ PARTIAL | Pre-flight catches stale | Prevents error 4 but doesn't enable reconnect |
| **Pre-flight Validation** | ✅ **CORRECT** | **FIXED IN THIS BUILD** | Scan list validation works |
| **Stale Peripheral Detection** | ✅ WORKS | Layer 2 catches stale peripherals | "Please scan again" message |
| **UITableView Crashes** | ❌ PRESENT | Crashes occur | Not yet fixed |
| **Error 4 Frequency (Pre-flight)** | ✅ 0% | Eliminated at pre-flight | **KEY ACHIEVEMENT** |

### What Was Fixed in Build 31

**Problem:** Build 30's pre-flight check blocked ALL connections (catastrophic)

**Build 30 Mistake:** Used `peripheral.state` to distinguish fresh vs stale - but state is unreliable

**Build 31 Solution:** Validate against scan list instead
```swift
// Layer 2: Pre-flight validation (CORRECT APPROACH)
guard scannedPeripheralsSubject.value().contains(where: { $0.identifier == peripheral.identifier }) else {
    return Observable.error(Error.stalePeripheralError)
}
```

**Logic:**
- If peripheral in recent scan list → fresh ✅
- If peripheral NOT in scan list → stale, reject ❌
- User sees "Please scan again to reconnect" message

**Files Changed:**
- `Zetara/Sources/ZetaraManager.swift` - Pre-flight validation logic

### Test Results

**From Test Logs (`bigbattery_logs_20251027_174646.json`):**
- ✅ Normal connections work
- ✅ Pre-flight validation catches stale peripherals
- ⚠️ BMS data only loads partially in some scenarios
- ❌ UITableView crashes still occur

**Success Rate:** 100% for preventing error 4 pre-flight

### Key Learning

Build 31 successfully PREVENTED error 4, but didn't ENABLE reconnection.
- User still has to "scan again" after battery restart
- Better than catastrophic error, but not ideal UX
- Led to Build 33-34 approaches for proactive freshening

### Git Information

**Commit:** 6588e52 (same commit as Build 30, but different fix iteration)
**Tag:** `build-31`

**View this build:**
```bash
git show build-31
```

### Test Logs

- `docs/fix-history/logs/bigbattery_logs_20251027_174646.json`

### Thread Reference

**THREAD-001** - Attempt #3 (Build 31 section)
Lines 427-509: Implementation and test results

---

## Build 30 (2025-10-27) 💥 CATASTROPHIC FAILURE

**Status:** 💥 CATASTROPHIC - All connections blocked (reverted same day)

### Feature Status

| Feature | Status | Evidence | Notes |
|---------|--------|----------|-------|
| **Connection (ALL)** | ❌ **BLOCKED** | 0% success rate | **ALL connections rejected** |
| **Reconnection** | ❌ BLOCKED | Pre-flight rejects everything | N/A |
| **Pre-flight Validation** | ❌ **WRONG LOGIC** | **BROKEN IN THIS BUILD** | False positives everywhere |
| **Error 4 Frequency** | N/A | No connections possible | Can't even test |

### What Went Wrong in Build 30

**Attempt:** Add pre-flight validation to prevent error 4

**Flawed Logic:**
```swift
// WRONG: Used peripheral.state to distinguish fresh vs stale
if peripheral.state == .connected {
    // Assumed this means "stale cached peripheral"
    return Observable.error(Error.stalePeripheralError)
}
```

**Why This Failed:**
`peripheral.state` CANNOT reliably distinguish fresh vs stale peripherals:
- Fresh peripherals from scan can have state = `.connected` if iOS cached them
- iOS's peripheral.state reflects iOS's internal connection tracking, not freshness
- State-based validation = fundamentally flawed approach

**Result:**
- Rejected ALL peripherals including freshly scanned ones
- 0% connection success rate
- Blocked normal usage completely
- Reverted same day

### Key Learning

**From THREAD-001:**
> "peripheral.state cannot distinguish cached (stale) vs freshly scanned (fresh) peripherals. iOS's state property reflects connection status, not cache status."

This catastrophic failure led to Build 31's correct approach: validate against scan list.

### Git Information

**Commit:** 6588e52 (includes both Build 30 failure and Build 31 fix)
**Tag:** `build-30`

**View this build:**
```bash
git show build-30
```

**Duration:** < 4 hours (discovered and reverted same day)

### Thread Reference

**THREAD-001** - Attempt #3 Analysis (Build 30 failure section)
Lines 373-426: Why state-based validation doesn't work

---

## Build 29 (2025-10-25) ⚠️ PARTIAL

**Status:** ⚠️ PARTIAL SUCCESS - Detection works but doesn't prevent connection

### Feature Status

| Feature | Status | Evidence | Notes |
|---------|--------|----------|-------|
| **Connection (First time)** | ✅ WORKS | Normal connections successful | Baseline working |
| **Reconnection** | ❌ FAILS | Error 4 still occurs | Detection doesn't prevent it |
| **Disconnect Detection (Layer 1)** | ✅ **WORKS** | **NEW IN THIS BUILD** | `didDisconnectPeripheral` monitors disconnect |
| **Health Monitor (Layer 3)** | ✅ **IMPLEMENTED** | **NEW IN THIS BUILD** | 3-second interval checks peripheral state |
| **Error 4 Frequency** | ❌ 100% | Still occurs | Detection only, no prevention |

### What Was Implemented in Build 29

**Approach:** Proactive monitoring to DETECT when peripheral becomes invalid

**Layer 1 - Global disconnect handler:**
```swift
manager.observeDisconnect()
    .subscribe(onNext: { [weak self] peripheral in
        self?.cleanConnection()
    })
```

**Layer 3 - Health monitor:**
```swift
Observable<Int>.interval(.seconds(3), scheduler: MainScheduler.instance)
    .subscribe(onNext: { [weak self] _ in
        if peripheral.state != .connected {
            self?.cleanConnection()
        }
    })
```

**Test Results:**
- ✅ Layer 1 detects disconnect events when iOS fires them
- ❌ Layer 1 does NOT fire for physical power-off (iOS limitation)
- ✅ Layer 3 health monitor runs every 3 seconds
- ❌ Neither prevents error 4 during connection attempt

### Why Build 29 Was Insufficient

**Problem:** Reactive detection vs Proactive prevention
- Build 29 DETECTS after peripheral becomes stale
- But doesn't PREVENT using stale peripheral
- User can still trigger error 4 by attempting connection before detection runs

**Key Finding:**
> "iOS does NOT fire didDisconnectPeripheral for physical power-off. Health monitor (3s interval) might miss quick reconnect attempts."

### What Came Next

Build 29 established monitoring foundation. Led to Build 30-31's pre-flight validation approach (prevent BEFORE connection).

### Git Information

**Commit:** a1953a6
**Tag:** `build-29`

**View this build:**
```bash
git show build-29
```

### Thread Reference

**THREAD-001** - Attempt #2 (Build 29 section)
Lines 232-372: Implementation and limitations

---

## 📈 Feature Evolution Timeline

### Connection Success Rate
```
Build 29: N/A (detection only)
Build 30: 0% ❌ (catastrophic)
Build 31: 100% ✅ (pre-flight works)
Build 32: 25% ⚠️ (regression)
Build 33: 0% ❌ (fix didn't run)
Build 34: 100% ✅ (reconnection resolved)
Build 35: Partial ⚠️ (crash issues)
Build 36: 75% ⚠️ (connection stability separate issue)
```

### Error 4 Pattern Evolution
```
Build 29: Pre-flight, 100% frequency
Build 30: N/A (all blocked)
Build 31: Pre-flight, 0% (eliminated) ✅
Build 32: POST-connect, 75% ❌ (regression)
Build 33: POST-connect, 100% (fix failed)
Build 34: 0% ✅ (eliminated)
Build 35-36: Some scenarios (separate issue)
```

### Settings Display
```
Build 29-34: N/A (not tested)
Build 35: Shows "--" ❌ (regression)
Build 36: Works correctly ✅ (fixed)
```

### Crashes
```
Build 29-31: UITableView crashes present
Build 32: UITableView crashes fixed ✅
Build 33-34: UITableView crashes fixed ✅
Build 34: Disconnect crash introduced ❌
Build 35: Disconnect crash fixed ✅
Build 36: No crashes ✅
```

---

## 🎯 Current Recommended Build

**Build 36** is the current recommended build for production use.

**Reasons:**
- ✅ Settings display works correctly (Build 36 fix)
- ✅ Reconnection works (Build 34 fix)
- ✅ No crashes (Build 32 + Build 35 fixes)
- ✅ BMS data loads (Build 34+)
- ⚠️ Connection stability issue (error 4 in some scenarios) - tracked separately, will be addressed in Build 37

**Evidence:**
- Test Scenarios 1, 2.1, 3: SUCCESS
- THREAD-001: Build 36 marked as "SUCCESS VERIFIED"
- 4 test logs showing working state

---

## 📚 Related Documentation

- **THREAD-001:** Deep dive into reconnection issue evolution
- **STABLE-BUILDS.md:** Last known good builds per feature
- **REGRESSION-TIMELINE.md:** Break/fix chronology
- **START-HERE.md:** Main entry point for documentation

---

## 🔄 Update History

- **2025-11-10:** Initial creation - Build 29-36 documented
- **2025-11-07:** Build 36 verified as SUCCESS
