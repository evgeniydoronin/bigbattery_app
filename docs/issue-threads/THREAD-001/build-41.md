# Build 41: Fix viewWillAppear Auto-Reconnect Destroyer

**Date:** 2025-11-19
**Status:** ⏳ TESTING (awaiting results)
**Attempt:** #11

**Navigation:**
- ⬅️ Previous: [Build 40](build-40.md)
- ➡️ Next: [Build 42](build-42.md)
- 🏠 Main: [../THREAD-001.md](../THREAD-001.md)

---

## Build 40 Test Results Summary:

See [build-40.md](build-40.md#test-results-2025-11-19) for full details.

**Tests PASSED (3/6):**
- ✅ Test 2: Settings save (misleading - battery never disconnected)
- ✅ Test 4: Cross-session reconnect
- ✅ Test 5: Cross-session reconnect

**Tests FAILED (3/6):**
- ❌ Test 1: Mid-session reconnect (battery restart)
- ❌ Test 3: Mid-session reconnect (1st attempt)
- ❌ Test 6: Mid-session reconnect (2nd attempt)

**Pattern Identified:**
- Startup auto-reconnect: WORKS ✅
- Mid-session auto-reconnect: BROKEN ❌

**Build 40's Fix Was CORRECT But INCOMPLETE:**
- ✅ Health monitor now uses partial cleanup (lines 178-198)
- ❌ But UUID still being destroyed by something else!

---

## Root Cause Analysis:

### Discovery Process:

**Initial Hypothesis (Build 40):**
Health monitor was calling `cleanConnection()` instead of `cleanConnectionPartial()`.

**Reality Check:**
Build 40 fixed health monitor, but tests still failed with identical pattern!

### Investigation:

Used grep to find ALL sources of `cleanConnection()` calls:

1. ✅ Health monitor (ZetaraManager.swift:178-198) - FIXED in Build 40
2. ✅ observeDisconnect() handler (ZetaraManager.swift:131-157) - ALREADY fixed in Build 38!
3. ❌ Bluetooth state observer (ZetaraManager.swift:117-126) - unlikely during battery disconnect
4. 🎯 **ConnectivityViewController.viewWillAppear()** (line 132) - **THE CULPRIT!**

### THE REAL ROOT CAUSE:

**File:** `BatteryMonitorBL/ConnectivityViewController.swift`
**Lines 116-144:** viewWillAppear lifecycle method

```swift
override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    // Layer 1: Proactive peripheral state check
    // iOS CoreBluetooth doesn't generate disconnect events for physical power off,
    // so we actively check peripheral state every time user returns to this screen
    ZetaraManager.shared.protocolDataManager.logProtocolEvent("[CONNECTIVITY] viewWillAppear - checking peripheral state")

    if let peripheral = try? ZetaraManager.shared.connectedPeripheralSubject.value() {
        let peripheralState = peripheral.state
        ZetaraManager.shared.protocolDataManager.logProtocolEvent("[CONNECTIVITY] Peripheral state: \(peripheralState.rawValue)")

        if peripheralState != .connected {
            // Peripheral is NOT connected - force cleanup
            ZetaraManager.shared.protocolDataManager.logProtocolEvent("[CONNECTIVITY] ⚠️ Peripheral state is \(peripheralState.rawValue), not connected - forcing cleanup")
            ZetaraManager.shared.cleanConnection()  // ← DESTROYS UUID!
            scannedPeripherals = []
            tableView.reloadData()
        }
    }
}
```

### Why This Breaks Auto-Reconnect:

**Timeline:**
```
00:00 - Battery disconnects physically
00:01 - iOS fires didDisconnect event
00:01 - observeDisconnect() handler executes
00:01 - cleanConnectionPartial() called → UUID PRESERVED ✅
00:01 - attemptAutoReconnect() called → persistent request established ✅
00:05 - User navigates to Settings/Connectivity screen
00:05 - viewWillAppear() fires
00:05 - Checks peripheral.state → sees disconnected
00:05 - Calls cleanConnection() → UUID DESTROYED ❌
00:05 - Persistent request cancelled
00:05 - Auto-reconnect IMPOSSIBLE!
```

**Why This Code Exists:**
Comment lines 119-121 explain: "iOS CoreBluetooth doesn't generate disconnect events for physical power off, so we actively check peripheral state every time user returns to this screen"

This was added as a workaround for iOS disconnect events not firing (the Build 21 assumption). But it uses the WRONG cleanup method!

### Historical Context:

- **Build 21:** Documented iOS doesn't fire disconnect events for battery power off
- **Build 38:** Added `cleanConnectionPartial()` + auto-reconnect, fixed `observeDisconnect()` handler
- **Build 39:** Added startup auto-reconnect (works correctly)
- **Build 40:** Fixed health monitor to use partial cleanup (correct but incomplete)
- **Build 41:** Fix viewWillAppear() - the REAL culprit!

---

## Build 41 Hypothesis:

**Problem:** `ConnectivityViewController.viewWillAppear()` using wrong cleanup method (full instead of partial).

**Expected Behavior:**
```
Battery disconnects
    ↓
observeDisconnect() handler: cleanConnectionPartial() + attemptAutoReconnect() ✅
    ↓
UUID preserved, persistent request active ✅
    ↓
User navigates to Settings screen
    ↓
viewWillAppear() fires → detects disconnected state
    ↓
Call cleanConnectionPartial() (preserve UUID) ✅
    ↓
Call attemptAutoReconnect() if not already active ✅
    ↓
Battery powers back on
    ↓
iOS auto-connects (persistent request still active)
    ↓
SUCCESS
```

**Fix Location:** ConnectivityViewController.swift lines 129-148 (viewWillAppear method)

---

## Build 41 Solution:

### PRIMARY FIX: Update viewWillAppear to Use Partial Cleanup

**File:** `BatteryMonitorBL/ConnectivityViewController.swift`

**Lines 129-148: viewWillAppear Method**
```swift
if peripheralState != .connected {
    // Build 41 FIX: Use partial cleanup + auto-reconnect instead of full cleanup
    ZetaraManager.shared.protocolDataManager.logProtocolEvent("[CONNECTIVITY] ⚠️ Peripheral state is \(peripheralState.rawValue), not connected - triggering auto-reconnect")

    ZetaraManager.shared.cleanConnectionPartial()

    // Attempt auto-reconnect if enabled and UUID available
    if ZetaraManager.shared.autoReconnectEnabled {
        if let uuid = ZetaraManager.shared.cachedDeviceUUID {
            ZetaraManager.shared.protocolDataManager.logProtocolEvent("[CONNECTIVITY] Triggering auto-reconnect with UUID: \(uuid)")
            ZetaraManager.shared.attemptAutoReconnect(peripheralUUID: uuid)
        } else {
            ZetaraManager.shared.protocolDataManager.logProtocolEvent("[CONNECTIVITY] ⚠️ Cannot auto-reconnect: No cached UUID")
        }
    } else {
        ZetaraManager.shared.protocolDataManager.logProtocolEvent("[CONNECTIVITY] Auto-reconnect disabled - manual scan required")
    }

    scannedPeripherals = []
    tableView.reloadData()
}
```

**What Changed:**
- ❌ BEFORE: `cleanConnection()` → destroyed UUID
- ✅ AFTER: `cleanConnectionPartial()` → preserves UUID
- ✅ ADDED: Check `autoReconnectEnabled` flag
- ✅ ADDED: Call `attemptAutoReconnect()` if UUID available
- ✅ ADDED: Comprehensive logging for all paths

### SECONDARY FIX: Make Methods Public for Cross-Module Access

**File:** `Zetara/Sources/ZetaraManager.swift`

**Line 86:** cachedDeviceUUID property
```swift
// BEFORE: private var cachedDeviceUUID: String?
// AFTER:  public var cachedDeviceUUID: String?
```

**Line 530:** cleanConnectionPartial() method
```swift
// BEFORE: private func cleanConnectionPartial()
// AFTER:  public func cleanConnectionPartial()
```

**Line 577:** attemptAutoReconnect() method
```swift
// BEFORE: private func attemptAutoReconnect(peripheralUUID: String)
// AFTER:  public func attemptAutoReconnect(peripheralUUID: String)
```

**Why Needed:**
ConnectivityViewController is in `BatteryMonitorBL` target, ZetaraManager is in `Zetara` module. Cross-module access requires `public` visibility.

**Precedent:**
`cleanConnection()` is already `public` (line 455) for the same reason.

### Version Update:

**File:** `BatteryMonitorBL.xcodeproj/project.pbxproj`

```
CURRENT_PROJECT_VERSION = 41;
```

**Build Status:** ✅ Compiled successfully

---

## Changes Summary:

### Files Modified:

1. `BatteryMonitorBL.xcodeproj/project.pbxproj` - Version 40→41
2. `BatteryMonitorBL/ConnectivityViewController.swift` - viewWillAppear fix (PRIMARY FIX)
3. `Zetara/Sources/ZetaraManager.swift` - Access modifiers (SECONDARY FIX)

### Lines Changed:

**ConnectivityViewController.swift:**
- Lines 129-148: viewWillAppear handler (PRIMARY FIX)

**ZetaraManager.swift:**
- Line 86: `cachedDeviceUUID` private→public
- Line 530: `cleanConnectionPartial()` private→public
- Line 577: `attemptAutoReconnect()` private→public

---

## Expected Results:

**Test 1 (Mid-session reconnect):**
- Build 40: FAILED (UUID destroyed by viewWillAppear)
- Build 41: Should PASS (UUID preserved, auto-reconnect triggered)

**Test 3 (Mid-session reconnect 1st attempt):**
- Build 40: FAILED (UUID destroyed by viewWillAppear)
- Build 41: Should PASS (UUID preserved, auto-reconnect triggered)

**Test 6 (Mid-session reconnect 2nd attempt):**
- Build 40: FAILED (UUID destroyed by viewWillAppear)
- Build 41: Should PASS (UUID preserved, auto-reconnect triggered)

**Test 2, 4, 5 (Regression tests):**
- Build 40: PASSED
- Build 41: Should still PASS (no changes to startup logic or Settings save flow)

---

## Test Plan for Joshua:

### Priority Tests (FAILED in Build 40 → should PASS in Build 41):

1. **Test 1:** Mid-session reconnect (battery restart)
   - Connect to battery
   - Turn off battery
   - Wait 10 seconds
   - Turn on battery
   - **Expected:** Auto-reconnect WITHOUT manual scan

2. **Test 3:** Mid-session reconnect after Settings navigation
   - Connect to battery
   - Navigate to Settings screen
   - Turn off battery
   - Turn on battery
   - **Expected:** Auto-reconnect WITHOUT manual scan

3. **Test 6:** Multiple disconnect cycles
   - Connect to battery
   - Turn off battery → Turn on battery
   - Repeat cycle 2-3 times
   - **Expected:** Auto-reconnect every time WITHOUT manual scan

### Regression Tests (PASSED in Build 40 → verify no regression):

4. **Test 4:** Cross-session reconnect
   - Connect to battery
   - Close app (swipe up)
   - Reopen app
   - **Expected:** Auto-reconnect on startup

5. **Test 5:** App restart reconnect
   - Connect to battery
   - Close app
   - Wait
   - Reopen app
   - **Expected:** Auto-reconnect on startup

**Total: 5 tests required**

---

## Success Criteria:

**Build 41 = SUCCESS if:**
- ✅ Tests 1, 3, 6 now PASS (previously FAILED)
- ✅ Tests 4, 5 still PASS (no regression)
- ✅ Logs show `[CONNECTIVITY] Triggering auto-reconnect with UUID:`
- ✅ Logs show `[CLEANUP] Partial cleanup - preserving UUID for auto-reconnect`
- ✅ NO instances of `[CONNECTIVITY] ⚠️ ... forcing cleanup` followed by `Cleared persistent UUID from storage`

**Build 41 = PARTIAL if:**
- ⚠️ Some tests pass, some fail
- ⚠️ Inconsistent behavior
- ⚠️ Auto-reconnect works but requires multiple attempts

**Build 41 = FAILED if:**
- ❌ Tests 1, 3, 6 still fail
- ❌ Tests 4, 5 regress
- ❌ New errors introduced
- ❌ UUID still being destroyed

---

## Risk Assessment:

**Risk 1: Low** - Minimal change to ConnectivityViewController lifecycle method
**Risk 2: Low** - Access modifiers changed to public (safe, follows precedent of cleanConnection())
**Risk 3: Low** - No changes to startup auto-reconnect (Tests 4, 5 should not regress)
**Risk 4: Low** - Duplicate detection from Build 40 prevents race conditions

**Mitigation:**
- Comprehensive logging traces all paths
- Falls back to manual scan if UUID missing
- Auto-reconnect can be disabled by flag
- Same pattern as health monitor fix (Build 40)

---

## Expected Outcome:

**Build 41 should achieve:**
- ✅ 5/5 tests passing (60% → 100%)
- ✅ Complete auto-reconnect feature (mid-session + startup)
- ✅ No user intervention required
- ✅ Handles all disconnect scenarios including Settings navigation

**Build 38 + Build 39 + Build 40 + Build 41 = Complete, Working Feature:**
- ✅ Mid-session auto-reconnect (Build 38 foundation + Build 41 fix)
- ✅ Startup auto-reconnect (Build 39)
- ✅ Health monitor integration (Build 40)
- ✅ viewWillAppear cleanup fix (Build 41)
- ✅ Cross-session persistence (Build 38)
- ✅ Duplicate prevention (Build 40)

**This should be the FINAL build to complete auto-reconnect functionality.**

The difference from Build 40: We found and fixed the REAL source of UUID destruction - the viewWillAppear lifecycle method that fires when user navigates to Settings screen!

---

**Navigation:**
- ⬅️ Previous: [Build 40](build-40.md)
- ➡️ Next: [Build 42](build-42.md)
- 🏠 Main: [../THREAD-001.md](../THREAD-001.md)
