# Test Instructions - Build 41

**Date:** 2025-11-19
**Build:** 41
**Tester:** Joshua
**Focus:** Mid-session auto-reconnect after viewWillAppear fix

---

## What Changed in Build 41

**Fixed:** ConnectivityViewController.viewWillAppear() was destroying UUID even after observeDisconnect() correctly preserved it.

**Expected Result:** Mid-session auto-reconnect should now work, especially after navigating to Settings screen.

---

## Test Configuration

**Battery:** BigBattery ETHOS module BB-51.2V100Ah-0855
**App Version:** Build 41
**Tests Required:** 3 tests (2 priority + 1 regression)

---

## Priority Tests (Previously FAILED → Should PASS Now)

### Test 1: Mid-session Reconnect (Basic Battery Restart)

**Steps:**
1. Open app
2. Scan and connect to battery
3. Wait for connection to complete (see battery data on Home screen)
4. Turn OFF battery (power button)
5. Wait 10 seconds
6. Turn ON battery (power button)
7. **Wait up to 30 seconds** - DO NOT manually scan!

**Expected Result:**
- ✅ App auto-reconnects WITHOUT requiring manual scan
- ✅ Battery data appears automatically
- ✅ Connection successful

**If FAILED:**
- ❌ App shows "Not connected"
- ❌ Must manually scan to reconnect
- ❌ "Connection error" appears

**After test:** Send logs immediately (share button in app)

---

### Test 2: Mid-session Reconnect After Settings Navigation

**This is the MAIN fix for Build 41!**

**Steps:**
1. Open app
2. Scan and connect to battery
3. Wait for connection to complete
4. Navigate to **Settings screen** (gear icon)
5. Check Module ID and protocols display (should show values, not "--")
6. **While on Settings screen:** Turn OFF battery
7. Wait 10 seconds
8. Turn ON battery
9. **Wait up to 30 seconds** - DO NOT manually scan!
10. Check if connection restores automatically

**Expected Result:**
- ✅ App auto-reconnects WITHOUT requiring manual scan
- ✅ Settings screen shows correct Module ID and protocols after reconnect
- ✅ Connection successful

**If FAILED:**
- ❌ App shows "Not connected"
- ❌ Must manually navigate to Bluetooth screen and scan
- ❌ Settings shows "--" for protocols

**After test:** Send logs immediately (share button in app)

---

## Regression Test (Previously PASSED → Should Still PASS)

### Test 3: Cross-session Reconnect (App Restart)

**Steps:**
1. Open app
2. Scan and connect to battery
3. Wait for connection to complete
4. **Close app completely** (swipe up from app switcher)
5. Wait 5 seconds
6. **Reopen app**
7. **Wait up to 30 seconds** - DO NOT manually scan!

**Expected Result:**
- ✅ App auto-reconnects WITHOUT requiring manual scan
- ✅ Battery data appears automatically on Home screen
- ✅ Connection successful

**If FAILED:**
- ❌ App shows "Not connected"
- ❌ Must manually scan to reconnect

**After test:** Send logs immediately (share button in app)

---

## How to Send Logs

**After EACH test:**
1. Tap **Share button** in app (top right)
2. Send logs via email/Telegram to Evgenii
3. In message, specify which test it was:
   - "Build 41 - Test 1 (battery restart)"
   - "Build 41 - Test 2 (Settings navigation)"
   - "Build 41 - Test 3 (app restart)"
4. Mention if test PASSED or FAILED

---

## Important Notes

- **DO NOT scan manually** during tests - we're testing AUTO-reconnect!
- Wait full 30 seconds before declaring test failed
- Send logs **immediately after each test** (don't wait to finish all 3)
- Battery should be fully charged (prevents power issues)
- Keep battery close to phone (Bluetooth range ~10 meters)

---

## What Logs Should Show (If Working Correctly)

**Test 1 & 2 (Mid-session reconnect):**
```
[CLEANUP] Partial cleanup - preserving UUID for auto-reconnect
[RECONNECT] ⚡ Starting auto-reconnect sequence
[RECONNECT] Target UUID: ...
[RECONNECT] Retrieved 1 peripheral(s) with matching UUID
[CONNECT] ✅ Connection established
```

**Should NOT see:**
```
[CLEANUP] 🔴 Full cleanup requested (MANUAL disconnect)
[CLEANUP] Cleared persistent UUID from storage
```

**Test 3 (Cross-session reconnect):**
```
[STARTUP] Checking for auto-reconnect possibility
[STARTUP] Found cached UUID: ...
[RECONNECT] ⚡ Starting auto-reconnect sequence
[CONNECT] ✅ Connection established
```

---

## Test Results Summary

Please fill out and send back:

**Test 1 (Battery restart):** [ ] PASSED / [ ] FAILED
**Test 2 (Settings navigation):** [ ] PASSED / [ ] FAILED
**Test 3 (App restart):** [ ] PASSED / [ ] FAILED

**Additional comments:**
_[Any observations, weird behavior, etc.]_

---

## Expected Timeline

- Test 1: ~2 minutes
- Test 2: ~3 minutes (includes Settings navigation)
- Test 3: ~2 minutes
- **Total: ~7 minutes**

Much faster than Build 40's 6 tests!

---

**Questions?** Contact Evgenii before starting tests.
