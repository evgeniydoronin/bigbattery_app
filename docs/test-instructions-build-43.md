# Test Instructions - Build 43

**Build:** 43
**Date:** 2025-11-25
**Tester:** Joshua
**Focus:** Fix PHANTOM detection cleanup (preserve UUID for auto-reconnect)

---

## What Changed in Build 43:

PHANTOM detection now uses partial cleanup instead of full cleanup.
This preserves the UUID so auto-reconnect can work.

---

## Test 1: Mid-Session Reconnect (Battery Restart)

**Purpose:** Verify auto-reconnect works when battery restarts mid-session.

**Steps:**
1. Open app, connect to battery
2. Wait for protocols to show (P01-GRW, ID 1)
3. Turn OFF battery (physical switch)
4. Wait 10 seconds
5. Turn ON battery

**Expected Result:**
- App should auto-reconnect WITHOUT manual scan
- Protocols should show correctly after reconnect
- NO need to tap "Connect" button

**If FAILED:**
- Send logs from Diagnostics screen
- Note: Does "Tap to Connect" appear? Or does it stay "connected"?

---

## What to Report:

1. PASS or FAIL
2. If FAIL: What behavior did you observe?
3. Send logs from Diagnostics screen

**Logs Location:**
Diagnostics screen -> Send Logs button

Total time: ~2 minutes
