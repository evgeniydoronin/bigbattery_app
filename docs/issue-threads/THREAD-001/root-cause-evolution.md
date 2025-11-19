# Root Cause Evolution

How our understanding of the reconnection problem evolved across 40 builds.

**Navigation:**
- 🏠 Main: [../THREAD-001.md](../THREAD-001.md)

---

## Initial Understanding (2025-10-10):

**Problem:** Stale peripheral references in `scannedPeripherals` array.
**Solution:** Call `cleanScanning()` in `cleanConnection()`.
**Assumption:** `cleanConnection()` gets called when disconnect happens.

---

## Updated Understanding (2025-10-20):

**Problem:** `cleanConnection()` not called because `observeDisconect()` subscription cancelled by ViewController lifecycle.
**Solution:** Move disconnect handler to global scope (ZetaraManager singleton).
**Assumption:** iOS generates disconnect events that our handler will catch.

---

## Understanding After Attempt #2 (2025-10-21):

**Problem:** iOS CoreBluetooth **does NOT generate disconnect events** for physical power off!
**Root Cause:** Reactive approach (waiting for events) fundamentally flawed for this scenario.
**Solution:** Proactive approach - actively check `peripheral.state` instead of waiting for events.

**Key Insights:**
1. **iOS disconnect events are NOT reliable** for physical power off scenarios
2. **peripheral.state is more reliable** than waiting for disconnect events
3. **Multi-layer defense needed** - single point of failure is risky
4. **Apple's "best practices" assume graceful disconnects** - real world has physical power off
5. **Reactive patterns fail** when events don't fire - need proactive monitoring

---

## Current Understanding (2025-10-24 after testing Attempt #2):

**Problem:** Detection works, but **iOS caches peripheral instances across scans!**

**What we learned from Build 29 testing:**
- ✅ Layer 1 & Layer 2 successfully DETECT stale peripherals
- ❌ But detection alone doesn't solve the problem!
- ❌ iOS returns CACHED peripheral instance even after fresh scan

**Root Cause Chain:**
```
Battery physically disconnects
    ↓
iOS peripheral instance remains in memory (state → 0, but object persists)
    ↓
User does fresh BLE scan
    ↓
iOS finds same device by name/UUID
    ↓
iOS returns SAME cached peripheral object (not creating new one)
    ↓
App detects peripheral.state = 0 (via pre-flight check)
    ↓
But connection attempt CONTINUES anyway
    ↓
iOS rejects: error 4 ("peripheral not connected")
    ↓
SOLUTION NEEDED: Must force iOS to FORGET cached instance
```

**Why previous solution was incomplete:**
- Attempt #2 added detection (peripheral.state checks) ✅
- But didn't add prevention (abort connection + force forget) ❌
- Pre-flight logs warning but doesn't STOP the bad connection attempt

**What Attempt #3 needs:**
1. **Pre-flight must ABORT** - Return error instead of just logging warning
2. **Must call `cancelPeripheralConnection()`** - Force iOS to release cached instance
3. **Must get FRESH peripheral** - Only connect to peripherals with state = .disconnected from NEW scan
4. **Fix Layer 3** - Health monitor not logging (separate issue)

**Key Insights:**
1. **iOS CoreBluetooth caches peripheral objects** - doesn't create new instances for same device
2. **Detection ≠ Prevention** - Knowing about problem doesn't prevent it
3. **Must explicitly tell iOS to forget** - `cancelPeripheralConnection()` required
4. **Cached peripherals are unusable** - state = 0 peripherals will always fail connection
5. **Need gate logic** - Prevent connection attempts to known-bad peripherals

---

## Current Understanding (2025-10-27 after Build 30 failure):

**Problem:** `peripheral.state` **CANNOT** distinguish fresh from stale peripherals!

**Critical Discovery from Build 30 catastrophic failure:**

Attempted to use `peripheral.state == .disconnected` to identify stale peripherals.
**This blocked ALL connections** because fresh peripherals also have `.disconnected` state.

**Why peripheral.state is useless:**
- Fresh peripheral after scan: `state = .disconnected` ✅ (NORMAL - ready to connect)
- Stale cached peripheral: `state = .disconnected` ❌ (PROBLEM - should reject)
- **IDENTICAL STATE** - impossible to distinguish!

State only changes **DURING** connection:
- Before connection: `.disconnected`
- During connection: `.connecting` → `.connected`
- During disconnection: `.disconnecting` → `.disconnected`

**Solution (Build 31):** Check **scan list membership**, not state.
- Peripheral UUID in `scannedPeripheralsSubject`? → Fresh from current scan → ALLOW
- Peripheral UUID NOT in list? → Stale from previous session → REJECT

**Why scan list works:**
1. New scan → UUIDs added to `scannedPeripheralsSubject`
2. Disconnect → `cleanConnection()` → `cleanScanning()` → list cleared
3. Old peripheral still in UI → UUID not in list → reject
4. New scan → UUID back in list → connection works

**Key Insights:**
1. **peripheral.state is NOT a reliable indicator** - same value for fresh and stale
2. **Must validate against scan session** - not peripheral properties
3. **Scan list is source of truth** - managed by cleanConnection() lifecycle
4. **UI cache is NOT reliable** - can contain stale references after disconnect
5. **Session-based validation** - peripheral must be from CURRENT scan session

---

## Current Understanding (2025-11-14 after Build 37 testing):

**Problem:** Build 37 fix implementation location was WRONG - placed AFTER pre-flight abort!

**Critical Discovery from Build 37 FAILED testing:**

Build 37 attempted to force iOS peripheral cache release with `cancelPeripheralConnection()`.
**Fix code NEVER EXECUTED** because pre-flight validation (Build 31) aborted connection attempts BEFORE reaching Build 37 fix code.

**Why Build 37 failed:**

**Code Flow in ZetaraManager.swift connect():**
```
Lines 252-279: Pre-flight validation (Build 31)
    └─ If peripheral not in scan list → Return Observable.error() → FUNCTION EXITS

Lines 282-297: Build 37 fix (cancelPeripheralConnection) ← UNREACHABLE CODE!
```

**Evidence from logs:**
- Test 1 (Battery Restart): "[CONNECT] ❌ ABORT: Peripheral not found in current scan list"
- Test 2 (Settings Save): "[CONNECT] Connection failed: Please scan again to reconnect"
- **ZERO** instances of "Build 37: Forcing release of cached peripheral"
- Build 37 fix never ran in either test

**Real Problem Uncovered:**

**What we thought (Build 37 hypothesis):**
- iOS caches peripheral instances with stale characteristic handles
- Solution: Force cache release with `cancelPeripheralConnection()`
- Implementation: Add forced release in `connect()` method

**What actually happens (Build 37 reality):**
1. Battery disconnects (restart OR settings save)
2. iOS doesn't fire disconnect event (known since Build 21)
3. Cleanup triggered reactively (timeout or error detection)
4. `cleanConnection()` → `cleanScanning()` → **scan list cleared**
5. UI TableView still shows old peripheral (cached in UI layer)
6. User clicks old peripheral (reasonable user action)
7. Pre-flight check: Peripheral UUID not in `scannedPeripheralsSubject` (cleared in step 4)
8. Pre-flight **correctly** aborts: "This peripheral is from previous session"
9. Function returns → Build 37 fix never reached
10. User sees error → must manually scan

**Root Cause:** Not iOS peripheral caching. It's **scan list clearing + UI state mismatch**.

**Why Pre-Flight Validation is Actually Working Correctly:**
- ✅ Scan list cleared after disconnect (cleanup working)
- ✅ Pre-flight detects peripheral not in current session (validation working)
- ✅ Pre-flight prevents connection to stale peripheral (protection working)
- ❌ BUT this creates catch-22: Can't "fix" stale peripherals if pre-flight blocks all access
- ❌ Build 37 attempted to fix something that pre-flight correctly prevents

**The Real Gap:**

```
Disconnect happens
    ↓
Cleanup clears scan list (correct behavior)
    ↓
UI still shows old peripheral (UI layer not updated)
    ↓
User clicks old peripheral (expects it to work)
    ↓
Pre-flight rejects it (correct behavior)
    ↓
USER CONFUSED: "Why can't I connect? Battery is right there!"
```

**The UX Problem:**
- User sees peripheral in UI list
- User clicks peripheral
- App says "scan again"
- User thinks: "But I can SEE the battery in the list!"
- **Gap:** UI shows old peripheral that scan list doesn't contain

**Why "Force Cache Release" Approach Was Wrong:**

1. **Pre-flight protection is GOOD** - it prevents error 4 by rejecting stale peripherals
2. **Disabling pre-flight would be BAD** - would reintroduce error 4 problems
3. **Moving Build 37 fix BEFORE pre-flight would be RISKY** - might break protection
4. **Forcing cache release doesn't solve UX problem** - user still sees old peripheral in UI

**What Build 38 Should Do Instead:**

Instead of trying to "fix" stale peripherals, **prevent the UX confusion:**

**Solution:** Auto-trigger fresh scan when scan list cleared after disconnect

**Location:** UI layer (ConnectivityViewController), NOT Bluetooth logic

**Implementation:**
```swift
// In ConnectivityViewController
scannedPeripheralsSubject
    .subscribe(onNext: { [weak self] peripherals in
        if peripherals.isEmpty && self?.wasConnected == true {
            // Scan list cleared after disconnect - auto-start fresh scan
            self?.startScanning()
        }
    })
```

**Benefits:**
- ✅ Minimal risk - only affects UI layer
- ✅ Doesn't touch Bluetooth logic (ZetaraManager)
- ✅ Keeps pre-flight protection working
- ✅ Solves UX problem (fresh scan → fresh peripheral list → user can connect)
- ✅ No manual scan required by user

**Key Insights:**

1. **Code placement is critical** - Placing fix AFTER early return = unreachable code
2. **Pre-flight validation working TOO well** - Correctly blocks stale peripherals but also blocks fix attempts
3. **Don't fight good protection mechanisms** - Pre-flight is doing its job correctly
4. **Real problem is UX not Bluetooth** - UI showing old peripheral while scan list empty
5. **Fix in the right layer** - UI problem needs UI solution, not Bluetooth layer fix
6. **Defensive code can block fixes** - Early returns, guards, validation can make code unreachable
7. **Test assumptions matter** - We assumed iOS caching was problem, but it was UI/scan list mismatch
8. **One positive outcome** - DiagnosticsViewController crash fix works! (reloadData() vs reloadSections())

**Comparison: Build 36 vs Build 37:**
- Connection success (Scenario 2): 0% → 0% (NO CHANGE)
- Error 4 frequency: Some → Some (NO CHANGE)
- DiagnosticsViewController crash: N/A → FIXED ✅ (IMPROVEMENT)
- User experience: Manual scan → Manual scan (NO CHANGE)

**Success Rate:** 0% on PRIMARY objective (auto-reconnection), 100% on SECONDARY objective (crash fix)

---

## Current Understanding (2025-11-17 after Build 38 implementation):

**Problem:** Our cleanup logic IMPLICITLY CANCELS iOS connection requests!

**Critical Discovery from Apple CoreBluetooth Documentation Research:**

After Builds 34-37 all failed to solve auto-reconnection, we conducted deep research into Apple's CoreBluetooth documentation and discovered the FUNDAMENTAL architectural flaw:

**Apple Documentation:**
- "Connection requests do not time out"
- "iOS will automatically reconnect when peripheral comes back in range"
- **BUT ONLY IF the connection request remains active!**

**What We Were Doing Wrong (All Previous Builds):**

```
Battery disconnects
    ↓
didDisconnect handler fires
    ↓
cleanConnection() called
    ↓
connectedPeripheralSubject.onNext(nil) ← CLEARS PERIPHERAL REFERENCE
    ↓
iOS IMPLICITLY CANCELS connection request (no reference = no request)
    ↓
iOS no longer "watching" for peripheral to return
    ↓
Battery powers back on
    ↓
iOS does NOTHING (no active connection request)
    ↓
User must manually scan and reconnect
```

**Root Cause:** We were fighting AGAINST iOS CoreBluetooth design instead of working WITH it.

**Why All Previous Attempts Failed:**

1. **Build 34-36:** Attempted to use `retrievePeripherals()` but still cleared peripheral references during cleanup
2. **Build 37:** Attempted forced cache release but code never executed (pre-flight abort)
3. **All builds:** Called full cleanup which cleared `connectedPeripheralSubject` → cancelled connection request

**The Paradigm Shift:**

**OLD thinking (Builds 1-37):**
- Disconnect → Full cleanup → Wait for user to scan → Connect
- Connection request is ONE-TIME operation
- Each connection needs fresh scan

**NEW thinking (Build 38):**
- Disconnect → Partial cleanup (preserve UUID) → Establish PERSISTENT connection request → iOS auto-reconnects when peripheral appears
- Connection request is PERSISTENT until explicitly cancelled
- No scan needed - iOS watches for peripheral UUID

**Build 38 Solution:**

**Persistent Connection Request Pattern:**

```
Battery disconnects
    ↓
didDisconnect handler fires
    ↓
cleanConnectionPartial() ← NEW! Only clears invalidated characteristics
    ↓
Preserve UUID in memory AND UserDefaults
    ↓
attemptAutoReconnect(UUID)
    ↓
retrievePeripherals(withIdentifiers: [UUID]) ← Get peripheral by UUID (NO scan!)
    ↓
establishConnection() ← Creates PERSISTENT connection request
    ↓
iOS keeps request active indefinitely
    ↓
Battery powers back on
    ↓
iOS AUTO-CONNECTS! (request was active, watching for UUID)
    ↓
rediscoverServicesAndCharacteristics() ← Fresh handles required (Apple docs)
    ↓
Auto-load protocols → Resume BMS data
    ↓
User sees: "🎉 AUTO-RECONNECTION COMPLETE!"
```

**Why This Works:**

1. **Partial cleanup** - Clears only what Apple says becomes invalid (characteristics), keeps foundation for reconnect
2. **Persistent UUID storage** - UserDefaults survives app restarts, enables cross-session reconnect
3. **retrievePeripherals()** - Gets peripheral by UUID without scan (iOS remembers paired devices)
4. **establishConnection()** - Creates connection request that persists until cancelled
5. **Service rediscovery** - Apple: "All services, characteristics become invalidated after disconnect"

**Key Difference from Build 34:**

Build 34 used `retrievePeripherals()` but:
- Called it DURING connect (user-initiated)
- Still did full cleanup on disconnect
- Lost UUID between sessions
- Connection request cancelled by cleanup

Build 38:
- Calls `retrievePeripherals()` AUTOMATICALLY on disconnect
- Does partial cleanup (preserves UUID)
- Stores UUID persistently (survives app restarts)
- Connection request stays ACTIVE

**Why Builds 34-37 Worked Cross-Session but NOT Within-Session:**

Cross-session (app restart):
- App launches → Calls `retrievePeripherals()` → Works ✅

Within-session (battery restart):
- Battery disconnects → `cleanConnection()` → Clears peripheral reference → Connection request CANCELLED → iOS forgets to watch → Battery returns → Nothing happens ❌

Build 38 fixes within-session by NOT cancelling the connection request!

**Key Insights:**

1. **iOS connection requests are PERSISTENT by design** - Don't time out, stay active until cancelled
2. **Clearing peripheral reference = implicit cancellation** - iOS assumes you're done with that peripheral
3. **Partial cleanup is critical** - Must preserve what's needed for auto-reconnect
4. **UUID persistence enables cross-session** - UserDefaults survives app lifecycle
5. **Apple's "invalidation" concept** - Only characteristics become invalid, not the peripheral itself
6. **Work WITH CoreBluetooth design** - Use persistent connection pattern as Apple intended
7. **Previous attempts misunderstood the problem** - Thought it was caching/staleness, but it was connection request lifecycle

**Architectural Change:**

**Before Build 38:**
```
Connection = One-time operation
Disconnect = Full teardown
Reconnect = Start from scratch (scan → connect)
```

**After Build 38:**
```
Connection = Persistent relationship
Disconnect = Partial cleanup (preserve foundation)
Reconnect = Automatic (iOS handles it)
```

**Expected Impact:**

- ✅ Auto-reconnect within same app session (battery restart)
- ✅ Auto-reconnect across app sessions (app restart)
- ✅ No manual scan required
- ✅ Works for Settings save scenario (battery restart)
- ✅ User control (can disable auto-reconnect)
- ✅ "Reconnecting..." UI feedback

**Success Rate Prediction:** 95%+ (some edge cases: iOS forgets peripheral, UUID changes, etc.)

**This is Build 38 - Testing pending.**

---

**Navigation:**
- 🏠 Main: [../THREAD-001.md](../THREAD-001.md)
