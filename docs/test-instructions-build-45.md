# Test Instructions - Build 45

**Build:** 45
**Tester:** Joshua
**Focus:** Module ID loading after reconnect

---

## What This Build Fixes

Build 44 fixed auto-reconnect (battery reconnects automatically after signal loss).
Build 45 fixes Module ID not loading after reconnect (showed "--" instead of "ID 1").

---

## Test 1: Mid-Session Reconnect [CRITICAL]

**Steps:**
1. Install Build 45
2. Open app, connect to battery
3. Verify Module ID shows "ID 1" on home screen (Protocol Parameters section)
4. Walk away from battery (50+ feet) until signal is lost
5. Wait 10 seconds
6. Return to battery range
7. Wait for auto-reconnect (up to 30 seconds)
8. Check Module ID on home screen

**Expected Result:**
- Module ID shows "ID 1" (not "--")
- Battery data (SOC, voltage) displays correctly
- All protocols load (RS485, CAN, Module ID)

**If FAILED:**
- Note what Module ID shows
- Export diagnostic logs
- Send logs to dev team

---

## Additional Verification (Optional)

After Test 1 passes, you can also verify:

**Protocol Parameters View:**
- Module ID: "ID 1"
- RS485: P01-GRW (or current protocol)
- CAN: P01-GRW (or current protocol)

**Logs to look for (in exported diagnostics):**
```
[PROTOCOL MANAGER] Module ID loaded: ID 1
[PROTOCOL MANAGER] RS485 loaded: P01-GRW
[PROTOCOL MANAGER] CAN loaded: P01-GRW
[PROTOCOL MANAGER] All protocols loaded successfully!
```

---

## Test Results

| Test | Result | Module ID | Notes |
|------|--------|-----------|-------|
| Test 1 | | | |

---

**Build 45 = SUCCESS if:**
- Test 1 shows Module ID = "ID 1" after reconnect

**Build 45 = FAILED if:**
- Module ID still shows "--" after reconnect
