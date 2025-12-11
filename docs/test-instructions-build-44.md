# Test Instructions - Build 44

**Build:** 44
**Date:** 2025-12-11
**Tester:** Joshua
**Focus:** Fix missing UUID save in reconnect path

---

## What Changed in Build 44:

When app connects via startup auto-reconnect (not manual tap),
the UUID was not being saved to memory. This caused mid-session
reconnect to fail because health monitor couldn't find the UUID.

Build 44 adds UUID save in `rediscoverServicesAndCharacteristics()`.

---

## Test 1: Mid-Session Reconnect (Battery Restart)

**Purpose:** Verify auto-reconnect works when battery restarts mid-session.

**Steps:**
1. Open app, wait for automatic connection (do NOT manually tap to connect)
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

**New log to look for:**
`[RECONNECT] UUID saved to memory:` - this confirms Build 44 fix is working

Total time: ~2 minutes
