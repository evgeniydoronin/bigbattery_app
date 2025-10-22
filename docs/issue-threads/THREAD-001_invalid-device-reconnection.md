# THREAD-001: Invalid Device Error After Battery Reconnection

**Status:** 🔴 ACTIVE
**Severity:** CRITICAL
**First Reported:** 2025-10-10
**Last Updated:** 2025-10-21
**Client:** Joshua (BigBattery ETHOS module BB-51.2V100Ah-0855)

---

## 📍 CURRENT STATUS

**Quick Summary:**
Client unable to reconnect to battery after physical disconnect/restart. App shows battery in Bluetooth list but clicking it results in "BluetoothError error 4" / "Invalid BigBattery device". iOS CoreBluetooth doesn't generate disconnect events for physical power off, causing stale peripheral references.

**Latest Test Result:** ⏳ PENDING (Attempt #2 - Proactive Monitoring deployed, waiting for client logs)

**Next Steps:**
- [ ] Wait for Joshua testing results (Attempt #2 with 3-layer proactive monitoring)
- [ ] Analyze new diagnostic logs
- [ ] Update METRICS table with results
- [ ] If failed: analyze WHY proactive monitoring didn't work
- [ ] If partial: identify which layer worked, which didn't

---

## 📜 TIMELINE (chronological, oldest first)

### 📅 2025-10-10: Initial Report

**Client Report (Joshua):**
> After the battery restart, I went to the Bluetooth screen and
> tried to reconnect but now I'm getting "invalid" when clicking
> on the battery 855.

**Diagnostic Logs:**
- Before restart: `docs/fix-history/logs/bigbattery_logs_20251010_153756.json`
- After restart: `docs/fix-history/logs/bigbattery_logs_20251010_153942.json`
- Timestamp: 15:37-15:39 10.10.2025

**Initial Symptoms:**
- ✅ Battery connected successfully before restart
- ✅ Protocols saved successfully (ID 1, P02-LUX, P06-LUX)
- ❌ After battery restart: "Invalid BigBattery device" error
- ❌ Voltage = 0, no battery data
- ⚠️ PHANTOM connection detected in logs

**Evidence from Logs:**
```
[Before restart - 15:37:56]
"peripheralName": "BB-51.2V100Ah-0855"
"peripheralIdentifier": "1997B63E-02F2-BB1F-C0DE-63B68D347427"
"rs485Protocol": "P02-LUX"
"canProtocol": "P06-LUX"

[After restart - 15:39:42]
// NO peripheralName!
// NO peripheralIdentifier!
"rs485Protocol": "--"
"canProtocol": "--"
"recentLogs": [
  "[15:39:25] [CONNECTION] ⚠️ PHANTOM: No peripheral but BMS timer running!",
  "[15:39:25] [CONNECTION] Cleaning connection state"
]
```

**Initial Root Cause:**
Stale peripheral references in `scannedPeripherals` array not cleared after battery disconnect.

**Initial Fix (Oct 10):**
Added `cleanScanning()` call in `cleanConnection()` method to clear stale peripherals.

**Related Documentation:**
- `docs/fix-history/2025-10-10_reconnection-after-restart-bug.md`

---

### 📅 2025-10-20: ATTEMPT #1 - Global Disconnect Handler

**Client Report (Joshua):**
> Connected to battery
> - ID stayed at 1
> - changed both protocols from GRW → LUX
> - saved changes
> - disconnected & restarted battery (turned off & turned back on)
> - **invalid connection error when I click on battery in Bluetooth**

**Diagnostic Logs:**
- File: `docs/fix-history/logs/bigbattery_logs_20251020_091648.json`
- Timestamp: 09:16:34-09:16:41 20.10.2025

**Hypothesis:**
The Oct 10 fix added `cleanScanning()` to `cleanConnection()`, but `cleanConnection()` was only called when disconnect was detected. The problem: `observeDisconect()` subscription in ConnectivityViewController was tied to ViewController lifecycle and cancelled in `viewWillDisappear`. When battery disconnected while user was on different screen (Settings), disconnect event was NOT detected, so `cleanConnection()` was never called.

**Solution Implemented:**
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

**Expected Improvement:**
- ✅ Disconnect detected from ANY screen (not just ConnectivityVC)
- ✅ `cleanConnection()` called IMMEDIATELY when battery disconnects
- ✅ Stale peripherals cleared before user returns to Bluetooth screen
- ✅ Fresh scan obtains new peripheral instance
- ✅ No "BluetoothError error 4"

**Expected Log Sequence:**
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

**Files Modified:**
- `Zetara/Sources/ZetaraManager.swift` (lines 108-122)
- `BatteryMonitorBL/ConnectivityViewController.swift` (lines 95-112)
- `docs/fix-history/logs/bigbattery_logs_20251020_091648.json` (copied)

**Commit:**
- `6e4f177`: "fix: Fix 'Invalid Device' error after battery restart (observeDisconect lifecycle issue)"
- `09081a9`: "docs: Add fix-history and common-issues documentation for lifecycle issue"

**Test Result:** ❌ FAILED

**Related Documentation:**
- `docs/fix-history/2025-10-20_invalid-device-after-restart-regression.md`
- `docs/common-issues-and-solutions.md` (Problem 5, lines 893-1142)

---

### 📅 2025-10-21: ATTEMPT #1 RESULT - Test Failed

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

### 📅 2025-10-21: ATTEMPT #2 - Proactive State Monitoring (3 Layers)

**New Hypothesis:**
Need **PROACTIVE monitoring**, not reactive (waiting for events). Check `peripheral.state` actively instead of waiting for iOS disconnect events.

**Solution Implementing:**

**Layer 1: viewWillAppear State Check** (`ConnectivityViewController.swift`)
- Check `peripheral.state` every time user returns to Connectivity screen
- If `peripheral.state != .connected` → force cleanup
- Log all state checks for diagnostics

**Layer 2: Pre-Flight Check** (`ZetaraManager.connect()`)
- Check `peripheral.state` BEFORE attempting connection
- Log WARNING if state is .disconnected or .disconnecting
- Helps diagnose stale peripheral attempts in logs

**Layer 3: Periodic Health Monitor** (`ZetaraManager.init()`)
- Active monitoring every 3 seconds
- Check `peripheral.state` of connected peripheral
- If `state != .connected` → trigger cleanup
- Log health checks every 30 seconds

**Expected Improvement:**
- ✅ Detect disconnect within 3 seconds (Layer 3 periodic check)
- ✅ Catch stale peripherals on screen return (Layer 1)
- ✅ Diagnose stale connection attempts (Layer 2 logging)
- ✅ Multi-layer defense (if one fails, others catch it)
- ✅ No dependency on iOS disconnect events

**Expected Log Sequence:**
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

**Files Modified:**
- `BatteryMonitorBL/ConnectivityViewController.swift` (added viewWillAppear lines 116-142)
- `Zetara/Sources/ZetaraManager.swift` (added pre-flight check lines 220-229, health monitor lines 124-150)

**Test Result:** ⏳ PENDING (waiting for Joshua testing)

---

## 🔍 ROOT CAUSE EVOLUTION

### Initial Understanding (2025-10-10):
**Problem:** Stale peripheral references in `scannedPeripherals` array.
**Solution:** Call `cleanScanning()` in `cleanConnection()`.
**Assumption:** `cleanConnection()` gets called when disconnect happens.

### Updated Understanding (2025-10-20):
**Problem:** `cleanConnection()` not called because `observeDisconect()` subscription cancelled by ViewController lifecycle.
**Solution:** Move disconnect handler to global scope (ZetaraManager singleton).
**Assumption:** iOS generates disconnect events that our handler will catch.

### Current Understanding (2025-10-21):
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

## 📊 METRICS

| Metric | Before Any Fix | After Attempt #1 | After Attempt #2 | Target |
|--------|----------------|------------------|------------------|--------|
| Successful reconnect after restart | 0% | 0% ❌ | ⏳ | 100% |
| Disconnect detected immediately | No | No ❌ | ⏳ | Yes (< 5s) |
| [DISCONNECT] events in logs | No | No ❌ | ⏳ | Yes (or [HEALTH]) |
| "BluetoothError error 4" frequency | 100% (every attempt) | 100% ❌ | ⏳ | 0% |
| Time to detect disconnect | N/A | Never | ⏳ | < 5s |
| Stale peripherals cleared | No | No ❌ | ⏳ | Yes |
| App shows correct state | No ("still connected") | No ❌ | ⏳ | Yes |

**Key Performance Indicators:**
- ✅ SUCCESS if: All 3 test scenarios pass, no error 4, disconnect < 5s
- 🔄 PARTIAL if: Some scenarios pass, improved but not 100%
- ❌ FAILED if: No improvement, same error pattern

---

## 🎯 SUCCESS CRITERIA

Thread can be marked 🟢 RESOLVED when:
- [ ] **All 3 test scenarios pass** (Joshua confirmation)
  - [ ] Scenario 1: Change protocols → Restart → Reconnect successfully
  - [ ] Scenario 2: Disconnect while on different screen → Screen shows cleared state
  - [ ] Scenario 3: Quick reconnect → Works immediately
- [ ] **Disconnect detected within 5 seconds** of physical power off
- [ ] **NO "BluetoothError error 4" errors** in diagnostic logs
- [ ] **Logs show proactive detection** ([HEALTH] or [CONNECTIVITY] state check messages)
- [ ] **Successful reconnection rate > 95%** over 1 week of testing
- [ ] **NO regressions** in other features (BMS data loading, protocol saving, etc.)

Thread can be marked ⚫ CLOSED when:
- [ ] RESOLVED criteria met for 2+ weeks
- [ ] No recurrence reported by client
- [ ] Metrics remain stable

---

## 📚 RELATED DOCUMENTATION

**Fix History:**
- `docs/fix-history/2025-10-10_reconnection-after-restart-bug.md` - Initial stale peripherals fix
- `docs/fix-history/2025-10-20_invalid-device-after-restart-regression.md` - Global disconnect handler attempt
- `docs/fix-history/2025-10-21_proactive-monitoring-fix.md` - **TO BE CREATED** after Attempt #2 results

**Common Issues:**
- Section 4: Bluetooth Connection Issues
  - Problem 3: Stale Peripheral References (lines 572-699)
  - Problem 5: "Invalid Device" After Restart (Lifecycle Issue) (lines 893-1142)

**Apple Documentation:**
- [Core Bluetooth Best Practices](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/BestPracticesForInteractingWithARemotePeripheralDevice/BestPracticesForInteractingWithARemotePeripheralDevice.html)
- [CBPeripheral State Documentation](https://developer.apple.com/documentation/corebluetooth/cbperipheralstate)

**External Resources:**
- [Stack Overflow: CoreBluetooth doesn't discover services on reconnect](https://stackoverflow.com/questions/28285393/corebluetooth-doesnt-discover-services-on-reconnect)
- [RxBluetoothKit Issue #298](https://github.com/Polidea/RxBluetoothKit/issues/298)

---

## 💡 LESSONS LEARNED

### 1. Don't Rely on iOS Disconnect Events for Physical Power Off
**What we learned:** iOS CoreBluetooth disconnect events are NOT reliable for physical disconnect scenarios. They work for graceful disconnects but NOT for sudden power loss.

**Impact:** Future BLE implementations should use PROACTIVE state monitoring, not reactive event listening. Always check `peripheral.state` actively.

**Prevention:** Add health monitoring from DAY 1, don't wait for bugs to appear.

### 2. Multi-Layer Defense Strategy
**What we learned:** Single point of failure is risky. If iOS doesn't fire event, entire disconnect detection fails.

**Impact:** Implement defense in depth:
- Layer 1: UI-level checks (viewWillAppear)
- Layer 2: Business logic checks (pre-flight in connect())
- Layer 3: Background monitoring (periodic health checks)

**Prevention:** For critical functionality (connection state), always have backup detection mechanisms.

### 3. Test with REAL Scenarios, Not Simulated
**What we learned:** Simulator and manual `cancelPeripheralConnection()` generate events. Physical power off does NOT. Testing must match real-world usage.

**Impact:** Always test:
- ✅ Physical battery power off
- ✅ User navigating between screens
- ✅ Delayed scenarios (30s gaps)
- ❌ Don't rely only on simulator testing

### 4. Reactive vs Proactive Patterns
**What we learned:** Reactive patterns (`.subscribe(onNext:)`) assume events will fire. When they don't, entire system fails silently.

**Impact:** For critical state (connection), combine reactive + proactive:
- Reactive: Handle events when they DO fire (efficiency)
- Proactive: Poll/check when events might NOT fire (reliability)

### 5. Documentation of Assumptions
**What we learned:** Our fix documentation said "Global handler will catch disconnect" but didn't document the ASSUMPTION "iOS will fire disconnect event." When assumption was wrong, fix failed.

**Impact:** Always document:
- ✅ What we're fixing
- ✅ **What we're ASSUMING** (critical!)
- ✅ What could go wrong if assumption is false

### 6. Thread System Value
**What we learned:** This thread system ITSELF is a lesson learned! We would have repeated the same "wait for events" mistake if we hadn't tracked the full history.

**Impact:** Thread system shows:
- Failed attempts teach us what NOT to do
- Evolution of understanding is valuable
- Context prevents repeating mistakes

---

## 🔗 RELATED THREADS

None yet. This is the first thread in the system.

---

## 📝 NOTES

**Apple Best Practices Limitations:**
Apple's CoreBluetooth best practices assume graceful disconnects (app calls cancel, peripheral sends disconnect command). They don't adequately cover physical power loss scenarios, which are common in IoT/battery applications.

**BigBattery Firmware Behavior:**
- Battery restarts automatically after protocol settings change (firmware requirement)
- User must physically power cycle battery
- No graceful disconnect signal sent to app
- This is common in industrial/battery equipment (power loss is normal operation mode)

**CBPeripheralState Values:**
- 0 = .disconnected
- 1 = .connecting
- 2 = .connected
- 3 = .disconnecting

**Testing Environment:**
- iOS 26.0 (from logs)
- Build 28
- BigBattery ETHOS module: BB-51.2V100Ah-0855
- UUID: 1997B63E-02F2-BB1F-C0DE-63B68D347427

---

**Last Updated By:** Claude Code
**Last Updated Date:** 2025-10-21
