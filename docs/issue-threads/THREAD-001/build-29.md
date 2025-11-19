# Build 29: Proactive State Monitoring (3 Layers)

**Date:** 2025-10-21 (implementation) / 2025-10-24 (test result)
**Status:** 🔄 PARTIAL SUCCESS
**Attempt:** #2

**Navigation:**
- ⬅️ Previous: [Build 28](build-28.md)
- ➡️ Next: [Build 30](build-30.md)
- 🏠 Main: [../THREAD-001.md](../THREAD-001.md)

---

## New Hypothesis:

Need **PROACTIVE monitoring**, not reactive (waiting for events). Check `peripheral.state` actively instead of waiting for iOS disconnect events.

## Solution Implementing:

### Layer 1: viewWillAppear State Check (`ConnectivityViewController.swift`)
- Check `peripheral.state` every time user returns to Connectivity screen
- If `peripheral.state != .connected` → force cleanup
- Log all state checks for diagnostics

### Layer 2: Pre-Flight Check (`ZetaraManager.connect()`)
- Check `peripheral.state` BEFORE attempting connection
- Log WARNING if state is .disconnected or .disconnecting
- Helps diagnose stale peripheral attempts in logs

### Layer 3: Periodic Health Monitor (`ZetaraManager.init()`)
- Active monitoring every 3 seconds
- Check `peripheral.state` of connected peripheral
- If `state != .connected` → trigger cleanup
- Log health checks every 30 seconds

## Expected Improvement:

- ✅ Detect disconnect within 3 seconds (Layer 3 periodic check)
- ✅ Catch stale peripherals on screen return (Layer 1)
- ✅ Diagnose stale connection attempts (Layer 2 logging)
- ✅ Multi-layer defense (if one fails, others catch it)
- ✅ No dependency on iOS disconnect events

## Expected Log Sequence:

```
[INIT] ✅ Connection health monitor started (3s interval)
    ↓
[User changes protocols → Save → Battery disconnects]
    ↓
[Within 3 seconds]
[HEALTH] ⚠️ DETECTED: Peripheral state changed to 0 (disconnected)
[HEALTH] Connection lost without disconnect event - forcing cleanup
[CONNECTION] Cleaning connection state
[CONNECTION] Scanned peripherals cleared
    ↓
[User returns to Connectivity screen]
    ↓
[CONNECTIVITY] viewWillAppear - checking peripheral state
[CONNECTIVITY] No connected peripheral - clearing scanned list
    ↓
[Fresh scan starts]
[User clicks battery]
    ↓
[CONNECT] Pre-flight check: Peripheral state = 0
[CONNECT] Attempting connection  ← SUCCESS!
```

## Files Modified:

- `BatteryMonitorBL/ConnectivityViewController.swift` (added viewWillAppear lines 116-142)
- `Zetara/Sources/ZetaraManager.swift` (added pre-flight check lines 220-229, health monitor lines 124-150)

---

## Test Result (2025-10-24):

**Status:** 🔄 PARTIAL SUCCESS

## Client Testing (Joshua):

> Followed usual protocol:
> Connect to battery
> Check settings page, can't select different ID's or protocols,
> Save changes button clicked
> Restarted battery
> App displays connection even though battery is off
> Try to connect to battery again, connection error given

## Diagnostic Logs:

- File: `docs/fix-history/logs/bigbattery_logs_20251024_091932.json`
- Timestamp: 09:19:19-09:19:32 24.10.2025
- Build: 29

## Expected vs Reality Comparison:

| Expected (from Attempt #2) | Reality (from logs) | Evidence | Status |
|---------------------------|---------------------|----------|---------|
| [INIT] Health monitor started | NOT found | No [INIT] in recentLogs | ❌ MISSING |
| [HEALTH] Periodic check events | NOT found | No [HEALTH] in any logs | ❌ MISSING |
| [HEALTH] Disconnect detected within 3s | NOT found | No [HEALTH] events at all | ❌ FAILED |
| [CONNECTIVITY] viewWillAppear check | FOUND ✅ | `[09:19:27] [CONNECTIVITY] viewWillAppear - checking peripheral state` | ✅ WORKS |
| [CONNECTIVITY] No connected peripheral | FOUND ✅ | `[09:19:27] [CONNECTIVITY] No connected peripheral - clearing scanned list` | ✅ WORKS |
| [CONNECT] Pre-flight check | FOUND ✅ | `[09:19:30] [CONNECT] Pre-flight check: Peripheral state = 0` | ✅ WORKS |
| [CONNECT] WARNING logged | FOUND ✅ | `[09:19:30] [CONNECT] ⚠️ WARNING: Attempting connection with stale peripheral (state: 0)` | ✅ WORKS |
| Connection SUCCESS | FAILED ❌ | `[09:19:30] [CONNECTIVITY] Connection failed: error 4` | ❌ FAILED |
| No "BluetoothError error 4" | Still present | `RxBluetoothKit2.BluetoothError error 4` | ❌ SAME |
| Stale peripheral prevented | NOT prevented | Pre-flight detected but didn't STOP connection | ❌ FAILED |

## What Got Better:

- ✅ **Layer 1 (viewWillAppear) WORKS** - Successfully detects when no connected peripheral present
- ✅ **Layer 2 (Pre-flight check) WORKS** - Successfully detects and logs stale peripheral (state = 0)
- ✅ **Diagnostics massively improved** - Logs now show EXACTLY what's wrong with clear warnings
- ✅ **Problem correctly identified** - Pre-flight accurately detects stale peripheral before connection attempt

## What Got Worse:

- ❌ **Layer 3 (Health Monitor) MISSING** - No [INIT] or [HEALTH] logs appearing at all (needs investigation)

## What Stayed Same (Still Broken):

- ❌ **Connection still fails with error 4** - User cannot reconnect to battery
- ❌ **Pre-flight detection doesn't PREVENT connection** - Only logs warning, then proceeds to fail
- ❌ **User experience unchanged** - Same "connection error" as before

## Log Timeline Analysis:

```
[09:19:19] Previous session cleanup
[09:19:19] [CONNECTION] Scanned peripherals cleared

[User returns to Connectivity screen - Layer 1 triggers]
[09:19:27] [CONNECTIVITY] viewWillAppear - checking peripheral state
[09:19:27] [CONNECTIVITY] No connected peripheral - clearing scanned list

[User clicks battery - Layer 2 triggers]
[09:19:30] [CONNECT] Attempting connection
[09:19:30] [CONNECT] Device name: BB-51.2V100Ah-0855
[09:19:30] [CONNECT] Pre-flight check: Peripheral state = 0  ← DETECTED!
[09:19:30] [CONNECT] ⚠️ WARNING: Attempting connection with stale peripheral (state: 0)
[09:19:30] [CONNECT] This peripheral reference may be invalid - connection likely to fail with error 4

[Connection CONTINUES despite warning!]
[09:19:30] [CONNECTION] Cleaning connection state
[09:19:30] [CONNECTIVITY] Connection failed: error 4  ← FAILED!

[iOS discovers services AFTER failure]
[09:19:30] [CONNECT] Services discovered: 1
[09:19:30] [CONNECTION] ✅ Characteristics configured
```

## Critical Finding:

Pre-flight check **DETECTS** the problem correctly (peripheral.state = 0), but **DOES NOT PREVENT** the connection attempt. Connection proceeds → cleanup happens → fails with error 4.

## Root Cause Update:

Detection is NOT the problem! We successfully detect stale peripheral.

**Real Problem: iOS caches peripheral instances even after fresh scan!**

Evidence chain:
1. Battery disconnects (physical power off)
2. iOS keeps peripheral instance in memory (state changes to 0, but instance remains)
3. User does fresh scan → finds same battery name
4. iOS returns SAME cached peripheral instance (not a new one!)
5. App attempts connection to cached peripheral with state = 0
6. iOS rejects: error 4 (peripheral not in connected state)

## What we need for Attempt #3:

1. ✅ Detection working (Layer 1, Layer 2 confirmed)
2. ❌ Prevention NOT working - Need to:
   - **ABORT** connection attempt when pre-flight detects state = 0
   - **Force iOS to forget** old peripheral via `cancelPeripheralConnection()`
   - **Return error** to user: "Need fresh scan"
   - Get FRESH peripheral instance from iOS
3. ❌ Layer 3 NOT working - Investigate why no [INIT]/[HEALTH] logs

## Next Steps:

- [ ] Fix pre-flight to ABORT connection when state = 0 detected
- [ ] Add `cancelPeripheralConnection()` call to force iOS to forget stale peripheral
- [ ] Debug Layer 3 - why no health monitor logs appearing
- [ ] Implement Attempt #3 with these fixes

---

**Navigation:**
- ⬅️ Previous: [Build 28](build-28.md)
- ➡️ Next: [Build 30](build-30.md)
- 🏠 Main: [../THREAD-001.md](../THREAD-001.md)
