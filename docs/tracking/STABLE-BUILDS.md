# Stable Builds - Last Known Good

Quick reference для поиска последнего стабильного билда для каждой фичи и rollback сценариев.

**Last Updated:** 2025-11-17
**Current Recommended Build:** Build 36 (Build 37 FAILED)

---

## 🎯 Quick Reference Table

| Feature | Last Known Good Build | Commit Hash | Git Tag | Date | Evidence |
|---------|----------------------|-------------|---------|------|----------|
| **DiagnosticsViewController Crash Fix** | Build 37 ✅ | d1bb7a1 | `build-37` | 2025-11-10 | Test 2 - no crash when saving settings |
| **Settings Protocol Display** | Build 36 ✅ | c5db5fe | `build-36` | 2025-11-07 | THREAD-001 Build 36 SUCCESS, 4 test logs |
| **Reconnection (Error 4 eliminated)** | Build 34 ✅ | 749a187 | `build-34` | 2025-10-30 | THREAD-001 Build 34 SUCCESS, error 4 = 0% |
| **No Crash on Disconnect** | Build 35 ✅ | b4ba427 | `build-35` | 2025-11-03 | THREAD-001 Build 35 fix, guard during disconnect |
| **UITableView Stability** | Build 32 ✅ | 6426b1e | `build-32` | 2025-10-28 | THREAD-001 Build 32, crashes eliminated |
| **BMS Data Loading** | Build 34 ✅ | 749a187 | `build-34` | 2025-10-30 | Test logs show consistent data loading |
| **Pre-flight Validation** | Build 31 ✅ | 6588e52 | `build-31` | 2025-10-27 | THREAD-001 Build 31, scan list validation |
| **Health Monitor** | Build 29 ✅ | a1953a6 | `build-29` | 2025-10-25 | THREAD-001 Build 29, Layer 1+3 monitoring |

---

## ❌ Build 37 Status: FAILED

**Date:** 2025-11-10
**Commit:** d1bb7a1
**Tag:** `build-37`
**Status:** ❌ FAILED - PRIMARY objective not met

### Why Build 37 is NOT Recommended

Build 37 attempted to fix connection stability (battery restart reconnection) but **FAILED**:

**❌ What FAILED:**
- **Connection Stability** - 0% success, same as Build 36
- **Build 37 fix execution** - 0%, code never ran (blocked by pre-flight validation)
- **Error 4** - Still present
- **Auto-reconnection** - Still requires manual scan

**✅ What WORKS (only positive outcome):**
- **DiagnosticsViewController crash** - FIXED ✅
  - No crash when saving settings
  - reloadData() instead of reloadSections() solved batch update issue

### Why Build 37 Fix Failed

**Root Cause:** Code placement error - fix placed AFTER pre-flight abort

**Flow:**
```
Pre-flight validation (lines 252-279) → If stale peripheral → Return error → EXIT
Build 37 fix (lines 282-297) → NEVER REACHED
```

**Evidence:** ZERO instances of "Build 37: Forcing release" in test logs

### Test Results (2025-11-14)

**Test 1: Battery Restart**
- ❌ Connection failed
- ❌ Error 4 present
- ❌ Build 37 fix never ran

**Test 2: Settings Save**
- ✅ NO crash (DiagnosticsViewController fix works)
- ❌ Unable to reconnect (Build 37 fix never ran)

**Success Rate:** 0% on PRIMARY objective (connection stability)

### Recommendation

**DO NOT use Build 37 for production.** Use **Build 36** instead.

**One Exception:** If you need DiagnosticsViewController crash fix, you can use Build 37, but be aware that connection stability is NOT improved.

For most users: **Build 36 is still recommended.**

---

## ✅ Current Recommended Build: Build 36

**Date:** 2025-11-07
**Commit:** c5db5fe
**Tag:** `build-36`

### Why Build 36 is Recommended

Build 36 is the most stable and feature-complete build to date. All critical issues are resolved:

**✅ What Works:**
- **Settings Display** - Shows Module ID, RS485, CAN protocols correctly after reconnect
- **Settings Persistence** - Protocols persist when navigating away and back (disposeBag fix)
- **Reconnection** - Works reliably in most scenarios (Build 34 fix)
- **No Crashes** - UITableView crashes fixed (Build 32), disconnect crashes fixed (Build 35)
- **BMS Data** - Loads consistently (Build 34 timer fix)

**⚠️ Known Issues:**
- **Connection Stability** - Some scenarios (battery restart without app restart) may fail to reconnect
  - This is a SEPARATE issue not addressed by Build 36
  - Build 36 focused ONLY on Settings display (following "ONE PROBLEM = ONE BUILD" rule)
  - Will be addressed in Build 37

### Test Evidence

**4 Test Scenarios (2025-11-07):**
- ✅ Scenario 1: First connection - protocols display (P02-LUX, P06-LUX)
- ❌ Scenario 2: Battery restart - connection error (separate issue)
- ✅ Scenario 2.1: App restart - protocols display AND update (LUX → GRW)
- ✅ Scenario 3: Navigate away and back - protocols persist

**Success Rate:** 3/4 scenarios (75%)
- The 1 failure (Scenario 2) is connection stability, NOT Settings display
- Settings display SUCCESS rate: 100% (when connection succeeds)

**Logs:**
- `docs/fix-history/logs/bigbattery_logs_20251107_090816.json`
- `docs/fix-history/logs/bigbattery_logs_20251107_091116.json`
- `docs/fix-history/logs/bigbattery_logs_20251107_091240.json`
- `docs/fix-history/logs/bigbattery_logs_20251107_091457.json`

### How to Use Build 36

```bash
# View the commit
git show build-36

# Checkout this build
git checkout build-36

# Compare with previous build
git diff build-35..build-36

# See what changed
git log build-35..build-36 --oneline
```

---

## 🔄 Rollback Scenarios

Сценарии когда нужно откатиться на известный working build.

### Scenario 1: Settings Display Breaks

**Symptoms:**
- Settings screen shows "--" for Module ID, RS485, CAN
- Protocols don't update after reconnect
- Values don't persist when navigating away and back

**Rollback To:** Build 36 ✅
```bash
git checkout build-36
```

**Why:** Build 36 is last build with working Settings display (disposeBag fix)

**Root Cause (if regression occurs):**
- Check if `disposeBag = DisposeBag()` was re-added to `SettingsViewController.viewWillDisappear`
- Check if RxSwift subscriptions to protocol subjects were modified
- Verify `ProtocolDataManager` subjects still publishing correctly

---

### Scenario 2: Error 4 Returns (Invalid Handle)

**Symptoms:**
- "BluetoothError error 4" in logs
- Connection fails with "invalid handle" message
- Reconnection after battery restart fails

**Rollback To:** Build 34 ✅
```bash
git checkout build-34
```

**Why:** Build 34 is last build with error 4 completely eliminated (0% frequency)

**Root Cause (if regression occurs):**
- Check if `refreshPeripheralInstanceIfNeeded()` still being called at launch/foreground
- Check if fresh peripheral retrieval logic modified
- Verify AppDelegate calls to ZetaraManager refresh

**Warning:** Build 34 has disconnect crash issue. If crashes occur, use Build 35 instead.

---

### Scenario 3: App Crashes on Disconnect

**Symptoms:**
- App crashes when battery disconnected
- Race condition errors in logs
- Crash during peripheral state transitions

**Rollback To:** Build 35 ✅
```bash
git checkout build-35
```

**Why:** Build 35 fixed disconnect crash (guard during .disconnecting state)

**Root Cause (if regression occurs):**
- Check if guard `if peripheral.state == .disconnecting` removed from `refreshPeripheralInstanceIfNeeded()`
- Check if connection cleanup logic modified
- Verify disconnect handlers not calling refresh during disconnect

**Warning:** Build 35 has Settings display regression. If Settings breaks, need Build 36.

---

### Scenario 4: UITableView Crashes

**Symptoms:**
- App crashes when opening Settings screen
- Table view data source inconsistency errors
- Crashes during cell dequeue

**Rollback To:** Build 32 ✅
```bash
git checkout build-32
```

**Why:** Build 32 fixed UITableView crashes

**Root Cause (if regression occurs):**
- Check Settings ViewController table view data source management
- Verify cell registration and dequeue logic
- Check if data source methods returning consistent counts

**Warning:** Build 32 has error 4 regression (75% frequency). If error 4 occurs, need Build 34+.

---

### Scenario 5: All Connections Blocked

**Symptoms:**
- 0% connection success rate
- "Please scan again" for ALL peripherals including fresh ones
- Pre-flight validation rejecting everything

**Rollback To:** Build 31 ✅
```bash
git checkout build-31
```

**Why:** Build 31 has correct pre-flight validation (scan list based, not state based)

**Root Cause (if regression occurs):**
- Check if pre-flight validation using `peripheral.state` instead of scan list
- Verify scannedPeripheralsSubject contains freshly scanned peripherals
- Check connection logic not rejecting valid peripherals

**Warning:** Build 31 has UITableView crashes. If crashes occur, need Build 32+.

---

## 📊 Feature Stability Matrix

Matrix showing which builds have which features working:

| Feature | Build 29 | Build 30 | Build 31 | Build 32 | Build 33 | Build 34 | Build 35 | Build 36 |
|---------|----------|----------|----------|----------|----------|----------|----------|----------|
| **Connection (First time)** | ✅ | ❌ | ✅ | ⚠️ | ✅ | ✅ | ✅ | ✅ |
| **Reconnection** | ❌ | ❌ | ⚠️ | ⚠️ | ❌ | ✅ | ⚠️ | ⚠️ |
| **Settings Display** | ? | ? | ? | ? | ? | ? | ❌ | ✅ |
| **No Disconnect Crash** | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| **No UITableView Crash** | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Error 4 (Pre-flight)** | ❌ | N/A | ✅ | N/A | N/A | ✅ | ✅ | ✅ |
| **BMS Data Loading** | ✅ | ❌ | ⚠️ | ⚠️ | ❌ | ✅ | ✅ | ✅ |

**Legend:**
- ✅ = Working
- ❌ = Broken
- ⚠️ = Partially working
- ? = Not tested/documented
- N/A = Not applicable

---

## 🎯 Best Build for Specific Use Cases

### Use Case 1: Production Release (General Users)
**Recommended:** Build 36 ✅

**Reasons:**
- Most feature-complete
- Settings display works (important UX)
- No crashes
- Reconnection works in most scenarios

**Trade-off:** Connection stability issue in some edge cases (battery restart without app restart)

---

### Use Case 2: Maximum Connection Reliability
**Recommended:** Build 34 ✅

**Reasons:**
- Error 4 = 0% (completely eliminated)
- Reconnection works 100% when connection succeeds
- Fresh peripheral logic most robust

**Trade-offs:**
- Has disconnect crash issue (use Build 35 if this matters)
- Settings display not tested in this build

---

### Use Case 3: Maximum Stability (No Crashes Priority)
**Recommended:** Build 35 ✅

**Reasons:**
- No disconnect crashes (Build 35 fix)
- No UITableView crashes (Build 32 fix)
- Reconnection works

**Trade-off:** Settings display shows "--" (regressed in this build)

---

### Use Case 4: Testing New Features
**Recommended:** Build 36 ✅ (current development)

**Reasons:**
- Latest code
- All known issues documented
- Clear baseline for measuring improvements

---

## 📈 Stability Trend

Stability has improved significantly over time:

```
Build 29: 🟡 PARTIAL (detection only)
Build 30: 🔴 CATASTROPHIC (reverted)
Build 31: 🟢 SUCCESS (pre-flight working)
Build 32: 🟡 MIXED (UITable fixed, error 4 regressed)
Build 33: 🔴 FAILED (fix didn't run)
Build 34: 🟢 SUCCESS (reconnection resolved, but crash)
Build 35: 🟡 PARTIAL (crash fixed, Settings regressed)
Build 36: 🟢 STABLE (Settings fixed, recommended)
```

**Current Direction:** ⬆️ Improving
- Critical issues resolved
- Known remaining issues documented and tracked
- Clear path forward (Build 37 will address connection stability)

---

## 🔮 Future Builds

### Build 37 (Planned)
**Focus:** Connection Stability (error 4 in battery restart scenarios)
**Status:** Investigation in progress
**Expected:** Eliminate Scenario 2 connection errors

**When Build 37 is Ready:**
- Update this file with Build 37 as "Current Recommended"
- Add Build 37 to Quick Reference table
- Update stability matrix

---

## 📚 Related Documentation

- **BUILD-TRACKING.md:** Full feature status for each build
- **REGRESSION-TIMELINE.md:** When things broke and when they were fixed
- **THREAD-001:** Deep technical analysis of reconnection issue
- **Git Tags:** Use `git tag -l "build-*"` to see all available builds

---

## 🔄 Update History

- **2025-11-10:** Initial creation
- **2025-11-07:** Build 36 verified as stable recommended build
