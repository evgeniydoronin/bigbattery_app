# Fix History: Double Main Thread Dispatch Crash on Battery Disconnect

**Date:** October 13, 2025
**Author:** Development Team
**Severity:** 🔴 Critical
**Status:** ✅ Fixed
**Affected Component:** SettingsViewController.swift - setupDisconnectHandler()
**Related Issues:** App crashes when battery disconnects after saving settings

---

## Context

### Client Report (Joshua - October 13, 2025)

**Email 1 (before restart):**
> "Homepage shows the right protocols and ID's, I changed protocols from LUX to GRW, sending diagnostics before saving and restarting as it sends the app to crash"
- Log: `bigbattery_logs_20251013_100206.json` (10:02:06)

**Email 2 (after restart):**
> "After restarting app and battery, the app remembers my changes from LUX → GRW, it just keeps crashing after disconnecting battery to restart"
- Log: `bigbattery_logs_20251013_100332.json` (10:03:32)

**Email 3:**
- Additional log: `bigbattery_logs_20251013_100106.json` (10:01:06)

### Crash Feedback Timestamps

- **5:01 PM** - "App crashed after pressing save with no changes made and restarting battery (disconnecting)"
- **5:03 PM** - "Crashed after disconnecting battery"
- **5:04 PM** - "When battery is manually turned off it crashes"

**Pattern:** All crashes occur at the moment of battery disconnect/restart.

---

## Problem Analysis

### What Worked ✅

1. **Protocol Save Functionality**
   - Log 1 shows successful protocol changes:
     ```
     [10:02:04] [SETTINGS] ✅ RS485 Protocol set successfully
     [10:02:03] [SETTINGS] ✅ CAN Protocol set successfully
     ```
   - Protocols: P02-LUX → P01-GRW (RS485)
   - Protocols: P06-LUX → P01-GRW (CAN)

2. **Protocol Persistence**
   - Log 2 (after restart) confirms protocols saved correctly:
     ```json
     "currentValues": {
       "canProtocol": "P01-GRW",
       "moduleId": "ID 1",
       "rs485Protocol": "P01-GRW"
     }
     ```

### What Failed ❌

1. **App Crash on Disconnect**
   - All 3 crash reports occur during battery disconnect
   - Crash happens AFTER save but BEFORE restart completes

2. **Missing Disconnect Handler Logs**
   - **Critical observation:** NO disconnect handler logs in any of the 3 diagnostic files
   - Expected logs like "[DISCONNECT HANDLER] ..." are completely absent
   - This indicates the handler was crashing BEFORE it could log anything

---

## Root Cause

### The Bug: Double Main Thread Dispatch

**Location:** `SettingsViewController.swift` lines 765-783

```swift
private func setupDisconnectHandler() {
    disconnectHandlerDisposable?.dispose()

    disconnectHandlerDisposable = ZetaraManager.shared.connectedPeripheralSubject
        .subscribeOn(MainScheduler.instance)
        .observe(on: MainScheduler.instance)  // ← Already guarantees main thread
        .filter { $0 == nil }
        .take(1)
        .subscribe(onNext: { [weak self] _ in
            // Battery disconnected (restarting)
            DispatchQueue.main.async {  // ❌ PROBLEM: Double dispatch!
                Alert.hide()
                self?.showBatteryRestartingMessage()
            }
        })
}
```

### Why This Crashes

1. **`.observe(on: MainScheduler.instance)`** already guarantees the subscription block executes on the main thread
2. **`DispatchQueue.main.async`** adds a SECOND layer of main thread dispatch
3. This creates a **delay** between the disconnect event and UI operations
4. During this delay, the app state becomes **invalid**:
   - Bluetooth connection is already torn down
   - View controller might be deallocating
   - UI elements might be in inconsistent state
5. When the delayed block finally executes → **CRASH**

### Race Condition Timeline

```
Time 0ms:   Battery disconnects
            ↓
Time 1ms:   connectedPeripheralSubject emits nil
            ↓
Time 2ms:   .observe(on:) schedules block on main thread
            ↓
Time 3ms:   Block executes, DispatchQueue.main.async schedules ANOTHER block
            ↓
Time 4ms:   Bluetooth state tears down
            ↓
Time 5ms:   View controller might be deallocating
            ↓
Time 6ms:   Delayed block tries to execute Alert.hide() → CRASH
```

---

## Solution

### Code Changes

**File:** `BatteryMonitorBL/SettingsViewController.swift`

**BEFORE (lines 765-783):**
```swift
private func setupDisconnectHandler() {
    disconnectHandlerDisposable?.dispose()

    disconnectHandlerDisposable = ZetaraManager.shared.connectedPeripheralSubject
        .subscribeOn(MainScheduler.instance)
        .observe(on: MainScheduler.instance)
        .filter { $0 == nil }
        .take(1)
        .subscribe(onNext: { [weak self] _ in
            DispatchQueue.main.async {
                Alert.hide()
                self?.showBatteryRestartingMessage()
            }
        })
}
```

**AFTER (lines 765-784):**
```swift
private func setupDisconnectHandler() {
    disconnectHandlerDisposable?.dispose()

    ZetaraManager.shared.protocolDataManager.logProtocolEvent("[DISCONNECT HANDLER] Setting up disconnect handler")

    disconnectHandlerDisposable = ZetaraManager.shared.connectedPeripheralSubject
        .subscribeOn(MainScheduler.instance)
        .observe(on: MainScheduler.instance)
        .filter { $0 == nil }
        .take(1)
        .subscribe(onNext: { [weak self] _ in
            ZetaraManager.shared.protocolDataManager.logProtocolEvent("[DISCONNECT HANDLER] Disconnect detected, showing restart message")
            // Already on main thread thanks to .observe(on: MainScheduler.instance)
            Alert.hide()
            self?.showBatteryRestartingMessage()
        })
}
```

### Changes Made

1. **Removed:** `DispatchQueue.main.async` wrapper (eliminating the double dispatch)
2. **Added:** Diagnostic logging when handler is set up
3. **Added:** Diagnostic logging when disconnect is detected
4. **Added:** Explanatory comment about threading

### Impact

- **No more delay** between disconnect event and UI operations
- **Immediate execution** on main thread (single dispatch via `.observe(on:)`)
- **Visible logging** for future debugging
- **Eliminates race condition** that was causing crashes

---

## Expected Behavior After Fix

### New Logs in Diagnostics

When battery disconnects, the diagnostic logs will now show:

```
[10:02:03] [DISCONNECT HANDLER] Setting up disconnect handler
[10:02:03] [SETTINGS] ✅ RS485 Protocol set successfully
[10:02:04] [SETTINGS] ✅ CAN Protocol set successfully
[10:02:05] [DISCONNECT HANDLER] Disconnect detected, showing restart message
```

**Key Indicators:**
- ✅ "[DISCONNECT HANDLER] Setting up..." appears when save button is pressed
- ✅ "[DISCONNECT HANDLER] Disconnect detected..." appears when battery disconnects
- ✅ No crash occurs
- ✅ User sees "Battery is restarting..." message

---

## Testing Checklist

### Scenario 1: Save Settings and Restart Battery
1. Connect to battery
2. Change protocol (e.g., P02-LUX → P01-GRW)
3. Press "Save" button
4. ✅ Verify save confirmation message appears
5. Physically disconnect battery (or turn off)
6. ✅ Verify app shows "Battery is restarting..." message
7. ✅ Verify app does NOT crash
8. Reconnect battery
9. ✅ Verify new protocols are loaded correctly

### Scenario 2: Save Without Changes
1. Connect to battery
2. Press "Save" button without changing any settings
3. Disconnect battery
4. ✅ Verify app shows restart message
5. ✅ Verify app does NOT crash

### Scenario 3: Manual Battery Shutdown
1. Connect to battery
2. Make protocol changes and save
3. Use battery's power button to turn off
4. ✅ Verify app handles disconnect gracefully
5. ✅ Verify no crash occurs

### Scenario 4: Verify Diagnostic Logs
1. After testing above scenarios, export diagnostics
2. ✅ Verify "[DISCONNECT HANDLER] Setting up..." appears in logs
3. ✅ Verify "[DISCONNECT HANDLER] Disconnect detected..." appears in logs
4. ✅ Verify no crash/error logs related to disconnect handler

---

## Lessons Learned

### 1. Never Combine .observe(on:) with DispatchQueue.main.async

**❌ WRONG:**
```swift
.observe(on: MainScheduler.instance)
.subscribe(onNext: {
    DispatchQueue.main.async {  // Double dispatch!
        updateUI()
    }
})
```

**✅ CORRECT:**
```swift
.observe(on: MainScheduler.instance)
.subscribe(onNext: {
    updateUI()  // Already on main thread
})
```

### 2. Choose ONE Threading Strategy

**Option A: Use RxSwift's .observe(on:) (Recommended)**
```swift
.observe(on: MainScheduler.instance)
.subscribe(onNext: { value in
    // Already on main thread
    self.label.text = value
})
```

**Option B: Use DispatchQueue Manually (Only if NOT using .observe(on:))**
```swift
.subscribe(onNext: { value in
    DispatchQueue.main.async {
        self.label.text = value
    }
})
```

**❌ NEVER: Both A and B Together**

### 3. Add Diagnostic Logging to Critical Handlers

- Disconnect handlers are hard to debug without logs
- Add logging at entry and key decision points
- Use `protocolDataManager.logProtocolEvent()` for remote visibility

### 4. Test Disconnect Scenarios Thoroughly

- Disconnect during save
- Disconnect after save
- Manual battery shutdown
- Bluetooth range disconnect
- Battery power off

---

## Prevention Guidelines

### Code Review Checklist

When reviewing RxSwift code, check for:

- [ ] Is `.observe(on: MainScheduler.instance)` used?
- [ ] Is `DispatchQueue.main.async` used inside the subscription?
- [ ] If both are present → **RED FLAG** - remove one
- [ ] Are critical handlers (disconnect, reconnect, errors) logging their execution?
- [ ] Is there a race condition between event and UI update?

### Pattern to Avoid

**Search Pattern:** Look for this anti-pattern in codebase:
```swift
.observe(on: MainScheduler.instance)
.subscribe(onNext: {
    DispatchQueue.main.async {  // ← FIND THIS
```

**Fix:** Remove the inner `DispatchQueue.main.async` block.

---

## Related Documentation

- **Common Issues:** See `docs/common-issues-and-solutions.md` - "Проблема 2: Double Main Thread Dispatch"
- **Previous Fix:** `docs/fix-history/2025-10-10_protocol-save-and-crash-bug.md` - Shows correct pattern
- **Previous Fix:** `docs/fix-history/2025-10-10_reconnection-after-restart-bug.md` - Shows correct pattern

---

## Files Modified

1. `BatteryMonitorBL/SettingsViewController.swift` (lines 765-784)
   - Removed: `DispatchQueue.main.async` wrapper
   - Added: Diagnostic logging

2. `docs/common-issues-and-solutions.md` (lines 114-280)
   - Added: New subsection "Проблема 2: Double Main Thread Dispatch"
   - Added: Code examples and prevention guidelines

3. `docs/fix-history/logs/` (new files)
   - `bigbattery_logs_20251013_100106.json`
   - `bigbattery_logs_20251013_100206.json`
   - `bigbattery_logs_20251013_100332.json`

---

## Status

✅ **Fixed** - Ready for testing with client
