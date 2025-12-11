# Full Test Instructions - Build 44

**Build:** 44
**Date:** 2025-12-11
**Tester:** Joshua
**Purpose:** Complete app verification after auto-reconnect fix

---

## Test Priority Legend

- **[CRITICAL]** - Must pass. Core functionality.
- **[IMPORTANT]** - Should pass. Key user scenarios.
- **[OPTIONAL]** - Nice to have. Edge cases.

---

## Test 1: Fresh Connection [CRITICAL]

**Purpose:** Verify first-time connection works.

**Steps:**
1. Delete app and reinstall (or clear app data)
2. Open app
3. Tap "Connect" button
4. Select battery from list (BB-51.2V100Ah-0855)
5. Wait for protocols to load

**Expected Result:**
- Protocols show: P01-GRW (or similar)
- Module ID shows: ID 1
- Battery data displays (SOC%, Voltage, etc.)
- No errors in Diagnostics screen

**If FAILED:** Send logs from Diagnostics screen

---

## Test 2: Mid-Session Reconnect [CRITICAL]

**Purpose:** Verify auto-reconnect when battery restarts.

**Steps:**
1. App connected to battery, protocols showing
2. Turn OFF battery (physical switch)
3. Wait 10 seconds
4. Turn ON battery

**Expected Result:**
- App auto-reconnects WITHOUT manual scan
- Protocols show correctly after reconnect
- NO need to tap "Connect" button
- Battery data resumes automatically

**If FAILED:** Send logs, note if "Tap to Connect" appeared

---

## Test 3: Cross-Session Reconnect [CRITICAL]

**Purpose:** Verify auto-connect after app restart.

**Steps:**
1. App connected to battery
2. Close app completely (swipe up to kill)
3. Wait 5 seconds
4. Open app again

**Expected Result:**
- App auto-connects to same battery
- Protocols load automatically
- No manual scan needed

**If FAILED:** Send logs, note what screen appeared on launch

---

## Test 4: Settings Navigation [IMPORTANT]

**Purpose:** Verify data persists after navigation.

**Steps:**
1. App connected, protocols showing
2. Go to Settings screen
3. Return to main screen

**Expected Result:**
- Protocols still displayed correctly
- Battery data still showing
- No "Tap to Connect" message

**If FAILED:** Send logs, note if protocols show "--"

---

## Test 5: Protocol Change [IMPORTANT]

**Purpose:** Verify protocol settings can be changed.

**Steps:**
1. Connect to battery
2. Go to Settings
3. Change RS485 protocol to different value
4. Save and return to main screen

**Expected Result:**
- New protocol value saved
- Settings screen shows new value
- No errors during save

**If FAILED:** Send logs, note error message if any

---

## Test 6: Walk Away / Signal Loss [OPTIONAL]

**Purpose:** Verify behavior when leaving Bluetooth range.

**Steps:**
1. Connect to battery
2. Walk away from battery (lose Bluetooth signal)
3. Wait for disconnect notification
4. Return to battery

**Expected Result:**
- "Tap to Connect" appears when signal lost
- After returning, tap connects successfully
- Protocols load after reconnection

**If FAILED:** Send logs, note app behavior

---

## Summary Checklist

| # | Test | Priority | Result |
|---|------|----------|--------|
| 1 | Fresh Connection | CRITICAL | |
| 2 | Mid-Session Reconnect | CRITICAL | |
| 3 | Cross-Session Reconnect | CRITICAL | |
| 4 | Settings Navigation | IMPORTANT | |
| 5 | Protocol Change | IMPORTANT | |
| 6 | Walk Away | OPTIONAL | |

---

## How to Report

For each test:
1. Write PASS or FAIL
2. If FAIL: Describe what happened
3. Send logs from Diagnostics screen (tap "Send Logs")

**Estimated time:** 10-15 minutes for all tests

---

## Logs Location

Diagnostics screen -> Send Logs button

Send logs after completing ALL tests (or after any failure).
