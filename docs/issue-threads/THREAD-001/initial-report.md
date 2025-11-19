# Initial Report: Invalid Device Error After Battery Reconnection

**Date:** 2025-10-10
**Client:** Joshua (BigBattery ETHOS module BB-51.2V100Ah-0855)

**Navigation:**
- 🏠 Main: [../THREAD-001.md](../THREAD-001.md)

---

## Client Report

**Joshua:**
> After the battery restart, I went to the Bluetooth screen and
> tried to reconnect but now I'm getting "invalid" when clicking
> on the battery 855.

## Diagnostic Logs

- Before restart: `docs/fix-history/logs/bigbattery_logs_20251010_153756.json`
- After restart: `docs/fix-history/logs/bigbattery_logs_20251010_153942.json`
- Timestamp: 15:37-15:39 10.10.2025

## Initial Symptoms

- ✅ Battery connected successfully before restart
- ✅ Protocols saved successfully (ID 1, P02-LUX, P06-LUX)
- ❌ After battery restart: "Invalid BigBattery device" error
- ❌ Voltage = 0, no battery data
- ⚠️ PHANTOM connection detected in logs

## Evidence from Logs

```
[Before restart - 15:37:56]
"peripheralName": "BB-51.2V100Ah-0855"
"peripheralIdentifier": "1997B63E-02F2-BB1F-C0DE-63B68D347427"
"rs485Protocol": "P02-LUX"
"canProtocol": "P06-LUX"

[After restart - 15:39:42]
// NO peripheralName!
// NO peripheralIdentifier!
"rs485Protocol": "--"
"canProtocol": "--"
"recentLogs": [
  "[15:39:25] [CONNECTION] ⚠️ PHANTOM: No peripheral but BMS timer running!",
  "[15:39:25] [CONNECTION] Cleaning connection state"
]
```

## Initial Root Cause

Stale peripheral references in `scannedPeripherals` array not cleared after battery disconnect.

## Initial Fix (Oct 10)

Added `cleanScanning()` call in `cleanConnection()` method to clear stale peripherals.

## Related Documentation

- `docs/fix-history/2025-10-10_reconnection-after-restart-bug.md`

---

**Navigation:**
- 🏠 Main: [../THREAD-001.md](../THREAD-001.md)
