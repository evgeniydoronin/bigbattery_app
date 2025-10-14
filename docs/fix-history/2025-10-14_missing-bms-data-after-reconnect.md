# Fix History: Missing BMS Data After Reconnect (Insufficient Diagnostic Logging)

**Date:** October 14, 2025
**Author:** Development Team
**Severity:** 🟡 Medium
**Status:** ✅ Fixed
**Affected Component:** ZetaraManager.swift - getBMSData(), startRefreshBMSData()
**Related Issues:** No BMS data displayed after reconnecting to battery, diagnostic logs insufficient for remote debugging

---

## Context

### Client Report (Joshua - October 14, 2025)

**Email 1 (09:38:58):**
> "After saving changes from Protocols from GRW -> LUX, keeping the same ID at 1. I saved changes and disconnected battery, the app does not display active status but still shows connected status on settings page and battery name on home page. Must restart app in order to see changes made, sending log"
- Log: `bigbattery_logs_20251014_093858.json` (09:38:58)

**Email 2 (09:41:18):**
> "After connecting to battery, all battery info on homepage is not showing after 20 seconds"
- Log: `bigbattery_logs_20251014_094118.json` (09:41:18)

**Pattern:** Protocols load successfully after reconnect, BUT battery data (voltage, SOC, cell voltages) remains zeros.

---

## Problem Analysis

### What Worked ✅

1. **Protocol Loading**
   - Log 1 shows protocols being set:
     ```
     [09:38:44] [SETTINGS] ✅ RS485 Protocol set successfully
     [09:38:43] [SETTINGS] ✅ CAN Protocol set successfully
     ```
   - Protocols: P01-GRW → P02-LUX (RS485)
   - Protocols: P01-GRW → P06-LUX (CAN)

2. **Connection Established**
   - Log 2 (after reconnect) shows successful connection:
     ```json
     "bluetoothInfo": {
       "state": "poweredOn",
       "peripheralName": "BB-51.2V100Ah-0855",
       "peripheralIdentifier": "1997B63E-02F2-BB1F-C0DE-63B68D347427"
     }
     ```

3. **Protocols Loaded After Reconnect**
   - Log 2 shows protocols loaded (though they're OLD values - separate issue):
     ```
     [09:40:49] [PROTOCOL MANAGER] ✅ CAN loaded: P01-GRW
     [09:40:48] [PROTOCOL MANAGER] ✅ RS485 loaded: P01-GRW
     ```

### What Failed ❌

1. **NO BMS Data After Reconnect**
   - Log 2 shows ALL battery data = zeros:
     ```json
     "batteryInfo": {
       "voltage": 0,
       "soc": 0,
       "cellVoltages": [],
       "cellCount": 0,
       "status": "Standby"
     }
     ```

2. **No BMS Data Stream Visible**
   - 29 seconds elapsed since connection (09:41:18 - 09:40:49)
   - BMS timer interval = 5 seconds
   - Should have 5-6 BMS requests in logs
   - **ZERO BMS requests visible in diagnostic logs**

3. **Insufficient Diagnostic Logging**
   - `getBMSData()` uses only `print()` statements (visible only in Xcode console)
   - Impossible to diagnose remotely:
     - Is BMS timer starting?
     - Is `getBMSData()` being called?
     - Is BMS request being sent?
     - Is battery responding?
     - Is CRC validation failing?
     - Is parsing failing?

---

## Root Cause

### The Problem: Console-Only Logging in Critical BMS Flow

**Location:** `Zetara/Sources/ZetaraManager.swift`

**BEFORE:**
```swift
func getBMSData() -> Maybe<Data.BMS> {
    print("!!! МЕТОД getBMSData() ВЫЗВАН !!!")  // ❌ Only in Xcode console

    // ...

    let data = Foundation.Data.getBMSData
    print("getting bms data write data: \(data.toHexString())")  // ❌ Only in Xcode console

    return Maybe.create { observer in
        peripheral.observeValueUpdateAndSetNotification(for: notifyCharacteristic)
            .compactMap { $0.value }
            .do { print("recevie bms data: \($0.toHexString())") }  // ❌ Only in Xcode console
            // ...
    }
}
```

### Why This Is a Problem

1. **Client Has No Xcode Access**
   - Client can't see console output
   - `print()` statements not captured in diagnostic exports
   - Remote debugging impossible

2. **Unknown Failure Point**
   - Without logs, can't determine:
     - ✅ Timer started?
     - ✅ getBMSData() called?
     - ✅ Device connected?
     - ❌ BMS request sent?
     - ❌ Response received?
     - ❌ CRC valid?
     - ❌ Parse successful?

3. **Unable to Diagnose Root Cause**
   - Log shows connection established ✅
   - Log shows protocols loaded ✅
   - Log shows battery data = zeros ❌
   - **Can't determine WHY data is zeros**

---

## Solution

### Code Changes

**File:** `Zetara/Sources/ZetaraManager.swift`

#### Change 1: Add Logging to startRefreshBMSData() (line 506)

**BEFORE:**
```swift
func startRefreshBMSData() {
    self.timer = Timer.scheduledTimer(withTimeInterval: Self.configuration.refreshBMSTimeInterval, repeats: true) { [weak self] _ in
        // ...
    }
}
```

**AFTER:**
```swift
func startRefreshBMSData() {
    protocolDataManager.logProtocolEvent("[BMS] 🚀 Starting BMS data refresh timer (interval: \(Self.configuration.refreshBMSTimeInterval)s)")
    print("[BMS] 🚀 Starting BMS data refresh timer (interval: \(Self.configuration.refreshBMSTimeInterval)s)")

    self.timer = Timer.scheduledTimer(withTimeInterval: Self.configuration.refreshBMSTimeInterval, repeats: true) { [weak self] _ in
        // ...
    }
}
```

#### Change 2: Add Comprehensive Logging to getBMSData()

**10 Logging Points Added:**

1. **Method Entry (line 541):**
```swift
protocolDataManager.logProtocolEvent("[BMS] 📡 getBMSData() called")
```

2. **Device Connection Status (line 548):**
```swift
protocolDataManager.logProtocolEvent("[BMS] Device connected: \(isDeviceConnected)")
```

3. **Mock Data Path (line 552):**
```swift
protocolDataManager.logProtocolEvent("[BMS] 🧪 Using mock data (no device connected)")
```

4. **No Peripheral Error (line 602):**
```swift
protocolDataManager.logProtocolEvent("[BMS] ❌ No peripheral/characteristics available")
```

5. **Using Real Device (line 609):**
```swift
protocolDataManager.logProtocolEvent("[BMS] ✅ Using real device data")
```

6. **Writing BMS Request (line 616):**
```swift
protocolDataManager.logProtocolEvent("[BMS] 📤 Writing BMS request: \(data.toHexString())")
```

7. **Receiving BMS Response (line 626):**
```swift
.do { [weak self] data in
    self?.protocolDataManager.logProtocolEvent("[BMS] 📥 Received BMS response: \(data.toHexString())")
}
```

8. **CRC and Validation (line 633):**
```swift
.filter { [weak self] bytes in
    let crcValid = bytes.crc16Verify()
    let isBMS = Data.BMS.isBMSData(bytes)
    self?.protocolDataManager.logProtocolEvent("[BMS] Validation - CRC: \(crcValid), isBMSData: \(isBMS)")
    return crcValid && isBMS
}
```

9-10. **Parse Success/Failure (lines 639, 641):**
```swift
.compactMap { [weak self] _bytes in
    let result = self?.bmsDataHandler.append(_bytes)
    if result != nil {
        self?.protocolDataManager.logProtocolEvent("[BMS] ✅ BMS data parsed successfully")
    } else {
        self?.protocolDataManager.logProtocolEvent("[BMS] ⚠️ Failed to parse BMS data")
    }
    return result
}
```

### Impact

- **Remote Debugging Enabled:** All BMS flow now visible in diagnostic exports
- **Pinpoint Failure:** Can identify exact step where BMS data flow fails
- **Future Issues:** Faster diagnosis and resolution
- **No Performance Impact:** Logging is lightweight

---

## Expected Behavior After Fix

### New Logs in Diagnostics

When BMS timer is running normally, diagnostic logs will show:

```
[09:40:49] [CONNECTION] ✅ Characteristics configured
[09:40:49] [BMS] 🚀 Starting BMS data refresh timer (interval: 5s)
[09:40:49] [BMS] 📡 getBMSData() called
[09:40:49] [BMS] Device connected: true
[09:40:49] [BMS] ✅ Using real device data
[09:40:49] [BMS] 📤 Writing BMS request: dd05000000ff2c77
[09:40:49] [BMS] 📥 Received BMS response: dd03002d0a1bc80c6b...
[09:40:49] [BMS] Validation - CRC: true, isBMSData: true
[09:40:49] [BMS] ✅ BMS data parsed successfully
[09:40:54] [BMS] 📡 getBMSData() called
[09:40:54] [BMS] Device connected: true
[09:40:54] [BMS] ✅ Using real device data
... (repeats every 5 seconds)
```

**Key Indicators:**
- ✅ "[BMS] 🚀 Starting BMS data refresh timer" appears once after connection
- ✅ "[BMS] 📡 getBMSData() called" appears every 5 seconds
- ✅ "[BMS] 📤 Writing BMS request" appears every 5 seconds
- ✅ "[BMS] 📥 Received BMS response" appears every 5 seconds
- ✅ "[BMS] ✅ BMS data parsed successfully" appears every 5 seconds

### When BMS Data Fails

If BMS data stops working, logs will show EXACTLY where:

**Scenario 1: Timer Not Starting**
```
[CONNECTION] ✅ Characteristics configured
// ❌ NO "[BMS] 🚀 Starting BMS data refresh timer"
```
**Diagnosis:** `startRefreshBMSData()` not being called

**Scenario 2: Timer Running But Not Calling getBMSData**
```
[BMS] 🚀 Starting BMS data refresh timer
// ❌ NO "[BMS] 📡 getBMSData() called"
```
**Diagnosis:** Timer created but not firing

**Scenario 3: Device Not Connected**
```
[BMS] 📡 getBMSData() called
[BMS] Device connected: false  // ❌ false!
[BMS] ❌ No peripheral/characteristics available
```
**Diagnosis:** Bluetooth state invalid

**Scenario 4: Battery Not Responding**
```
[BMS] 📤 Writing BMS request: dd05000000ff2c77
// ❌ NO "[BMS] 📥 Received BMS response"
(10 second timeout)
```
**Diagnosis:** Battery not responding to BMS requests

**Scenario 5: CRC Validation Failing**
```
[BMS] 📥 Received BMS response: dd03002d...
[BMS] Validation - CRC: false, isBMSData: true  // ❌ CRC false!
```
**Diagnosis:** Corrupted BMS data packets

**Scenario 6: Parse Failing**
```
[BMS] 📥 Received BMS response: dd03002d...
[BMS] Validation - CRC: true, isBMSData: true
[BMS] ⚠️ Failed to parse BMS data  // ❌ Parse failed!
```
**Diagnosis:** Protocol mismatch or malformed packet structure

---

## Testing Checklist

### Scenario 1: Normal BMS Data Flow
1. Connect to battery
2. Wait 30 seconds
3. ✅ Verify voltage/SOC/cell voltages appear on homepage
4. Export diagnostics
5. ✅ Verify "[BMS] 🚀 Starting BMS data refresh timer" appears once
6. ✅ Verify "[BMS] 📡 getBMSData() called" appears ~6 times (every 5s)
7. ✅ Verify "[BMS] ✅ BMS data parsed successfully" appears ~6 times

### Scenario 2: Reconnect After Protocol Save
1. Connect to battery
2. Change protocol (e.g., P01-GRW → P02-LUX)
3. Save settings
4. Disconnect battery (physically or auto-disconnect)
5. Reconnect battery
6. Wait 30 seconds
7. ✅ Verify battery data appears (not zeros)
8. Export diagnostics
9. ✅ Verify BMS request/response logs visible

### Scenario 3: Diagnose Missing BMS Data
1. Connect to battery
2. If battery data = zeros after 20 seconds
3. Export diagnostics
4. ✅ Use new logs to identify exact failure point:
   - Timer not starting?
   - getBMSData() not called?
   - Device not connected?
   - Battery not responding?
   - CRC failing?
   - Parse failing?

### Scenario 4: Mock Data Path
1. Disconnect from any battery
2. Open app (should use mock data if configured)
3. ✅ Verify "[BMS] 🧪 Using mock data" appears in logs
4. ✅ Verify mock battery data displays correctly

---

## Lessons Learned

### 1. Always Use protocolDataManager.logProtocolEvent() for Critical Operations

**❌ WRONG:**
```swift
func criticalBluetoothOperation() {
    print("Operation started")  // ❌ Only in Xcode console
    // ...
    print("Data sent: \(data)")  // ❌ Not in diagnostic exports
}
```

**✅ CORRECT:**
```swift
func criticalBluetoothOperation() {
    print("Operation started")  // ✅ Console for dev
    protocolDataManager.logProtocolEvent("[OPERATION] Started")  // ✅ Diagnostics for client

    // ...

    print("Data sent: \(data)")  // ✅ Console for dev
    protocolDataManager.logProtocolEvent("[OPERATION] 📤 Sent: \(data)")  // ✅ Diagnostics for client
}
```

### 2. Log ALL Key Steps in Critical Flows

For BMS data flow:
- ✅ Timer start
- ✅ Method entry
- ✅ Device connection check
- ✅ Request sent (with hex data)
- ✅ Response received (with hex data)
- ✅ Validation results
- ✅ Parse success/failure

### 3. Log Data in Hex Format for Debugging

```swift
// ❌ WRONG - not enough detail
protocolDataManager.logProtocolEvent("[BMS] Request sent")

// ✅ CORRECT - includes hex data
protocolDataManager.logProtocolEvent("[BMS] 📤 Writing BMS request: \(data.toHexString())")
```

### 4. Use Emojis for Quick Visual Parsing

- 🚀 Start/init operations
- 📡 Method calls
- 📤 Sending data
- 📥 Receiving data
- ✅ Success
- ❌ Errors
- ⚠️ Warnings
- 🧪 Mock data/testing

### 5. Test with Diagnostic Exports

- Don't assume console logs = diagnostic logs
- Always export diagnostics and verify new logs appear
- Test with client to ensure logs are useful

---

## Prevention Guidelines

### Code Review Checklist

When reviewing Bluetooth operations:

- [ ] Does method use BOTH `print()` AND `protocolDataManager.logProtocolEvent()`?
- [ ] Are ALL key steps logged (entry, send, receive, validate, parse)?
- [ ] Is data logged in hex format where applicable?
- [ ] Are success AND failure paths logged?
- [ ] Are validation results (CRC, isBMSData) logged?
- [ ] Can failure be diagnosed from logs alone (without Xcode)?

### Pattern to Follow

For ALL critical Bluetooth operations:

```swift
func criticalBluetoothOperation() -> Observable<Data> {
    // 1. Log entry
    print("[DEBUG] Operation started")
    protocolDataManager.logProtocolEvent("[OPERATION] Started")

    // 2. Log state/conditions
    let isConnected = checkConnection()
    protocolDataManager.logProtocolEvent("[OPERATION] Device connected: \(isConnected)")

    return Observable.create { observer in
        // 3. Log outgoing data
        let requestData = createRequest()
        print("[DEBUG] Sending: \(requestData.toHexString())")
        protocolDataManager.logProtocolEvent("[OPERATION] 📤 Sending: \(requestData.toHexString())")

        // 4. Log incoming data
        peripheral.observe()
            .do { data in
                print("[DEBUG] Received: \(data.toHexString())")
                self.protocolDataManager.logProtocolEvent("[OPERATION] 📥 Received: \(data.toHexString())")
            }
            // 5. Log validation
            .filter { [weak self] data in
                let valid = validate(data)
                self?.protocolDataManager.logProtocolEvent("[OPERATION] Validation: \(valid)")
                return valid
            }
            // 6. Log parse success/failure
            .compactMap { [weak self] data in
                let result = parse(data)
                if result != nil {
                    self?.protocolDataManager.logProtocolEvent("[OPERATION] ✅ Parse successful")
                } else {
                    self?.protocolDataManager.logProtocolEvent("[OPERATION] ⚠️ Parse failed")
                }
                return result
            }
            .subscribe(observer)
    }
}
```

### Areas to Apply This Pattern

1. **BMS Data Flow** ✅ (Fixed in this commit)
   - `getBMSData()`
   - `startRefreshBMSData()`

2. **Protocol Operations** ✅ (Already has logging)
   - `getModuleId()`, `getRS485()`, `getCAN()`
   - `setModuleId()`, `setRS485()`, `setCAN()`

3. **Connection Flow** ✅ (Already has logging)
   - `connect()`
   - `disconnect()`
   - `cleanConnection()`

4. **Other Areas to Review:**
   - Any method with `writeValue()` or `observeValueUpdate()`
   - Timer-based operations
   - Data parsing operations
   - Error handlers

---

## Related Documentation

- **Common Issues:** See `docs/common-issues-and-solutions.md` - "Проблема 4: Missing BMS Data After Reconnect"
- **START-HERE Workflow:** See `docs/START-HERE.md` - Demonstrates full workflow used for this fix

---

## Files Modified

1. `Zetara/Sources/ZetaraManager.swift`
   - Line 506-507: Added logging to `startRefreshBMSData()`
   - Lines 541, 548, 552, 602, 609, 616, 626, 633, 639, 641: Added comprehensive logging to `getBMSData()`
   - Total: 10 new logging points

2. `docs/common-issues-and-solutions.md`
   - Lines 701-890: Added new section "Проблема 4: Missing BMS Data After Reconnect"
   - Lines 1091-1092: Updated Quick Reference table
   - Line 1118: Updated "Последнее обновление" date to 2025-10-14

3. `docs/fix-history/logs/` (new files)
   - `bigbattery_logs_20251014_093858.json`
   - `bigbattery_logs_20251014_094118.json`

---

## Status

✅ **Fixed** - Ready for testing with client

---

## Next Steps

1. **Build and test** - Verify project compiles
2. **Test locally** - Connect to battery and verify new logs appear
3. **Deploy to client** - TestFlight build
4. **Request diagnostics** - After client tests, analyze new logs to diagnose original issue
5. **Follow-up fix** - Based on diagnostic logs, implement fix for WHY BMS data was zeros

**Note:** This fix adds diagnostic capability. The ROOT CAUSE of missing BMS data will be identified once we receive diagnostic logs with the new logging points.
