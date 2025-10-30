# Testing Instructions for Joshua

Hi Joshua,

We've fixed the timeout issues you reported. Please test the new build and send us logs after each test scenario.

## Installation

1. Download the new build from TestFlight (or we'll send you the build)
2. Make sure you have version **1.4.1 build 19+**
3. Clear the app data before testing (delete and reinstall)

## Test Scenarios

### Scenario 1: Normal Connection (Good Signal)

**Purpose:** Verify protocols load successfully with good Bluetooth signal

**Steps:**
1. Make sure battery is **turned ON** and **close to your iPhone** (1-2 meters)
2. Open the app
3. Connect to your battery (BB-51.2V100Ah-0855)
4. Wait 5-10 seconds for data to load
5. Go to **Settings** screen
6. Check if Module ID, RS485, and CAN protocols are displayed (not "--")
7. Try to change Module ID → verify Save button appears
8. **Export logs** and send them to us

**Expected Result:**
- Protocols load within 3-5 seconds
- Settings screen shows actual values (not "--")
- Save button appears when you change Module ID
- Logs show:
  ```
  [PROTOCOL MANAGER] ✅ Module ID loaded: ID X
  [PROTOCOL MANAGER] ✅ RS485 loaded: Protocol X
  [PROTOCOL MANAGER] ✅ CAN loaded: Protocol X
  [PROTOCOL MANAGER] 🎉 All protocols loaded successfully!
  ```

---

### Scenario 2: Weak Signal / Timeout Test

**Purpose:** Verify timeout works correctly (10 seconds max)

**Steps:**
1. **Turn OFF the battery** (or move iPhone very far from battery - 20+ meters)
2. Open the app
3. Try to connect to battery
4. If connection succeeds, immediately go to **Settings** screen
5. **Start timer on your phone** when Settings screen opens
6. Wait and observe
7. Check how long it takes before Settings screen shows error or "--"
8. **Export logs** and send them to us

**Expected Result:**
- Settings screen should show error/empty values within **10-12 seconds** (not 80+ seconds like before!)
- Logs should show:
  ```
  [QUEUE] 🚀 Executing getModuleId
  [PROTOCOL MANAGER] ⏱️ Module ID timeout after 10s
  [PROTOCOL MANAGER] ⏱️ RS485 timeout after 10s
  [PROTOCOL MANAGER] ⏱️ CAN timeout after 10s
  ```
- **Time from opening Settings to seeing "--" should be ~10-15 seconds MAX**

---

### Scenario 3: Disconnect Detection

**Purpose:** Verify app detects when battery is disconnected

**Steps:**
1. Connect to battery normally
2. Wait until data is displayed on Home screen
3. **Turn OFF the battery** (or go very far away)
4. Wait 10-15 seconds
5. Check Home screen - does it show "No device connected"?
6. **Export logs** and send them to us

**Expected Result:**
- App shows "No device connected" within 10-15 seconds
- Logs show:
  ```
  [CONNECTION] 🔌 Device disconnected: BB-51.2V100Ah-0855
  [CONNECTION] Cleaning connection state
  [PROTOCOL MANAGER] Clearing all protocols
  ```
- **NO MORE:** `[CONNECTION] ⚠️ PHANTOM: No peripheral but BMS timer running!`

---

### Scenario 4: Multiple Reconnects (Race Condition Test)

**Purpose:** Verify no crashes or duplicate cleaning with rapid reconnects

**Steps:**
1. Connect to battery
2. Wait 3 seconds
3. Go to Settings → back to Home
4. Disconnect battery (turn OFF)
5. Wait 5 seconds
6. Turn battery ON
7. Connect again
8. Repeat steps 2-7 **three times rapidly**
9. **Export logs** and send them to us

**Expected Result:**
- No app crashes
- Reconnects work smoothly
- Logs may show:
  ```
  [CONNECTION] ⚠️ Skipping duplicate cleanConnection call
  ```
  This is GOOD - it means our fix is working!

---

### Scenario 5: Settings Screen Recovery After Timeout

**Purpose:** Verify Settings screen is usable after timeout

**Steps:**
1. Turn OFF battery
2. Open app → Settings screen
3. Wait for timeout (~10 seconds)
4. Settings should show "--" for all protocols
5. Exit Settings screen
6. **Turn ON battery**
7. Go back to Settings screen
8. Wait 5-10 seconds
9. Check if protocols load now
10. **Export logs** and send them to us

**Expected Result:**
- After timeout, Settings screen is still usable (not frozen)
- After turning battery ON and reopening Settings, protocols load successfully
- Logs show successful loading after previous timeout

---

## How to Export Logs

**From Diagnostics Screen:**
1. Connect to battery (or simulate connection)
2. Tap **Settings** icon (top right)
3. Scroll to bottom → **Diagnostics**
4. Tap **"Send Diagnostics to Developer"**
5. Choose Email → send to our support email

**Label each log with test scenario:**
- Example: "Test Scenario 2 - Timeout Test - 2025-10-08"

---

## What We're Looking For

**Good signs in logs:**
✅ `[PROTOCOL MANAGER] ⏱️ Module ID timeout after 10s` (timeout works!)
✅ `[CONNECTION] Cleaning connection state` (no duplicates)
✅ `[PROTOCOL MANAGER] ✅ Module ID loaded: ID X` (successful load)
✅ `[CONNECTION] ⚠️ Skipping duplicate cleanConnection call` (race condition prevented)

**Bad signs (report immediately):**
❌ No timeout messages after 20+ seconds
❌ App crashes
❌ Settings screen frozen/unresponsive
❌ Duplicate logs (same message twice in a row)

---

## Questions?

If you see any unexpected behavior or have questions about these tests, please email us immediately. We're available to help!

Thank you for your detailed testing! 🙏
