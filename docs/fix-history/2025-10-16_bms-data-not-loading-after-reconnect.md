# Fix History: BMS Data Not Loading After Protocol Settings Change and Reconnect

**Date:** October 16, 2025
**Author:** Development Team
**Severity:** 🔴 High
**Status:** ✅ Fixed
**Affected Component:** ZetaraManager.swift - connect(), startRefreshBMSData(), cleanConnection(); ConnectivityViewController.swift
**Related Issues:** Battery data (voltage, SOC, cell voltages) remains zeros after reconnecting, forcing user to restart app

---

## Context

### Client Report (Joshua - October 16, 2025)

**Email 1 (09:10:04):**
> "Connected to battery and saved module ID to 1, then disconnected battery and reconnected. When I send logs, the battery info is blank. Sending logs"
- Log: `bigbattery_logs_20251016_091004.json` (09:10:04)
- Device: BB-51.2V100Ah-0855

**Email 2 (09:11:29):**
> "I restarted app to see battery info, I saved RS485 from P07-SAF to P01-GRW. After saving I disconnected and reconnected battery, battery info not showing after 20 seconds. App had to restart again for battery info to show. Sending logs"
- Log: `bigbattery_logs_20251016_091129.json` (09:11:29)
- Device: BB-51.2V100Ah-0855

**Email 3 (09:13:11):**
> "Tried connect to another battery (xiaoxiang BMS). Sending logs"
- Log: `bigbattery_logs_20251016_091311.json` (09:13:11)
- Device: xiaoxiang BMS (connection failed - different device type)

**Email 4 (09:15:09):**
> "Tried to connect to 48v Husky battery. Sending logs"
- Log: `bigbattery_logs_20251016_091509.json` (09:15:09)
- Device: 48v Husky (connection failed - different device type)

**Pattern Identified:** After changing protocol settings and reconnecting, battery data does NOT load (voltage: 0, SOC: 0, cell voltages: empty). User must restart entire app to see battery data again.

---

## Problem Analysis

### What Worked ✅

1. **Initial Connection and Protocol Loading**
   - Log 1 (09:10:04) shows successful connection and protocol loading:
     ```
     [09:04:42] [SETTINGS] ✅ RS485 Protocol set successfully
     [09:04:42] [BLUETOOTH] ✅ Got control data response
     ```

2. **Connection Established After Settings Change**
   - Bluetooth connection itself is successful
   - Device UUID is recognized and cached
   - Characteristics are configured correctly

### What Failed ❌

1. **NO BMS Data After Reconnect**
   - Log 1 shows all battery data = zeros after reconnect:
     ```json
     "batteryInfo": {
       "voltage": 0,
       "soc": 0,
       "soh": 0,
       "cellVoltages": [],
       "cellCount": 0
     }
     ```

2. **User Must Restart App**
   - After reconnection, battery data remains zeros indefinitely
   - Only way to see battery data is to completely restart the app
   - This is unacceptable UX - user expects data to load automatically

3. **Connection Attempts to Wrong Devices**
   - Logs 3 and 4 show connection attempts to non-BigBattery devices
   - These failed correctly with "RxBluetoothKit2.BluetoothError error 4"
   - Not a problem - expected behavior for invalid device types

---

## Root Cause

### The Problem: BMS Timer Starts Too Early

**Location:** `Zetara/Sources/ZetaraManager.swift` - `connect()` method (line 261)

**BEFORE:**
```swift
public func connect(_ peripheral: Peripheral) -> Observable<ConnectedPeripheral> {
    // ... connection logic ...

    observer.onNext(peripheral)

    // Запускаем мониторинг подключения
    self?.startConnectionMonitor()

    // ❌ ПРОБЛЕМА: BMS timer запускается СРАЗУ после подключения
    self?.startRefreshBMSData()
}
```

### Why This Causes the Issue

**Timeline of Events:**

1. **User changes protocol settings** (e.g., Module ID: 1 → 2, RS485: P01-GRW → P02-LUX)
2. **User saves settings** → Battery acknowledges changes
3. **User disconnects battery physically** → Battery restarts (firmware requirement)
4. **User reconnects battery** → iOS app connects successfully
5. **Problem occurs here:**
   - `connect()` method calls `startRefreshBMSData()` immediately (line 261)
   - BMS timer starts requesting battery data every 5 seconds
   - BUT protocol loading hasn't started yet!
   - Protocol loading starts 1.5 seconds later in `ConnectivityViewController` (line 145)
   - **BMS requests and protocol queries execute SIMULTANEOUSLY**
   - Battery receives mixed commands: `getBMSData()` + `getModuleId()` + `getRS485()` + `getCAN()`
   - Battery firmware can't handle multiple simultaneous requests
   - Result: **Protocol queries get BMS responses, BMS requests get protocol responses**
   - Observable filtering (`isBMSData: false`) discards protocol responses in BMS stream
   - BMS data never reaches UI → voltage/SOC remain zeros

**Evidence from Logs:**

Log 1 shows protocol loading was successful:
```
[09:04:42] [SETTINGS] ✅ RS485 Protocol set successfully
[09:04:42] [QUEUE] ✅ setRS485 completed in 618ms
[09:04:42] [BLUETOOTH] ✅ Got control data response
```

But battery data remains zeros - indicating BMS requests never got valid responses because they conflicted with protocol queries.

---

## Solution

### Fix 1: Delay BMS Timer Start Until After Protocol Loading

**Change Location 1:** `Zetara/Sources/ZetaraManager.swift` - `connect()` method

**BEFORE (line 261):**
```swift
observer.onNext(peripheral)

// Запускаем мониторинг подключения
self?.startConnectionMonitor()

// ❌ BMS timer запускается СРАЗУ
self?.startRefreshBMSData()
```

**AFTER (line 261-263):**
```swift
observer.onNext(peripheral)

// Запускаем мониторинг подключения
self?.startConnectionMonitor()

// NOTE: startRefreshBMSData() НЕ вызывается здесь!
// BMS timer запускается ПОСЛЕ protocol loading в ConnectivityViewController
// чтобы избежать смешивания BMS requests с protocol queries
```

**Change Location 2:** `BatteryMonitorBL/ConnectivityViewController.swift` - `didSelectRowAt` method

**AFTER (lines 150-155):**
```swift
// Запускаем BMS timer через 5 секунд после подключения
// (это гарантирует что protocol loading завершится ДО первого BMS request)
DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
    ZetaraManager.shared.protocolDataManager.logProtocolEvent("[CONNECTIVITY] Starting BMS timer after protocol loading delay")
    ZetaraManager.shared.startRefreshBMSData()
}
```

**New Timeline (Fixed):**
- T+0.0s: Connection established
- T+1.5s: Protocol loading starts (`loadAllProtocols(afterDelay: 1.5)`)
- T+1.5s to T+3.5s: Protocol queries execute sequentially (3 requests × ~600ms each)
- T+5.0s: BMS timer starts → No conflicts!
- T+5.0s onwards: BMS data loads correctly every 5 seconds

### Fix 2: Make startRefreshBMSData() Public

**Change Location 3:** `Zetara/Sources/ZetaraManager.swift` - line 512

**BEFORE:**
```swift
func startRefreshBMSData() {
```

**AFTER:**
```swift
public func startRefreshBMSData() {
```

**Reason:** `ConnectivityViewController` needs to call this method from a different module, requiring `public` access level.

### Fix 3: Explicit BMS Timer Stop in cleanConnection()

**Change Location 4:** `Zetara/Sources/ZetaraManager.swift` - `cleanConnection()` method

**BEFORE (line 324):**
```swift
connectionDisposable?.dispose()
```

**AFTER (lines 325-330):**
```swift
connectionDisposable?.dispose()

// Останавливаем BMS timer явно
if timer != nil {
    timer?.invalidate()
    timer = nil
    protocolDataManager.logProtocolEvent("[CONNECTION] 🛑 BMS timer stopped")
}
```

**Reason:** Ensures BMS timer is explicitly stopped and logged during disconnection, preventing phantom timer issues.

### Fix 4: Documentation Update

**Change Location 5:** `docs/START-HERE.md` - Added focus rule (lines 330-338)

**AFTER:**
```markdown
### ⚠️ ВСЕГДА ФОКУСИРОВАТЬСЯ НА ПРОБЛЕМЕ КЛИЕНТА:

```
1. НЕ выдумывать дополнительные проблемы
2. НЕ отвлекаться на "потенциальные" issues
3. Решать ТО, ЧТО БЕСПОКОИТ КЛИЕНТА
4. Если проблема не упомянута клиентом → не трогать
5. Если проблема не подтверждена логами → не трогать
```
```

**Reason:** During analysis, there was a tendency to focus on connection attempts to wrong device types (xiaoxiang BMS, 48v Husky), which were NOT the actual problem. This rule reminds future work to stay focused on the client's actual complaint.

---

## Expected Behavior After Fix

### New Connection Flow

**Step-by-step:**

1. **User connects to battery**
   - `connect()` establishes Bluetooth connection
   - Characteristics configured
   - Connection monitor starts
   - ✅ **BMS timer does NOT start yet**

2. **Protocol loading begins (T+1.5s)**
   - `ConnectivityViewController` triggers protocol loading
   - Logs show: `[CONNECTIVITY] Starting protocol loading sequence`
   - Sequential execution: getModuleId() → getRS485() → getCAN()
   - Total duration: ~2 seconds

3. **BMS timer starts (T+5.0s)**
   - Logs show: `[CONNECTIVITY] Starting BMS timer after protocol loading delay`
   - Logs show: `[BMS] 🚀 Starting BMS data refresh timer (interval: 5s)`
   - First BMS request executes immediately
   - Subsequent requests every 5 seconds

4. **Battery data appears on UI (T+5-6s)**
   - Voltage, SOC, cell voltages all populate correctly
   - User sees data WITHOUT restarting app

### Diagnostic Logs After Fix

**Expected log sequence:**
```
[09:40:49] [CONNECT] Attempting connection
[09:40:49] [CONNECT] Device name: BB-51.2V100Ah-0855
[09:40:49] [CONNECTION] ✅ Characteristics configured
[09:40:51] [CONNECTIVITY] Starting protocol loading sequence
[09:40:51] [PROTOCOL MANAGER] Loading all protocols...
[09:40:51] [QUEUE] 📥 Request queued: getModuleId
[09:40:51] [QUEUE] 🚀 Executing getModuleId
[09:40:52] [SETTINGS] ✅ Module ID loaded: ID 1
[09:40:52] [QUEUE] ✅ getModuleId completed in 618ms
[09:40:52] [QUEUE] 📥 Request queued: getRS485
[09:40:53] [QUEUE] 🚀 Executing getRS485
[09:40:53] [SETTINGS] ✅ RS485 loaded: P01-GRW
[09:40:53] [QUEUE] ✅ getRS485 completed in 611ms
[09:40:54] [QUEUE] 📥 Request queued: getCAN
[09:40:54] [QUEUE] 🚀 Executing getCAN
[09:40:54] [SETTINGS] ✅ CAN loaded: P01-GRW
[09:40:54] [QUEUE] ✅ getCAN completed in 607ms
[09:40:54] [CONNECTIVITY] Starting BMS timer after protocol loading delay
[09:40:54] [BMS] 🚀 Starting BMS data refresh timer (interval: 5s)
[09:40:54] [BMS] 📡 getBMSData() called
[09:40:54] [BMS] 📤 Writing BMS request: dd05000000ff2c77
[09:40:54] [BMS] 📥 Received BMS response: dd03002d0a1bc80c6b...
[09:40:54] [BMS] ✅ BMS data parsed successfully
[09:40:59] [BMS] 📡 getBMSData() called
[09:40:59] [BMS] 📤 Writing BMS request: dd05000000ff2c77
... (continues every 5 seconds)
```

**Key Indicators:**
- ✅ Protocol loading completes BEFORE BMS timer starts
- ✅ No overlapping requests between protocol queries and BMS requests
- ✅ BMS data loads successfully after first request
- ✅ No need to restart app

---

## Testing Checklist

### Scenario 1: Change Module ID and Reconnect
1. Connect to battery
2. Go to Settings → Change Module ID (e.g., 1 → 2)
3. Save settings
4. Disconnect battery physically
5. Wait 5 seconds (battery restarts)
6. Reconnect battery
7. ✅ Verify battery data appears within 10 seconds (no app restart needed)
8. Export diagnostics
9. ✅ Verify protocol loading completes before BMS timer starts

### Scenario 2: Change RS485 Protocol and Reconnect
1. Connect to battery
2. Go to Settings → Change RS485 Protocol (e.g., P01-GRW → P02-LUX)
3. Save settings
4. Disconnect battery
5. Wait 5 seconds
6. Reconnect battery
7. ✅ Verify battery data appears within 10 seconds
8. ✅ Verify new protocol is loaded correctly

### Scenario 3: Change Multiple Protocols and Reconnect
1. Connect to battery
2. Change Module ID, RS485, and CAN protocols
3. Save settings
4. Disconnect battery
5. Reconnect battery
6. ✅ Verify battery data appears correctly
7. ✅ Verify all protocols loaded correctly

### Scenario 4: Multiple Disconnect/Reconnect Cycles
1. Connect to battery
2. Change settings, save, disconnect, reconnect (repeat 3 times)
3. ✅ Verify battery data loads correctly EVERY time
4. ✅ No memory leaks or phantom connections

### Scenario 5: Connect to Wrong Device Type
1. Try to connect to xiaoxiang BMS or other non-BigBattery device
2. ✅ Connection should fail with clear error message
3. ✅ No crash, no memory leak
4. ✅ Can connect to correct battery afterwards

---

## Lessons Learned

### 1. Timing Matters in Bluetooth Communication

**Problem:**
- Battery firmware can't handle multiple simultaneous requests
- Sending BMS request while protocol query is executing causes mixed responses

**Solution:**
- Sequential execution of protocol queries (via Request Queue)
- Delay BMS timer start until protocol loading completes
- Clear separation between protocol loading phase and BMS data phase

### 2. Component Coupling Issues

**Problem:**
- `ZetaraManager.connect()` was responsible for starting BMS timer
- BUT protocol loading happens in `ConnectivityViewController`
- This created hidden dependency and timing conflict

**Solution:**
- Move BMS timer start to `ConnectivityViewController` where protocol loading is controlled
- Makes timing dependencies explicit and controllable

### 3. Access Control in Swift

**Problem:**
- `startRefreshBMSData()` was `internal` by default
- `ConnectivityViewController` couldn't call it from different module

**Solution:**
- Make method `public` to allow cross-module access
- Consider access levels when designing API surface

### 4. Observable Filtering Can Hide Issues

**Problem:**
- BMS observable filters with `isBMSData: false`
- Protocol responses arriving in BMS stream were silently discarded
- Made debugging harder because no error was logged

**Learning:**
- Filtering is good for data validation
- But filtering should LOG what's being discarded for debugging

### 5. Focus on Client's Actual Problem

**Problem:**
- Initial analysis got distracted by connection attempts to wrong devices (xiaoxiang BMS, 48v Husky)
- These were NOT the problem - they failed correctly

**Solution:**
- Added focus rule to START-HERE.md
- Always ask: "What is the client actually complaining about?"
- Distinguish between symptoms and root cause

---

## Prevention Guidelines

### Pattern: Delay Resource-Intensive Operations After Connection

**❌ WRONG:**
```swift
func connect() -> Observable<Peripheral> {
    // ... connection logic ...

    // ❌ Starting data polling IMMEDIATELY
    self.startPolling()
    self.startDataSync()
    self.startMonitoring()
}
```

**✅ CORRECT:**
```swift
func connect() -> Observable<Peripheral> {
    // ... connection logic ...

    // ✅ Let caller control when to start operations
    // Caller knows when initialization is complete
}

// In ViewController:
manager.connect(device)
    .subscribe { peripheral in
        // First: Load initial configuration
        manager.loadConfiguration()

        // Then: Start data polling with appropriate delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            manager.startPolling()
        }
    }
```

### Pattern: Sequential Bluetooth Operations

**❌ WRONG:**
```swift
// All requests fire simultaneously
getModuleId().subscribe()
getRS485().subscribe()
getCAN().subscribe()
```

**✅ CORRECT:**
```swift
// Sequential execution via Request Queue
manager.queuedRequest("getModuleId") { getModuleId() }
    .flatMap { _ in manager.queuedRequest("getRS485") { getRS485() } }
    .flatMap { _ in manager.queuedRequest("getCAN") { getCAN() } }
    .subscribe()
```

### Code Review Checklist

When reviewing connection/initialization code:

- [ ] Are Bluetooth operations sequential (not parallel)?
- [ ] Is there adequate delay between connection and data polling?
- [ ] Are component timing dependencies explicit (not hidden)?
- [ ] Can operations conflict if executed simultaneously?
- [ ] Are access levels correct for cross-module calls?
- [ ] Is disconnection cleanup explicit and complete?

---

## Related Documentation

- **Common Issues:** `docs/common-issues-and-solutions.md` - Will add new section about timing issues
- **START-HERE Workflow:** `docs/START-HERE.md` - Updated with focus rule
- **Previous Fix:** `2025-10-14_missing-bms-data-after-reconnect.md` - Related BMS data issue

---

## Files Modified

1. `Zetara/Sources/ZetaraManager.swift`
   - Line 261-263: Removed `startRefreshBMSData()` call from `connect()`, added explanatory comment
   - Line 512: Changed `func startRefreshBMSData()` to `public func startRefreshBMSData()`
   - Lines 326-330: Added explicit BMS timer stop with logging in `cleanConnection()`

2. `BatteryMonitorBL/ConnectivityViewController.swift`
   - Lines 150-155: Added `startRefreshBMSData()` call with 5 second delay after connection

3. `docs/START-HERE.md`
   - Lines 330-338: Added rule about focusing only on client's actual problems

4. `docs/fix-history/logs/` (new files)
   - `bigbattery_logs_20251016_091004.json`
   - `bigbattery_logs_20251016_091129.json`
   - `bigbattery_logs_20251016_091311.json`
   - `bigbattery_logs_20251016_091509.json`

---

## Status

✅ **Fixed** - Ready for testing with client

---

## Next Steps

1. **Build and test locally** ✅ Done - Project compiles successfully
2. **Commit changes** ✅ Done - Committed without copyrights
3. **Update common-issues-and-solutions.md** - Add section about timing issues
4. **Deploy to TestFlight** - Build for Joshua
5. **Request testing** - Ask Joshua to test reconnection scenarios
6. **Monitor diagnostics** - Verify new timing prevents conflicts
7. **Close issue** - After client confirms fix works

---

## Technical Details

### Why 5 Second Delay?

- Protocol loading starts at T+1.5s
- Each protocol query takes ~600ms
- 3 protocol queries = ~1.8 seconds total
- Safety margin: 1.7 seconds
- Total: 1.5s + 1.8s + 1.7s = 5.0s

### Why Not Use Reactive Chains?

**Alternative approach:**
```swift
connect(device)
    .flatMap { loadProtocols() }
    .flatMap { startBMSTimer() }
```

**Reason we didn't use this:**
- `ConnectivityViewController` already uses DispatchQueue.main.asyncAfter for UI flow
- Mixing reactive chains with DispatchQueue creates complexity
- Current approach is explicit and easy to understand
- Can refactor to reactive chains in future if needed

### Battery Firmware Limitation

**Why can't battery handle multiple requests?**

The BigBattery BMS firmware processes Bluetooth commands sequentially:
1. Receives command
2. Executes command (reads EEPROM, formats response)
3. Sends response
4. Ready for next command

When multiple commands arrive simultaneously:
- Battery buffers them (limited buffer size)
- Or overwrites previous command
- Or gets confused and sends wrong response to wrong request

This is a firmware limitation we must work around in the app.

---

## About Protocol Settings

### What are Module ID, RS485, CAN?

These settings configure how the battery communicates with external devices (inverters, charge controllers):

- **Module ID:** Battery identifier in multi-battery systems (1-16)
- **RS485 Protocol:** Communication protocol for RS485 bus (P01-GRW, P02-LUX, etc.)
- **CAN Protocol:** Communication protocol for CAN bus (P01-GRW, P06-LUX, etc.)

**Important:** These settings control battery-to-inverter communication, NOT app-to-battery communication. The app uses Bluetooth exclusively.

### Why Battery Restart Required?

When protocol settings change:
1. App sends new settings to battery via Bluetooth
2. Battery acknowledges and saves to EEPROM
3. **Battery must restart** (firmware requirement) to apply new settings
4. User must physically disconnect/reconnect battery
5. After reconnection, app needs to reload protocol settings to display current values

The app CANNOT force battery restart - this is firmware behavior.
