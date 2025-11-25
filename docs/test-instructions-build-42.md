# Test Instructions - Build 42

**Build:** 42
**Date:** 2025-11-25
**Tester:** Joshua
**Focus:** Fix mid-session auto-reconnect (writeControlData/getBMSData cleanup removal)

---

## What Changed in Build 42:

Removed cleanConnection() calls from writeControlData() and getBMSData() methods.
These were destroying the UUID before the health monitor could trigger auto-reconnect.

---

## Test 1: Mid-Session Reconnect (Battery Restart)

**Purpose:** Verify auto-reconnect works when battery restarts mid-session.

**Steps:**
1. Open app, connect to battery
2. Wait for protocols to show (P01-GRW, ID 1)
3. Turn OFF battery (physical switch)
4. Wait 5-10 seconds
5. Turn ON battery

**Expected Result:**
- App should auto-reconnect WITHOUT manual scan
- Protocols should show correctly after reconnect
- NO need to tap "Connect" button

**If FAILED:**
- Send logs from Diagnostics screen
- Note: Does "Tap to Connect" appear? Or does it stay "connected"?

---

## Test 2: Settings Navigation Reconnect

**Purpose:** Verify auto-reconnect works after navigating to Settings during disconnect.

**Steps:**
1. Open app, connect to battery
2. Wait for protocols to show
3. Navigate to Settings screen
4. Turn OFF battery
5. Wait 5 seconds
6. Navigate back to main screen (Connectivity)
7. Turn ON battery

**Expected Result:**
- App should auto-reconnect WITHOUT manual scan
- Protocols should show correctly
- NO "--" in protocol display

**If FAILED:**
- Send logs from Diagnostics screen
- Note: What do protocols show? "--" or correct values?

---

## Test 3: Cross-Session Reconnect (Regression Test)

**Purpose:** Verify startup auto-reconnect still works (no regression).

**Steps:**
1. Connect to battery
2. Close app (swipe up to close completely)
3. Wait 5 seconds
4. Reopen app

**Expected Result:**
- App should auto-reconnect on startup
- Should NOT require manual scan
- This test PASSED in Build 41, should still PASS

**If FAILED:**
- This would be a regression - send logs immediately

---

## Summary Table:

| Test | Description | Build 41 Result | Build 42 Expected |
|------|-------------|-----------------|-------------------|
| 1 | Mid-session reconnect | FAILED | PASS |
| 2 | Settings navigation | FAILED | PASS |
| 3 | Cross-session (regression) | PASSED | PASS |

---

## What to Report:

For each test, please report:
1. PASS or FAIL
2. If FAIL: What behavior did you observe?
3. Send logs from Diagnostics screen (especially for failed tests)

**Logs Location:**
Diagnostics screen -> Send Logs button

---

## Quick Test (Minimum):

If time is limited, prioritize:
1. Test 1 (most important - this is what Build 42 fixes)
2. Test 3 (regression check)

Total time: ~5 minutes
