# Build 28: Global Disconnect Handler

**Date:** 2025-10-20
**Status:** ❌ FAILED
**Attempt:** #1

**Navigation:**
- ⬅️ Previous: N/A (first attempt)
- ➡️ Next: [Build 29](build-29.md)
- 🏠 Main: [../THREAD-001.md](../THREAD-001.md)

---

## Client Report (Joshua):

> Connected to battery
> - ID stayed at 1
> - changed both protocols from GRW → LUX
> - saved changes
> - disconnected & restarted battery (turned off & turned back on)
> - **invalid connection error when I click on battery in Bluetooth**

## Diagnostic Logs:

- File: `docs/fix-history/logs/bigbattery_logs_20251020_091648.json`
- Timestamp: 09:16:34-09:16:41 20.10.2025

## Hypothesis:

The Oct 10 fix added `cleanScanning()` to `cleanConnection()`, but `cleanConnection()` was only called when disconnect was detected. The problem: `observeDisconect()` subscription in ConnectivityViewController was tied to ViewController lifecycle and cancelled in `viewWillDisappear`. When battery disconnected while user was on different screen (Settings), disconnect event was NOT detected, so `cleanConnection()` was never called.

## Solution Implemented:

1. **Added global disconnect handler** in `ZetaraManager.init()` (lines 108-122)
   - Tied to singleton lifecycle, never cancelled
   - Calls `cleanConnection()` on disconnect
   - Logs disconnect events

2. **Removed duplicate subscription** from ConnectivityViewController (removed lines 95-100)
   - Old subscription tied to ViewController lifecycle

3. **Added UI state subscription** in ConnectivityViewController (lines 95-112)
   - Subscribes to `connectedPeripheralSubject` for UI updates
   - Clears `scannedPeripherals` when peripheral == nil
   - Safe to cancel in viewWillDisappear (only UI, not critical logic)

## Expected Improvement:

- ✅ Disconnect detected from ANY screen (not just ConnectivityVC)
- ✅ `cleanConnection()` called IMMEDIATELY when battery disconnects
- ✅ Stale peripherals cleared before user returns to Bluetooth screen
- ✅ Fresh scan obtains new peripheral instance
- ✅ No "BluetoothError error 4"

## Expected Log Sequence:

```
[09:16:35] [SETTINGS] ✅ RS485 Protocol set successfully
[09:16:35] [SETTINGS] ✅ CAN Protocol set successfully
    ↓
[Battery physically disconnects]
    ↓
[09:16:36] [DISCONNECT] 🔌 Device disconnected: BB-51.2V100Ah-0855  ← KEY!
[09:16:36] [CONNECTION] Cleaning connection state
[09:16:36] [CONNECTION] Scanned peripherals cleared
    ↓
[User returns to Connectivity screen]
    ↓
[09:16:40] [CONNECTIVITY] UI updated: disconnected, cleared stale peripherals
[09:16:40] [SCAN] Starting scan for peripherals
[09:16:42] [SCAN] Found peripheral: BB-51.2V100Ah-0855  ← FRESH!
    ↓
[User clicks battery]
    ↓
[09:16:45] [CONNECT] Attempting connection  ← SUCCESS!
```

## Files Modified:

- `Zetara/Sources/ZetaraManager.swift` (lines 108-122)
- `BatteryMonitorBL/ConnectivityViewController.swift` (lines 95-112)
- `docs/fix-history/logs/bigbattery_logs_20251020_091648.json` (copied)

## Commit:

- `6e4f177`: "fix: Fix 'Invalid Device' error after battery restart (observeDisconect lifecycle issue)"
- `09081a9`: "docs: Add fix-history and common-issues documentation for lifecycle issue"

## Test Result:

❌ FAILED (see Build 28 Test Results below)

## Related Documentation:

- `docs/fix-history/2025-10-20_invalid-device-after-restart-regression.md`
- `docs/common-issues-and-solutions.md` (Problem 5, lines 893-1142)

---

## Build 28 Test Results (2025-10-21)

**Client Testing (Joshua):**
Tested all 3 scenarios with Build 28 (our latest version with global disconnect handler).

**Test Results:**
- ❌ **Scenario 1** (Change protocols → Restart): "Unable to reconnect" + error 4
- ❌ **Scenario 2** (Disconnect while on different screen): "unable to reconnect... app thinking connectivity is still ongoing"
- ❌ **Scenario 3** (Quick reconnect): "connection error" + error 4

**Diagnostic Logs:**
- Scenario 1: `docs/fix-history/logs/bigbattery_logs_20251021_104425.json`
- Scenario 2: `docs/fix-history/logs/bigbattery_logs_20251021_104710.json`
- Scenario 3: `docs/fix-history/logs/bigbattery_logs_20251021_104922.json`
- All logs: 10:43-10:49 21.10.2025

**What Got Better:**
- **NOTHING!** Problem persists exactly as before.

**What Got Worse:**
- **NOTHING changed.** Same error pattern.

**Critical Finding from Logs:**
```
ALL 3 LOGS COMPLETELY MISSING [DISCONNECT] EVENTS!

Expected:
[XX:XX:XX] [DISCONNECT] 🔌 Device disconnected: ...

Reality in ALL logs:
❌ NO [DISCONNECT] events
❌ cleanConnection() called ONLY after connection error
❌ cleanConnection() called ONLY from BMS timer detecting no peripheral
```

**Log Timeline Analysis (Scenario 1):**
```
10:43:54 - [CONNECT] Attempting connection
10:43:54 - [CONNECT] Cached UUID: none
10:43:54 - [CONNECTION] Cleaning connection state  ← from connect() method
10:43:54 - [CONNECTIVITY] Connection failed: error 4  ← FAILED!
10:43:55 - [CONNECT] Services discovered: 1  ← Strange order
10:43:55 - [CONNECTION] ✅ Characteristics configured

[30 second gap - Joshua opens Diagnostics]

10:44:24 - [BMS] 🚀 Starting BMS data refresh timer
10:44:24 - [BMS] Device connected: false
10:44:24 - [CONNECTION] Cleaning connection state  ← from BMS timer
```

**Root Cause Update:**
Our hypothesis was **WRONG!**

**Initial hypothesis:** observeDisconect subscription cancelled by ViewController lifecycle.
**Reality:** iOS CoreBluetooth **DOES NOT** generate disconnect events for physical power off!

**From analysis:**
- Global disconnect handler IS running (it's in ZetaraManager init, never cancelled)
- BUT it's NOT being triggered because iOS is NOT generating the disconnect event
- iOS only generates disconnect events for:
  1. App calls `cancelPeripheralConnection()` (manual)
  2. Peripheral sends disconnect command (graceful)
  3. Connection timeout after failed communication attempts (delayed)
- iOS does NOT generate immediate disconnect events for:
  1. Physical power off (battery turned off)
  2. Device moves out of range
  3. Sudden connection loss

**Quote from Joshua (Scenario 2):**
> "unable to reconnect to husky battery due to **app thinking connectivity is still ongoing**"

This confirms:
- `connectedPeripheralSubject` still has peripheral instance
- `peripheral.state` likely NOT .connected but we're not checking it
- We're waiting for an event that will NEVER come

---

**Navigation:**
- ⬅️ Previous: N/A (first attempt)
- ➡️ Next: [Build 29](build-29.md)
- 🏠 Main: [../THREAD-001.md](../THREAD-001.md)
