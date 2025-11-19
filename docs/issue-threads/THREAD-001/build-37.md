# Build 37: Force Cache Release

**Date:** 2025-11-10 (implementation) / 2025-11-14 (test results)
**Status:** ❌ FAILED (Fix never executed)
**Attempt:** #7

**Navigation:**
- ⬅️ Previous: [Build 36](build-36.md)
- ➡️ Next: [Build 38](build-38.md)
- 🏠 Main: [../THREAD-001.md](../THREAD-001.md)

---

## Problem Being Fixed:

**Specific Issue:** Scenario 2 from Build 36 testing - connection error after battery restart WITHOUT app restart

**Evidence:** Build 36 test log `bigbattery_logs_20251107_091116.json`
- Battery restarted while app in foreground
- User tried to reconnect from app
- Connection failed: "No device connected", characteristics unavailable
- All battery data showed zeros

## Gap in Build 34 Fix:

Build 34's launch-time `refreshPeripheralInstanceIfNeeded()` works for:
- ✅ App launch → fresh peripheral retrieved
- ✅ Foreground return → fresh peripheral retrieved

Build 34 does NOT work for:
- ❌ Battery restart while app in foreground (no app lifecycle event)
- ❌ Within-session reconnection attempt

## Root Cause Analysis:

### The Core Problem:

`retrievePeripherals(withIdentifiers:)` returns iOS's **cached peripheral instance**, not truly fresh.

### Why Previous Fixes Didn't Solve This:

**Build 33:** Fresh peripheral in `connect()` method
- ✅ Correct location (before connection)
- ❌ But never called (user doesn't call connect() during reconnect)

**Build 34:** Launch-time refresh
- ✅ Works for cross-session (app restart)
- ❌ Doesn't work for within-session (battery restart without app restart)
- Problem: No app lifecycle event fired when battery restarts in foreground

### Scenario 2 Flow (Why It Failed):

```
App in foreground → Battery restart → iOS doesn't fire disconnect
    ↓
Stale peripheral remains in connectedPeripheralSubject
    ↓
User navigates to Connectivity screen → Layer 1 check may pass if timing wrong
    ↓
User clicks battery to reconnect → Pre-flight validation passes
    ↓
connect() method calls retrievePeripherals(withIdentifiers:)
    ↓
iOS returns SAME cached instance (not fresh!) ❌
    ↓
Characteristics still stale → Connection appears to work but operations fail
```

**Key Insight:** iOS doesn't always return fresh instance from `retrievePeripherals()` - it may return cached reference with stale characteristic handles.

## Build 37 Solution:

**Approach:** Force iOS to release cached peripheral BEFORE calling `retrievePeripherals()`

**Implementation:**

**File:** `Zetara/Sources/ZetaraManager.swift`
**Method:** `connect()`
**Location:** Lines 282-297 (inserted before Build 33's retrievePeripherals call)

```swift
// Build 37 Fix: Force cached peripheral release before fresh retrieval
// Problem: retrievePeripherals() may return iOS cached stale peripheral instance
// even after battery restart (within same app session)
// Solution: Explicitly cancel connection to force iOS CoreBluetooth to release cache
if let cachedPeripheral = try? connectedPeripheralSubject.value() {
    protocolDataManager.logProtocolEvent("[CONNECT] Build 37: Forcing release of cached peripheral")
    protocolDataManager.logProtocolEvent("[CONNECT] Cached peripheral state: \(cachedPeripheral.state.rawValue)")

    // Cancel connection to force iOS to release cached references
    manager.manager.cancelPeripheralConnection(cachedPeripheral.peripheral)

    // Brief delay to allow iOS to process cancellation
    Thread.sleep(forTimeInterval: 0.1)

    protocolDataManager.logProtocolEvent("[CONNECT] Build 37: Cached peripheral released, proceeding with fresh retrieval")
}
```

### Logic:

1. Check if there's a cached peripheral in memory (`connectedPeripheralSubject`)
2. If yes → explicitly cancel connection (`cancelPeripheralConnection()`)
3. Brief 0.1s delay for iOS to process cancellation
4. Now `retrievePeripherals()` should return truly fresh instance
5. Continue with Build 33's fresh peripheral logic

## Changes Summary:

### Files Modified:

1. `BatteryMonitorBL.xcodeproj/project.pbxproj`
   - Updated `CURRENT_PROJECT_VERSION` from 36 to 37 (lines 523, 560)

2. `Zetara/Sources/ZetaraManager.swift`
   - Added Build 37 fix code in `connect()` method (lines 282-297)
   - 16 lines added (code + comments)
   - Located before Build 33's `retrievePeripherals()` call
   - Minimal, surgical change

## Expected Results:

### Scenario 2 (Previously FAILED) → NOW EXPECTED TO WORK:

**Before Build 37:**
- Battery restart → User tries reconnect → ❌ Connection error
- retrievePeripherals() returns cached stale instance
- Success rate: 0% for within-session reconnection

**After Build 37:**
- Battery restart → User tries reconnect
- cancelPeripheralConnection() forces cache release
- retrievePeripherals() returns truly fresh instance
- ✅ Connection succeeds
- Expected success rate: 100%

### Expected Log Sequence:

```
[CONNECT] Pre-flight validation passed
[CONNECT] Build 37: Forcing release of cached peripheral
[CONNECT] Cached peripheral state: 3 (disconnected)
[CONNECT] Build 37: Cached peripheral released, proceeding with fresh retrieval
[CONNECT] ✅ Retrieved fresh peripheral instance
[CONNECTION] Device connected: BB-51.2V100Ah-0855
[PROTOCOL MANAGER] Loading protocols...
[BMS] Starting BMS data refresh timer
```

### Metrics Change:

| Metric | Build 36 | Build 37 (Expected) |
|--------|----------|---------------------|
| Connection success rate | 75% | **100%** |
| Error 4 frequency | Some | **0%** |
| Scenario 2 success | ❌ Failed | ✅ **EXPECTED SUCCESS** |

---

## Test Results (2025-11-14):

❌ **FAILED - Fix Never Executed**

### Test Status:

- **Date:** November 14, 2025
- **Tester:** Joshua
- **Build Version:** 37

### Test Scenarios Executed:

**Test 1: Battery Restart Without App Restart (PRIMARY)**
- **Status:** ❌ FAILED
- **Log:** `bigbattery_logs_20251114_091457.json`
- **Result:** Connection error, app does NOT reconnect
- **Error 4:** Present (09:14:10, 09:14:52)

**Test 2: Settings Save (Crash Verification)**
- **Status:** ✅/❌ PARTIAL
- **Log:** `bigbattery_logs_20251114_095054.json`
- **Crash:** ✅ NO crash (DiagnosticsViewController fix works!)
- **Reconnection:** ❌ Unable to reconnect after save

### Expected vs Reality Comparison:

| Expected Behavior | Reality in Logs | Evidence | Status |
|------------------|-----------------|----------|--------|
| [CONNECT] Build 37: Forcing release of cached peripheral | **NOT FOUND** | No such log entry | ❌ MISSING |
| [CONNECT] Cached peripheral state: X | **NOT FOUND** | No state logging | ❌ MISSING |
| [CONNECT] Cached peripheral released | **NOT FOUND** | No release confirmation | ❌ MISSING |
| cancelPeripheralConnection() called | **NOT EXECUTED** | No evidence in logs | ❌ MISSING |
| Connection succeeds after battery restart | **FAILED** | Error 4, connection error | ❌ FAILED |
| Error 4 eliminated | **ERROR 4 PRESENT** | 09:14:10, 09:14:52 | ❌ FAILED |
| Fresh peripheral retrieval | **NOT ATTEMPTED** | Pre-flight aborted before Build 37 code | ❌ BLOCKED |

### Critical Finding:

**Build 37 fix code NEVER EXECUTED in either test.**

The expected log entries from ZetaraManager.swift lines 282-297 are completely absent:
- No "Build 37: Forcing release of cached peripheral"
- No "Cached peripheral state: X"
- No "Cached peripheral released, proceeding with fresh retrieval"

**Root Cause:** Pre-flight validation (Build 31) aborted connection attempts BEFORE reaching Build 37 fix code.

### Detailed Log Analysis:

**Test 1 Timeline (Battery Restart):**
```
[09:14:10] Error 4 occurs → triggers cleanup
[09:14:10] Cleaning connection state (after error)
[09:14:10] Scan list cleared by cleanup
[09:14:12] User clicks battery to reconnect (2 seconds later)
[09:14:12] Pre-flight check: Peripheral not in scan list
[09:14:12] ❌ ABORT: "Peripheral not found in current scan list"
[09:14:12] "This peripheral is from a previous scan session"
[09:14:12] "Scan list was cleared during disconnect - this is a stale reference"
[09:14:52] ❌ Connection error: BluetoothError error 4
```

**Key Observations:**
1. Cleanup happened correctly (scan list cleared) ✅
2. Pre-flight validation detected stale peripheral ✅
3. Connection ABORTED with helpful error message ✅
4. **BUT** Build 37 code never reached (function returned before line 282) ❌

**Test 2 Timeline (Settings Save):**
```
[09:50:44] Connection state cleaned
[09:50:53] Connection state cleaned (second cleanup)
[09:50:29] No connected peripheral - clearing scanned list
[09:50:25] Connection failed: Please scan again to reconnect
[09:50:25] User must scan again to get fresh peripheral from current session
```

**Key Observations:**
1. Multiple cleanup cycles occurred ✅
2. Scan list cleared correctly ✅
3. Pre-flight instructed user to scan again ✅
4. Build 37 fix never executed ❌

### Why Build 37 Fix Failed:

**Code Execution Flow in ZetaraManager.swift connect() method:**

```
Lines 252-279: Pre-flight validation (Build 31)
    ├─ Check: Is peripheral UUID in scannedPeripheralsSubject?
    ├─ If NO → Log error message
    ├─ Return Observable.error(...) ← FUNCTION EXITS HERE
    └─ ABORT connection attempt

Lines 282-297: Build 37 fix (forced cache release) ← NEVER REACHED
    ├─ Get cached peripheral from connectedPeripheralSubject
    ├─ Call cancelPeripheralConnection()
    ├─ Thread.sleep(0.1)
    └─ Log "Build 37: Cached peripheral released"

Lines 299+: Build 33 fresh retrieval
```

**The Problem:**
- Pre-flight validation (Build 31) correctly identifies peripheral not in fresh scan list
- Pre-flight returns `Observable.error()` which **terminates function execution**
- Build 37 code placed AFTER pre-flight validation
- When pre-flight aborts → function returns → Build 37 code unreachable

**Evidence:**
- Test 1 logs: "[CONNECT] ❌ ABORT: Peripheral not found in current scan list"
- Test 2 logs: "[CONNECT] Connection failed: Please scan again to reconnect"
- **Zero** instances of "Build 37: Forcing release" in either log

### What Actually Happened:

**Scenario Flow (Both Tests):**

```
1. Battery disconnects (restart OR settings save triggers disconnect)
   ↓
2. Cleanup eventually triggered (reactive, via timeout/error detection)
   ↓
3. cleanConnection() → cleanScanning() → scannedPeripheralsSubject cleared
   ↓
4. UI TableView still shows old peripheral (cached in UI layer)
   ↓
5. User clicks old peripheral from UI (reasonable user action)
   ↓
6. connect() method called with old peripheral reference
   ↓
7. Pre-flight check (Build 31): "Is peripheral UUID in scannedPeripheralsSubject?"
   ↓
8. Answer: NO (list was cleared in step 3)
   ↓
9. Pre-flight conclusion: "This is stale peripheral from previous session"
   ↓
10. Pre-flight action: Return Observable.error → ABORT connection
    ↓
11. Function returns → Build 37 code lines 282-297 NEVER EXECUTE
    ↓
12. User sees error: "Please scan again to reconnect"
```

**The Gap:** Between cleanup (scan list cleared) and UI state (still showing old peripheral).

**Why This Is Actually Correct Behavior:**
- Pre-flight validation IS working correctly! ✅
- It correctly identifies peripheral not in current scan list ✅
- It correctly prevents connection to stale references ✅
- **BUT** this prevents Build 37 fix from ever running ❌

### Lessons Learned:

1. **Code placement matters critically**
   - Putting fix AFTER pre-flight validation = fix never runs
   - Pre-flight abort terminates function execution
   - Must place critical code BEFORE early returns

2. **Pre-flight validation working TOO well**
   - Correctly rejects stale peripherals ✅
   - But also blocks fix attempts ❌
   - Creates catch-22: Can't fix stale peripherals if pre-flight blocks all access

3. **Real problem is different than assumed**
   - Not: iOS peripheral caching with stale handles
   - Actually: Scan list cleared but UI still shows old peripheral
   - User clicks old peripheral → pre-flight correctly rejects → user confused

4. **Need different approach for Build 38**
   - Don't try to "fix" stale peripherals with forced cache release
   - Instead: Automatically trigger fresh scan when scan list cleared
   - Let pre-flight validation continue working (it's doing its job correctly)

5. **DiagnosticsViewController fix WORKS** ✅
   - No crashes reported in Test 2
   - reloadData() instead of reloadSections() solved batch update issue
   - At least one positive outcome from Build 37

### Comparison with Build 36:

| Metric | Build 36 | Build 37 | Change |
|--------|----------|----------|--------|
| Connection success (Scenario 2) | 0% | 0% | **NO CHANGE** |
| Error 4 frequency | Present | Present | **NO CHANGE** |
| Build 37 fix executed | N/A | 0% (never) | **FIX BLOCKED** |
| Pre-flight validation works | ✅ Yes | ✅ Yes | **SAME** |
| Settings display | ✅ Yes | Not tested | **LIKELY SAME** |
| DiagnosticsViewController crash | Fixed in Build 37 | ✅ Fixed | **IMPROVEMENT** |
| User experience (reconnection) | Manual scan required | Manual scan required | **NO CHANGE** |

**Verdict:** Build 37 shows **minimal improvement** (crash fix only). PRIMARY goal (auto-reconnection) completely unmet.

**Success Rate:** 0% on PRIMARY objective, 100% on SECONDARY objective (crash fix)

---

**Navigation:**
- ⬅️ Previous: [Build 36](build-36.md)
- ➡️ Next: [Build 38](build-38.md)
- 🏠 Main: [../THREAD-001.md](../THREAD-001.md)
