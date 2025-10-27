# THREAD-002: BMS Data Not Loading After Connection

**Status:** 🔴 ACTIVE
**Severity:** HIGH
**First Reported:** 2025-10-27
**Last Updated:** 2025-10-27
**Client:** Joshua (BigBattery ETHOS module BB-51.2V100Ah-0855)

---

## 📍 CURRENT STATUS

**Quick Summary:**
In some connection scenarios, protocols load successfully but BMS data remains all zeros (voltage=0, soc=0, empty cell arrays). **Root cause: BMS timer not starting after protocol loading.** Requires investigation.

**Latest Test Result:** ⏳ PENDING (investigating root cause)

**Next Steps:**
- [ ] Investigate why BMS timer doesn't start in some scenarios
- [ ] Review ConnectivityViewController BMS timer initialization
- [ ] Compare working vs non-working log timelines
- [ ] Identify conditions that prevent BMS timer from starting
- [ ] Implement fix

---

## 📜 TIMELINE (chronological, oldest first)

### 📅 2025-10-27: Initial Report (Build 31)

**Client Report (Joshua):**
> Letter 1: Connected to battery - not displaying any temps, status or battery level or cells or regular summary. Only shows protocols selected Unable to make changes

**Diagnostic Logs:**
- **Working case**: `docs/fix-history/logs/bigbattery_logs_20251027_144713.json` (14:47:13)
- **Problem case**: `docs/fix-history/logs/bigbattery_logs_20251027_144046.json` (14:40:46)

**Initial Symptoms:**
- ✅ Bluetooth connection successful
- ✅ Protocols load successfully (ID 1, RS485=P01-GRW, CAN=P01-GRW)
- ✅ Protocol statistics show successes (9 successes, 0 errors)
- ❌ BMS data ALL ZEROS (voltage=0, soc=0, soh=0, current=0)
- ❌ Cell voltages array EMPTY `[]`
- ❌ Cell temps array EMPTY `[]`
- ❌ Raw packet all zeros: `"0000000000000000000000000000000000000000000000000000"`

---

## 🔍 EVIDENCE FROM LOGS

### **Problem Case (Log 1 - 14:40:46) - BMS Data NOT Loading**

**Battery Info:**
```json
"batteryInfo": {
    "voltage": 0,
    "soc": 0,
    "soh": 0,
    "current": 0,
    "cellVoltages": [],
    "cellTemps": [],
    "cellCount": 0,
    "status": "Standby"
}
```

**Raw Data:**
```json
"rawDataInfo": {
    "lastReceivedPacket": "0000000000000000000000000000000000000000000000000000",
    "parseResult": "success"
}
```

**Protocol Logs (recentLogs) - NO [BMS] entries:**
```
[14:40:30] [PROTOCOL MANAGER] 🎉 All protocols loaded successfully!
[14:40:30] [PROTOCOL MANAGER] ✅ CAN loaded: P01-GRW
[14:40:30] [QUEUE] ✅ getCAN completed in 2059ms
[14:40:29] [QUEUE] ✅ getRS485 completed in 1459ms
[14:40:28] [QUEUE] ✅ getModuleId completed in 934ms

[NO [BMS] logs after this point!]
[Missing: [BMS] 🚀 Starting BMS data refresh timer]
[Missing: [BMS] 📡 getBMSData() called]
[Missing: [BMS] 📤 Writing BMS request]
```

**Protocol Statistics:**
```json
"statistics": {
    "totalLogs": 30,
    "successes": 9,
    "errors": 0,
    "warnings": 0
}
```

---

### **Working Case (Log 2 - 14:47:13) - BMS Data LOADING**

**Battery Info:**
```json
"batteryInfo": {
    "voltage": 53.279998779296875,
    "soc": 80,
    "soh": 100,
    "current": 0,
    "cellVoltages": [16 cells with valid values 3.328-3.331V],
    "cellTemps": [24, 24, 24, 23],
    "cellCount": 16,
    "status": "Standby"
}
```

**Raw Data:**
```json
"rawDataInfo": {
    "lastReceivedPacket": "B81E55420000000050000000000000006400000000000000560E55401B2F5540...",
    "parseResult": "success"
}
```

**Protocol Logs (recentLogs) - [BMS] entries PRESENT:**
```
[14:47:11] [BMS] ✅ BMS data parsed successfully
[14:47:11] [BMS] Validation - CRC: true, isBMSData: true
[14:47:11] [BMS] 📥 Received BMS response: 01034e14d000000d010d030d...
[14:47:11] [BMS] 📤 Writing BMS request: 01030000002705d0
[14:47:11] [BMS] ✅ Using real device data
[14:47:11] [BMS] Device connected: true
[14:47:11] [BMS] 📡 getBMSData() called

[14:47:06] [BMS] ✅ BMS data parsed successfully
[14:47:06] [BMS] 📡 getBMSData() called

[14:47:04] [PROTOCOL MANAGER] 🎉 All protocols loaded successfully!
```

**Protocol Statistics:**
```json
"statistics": {
    "totalLogs": 30,
    "successes": 10,
    "errors": 0,
    "warnings": 0
}
```

---

## 📊 LOG COMPARISON

| Aspect | Problem Case (Log 1) | Working Case (Log 2) | Difference |
|--------|----------------------|---------------------|------------|
| Connection | ✅ SUCCESS | ✅ SUCCESS | Same |
| Protocols loaded | ✅ YES (9 successes) | ✅ YES (10 successes) | Same |
| Protocol values | ID 1, P01-GRW × 2 | ID 1, P01-GRW × 2 | Same |
| **[BMS] logs** | ❌ **MISSING** | ✅ **PRESENT** | **DIFFERENT!** |
| BMS timer started | ❌ **NO** | ✅ **YES** | **DIFFERENT!** |
| getBMSData() called | ❌ **NO** | ✅ **YES** | **DIFFERENT!** |
| BMS data values | All zeros | Valid (53.28V, 80%, 16 cells) | Different |
| Raw packet | All zeros | Valid hex | Different |

---

## 🔍 ROOT CAUSE HYPOTHESIS

**Primary Hypothesis:**
BMS timer (`startRefreshBMSData()`) is **not being called** after protocol loading in some scenarios.

**From ConnectivityViewController.swift (lines 192-195):**
```swift
// BMS timer started 5 seconds after connection
DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
    ZetaraManager.shared.protocolDataManager.logProtocolEvent(
        "[CONNECTIVITY] Starting BMS timer after protocol loading delay"
    )
    ZetaraManager.shared.startRefreshBMSData()
}
```

**Possible failure scenarios:**

1. **DispatchQueue block never executes** (view dismissed before 5s delay?)
2. **startRefreshBMSData() called but timer doesn't start** (timer already exists?)
3. **Race condition** between protocol loading and BMS timer start
4. **Navigator pops before 5s** → DispatchQueue block cancelled

**Evidence supporting this:**
- Log 1 has **NO** `[CONNECTIVITY] Starting BMS timer after protocol loading delay` message
- Log 2 has **YES** BMS logs showing timer working
- Time gap in Log 1: 14:40:28 (Module ID) → 14:40:46 (logs sent) = 18 seconds
- Time gap in Log 2: 14:47:03 (RS485) → 14:47:13 (logs sent) = 10 seconds

**Investigation questions:**
1. Does Joshua navigate away from Diagnostics screen quickly in problem case?
2. Is there a pattern to when it works vs when it doesn't?
3. Should BMS timer start be tied to `viewDidLoad` or protocol loading completion, not navigation?

---

## 🛠 POTENTIAL FIXES (to investigate)

### Option 1: Move BMS timer start to protocol completion callback
Instead of 5s delay after connection, start timer when protocols actually finish loading.

### Option 2: Don't tie timer to DispatchQueue.main.asyncAfter
Use RxSwift subscription or notification instead of delayed dispatch.

### Option 3: Start BMS timer in DiagnosticsViewController
If user is on Diagnostics screen, screen should start timer itself.

### Option 4: Add failsafe check
If DiagnosticsViewController detects connected peripheral but no BMS data, trigger timer manually.

---

## 📊 METRICS

| Metric | Before Investigation | After Fix (TBD) | Target |
|--------|---------------------|----------------|--------|
| BMS data loads after connection | ~50% (1 of 2 logs) | TBD | 100% |
| BMS timer starts | Unreliable | TBD | 100% |
| User sees battery data | Sometimes | TBD | Always |

---

## 🎯 SUCCESS CRITERIA

Thread can be marked 🟢 RESOLVED when:
- [ ] Root cause identified
- [ ] Fix implemented
- [ ] BMS data loads 100% of time after successful connection
- [ ] Tested by Joshua with 5+ connections
- [ ] No reports of zero data in 1 week

---

## 💡 INVESTIGATION NOTES

**Questions for Joshua:**
1. In problem case (Log 1), did you navigate away from Diagnostics screen quickly?
2. How long after connection did you open Send Logs?
3. Does it happen every time or intermittently?
4. Any difference in behavior between fresh app launch vs reconnection?

**Code to review:**
- `ConnectivityViewController.swift:192-195` (BMS timer start with 5s delay)
- `ZetaraManager.swift:startRefreshBMSData()` (timer initialization)
- Navigation timing between screens

**Next steps:**
- [ ] Review DispatchQueue.main.asyncAfter lifecycle behavior
- [ ] Check if navigation pops before 5s delay completes
- [ ] Consider moving timer start to DiagnosticsViewController.viewDidLoad
- [ ] Add logging to track when timer start is attempted

---

## 📚 RELATED DOCUMENTATION

- **Discovered in**: THREAD-001 Build 31 testing
- **Related to**: Build 31/32 (not a regression, existing issue exposed by testing)
- **Logs location**: `docs/fix-history/logs/bigbattery_logs_20251027_*.json`
