# Build 40 Test Instructions for Joshua

## Test Summary

**Build 40 fixes:** Mid-session auto-reconnect (health monitor issue)
**Tests needed:** 5 tests total

---

## PRIORITY TESTS (must PASS - were FAILED in Build 39)

### Test 1: Mid-session Reconnect
**What to test:** Battery restart while app running
**Steps:**
1. Connect to battery
2. Wait for connection to complete
3. Power off battery (physical power button)
4. Wait 10 seconds
5. Power on battery
6. Check if app auto-reconnects

**Expected:** Auto-reconnect without manual scan
**Build 39 result:** FAILED
**Build 40 should:** PASS

---

### Test 2: Settings Screen After Save
**What to test:** Protocol change triggers battery restart
**Steps:**
1. Connect to battery
2. Go to Settings screen
3. Change protocol settings
4. Save changes (battery restarts automatically)
5. Check if Settings screen shows correct data after reconnect

**Expected:** Auto-reconnect + Settings shows saved protocols
**Build 39 result:** FAILED
**Build 40 should:** PASS

---

### Test 3: Multiple Disconnect Cycles
**What to test:** Repeated battery restarts
**Steps:**
1. Connect to battery
2. Power off battery → wait → power on → verify auto-reconnect
3. Repeat step 2 three more times (4 cycles total)

**Expected:** All 4 cycles auto-reconnect successfully
**Build 39 result:** FAILED (first cycle broke it)
**Build 40 should:** PASS (all 4 cycles)

---

## REGRESSION TESTS (must still PASS - were PASSED in Build 39)

### Test 4: Cross-Session Reconnect
**What to test:** App restart auto-reconnect
**Steps:**
1. Connect to battery
2. Force close app (swipe up)
3. Reopen app
4. Check if auto-reconnects to last battery

**Expected:** Auto-reconnect without manual scan
**Build 39 result:** PASSED
**Build 40 should:** Still PASS (no regression)

---

### Test 5: App Restart Reconnect
**What to test:** Device reboot scenario
**Steps:**
1. Connect to battery
2. Close app completely
3. Wait 30 seconds
4. Reopen app
5. Check if auto-reconnects

**Expected:** Auto-reconnect without manual scan
**Build 39 result:** PASSED
**Build 40 should:** Still PASS (no regression)

---

## SKIP THIS TEST

### Test 6: Disconnect Button UI
**Reason:** Separate UI issue, not related to auto-reconnect functionality
**Status:** Known issue, will fix separately

---

## Test Options

### FULL TEST (recommended): 5 tests
Tests 1, 2, 3, 4, 5

### MINIMUM TEST (if time limited): 4 tests
Tests 1, 2, 3, 4 (skip Test 5)

### QUICK TEST (sanity check): 3 tests
Tests 1, 2, 3 (priority only)

---

## What to Look For in Logs

**SUCCESS indicators:**
- `[HEALTH] Triggering auto-reconnect with UUID:`
- `[CLEANUP] Partial cleanup complete`
- `[RECONNECT] ✅ ✅ ✅ AUTO-RECONNECT SUCCESSFUL!`

**FAILURE indicators (should NOT appear):**
- `Cleared persistent UUID from storage`
- `[CLEANUP] 🔴 Full cleanup requested`
- `Please scan again to reconnect`

---

## Success Criteria

**Build 40 = SUCCESS if:**
- ✅ Tests 1, 2, 3 now PASS (were FAILED)
- ✅ Tests 4, 5 still PASS (no regression)
- ✅ Logs show auto-reconnect triggers
- ✅ NO UUID clearing in logs

**Build 40 = FAILED if:**
- ❌ Any of Tests 1, 2, 3 still fail
- ❌ Tests 4 or 5 regress (now fail)
