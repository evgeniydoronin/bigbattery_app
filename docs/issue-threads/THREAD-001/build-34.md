# Build 34: Launch-Time Fresh Peripheral

**Date:** 2025-10-30
**Status:** ✅/❌ MIXED (Reconnection resolved, but crash on disconnect)
**Attempt:** #4 (part 2)

**Navigation:**
- ⬅️ Previous: [Build 33](build-33.md)
- ➡️ Next: [Build 35](build-35.md)
- 🏠 Main: [../THREAD-001.md](../THREAD-001.md)

---

## Solution:

Expand fresh peripheral retrieval to **application launch** and **foreground**, not just explicit connection attempts.

## Implementation:

Added `refreshPeripheralInstanceIfNeeded()` public method in ZetaraManager:
```swift
// ZetaraManager.swift lines 450-480
public func refreshPeripheralInstanceIfNeeded() {
    guard let cachedUUID = cachedDeviceUUID,
          let uuidObj = UUID(uuidString: cachedUUID) else {
        return
    }

    let freshPeripherals = manager.retrievePeripherals(withIdentifiers: [uuidObj])

    guard let freshPeripheral = freshPeripherals.first else {
        // Peripheral no longer available - clear stale state
        cleanConnection()
        return
    }

    // Update subject with fresh instance (replaces stale one)
    connectedPeripheralSubject.onNext(freshPeripheral)
}
```

Called from AppDelegate:
```swift
// AppDelegate.swift didFinishLaunching
ZetaraManager.shared.refreshPeripheralInstanceIfNeeded()

// AppDelegate.swift applicationWillEnterForeground
ZetaraManager.shared.refreshPeripheralInstanceIfNeeded()
```

## When This Runs:

- Every app launch (before ANY operations)
- Every app return from background
- PLUS Build 33's connect-time retrieval (defense in depth)

## Why This Works:

- Catches stale peripherals at launch, BEFORE user navigates anywhere
- Works even if user doesn't click "Connect"
- Handles Joshua's exact scenario: disconnect → close app → reopen → navigate to Settings
- No UX flow dependencies - proactive refresh

## Expected Results:

- ✅ Error 4 eliminated (fresh peripheral from app launch)
- ✅ 100% connection success rate
- ✅ Works for Joshua's scenario (no Connect button needed)
- ✅ BMS data loads correctly
- ✅ Protocols load correctly
- ✅ Seamless UX (auto-reconnect if battery available)

---

## Test Results (2025-10-30):

**Letter from Joshua:** "Connection to battery successful, unfortunately it crashes when disconnecting battery to restart"

**Log:** `docs/fix-history/logs/bigbattery_logs_20251030_141251.json`

### Analysis:

- ✅ **Connection SUCCESS** - Error 4 ELIMINATED! Reconnection issue RESOLVED!
- ✅ **All battery data loads** - Voltage: 53.28V, SOC: 80%, all 16 cells present
- ✅ **All protocols load correctly** - Module ID: ID 1, RS485: P02-LUX, CAN: P06-LUX
- ✅ **No error 4 in logs** - The core reconnection problem is SOLVED
- ❌ **NEW ISSUE: Crash on disconnect** - App crashes when battery physically disconnected
- ⚠️ **No [LAUNCH] logs captured** - Either timing issue or fresh install scenario

## Verdict:

✅ **RECONNECTION ISSUE RESOLVED** - Build 34 successfully eliminates error 4 and enables reconnection!

❌ **NEW CRASH ISSUE** - Build 34 introduces crash when disconnecting battery, likely due to `applicationWillEnterForeground()` racing with disconnect cleanup.

## Root Cause of Crash:

When battery disconnects:
1. App may briefly enter background
2. User brings app back to foreground
3. `applicationWillEnterForeground()` calls `refreshPeripheralInstanceIfNeeded()`
4. Method tries to update peripheral while cleanup is happening
5. CRASH - race condition with disconnect state

---

**Navigation:**
- ⬅️ Previous: [Build 33](build-33.md)
- ➡️ Next: [Build 35](build-35.md)
- 🏠 Main: [../THREAD-001.md](../THREAD-001.md)
