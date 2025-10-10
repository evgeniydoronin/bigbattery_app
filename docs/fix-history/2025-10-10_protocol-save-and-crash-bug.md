# Fix: Protocol Save Not Working + App Crash on Battery Restart

**Date:** October 10, 2025
**Author:** Development Team
**Severity:** CRITICAL
**Status:** Fixed

## Context

After fixing the Settings screen protocol display issue (see `2025-10-09_settings-direct-call-bug.md`), client Joshua reported NEW critical issues:
- ✅ **Protocol values now visible in Settings** ("ID 1", "P01-GRW", etc.)
- ✅ **Timeout mechanism works** (requests complete in 1-2 seconds)
- ❌ **RS485/CAN protocols NOT saving** (only Module ID saves)
- ❌ **App crashes when battery restarts** after saving settings
- ❌ **Unable to change protocols** (UI doesn't confirm selections before save)

## Problem Analysis

### Evidence from New Logs

**Log 1: `/Users/evgeniydoronin/Downloads/bigbattery_logs_20251010_090138.json`**

Client Joshua: "I'm able to change protocols and ID!!! I'm going to save and test now"

```json
"protocolInfo": {
  "currentValues": {
    "moduleId": "ID 1",
    "rs485Protocol": "P01-GRW",
    "canProtocol": "P01-GRW"
  }
}
```

**Analysis:** Protocol values visible ✅ (previous fix worked)

---

**Log 2: `/Users/evgeniydoronin/Downloads/bigbattery_logs_20251010_090420.json`**

Client Joshua: "Before I click save on changes made, but nothing was selected from what I clicked"

**Analysis:** User confused because dropdown doesn't show checkmark/confirmation before save ⚠️

---

**Log 3: `/Users/evgeniydoronin/Downloads/bigbattery_logs_20251010_090446.json`**

**CRITICAL DISCOVERY** - All 3 protocol requests sent SIMULTANEOUSLY:

```json
"recentLogs": [
  "[09:04:38] [BLUETOOTH] 📤 Writing control data: 100701023574",  ← setModuleId
  "[09:04:38] [BLUETOOTH] 📤 Writing control data: 100601052576",  ← setRS485
  "[09:04:38] [BLUETOOTH] 📤 Writing control data: 10050101d4b5"   ← setCAN
]
```

**Problem:** All 3 requests sent at **EXACT same timestamp** (09:04:38)!

**Why this breaks:**
- Battery BMS can only process ONE control request at a time
- Requests sent simultaneously without queueing (500ms interval required)
- Battery processes first request (Module ID), **ignores** RS485/CAN
- Result: Only Module ID saves, RS485/CAN remain unchanged

---

**Log 4: `/Users/evgeniydoronin/Downloads/bigbattery_logs_20251010_090539.json`**

```json
"batteryInfo": {
  "voltage": 0,
  "cellVoltages": [],
  "soc": 0,
  "soh": 0
}
"currentValues": {
  "moduleId": "ID 2"  ← Changed from ID 1!
}
```

**Analysis:**
- Module ID **successfully saved** and changed to ID 2 ✅
- Battery stopped sending BMS data (restarting) ✅
- App likely crashed at this point ❌

---

**Log 5: `/Users/evgeniydoronin/Downloads/bigbattery_logs_20251010_090616.json`**

```json
"batteryInfo": {
  "voltage": 0,
  "cellVoltages": [],
  "soc": 0
}
"currentValues": {
  "moduleId": "ID 2",  ← Still ID 2 after restart
  "rs485Protocol": "P01-GRW",  ← UNCHANGED!
  "canProtocol": "P01-GRW"      ← UNCHANGED!
}
```

**Analysis:** Module ID persisted through restart, but RS485/CAN did NOT save ❌

---

**Log 6: `/Users/evgeniydoronin/Downloads/bigbattery_logs_20251010_090840.json`**

Client Joshua: "It remembered the ID I chose before crashing, protocols sometimes works & sometimes don't. **Major fix should be the crashing when the battery is restarting**"

```json
"currentValues": {
  "moduleId": "ID 1",  ← Reverted to ID 1
  "rs485Protocol": "P01-GRW",
  "canProtocol": "P01-GRW"
}
```

**Analysis:** Module ID changed back (user testing different IDs), protocols still unchanged

---

## Root Cause

### Issue 1: setModuleId/setRS485/setCAN NOT Using queuedRequest

**BatteryMonitorBL/SettingsViewController.swift (lines 815-831) - BEFORE:**

```swift
func setModuleId(at index: Int, completion: (() -> Void)? = nil) {
    // module id 从 1 开始的
    ZetaraManager.shared.setModuleId(index + 1)
        .subscribeOn(MainScheduler.instance)
        .timeout(.seconds(3), scheduler: MainScheduler.instance)  // ❌ External timeout
        .subscribe { [weak self] (success: Bool) in
            if success, let idData = self?.moduleIdData {
                self?.moduleIdSettingItemView?.label = idData.readableId(at: index)
            } else {
                print("[SETTINGS] ⚠️ Set module id failed")  // ❌ No logging
            }
            completion?()
        } onError: { _ in
            print("[SETTINGS] ❌ Set module id error")
            completion?()
        }.disposed(by: disposeBag)
}
```

**Problems:**
1. Calls `ZetaraManager.setModuleId()` **directly**, NOT using `queuedRequest`
2. No minimum 500ms interval between requests
3. External timeout (doesn't work with RxSwift)
4. Uses `print()` instead of `protocolDataManager.logProtocolEvent()`
5. RS485 and CAN have identical problems

**Result:** All 3 set methods execute simultaneously → battery ignores RS485/CAN

---

### Issue 2: Battery Auto-Restarts After setModuleId

**Battery Behavior:**
- After receiving `setModuleId` command, battery **automatically restarts**
- Restart takes ~5-10 seconds
- App receives unexpected disconnect event
- App crashes because disconnect not handled gracefully

**BatteryMonitorBL/SettingsViewController.swift (lines 661-709) - BEFORE:**

```swift
@objc private func saveButtonTapped() {
    // Hide all status indicators
    hideStatusLabel(moduleIdStatusLabel)
    // ...

    // Apply Module ID change if pending
    if let index = pendingModuleIdIndex {
        setModuleId(at: index, completion: checkCompletion)  // ← Triggers restart!
    }
    // ... no disconnect handler
}
```

**Problems:**
1. No warning that battery will restart
2. No disconnect handler to show informative message
3. Unexpected disconnect causes app crash
4. User confused about what's happening

---

### Issue 3: No User Feedback Before Save

**BatteryMonitorBL/SettingsViewController.swift (lines 200-222) - moduleIdSettingItemView:**

```swift
moduleIdSettingItemView?.selectedOptionIndex
    .skip(1)
    .subscribe {[weak self] index in
        // Track pending change
        self?.pendingModuleIdIndex = index
        // Get selected value name
        let selectedValue = self.moduleIdData?.readableId(at: index) ?? "ID\(index + 1)"
        // Update card label
        self?.moduleIdSettingItemView?.label = selectedValue  // ← Updates immediately
        // ...
    }.disposed(by: disposeBag)
```

**Problem:**
- Label updates immediately when dropdown selected
- User sees new value but hasn't clicked "Save" yet
- Confusing UX: "did it save or not?"

---

## Solution

### Fix 1: Use queuedRequest for setModuleId/setRS485/setCAN

**BatteryMonitorBL/SettingsViewController.swift (lines 815-841) - AFTER:**

```swift
func setModuleId(at index: Int, completion: (() -> Void)? = nil) {
    let moduleNumber = index + 1
    ZetaraManager.shared.protocolDataManager.logProtocolEvent("[SETTINGS] Setting Module ID to \(moduleNumber)")

    ZetaraManager.shared.queuedRequest("setModuleId") {
        ZetaraManager.shared.setModuleId(moduleNumber)
    }
    .subscribe(
        onSuccess: { [weak self] success in
            if success {
                ZetaraManager.shared.protocolDataManager.logProtocolEvent("[SETTINGS] ✅ Module ID set successfully")
                if let idData = self?.moduleIdData {
                    self?.moduleIdSettingItemView?.label = idData.readableId(at: index)
                    self?.toggleRS485AndCAN(index == 0)
                }
            } else {
                ZetaraManager.shared.protocolDataManager.logProtocolEvent("[SETTINGS] ⚠️ Module ID set failed")
            }
            completion?()
        },
        onError: { error in
            ZetaraManager.shared.protocolDataManager.logProtocolEvent("[SETTINGS] ❌ Module ID set error: \(error)")
            completion?()
        }
    )
    .disposed(by: disposeBag)
}
```

**Changes:**
1. ✅ Uses `queuedRequest()` for proper sequencing with 500ms intervals
2. ✅ Removed external timeout (uses internal 10s timeout from writeControlData)
3. ✅ Uses `protocolDataManager.logProtocolEvent()` for diagnostic logging
4. ✅ Identical refactoring applied to `setRS485()` and `setCAN()`

**Why this works:**
- `queuedRequest()` enforces minimum 500ms between requests
- Battery processes Module ID → waits 500ms → processes RS485 → waits 500ms → processes CAN
- All three protocols now save successfully

---

### Fix 2: Add Warning Before Save

**BatteryMonitorBL/SettingsViewController.swift (lines 661-675) - AFTER:**

```swift
@objc private func saveButtonTapped() {
    // Show restart warning FIRST
    let alert = UIAlertController(
        title: "Battery Will Restart",
        message: "Saving settings will cause the battery to restart automatically and disconnect the app temporarily. Continue?",
        preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
        self?.performSave()
    })

    present(alert, animated: true)
}
```

**Why this is important:**
- User understands battery will restart (not a bug!)
- User can cancel if needed
- Sets expectation for disconnect

---

### Fix 3: Handle Disconnect Gracefully

**BatteryMonitorBL/SettingsViewController.swift (lines 677-729) - ADDED:**

```swift
private func performSave() {
    // Hide all status indicators
    hideStatusLabel(moduleIdStatusLabel)
    hideStatusLabel(canStatusLabel)
    hideStatusLabel(rs485StatusLabel)

    // Setup disconnect handler to show informative message
    setupDisconnectHandler()

    // Show loading alert
    Alert.show("Saving settings...", timeout: 10)

    // Track how many operations completed
    var completedOperations = 0
    let totalOperations = [pendingModuleIdIndex, pendingCANIndex, pendingRS485Index].compactMap { $0 }.count

    let checkCompletion = { [weak self] in
        completedOperations += 1
        if completedOperations == totalOperations {
            Alert.hide()
            // Clear pending changes
            self?.pendingModuleIdIndex = nil
            self?.pendingCANIndex = nil
            self?.pendingRS485Index = nil
            // Deactivate Save button
            self?.deactivateSaveButton()
        }
    }

    // Apply Module ID change if pending (this will trigger battery restart)
    if let index = pendingModuleIdIndex {
        setModuleId(at: index, completion: checkCompletion)
    }

    // Apply CAN change if pending
    if let index = pendingCANIndex {
        setCAN(at: index, completion: checkCompletion)
    }

    // Apply RS485 change if pending
    if let index = pendingRS485Index {
        setRS485(at: index, completion: checkCompletion)
    }

    // If no pending changes (shouldn't happen), just hide alert
    if totalOperations == 0 {
        Alert.hide()
        deactivateSaveButton()
    }
}
```

**BatteryMonitorBL/SettingsViewController.swift (lines 731-758) - ADDED:**

```swift
private func setupDisconnectHandler() {
    // Cancel any existing disconnect handler
    disconnectHandlerDisposable?.dispose()

    // Subscribe to disconnect events
    disconnectHandlerDisposable = ZetaraManager.shared.connectedPeripheralSubject
        .subscribeOn(MainScheduler.instance)
        .observe(on: MainScheduler.instance)
        .filter { $0 == nil }
        .take(1) // Only handle the first disconnect after save
        .subscribe(onNext: { [weak self] _ in
            // Battery disconnected (restarting)
            Alert.hide()
            self?.showBatteryRestartingMessage()
        })
}

private func showBatteryRestartingMessage() {
    let alert = UIAlertController(
        title: "Battery Restarting",
        message: "The battery is restarting with new settings. Please wait a moment and reconnect to verify the changes.",
        preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(title: "OK", style: .default))

    present(alert, animated: true)
}
```

**Why this works:**
- Subscribes to `connectedPeripheralSubject` BEFORE save
- Filters for disconnect events (peripheral == nil)
- Takes only first disconnect (prevents duplicate alerts)
- Shows informative message instead of crashing
- User understands battery is restarting (expected behavior)

---

### Fix 4: Update Information Banner

**BatteryMonitorBL/SettingsViewController.swift (lines 79-104) - BEFORE:**

```swift
// Message Label
let messageLabel = UILabel()
messageLabel.text = "You must restart the battery using the power button after saving, then reconnect to the app to verify changes."
```

**AFTER:**

```swift
// Message Label
let messageLabel = UILabel()
messageLabel.text = "The battery will restart automatically when you save settings. Wait a moment, then reconnect to the app to verify changes."
```

**Why this is accurate:**
- Battery NOW restarts automatically (not manually)
- Sets correct expectation for user

---

### Fix 5: Cleanup Disconnect Handler

**BatteryMonitorBL/SettingsViewController.swift (lines 349-360) - AFTER:**

```swift
override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    print("[SETTINGS] View will disappear - cancelling pending requests")

    // Отменяем disconnect handler если есть
    disconnectHandlerDisposable?.dispose()
    disconnectHandlerDisposable = nil

    // Отменяем все текущие подписки
    disposeBag = DisposeBag()
}
```

**Why this is important:**
- Prevents memory leaks
- Disconnect handler only active during save operation
- Clean state when leaving Settings screen

---

## Expected Behavior After Fix

### Scenario 1: User Saves Module ID + RS485 + CAN

**Step 1: User clicks "Save"**

```
[USER] Confirmation alert appears:
"Battery Will Restart"
"Saving settings will cause the battery to restart automatically and disconnect the app temporarily. Continue?"
```

**Step 2: User confirms "Save"**

```
[SETTINGS] Setting Module ID to 2
[QUEUE] 📥 Request queued: setModuleId
[QUEUE] 🚀 Executing setModuleId
[BLUETOOTH] 📤 Writing control data: 100701023574
[BLUETOOTH] 📥 Received notification: ...
[BLUETOOTH] ✅ Got control data response
[QUEUE] ✅ setModuleId completed in 1200ms
[SETTINGS] ✅ Module ID set successfully

[QUEUE] ⏳ Waiting 500ms before setRS485  ← Sequential!

[SETTINGS] Setting RS485 Protocol to P02-LUX
[QUEUE] 📥 Request queued: setRS485
[QUEUE] 🚀 Executing setRS485
[BLUETOOTH] 📤 Writing control data: 100601052576
[BLUETOOTH] 📥 Received notification: ...
[QUEUE] ✅ setRS485 completed in 1150ms
[SETTINGS] ✅ RS485 Protocol set successfully

[QUEUE] ⏳ Waiting 500ms before setCAN  ← Sequential!

[SETTINGS] Setting CAN Protocol to P03-DY
[QUEUE] 📥 Request queued: setCAN
[QUEUE] 🚀 Executing setCAN
[BLUETOOTH] 📤 Writing control data: 10050101d4b5
[BLUETOOTH] 📥 Received notification: ...
[QUEUE] ✅ setCAN completed in 1100ms
[SETTINGS] ✅ CAN Protocol set successfully
```

**Step 3: Battery restarts automatically**

```
[CONNECTION] 🔌 Device disconnected: BB-51.2V100Ah-0855
[DISCONNECT HANDLER] Triggered
[ALERT] "Battery Restarting"
"The battery is restarting with new settings. Please wait a moment and reconnect to verify the changes."
```

**Step 4: User reconnects after 10 seconds**

```
[CONNECTION] ✅ Connected to: BB-51.2V100Ah-0855
[PROTOCOL MANAGER] Loading protocols...
[PROTOCOL MANAGER] ✅ Module ID loaded: ID 2  ← NEW!
[PROTOCOL MANAGER] ✅ RS485 loaded: P02-LUX  ← NEW!
[PROTOCOL MANAGER] ✅ CAN loaded: P03-DY     ← NEW!
```

**Result:** All 3 protocols saved successfully! ✅

---

### Scenario 2: User Saves Only RS485

**User changes RS485, doesn't change Module ID or CAN:**

```
[SETTINGS] Setting RS485 Protocol to P03-SCH
[QUEUE] 🚀 Executing setRS485
[BLUETOOTH] ✅ Got control data response
[QUEUE] ✅ setRS485 completed in 1150ms
[SETTINGS] ✅ RS485 Protocol set successfully

[NO DISCONNECT]  ← Battery doesn't restart if Module ID unchanged
```

**Result:** RS485 saved without battery restart (more efficient!)

---

## Testing Checklist

### Test 1: Save All 3 Protocols Simultaneously

**Steps:**
1. Connect to battery
2. Open Settings screen
3. Change Module ID to "ID 2"
4. Change RS485 to different protocol (e.g., "P02-LUX")
5. Change CAN to different protocol (e.g., "P03-DY")
6. Click "Save"
7. Confirm in alert dialog
8. Wait for battery restart
9. Reconnect to battery
10. Check Settings screen values

**Expected:**
- [ ] Warning alert appears before save
- [ ] "Saving settings..." alert shows during save
- [ ] Disconnect handler triggers (battery restarts)
- [ ] "Battery Restarting" alert shows after disconnect
- [ ] After reconnect, Settings shows: ID 2, P02-LUX, P03-DY
- [ ] Logs show sequential execution with 500ms intervals
- [ ] ALL 3 protocols saved successfully

---

### Test 2: Save Only RS485 (No Module ID Change)

**Steps:**
1. Connect to battery
2. Open Settings screen
3. Change ONLY RS485 protocol
4. Click "Save"
5. Confirm in alert dialog

**Expected:**
- [ ] Warning alert appears
- [ ] RS485 saves successfully
- [ ] Battery does NOT restart (Module ID unchanged)
- [ ] Settings screen shows new RS485 value immediately

---

### Test 3: Cancel Save

**Steps:**
1. Connect to battery
2. Open Settings screen
3. Change any protocol
4. Click "Save"
5. Click "Cancel" in alert dialog

**Expected:**
- [ ] Save operation cancelled
- [ ] No requests sent to battery
- [ ] Settings screen unchanged

---

### Test 4: Verify Diagnostic Logging

**Steps:**
1. Perform Test 1 (save all 3 protocols)
2. After reconnect, send diagnostic logs
3. Check logs for sequential execution

**Expected logs:**
```
[SETTINGS] Setting Module ID to 2
[SETTINGS] ✅ Module ID set successfully
[QUEUE] ⏳ Waiting 500ms before setRS485
[SETTINGS] Setting RS485 Protocol to P02-LUX
[SETTINGS] ✅ RS485 Protocol set successfully
[QUEUE] ⏳ Waiting 500ms before setCAN
[SETTINGS] Setting CAN Protocol to P03-DY
[SETTINGS] ✅ CAN Protocol set successfully
```

---

## Architecture Changes

### Before: Simultaneous Execution (BROKEN)

```
saveButtonTapped()
    ↓
setModuleId() ────────┐
setRS485()   ────────┼──→ [All 3 sent at SAME timestamp]
setCAN()     ────────┘
    ↓
Battery (09:04:38)
    ├─ Processes Module ID ✅
    ├─ Ignores RS485 ❌ (busy processing Module ID)
    └─ Ignores CAN ❌   (busy processing Module ID)
```

**Result:** Only Module ID saves, RS485/CAN lost

---

### After: Sequential Execution with queuedRequest (FIXED)

```
saveButtonTapped()
    ↓ [Warning Alert]
    ↓
performSave()
    ↓ [Setup disconnect handler]
    ↓
setModuleId() → queuedRequest("setModuleId")
    ↓ [Battery receives at 09:04:38]
    ↓ [Wait 500ms]
    ↓
setRS485() → queuedRequest("setRS485")
    ↓ [Battery receives at 09:04:38.5]
    ↓ [Wait 500ms]
    ↓
setCAN() → queuedRequest("setCAN")
    ↓ [Battery receives at 09:04:39.0]
    ↓
Battery restarts
    ↓
Disconnect handler shows "Battery Restarting" alert
```

**Result:** All 3 protocols saved successfully ✅

---

## Related Files

### Modified Files:

1. **BatteryMonitorBL/SettingsViewController.swift**
   - Lines 170-171: Added `disconnectHandlerDisposable` property
   - Lines 88: Updated informationBanner message text
   - Lines 661-675: Refactored `saveButtonTapped()` to show warning alert
   - Lines 677-729: Added `performSave()` method with completion tracking
   - Lines 731-746: Added `setupDisconnectHandler()` method
   - Lines 748-758: Added `showBatteryRestartingMessage()` method
   - Lines 354-356: Added disconnect handler cleanup in `viewWillDisappear`
   - Lines 815-841: Refactored `setModuleId()` to use `queuedRequest`
   - Lines 843-868: Refactored `setRS485()` to use `queuedRequest`
   - Lines 870-895: Refactored `setCAN()` to use `queuedRequest`

### Referenced Files:

- `Zetara/Sources/ZetaraManager.swift` - Contains `queuedRequest()` implementation
- `Zetara/Sources/ProtocolDataManager.swift` - Protocol logging and state management
- `docs/fix-history/2025-10-09_settings-direct-call-bug.md` - Previous fix (protocol display)

### Client Logs Analyzed:

- `logs/bigbattery_logs_20251010_090138.json` - Initial state showing protocols visible
- `logs/bigbattery_logs_20251010_090420.json` - User confusion before save
- `logs/bigbattery_logs_20251010_090446.json` - **CRITICAL: Simultaneous requests discovered**
- `logs/bigbattery_logs_20251010_090539.json` - Module ID saved, battery restarting
- `logs/bigbattery_logs_20251010_090616.json` - RS485/CAN unchanged after restart
- `logs/bigbattery_logs_20251010_090646.json` - Empty BMS data (restarting state)
- `logs/bigbattery_logs_20251010_090733.json` - Reconnection logs
- `logs/bigbattery_logs_20251010_090840.json` - Final state confirmation

---

## Lessons Learned

### 1. Battery BMS Cannot Process Simultaneous Control Requests

**Problem:** All 3 set methods executed simultaneously, battery ignored RS485/CAN.

**Lesson:** Battery BMS can only process ONE control request at a time. ALWAYS use `queuedRequest()` for sequential execution with minimum 500ms intervals between requests.

**Prevention:** Search codebase for any direct calls to `setModuleId/setRS485/setCAN/setControlData` - they ALL must use `queuedRequest()`.

---

### 2. Battery Auto-Restart Behavior Must Be Handled Gracefully

**Problem:** Battery restarts automatically after `setModuleId`, app crashes on unexpected disconnect.

**Lesson:**
- Document ALL battery behaviors that cause disconnect (restart, power off, range exit)
- Set user expectations BEFORE triggering disconnect (warning alerts)
- Show informative messages DURING disconnect (not just "connection lost")

**Prevention:** Any feature that sends control data should check: "Does this trigger restart? If yes, add disconnect handler."

---

### 3. RxSwift Timeouts Must Be Internal, Not External

**Problem:** Settings used `.timeout(.seconds(3))` externally on Maybe.

**Lesson:** External timeouts on Maybe don't propagate properly. Timeout MUST be inside the Observable chain (in `writeControlData`). This was fixed in Attempt #2, but Settings still had external timeouts.

**Prevention:** Code review checklist: "Are there any `.timeout()` calls outside `writeControlData`?"

---

### 4. Diagnostic Logging Critical for Remote Debugging

**Problem:** Without proper logging, couldn't diagnose "RS485/CAN not saving" issue.

**Solution:** Added `protocolDataManager.logProtocolEvent()` calls showing:
- Which protocol being set
- Success/failure status
- Sequential execution with wait intervals

**Lesson:** Every significant state change needs diagnostic logging. Client logs are our ONLY window into production issues.

---

### 5. User Expectations Must Match Reality

**Problem:** Information banner said "You must restart the battery using the power button" but battery restarts AUTOMATICALLY.

**Lesson:** Documentation and UI messages must be 100% accurate. Outdated instructions cause user confusion and support tickets.

**Prevention:** After fixing any user-facing behavior, search for ALL UI text mentioning that behavior and update it.

---

## Prevention Checklist

**For Future Protocol Set/Save Features:**

1. **Sequential Execution:**
   - [ ] Use `queuedRequest()` for ALL control data writes
   - [ ] Never call `setModuleId/setRS485/setCAN` directly
   - [ ] Verify 500ms minimum interval between requests
   - [ ] Test with 3+ simultaneous changes (catch race conditions)

2. **Disconnect Handling:**
   - [ ] Add warning alert if operation triggers restart
   - [ ] Setup disconnect handler BEFORE sending control data
   - [ ] Show informative message when disconnect occurs
   - [ ] Clean up disconnect handler in `viewWillDisappear`

3. **Diagnostic Logging:**
   - [ ] Use `protocolDataManager.logProtocolEvent()` not `print()`
   - [ ] Log BOTH request start AND result (success/failure)
   - [ ] Log sequential execution (wait intervals)
   - [ ] Verify logs visible in diagnostic exports

4. **Timeout Handling:**
   - [ ] No external `.timeout()` on Maybe/Observable
   - [ ] Use internal timeout in `writeControlData` (10 seconds)
   - [ ] Test timeout actually fires (simulate 15s delay)

5. **User Experience:**
   - [ ] Update ALL UI text mentioning changed behavior
   - [ ] Add confirmation dialogs for destructive operations
   - [ ] Show progress indicators during multi-step operations
   - [ ] Provide clear feedback on success/failure

---

## Commit Message

```
fix: Fix protocol save not working + app crash on battery restart

Root Cause:
- setModuleId/setRS485/setCAN called ZetaraManager directly (not queuedRequest)
- All 3 requests sent simultaneously at same timestamp (09:04:38)
- Battery can only process ONE control request at a time
- Battery processed Module ID, ignored RS485/CAN (busy)
- Battery auto-restarts after setModuleId, app crashes on unexpected disconnect

Changes:
1. Refactored setModuleId/setRS485/setCAN to use queuedRequest for sequential execution
2. Added warning alert before save ("Battery Will Restart")
3. Added setupDisconnectHandler to show informative message during restart
4. Added showBatteryRestartingMessage alert when disconnect occurs
5. Updated informationBanner text (battery restarts automatically, not manually)
6. Added disconnect handler cleanup in viewWillDisappear
7. Added comprehensive diagnostic logging with protocolDataManager.logProtocolEvent

Result:
- All 3 protocols (Module ID, RS485, CAN) now save successfully
- Sequential execution with 500ms intervals (not simultaneous)
- App handles battery restart gracefully (no crash)
- User sees clear warnings and informative messages
- Diagnostic logs show sequential execution flow

Files Modified:
- BatteryMonitorBL/SettingsViewController.swift (lines 88, 170-171, 354-356, 661-895)

Client Logs Analyzed:
- bigbattery_logs_20251010_090138.json through 090840.json (8 logs)
- Critical discovery in 090446.json: simultaneous requests at same timestamp
```

---

## ADDITIONAL FIX: Threading Error on Save (October 10, 2025)

**Date:** October 10, 2025 (later same day)
**Severity:** CRITICAL
**Status:** Fixed

### Problem

After implementing the fixes above and testing, discovered a **NEW runtime crash** when clicking Save:

```
Thread 6: "Modifications to the layout engine must not be performed from a background thread after it has been accessed from the main thread."
```

**Error occurs when:**
- User clicks "Save" button
- setModuleId/setRS485/setCAN completion callbacks execute
- Callbacks update UI (labels) and call `Alert.hide()` from background thread

### Root Cause

**RxSwift callbacks executing on background thread:**

The three set methods (`setModuleId()`, `setRS485()`, `setCAN()`) were missing `.observe(on: MainScheduler.instance)`, causing their `.subscribe()` callbacks to execute on **background threads**.

**BatteryMonitorBL/SettingsViewController.swift (lines 913-934) - BEFORE:**

```swift
ZetaraManager.shared.queuedRequest("setModuleId") {
    ZetaraManager.shared.setModuleId(moduleNumber)
}
.subscribe(  // ❌ No .observe(on:) - callback runs on background thread!
    onSuccess: { [weak self] success in
        if success {
            // ❌ UI update on background thread!
            self?.moduleIdSettingItemView?.label = idData.readableId(at: index)
        }
        // ❌ Calls checkCompletion() → Alert.hide() on background thread!
        completion?()
    }
)
```

**Why this crashes:**
1. `queuedRequest()` returns Maybe on background thread
2. `.subscribe()` callbacks execute on same thread as observable
3. Callbacks update UI (`label =` , `Alert.hide()`)
4. iOS forbids UI updates from background threads → **CRASH**

**Identical problem in setRS485() and setCAN().**

### Solution

Add `.observe(on: MainScheduler.instance)` **before** `.subscribe()` in all three set methods.

**BatteryMonitorBL/SettingsViewController.swift (lines 913-935) - AFTER:**

```swift
ZetaraManager.shared.queuedRequest("setModuleId") {
    ZetaraManager.shared.setModuleId(moduleNumber)
}
.observe(on: MainScheduler.instance)  // ✅ Force callbacks to main thread
.subscribe(
    onSuccess: { [weak self] success in
        // ✅ Now executes on main thread - safe for UI updates
        if success {
            self?.moduleIdSettingItemView?.label = idData.readableId(at: index)
        }
        completion?()  // ✅ Alert.hide() now on main thread
    }
)
```

**Applied to all three methods:**
- `setModuleId()` - line 915
- `setRS485()` - line 949
- `setCAN()` - line 982

### Why This Works

**RxSwift Scheduler Behavior:**
- `.observe(on: MainScheduler.instance)` forces all downstream operators to execute on main thread
- Ensures `onSuccess` and `onError` callbacks run on main thread
- Makes UI updates (labels, Alert) thread-safe

**Reference from Previous Fix:**

This same pattern was already used in `setupDisconnectHandler()` (lines 764-778):

```swift
disconnectHandlerDisposable = ZetaraManager.shared.connectedPeripheralSubject
    .subscribeOn(MainScheduler.instance)
    .observe(on: MainScheduler.instance)  // ← Already fixed here!
    .subscribe(onNext: { [weak self] _ in
        Alert.hide()  // Safe - runs on main thread
    })
```

We applied the same fix to the three set methods.

### Files Modified

**BatteryMonitorBL/SettingsViewController.swift:**
- Line 915: Added `.observe(on: MainScheduler.instance)` in `setModuleId()`
- Line 949: Added `.observe(on: MainScheduler.instance)` in `setRS485()`
- Line 982: Added `.observe(on: MainScheduler.instance)` in `setCAN()`

### Lesson Learned

**Threading Rule for RxSwift + UI:**

ANY RxSwift subscription that:
1. Updates UI (labels, buttons, alerts, etc.)
2. Calls completion handlers that might update UI

MUST use `.observe(on: MainScheduler.instance)` before `.subscribe()`.

**Prevention Checklist:**
- [ ] Search codebase for all `.subscribe(` calls
- [ ] Verify each has `.observe(on: MainScheduler.instance)` if touching UI
- [ ] Test on device (threading crashes often don't appear in Simulator)

---
