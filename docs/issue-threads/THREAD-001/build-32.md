# Build 32: UITableView Crash Fixes

**Date:** 2025-10-28
**Status:** ⚠️ REGRESSION (Error 4 pattern changed)
**Attempt:** N/A (fixes from Build 31 side effects)

**Navigation:**
- ⬅️ Previous: [Build 31](build-31.md)
- ➡️ Next: [Build 33](build-33.md)
- 🏠 Main: [../THREAD-001.md](../THREAD-001.md)

---

## Test Execution:

Joshua tested Build 32 same day (28 October 2025), sent 4 diagnostic logs.

## Diagnostic Logs:

- Letter 1: `docs/fix-history/logs/bigbattery_logs_20251028_090206.json` - Changed ID 1→2, battery off/on, app shows connection but no info
- Letter 2: `docs/fix-history/logs/bigbattery_logs_20251028_090446.json` - Changed ID 2→1, unable to change protocols, homepage shows no info
- Letter 3: `docs/fix-history/logs/bigbattery_logs_20251028_090726.json` - Changed protocols GRW→LUX, reconnection "connection error"
- Letter 4: `docs/fix-history/logs/bigbattery_logs_20251029_090738.json` - Unable to make changes in settings

## Expected vs Reality Comparison:

| Expected (Build 32) | Reality (Logs) | Evidence | Status |
|---------------------|----------------|----------|---------|
| UITableView crashes resolved | ✅ RESOLVED | No crashes reported | ✅ SUCCESS |
| Error 4 eliminated (from Build 31) | ❌ **REGRESSION** | Error 4 occurs but in NEW pattern | 🔄 PARTIAL |
| Connection success rate 100% | ❌ FAILED | Only 1 of 4 logs successful (25%) | ❌ REGRESSION |
| BMS data loads consistently | ❌ FAILED | Only loads when connection fully succeeds | ❌ FAILED |

## Critical Discovery: Error 4 Pattern Changed

Build 31 eliminated error 4 in pre-flight phase, but Build 32 testing revealed error 4 **still occurs AFTER characteristics are configured**:

### OLD Pattern (Pre-Build 31):
```
Pre-flight detects problem → Connection fail → Error 4
```

### NEW Pattern (Build 32):
```
Pre-flight PASS → Connection starts → Services discovered →
Characteristics configured → Error 4 when writing to characteristics
```

## What This Means:

- ✅ Pre-flight validation works (stale peripherals correctly rejected)
- ✅ Connection establishment succeeds
- ✅ Service and characteristic discovery succeeds
- ❌ But characteristics become **STALE/INVALID** after disconnect
- ❌ Writing to cached stale characteristics causes error 4

## Root Cause Hypothesis:

iOS caches characteristics at the peripheral object level. After disconnect, these cached references become invalid. Even though we rediscover services/characteristics, iOS may return the stale cached versions.

## Verdict for THREAD-001:

🔄 **PARTIAL SUCCESS / MINOR REGRESSION** - Build 31's reconnection fix works (pre-flight validation prevents stale connections), but Build 32 revealed error 4 still occurs in a different phase. The original "invalid device" error is resolved, but characteristic caching causes error 4 after connection.

---

**Navigation:**
- ⬅️ Previous: [Build 31](build-31.md)
- ➡️ Next: [Build 33](build-33.md)
- 🏠 Main: [../THREAD-001.md](../THREAD-001.md)
