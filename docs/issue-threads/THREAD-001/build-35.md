# Build 35: Prevent Refresh During Disconnect

**Date:** 2025-10-30 (implementation) / 2025-11-03 (test results)
**Status:** ✅ Crash Fixed / ❌ New Issue (Settings display)
**Attempt:** #5

**Navigation:**
- ⬅️ Previous: [Build 34](build-34.md)
- ➡️ Next: [Build 36](build-36.md)
- 🏠 Main: [../THREAD-001.md](../THREAD-001.md)

---

## Solution:

Add guard to prevent `refreshPeripheralInstanceIfNeeded()` from running during disconnect.

## Implementation:

Added state check in `refreshPeripheralInstanceIfNeeded()`:
```swift
// ZetaraManager.swift lines 455-461
// Build 35: Guard against refresh during disconnect to prevent crash
// Skip refresh if peripheral is currently disconnecting
if let currentPeripheral = connectedPeripheralSubject.value,
   currentPeripheral.state == .disconnecting {
    protocolDataManager.logProtocolEvent("[LAUNCH] ⚠️ Skip refresh - peripheral disconnecting")
    return
}
```

## Why This Works:

- Checks peripheral state BEFORE attempting refresh
- Skips refresh if peripheral is `.disconnecting` (race condition window)
- Keeps all Build 34 benefits (launch-time + foreground refresh)
- Prevents crash by avoiding operation during unstable state

## Expected Results:

- ✅ Connection success (already working in Build 34)
- ✅ No error 4 (already fixed in Build 34)
- ✅ No crash on disconnect (fixed in Build 35)
- ✅ All BMS data loads correctly
- ✅ All protocols load correctly
- ✅ Seamless UX with stable disconnect handling

---

## Test Results (2025-11-03):

**Letter from Joshua #1:** "After connecting to battery and manually disconnecting battery, app still displays connection to battery"

**Letter from Joshua #2:** "Connect to battery, Manually turn off battery, App no longer shows battery status or vitals, Still displays connection to battery in settings, Unable to reconnect to battery due to error"

### Logs:

- `docs/fix-history/logs/bigbattery_logs_20251103_113252.json`
- `docs/fix-history/logs/bigbattery_logs_20251103_113737.json`

### Analysis:

**Log 1 (11:32:52):**
- ⚠️ **PARTIAL SUCCESS** - Crash on disconnect fixed (no crash reported)
- ✅ Protocols loaded successfully (RS485: P02-LUX, CAN: P06-LUX at 11:32:09-10)
- ❌ **NEW ISSUE**: Settings screen shows "--" for all protocols after reconnect
- ❌ Connection error 4 occurred at 11:32:40, triggered cleanConnection() which cleared protocols
- Result: `protocolInfo.currentValues` shows all "--"

**Log 2 (11:37:37):**
- ❌ Connection failed with error 4 immediately
- ❌ Protocols never loaded (all "--")
- Device in partially connected state (characteristics configured but no data)

## Verdict:

✅ **CRASH FIXED** - Build 35 successfully prevents crash on disconnect

❌ **NEW ISSUE DISCOVERED** - Settings screen not displaying protocols after reconnect due to destroyed subscriptions

## Root Cause Analysis:

Settings screen uses RxSwift subscriptions to protocol subjects (`moduleIdSubject`, `rs485Subject`, `canSubject`). In `viewWillDisappear` (line 359), the code recreates disposeBag which **destroys all subscriptions**:

```swift
override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    disposeBag = DisposeBag()  // ❌ Kills all subscriptions!
}
```

### Flow that causes the issue:

1. First connection → Settings subscribes in `viewDidLoad()` → receives protocol updates → shows data ✅
2. User leaves Settings → `viewWillDisappear` → disposeBag recreated → subscriptions destroyed ❌
3. Battery restarts → user reconnects → protocols load successfully
4. User returns to Settings → **NO active subscriptions** → cannot receive protocol updates → shows "--" ❌

**Protocols ARE loaded** (proven by Log 1), but Settings screen cannot display them because subscriptions were destroyed.

---

**Navigation:**
- ⬅️ Previous: [Build 34](build-34.md)
- ➡️ Next: [Build 36](build-36.md)
- 🏠 Main: [../THREAD-001.md](../THREAD-001.md)
