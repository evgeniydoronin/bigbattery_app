# THREAD-001: Invalid Device Error After Battery Reconnection

**Status:** BUILD 43 TESTING
**Severity:** CRITICAL
**First Reported:** 2025-10-10
**Last Updated:** 2025-11-25
**Client:** Joshua (BigBattery ETHOS module BB-51.2V100Ah-0855)

---

## Quick Summary

### Current Status (Build 43):

**Testing Phase:** Build 43 currently being tested by Joshua

**What's Fixed:**
- Build 31: Initial reconnection issue (scan list validation)
- Build 34-35: Fresh peripheral retrieval at launch
- Build 36: Settings screen protocol display
- Build 37: DiagnosticsViewController crash fix
- Build 38: Persistent connection request pattern
- Build 39: Startup auto-reconnect (works correctly!)
- Build 40: Health monitor partial cleanup
- Build 41: viewWillAppear partial cleanup
- Build 42: writeControlData/getBMSData cleanup removed

**What's Being Fixed (Build 43):**
- PHANTOM detection (lines 961, 985) calling cleanConnection()
- Mid-session auto-reconnect failing due to UUID destruction

**Root Cause (Build 42 -> 43):**
- Build 42 fix worked (no cleanup after getBMSData error in logs)
- But PHANTOM detection still calls cleanConnection() and destroys UUID
- Logs showed: `[PHANTOM: No peripheral but BMS timer running!]` followed by `[CLEANUP] Full cleanup`

**Expected Outcome:**
- Complete auto-reconnect feature (mid-session + startup)
- No manual scans required
- PHANTOM detection preserves UUID and triggers auto-reconnect

---

## Build History

| Build | Date | Status | Description | File |
|-------|------|--------|-------------|------|
| 28 | 2025-10-20 | ❌ FAILED | Global Disconnect Handler | [build-28.md](THREAD-001/build-28.md) |
| 29 | 2025-10-24 | 🔄 PARTIAL | Proactive State Monitoring | [build-29.md](THREAD-001/build-29.md) |
| 30 | 2025-10-27 | ❌ CATASTROPHIC | Pre-flight Abort | [build-30.md](THREAD-001/build-30.md) |
| 31 | 2025-10-27 | ✅ SUCCESS | Pre-flight Scan List | [build-31.md](THREAD-001/build-31.md) |
| 32 | 2025-10-28 | ⚠️ REGRESSION | UITableView Fixes | [build-32.md](THREAD-001/build-32.md) |
| 33 | 2025-10-30 | ❌ FAILED | Fresh Peripheral | [build-33.md](THREAD-001/build-33.md) |
| 34 | 2025-10-30 | ✅/❌ MIXED | Launch-Time Fresh | [build-34.md](THREAD-001/build-34.md) |
| 35 | 2025-10-30 | ✅ SUCCESS | Prevent Refresh | [build-35.md](THREAD-001/build-35.md) |
| 36 | 2025-11-07 | ✅ SUCCESS | Settings Display | [build-36.md](THREAD-001/build-36.md) |
| 37 | 2025-11-14 | ❌ FAILED | Connection Stability | [build-37.md](THREAD-001/build-37.md) |
| 38 | 2025-11-17 | ⏳ TESTING | Persistent Connection | [build-38.md](THREAD-001/build-38.md) |
| 39 | 2025-11-18 | PARTIAL | Startup Auto-Reconnect | [build-39.md](THREAD-001/build-39.md) |
| 40 | 2025-11-19 | PARTIAL | Health Monitor Fix | [build-40.md](THREAD-001/build-40.md) |
| 41 | 2025-11-19 | PARTIAL | ViewWillAppear Fix | [build-41.md](THREAD-001/build-41.md) |
| 42 | 2025-11-25 | PARTIAL | writeControlData/getBMSData Fix | [build-42.md](THREAD-001/build-42.md) |
| 43 | 2025-11-25 | TESTING | PHANTOM Detection Fix | [build-43.md](THREAD-001/build-43.md) |

---

## Key Milestones

### Major Achievements:

- **Build 31 (2025-10-27):** ✅ Initial reconnection issue RESOLVED
  - Scan list validation prevents stale peripheral connections
  - Pre-flight checks ensure fresh peripherals only

- **Build 36 (2025-11-07):** ✅ Settings display RESOLVED
  - Protocol information persists after reconnect
  - DisposeBag subscriptions remain active

- **Builds 38-41 (2025-11-17 to 11-19):** 🎯 Auto-reconnect feature (in progress)
  - Build 38: Persistent connection request pattern
  - Build 39: Startup auto-reconnect (works correctly!)
  - Build 40: Health monitor partial cleanup (correct but incomplete)
  - Build 41: Fix viewWillAppear() UUID destruction (final piece)

---

## Metrics

| Metric | Before Any Fix | Build 29 | Build 30 | Build 31 | Build 32 | Build 33 | Build 34 (Expected) | Build 34 (Actual) | Build 35 (Expected) | Build 35 (Actual) | Build 36 (Expected) | Build 36 (Actual) | Build 37 (Actual) | Build 40 (Expected) | Target |
|--------|----------------|----------|----------|----------|----------|----------|---------------------|-------------------|---------------------|-------------------|---------------------|-------------------|-------------------|---------------------|--------|
| Connection success rate | 0% | 0% ❌ | **0% (ALL BLOCKED)** 💥 | **100%** ✅ | **25%** ⚠️ | **0%** ❌ | **100%** 🎯 | **100%** ✅ | **100%** 🎯 | **Partial** ⚠️ | **100%** 🎯 | **75%** ⚠️ | **0%** ❌ | **100%** 🎯 | 100% |
| Error 4 frequency | 100% | 100% ❌ | N/A | **0% (pre-flight)** ✅ | **75% (post-connect)** ⚠️ | **100%** ❌ | **0%** 🎯 | **0%** ✅ | **0%** 🎯 | **Some** ⚠️ | **0%** 🎯 | **Some** ⚠️ | **Some** ⚠️ | **0%** 🎯 | 0% |
| Normal connections work | 100% | 100% ✅ | **0%** 💥 | **100%** ✅ | **25%** ⚠️ | **0%** ❌ | **100%** 🎯 | **100%** ✅ | **100%** 🎯 | **Partial** ⚠️ | **100%** 🎯 | **Partial** ⚠️ | **Partial** ⚠️ | **100%** 🎯 | 100% |
| BMS data loads | 100% | 100% ✅ | N/A | **Partial** 🔄 | **25%** ⚠️ | **0%** ❌ | **100%** 🎯 | **100%** ✅ | **100%** 🎯 | **100%** ✅ | **100%** 🎯 | **100%** ✅ | Not tested | **100%** 🎯 | 100% |
| Disconnect detected | No | **YES (Layer 1)** ✅ | **YES** ✅ | **YES** ✅ | **YES** ✅ | **YES** ✅ | **YES** ✅ | **YES** ✅ | **YES** ✅ | **YES** ✅ | **YES** ✅ | **YES** ✅ | **YES** ✅ | **YES** ✅ | Yes |
| Pre-flight validation | N/A | **Partial** 🔄 | **WRONG** 💥 | **CORRECT** ✅ | **CORRECT** ✅ | **CORRECT** ✅ | **CORRECT** ✅ | **CORRECT** ✅ | **CORRECT** ✅ | **CORRECT** ✅ | **CORRECT** ✅ | **CORRECT** ✅ | **CORRECT** ✅ | **CORRECT** ✅ | Yes |
| Fresh peripheral in connect() | ❌ | ❌ | ❌ | ❌ | ❌ | **YES (not called)** 🔄 | **YES** ✅ | **YES** ✅ | **YES** ✅ | **YES** ✅ | **YES** ✅ | **YES** ✅ | **NOT REACHED** ❌ | **YES** ✅ | Yes |
| Fresh peripheral at launch | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | **YES** 🎯 | **YES (no logs)** ⚠️ | **YES** 🎯 | **YES** ✅ | **YES** ✅ | **YES** ✅ | Not tested | **YES** ✅ | Yes |
| Stale peripheral detection | No | **YES** ✅ | **TOO AGGRESSIVE** 💥 | **CORRECT** ✅ | **CORRECT** ✅ | **CORRECT** ✅ | **CORRECT** ✅ | **CORRECT** ✅ | **CORRECT** ✅ | **CORRECT** ✅ | **CORRECT** ✅ | **CORRECT** ✅ | **CORRECT** ✅ | **CORRECT** ✅ | Yes |
| UITableView crashes | No | No | N/A | **YES** ❌ | **FIXED** ✅ | **FIXED** ✅ | **FIXED** ✅ | **FIXED** ✅ | **FIXED** ✅ | **FIXED** ✅ | **FIXED** ✅ | **FIXED** ✅ | **FIXED** ✅ | **FIXED** ✅ | No crashes |
| Crash on disconnect | No | No | No | No | No | No | No | **YES** ❌ | **FIXED** 🎯 | **FIXED** ✅ | **FIXED** ✅ | **FIXED** ✅ | **FIXED** ✅ | **FIXED** ✅ | No crashes |
| Settings protocols display | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | **"--"** ❌ | **Correct** 🎯 | **✅ SUCCESS!** | Not tested | **Correct** ✅ | Always show correctly |
| DiagnosticsViewController crash | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | **✅ FIXED!** | **FIXED** ✅ | No crashes |
| Auto-reconnect (mid-session) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | **100%** 🎯 | 100% |
| Auto-reconnect (startup) | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | **100%** 🎯 | 100% |

**Key Performance Indicators:**
- ✅ SUCCESS if: All 3 test scenarios pass, no error 4, disconnect < 5s
- 🔄 PARTIAL if: Some scenarios pass, improved but not 100%
- ❌ FAILED if: No improvement or worse than before

---

## Evolution Summary

### Phase 1: Initial Investigation (Builds 28-29)
**Problem:** iOS doesn't fire disconnect events for physical power off
**Discovery:** Need proactive state monitoring, not reactive event handling
**Status:** Detection works, prevention doesn't

### Phase 2: Pre-flight Validation (Builds 30-31)
**Problem:** iOS caches peripheral instances across scans
**Solution:** Validate against scan list membership, not peripheral.state
**Status:** ✅ Reconnection issue RESOLVED (Build 31)

### Phase 3: Characteristic Caching (Builds 32-35)
**Problem:** iOS caches characteristics at peripheral level
**Solution:** Retrieve fresh peripheral at launch + prevent race conditions
**Status:** ✅ Connection works, crash fixed (Build 35)

### Phase 4: Settings Display (Build 36)
**Problem:** DisposeBag destroyed killing RxSwift subscriptions
**Solution:** Keep subscriptions alive throughout ViewController lifecycle
**Status:** ✅ Settings display RESOLVED (Build 36)

### Phase 5: Auto-Reconnect Feature (Builds 37-40)
**Problem:** Manual scans still required after disconnect
**Attempt #7 (Build 37):** Force cache release → ❌ Code never executed
**Attempt #8 (Build 38):** Persistent connection request pattern
**Attempt #9 (Build 39):** Add startup auto-reconnect trigger
**Attempt #10 (Build 40):** Fix health monitor to use partial cleanup
**Status:** ⏳ TESTING (Build 40)

---

## Related Files

- [Initial Report](THREAD-001/initial-report.md) - First reported issue details
- [Root Cause Evolution](THREAD-001/root-cause-evolution.md) - How understanding evolved
- [All Build Files](THREAD-001/) - Individual build documentation

---

## Related Threads

- **THREAD-002:** BMS Data Loading Issues
- **THREAD-003:** UITableView Crashes

---

## Testing Status

### Build 40 Test Plan:

**Priority Tests (FAILED in Build 39):**
1. Test 1: Mid-session reconnect (battery restart)
2. Test 2: Settings screen after save
3. Test 5: Multiple disconnect cycles

**Regression Tests (PASSED in Build 39):**
4. Test 3: Cross-session reconnect (app restart)
5. Test 4: App restart reconnect

### Expected Outcome:

✅ 5/5 tests passing (complete auto-reconnect feature)
✅ No manual intervention required
✅ Works for all disconnect scenarios
✅ Health monitor properly integrated

---

## Documentation Structure

```
docs/issue-threads/
├── THREAD-001.md (this file)
└── THREAD-001/
    ├── initial-report.md
    ├── root-cause-evolution.md
    ├── build-28.md
    ├── build-29.md
    ├── build-30.md
    ├── build-31.md
    ├── build-32.md
    ├── build-33.md
    ├── build-34.md
    ├── build-35.md
    ├── build-36.md
    ├── build-37.md
    ├── build-38.md
    ├── build-39.md
    └── build-40.md
```

Each build file contains:
- Problem analysis
- Solution implementation
- Test results
- Lessons learned
- Navigation links

---

**Last Updated:** 2025-11-19 (Build 40 deployed for testing)
