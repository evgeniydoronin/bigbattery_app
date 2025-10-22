# Fix Validation Checklist

**Цель:** Структурированный анализ логов после deploy fix. Сравнение reality vs expected behavior.

**Когда использовать:** После получения diagnostic logs от клиента, testing нового fix.

---

## ШАГ 1: Thread Context ✅

**КРИТИЧНО:** Начни с чтения Issue Thread!

- [ ] Opened relevant `THREAD-XXX` file in `docs/issue-threads/`
- [ ] Read **TIMELINE** section - all previous attempts
- [ ] Read **METRICS** table - what already improved/worsened
- [ ] Identify what fix was deployed last time (last ATTEMPT entry)
- [ ] Know **EXPECTED behavior** from last fix (what logs should show)

**Если Thread НЕ найден:**
- [ ] Create new THREAD-XXX using template
- [ ] Update `docs/issue-threads/README.md` table

---

## ШАГ 2: Log Collection & Organization 📥

- [ ] Copy new logs to `docs/fix-history/logs/`
  - Format: `bigbattery_logs_YYYYMMDD_HHMMSS.json`
- [ ] Count total logs received: `___` logs
- [ ] Note timestamps (from - to): `_______`
- [ ] Identify which test scenario each log represents:
  - Log 1: `____________` (scenario X)
  - Log 2: `____________` (scenario Y)
  - Log 3: `____________` (scenario Z)

---

## ШАГ 3: Expected vs Reality Comparison 📊

**Create comparison table** based on EXPECTED from thread:

### Attempt #__ Result Analysis

| Expected (from fix docs) | Reality (from new logs) | Evidence | Status |
|-------------------------|------------------------|----------|---------|
| [Event X] appears in logs | Found / NOT found | `[Quote log entry]` | ✅ / ❌ |
| [Metric Y] improved | Value: ___ | `[Quote]` | ✅ / ❌ |
| [Error Z] eliminated | Frequency: ___ | `[Quote]` | ✅ / ❌ |

**Example:**

| Expected | Reality | Evidence | Status |
|----------|---------|----------|--------|
| [DISCONNECT] events visible | **NOT found** in ANY log | No "[DISCONNECT]" in recentLogs | ❌ WORSE |
| Disconnect detected in 5s | Not detected at all | No disconnect logged | ❌ WORSE |
| No "error 4" | Still present in all 3 logs | "[CONNECTIVITY] Connection failed: error 4" | ❌ SAME |
| cleanConnection called immediately | Only after error | Timeline shows cleanup AFTER error | ❌ SAME |

---

## ШАГ 4: Log Deep Dive 🔍

For EACH diagnostic log file:

### Log Analysis Template

**File:** `___________`
**Timestamp:** `___________`
**Scenario:** `___________`

#### 4.1 Protocol Info
```
Current Values:
- moduleId: ___
- rs485Protocol: ___
- canProtocol: ___

Statistics:
- errors: ___
- warnings: ___
- successes: ___
```

#### 4.2 Recent Logs Timeline

Extract `recentLogs` and reverse (chronological order):

```
[TIME] [COMPONENT] Message
[TIME] [COMPONENT] Message
...
```

#### 4.3 Key Events Checklist

- [ ] Connection attempt logged?
  - [ ] Peripheral name logged?
  - [ ] Peripheral UUID logged?
  - [ ] Peripheral STATE logged? (Expected: pre-flight check)
- [ ] Disconnect event logged?
  - [ ] [DISCONNECT] message? (iOS event)
  - [ ] [HEALTH] detection? (proactive monitor)
  - [ ] [CONNECTIVITY] viewWillAppear check?
- [ ] Cleanup executed?
  - [ ] When: BEFORE error or AFTER error?
  - [ ] [CONNECTION] Cleaning connection state
  - [ ] [CONNECTION] Scanned peripherals cleared
- [ ] Errors present?
  - [ ] BluetoothError error 4?
  - [ ] PHANTOM connection?
  - [ ] Other errors?

#### 4.4 Missing Expected Events

List events we EXPECTED to see but are MISSING:

- ❌ Missing: `___________`
- ❌ Missing: `___________`

#### 4.5 Unexpected Events

List events we DID NOT expect but ARE present:

- ⚠️ Unexpected: `___________`
- ⚠️ Unexpected: `___________`

---

## ШАГ 5: Metrics Update 📈

**Update METRICS table in Thread:**

Go to `THREAD-XXX` file → **📊 METRICS** section

Add new column for this attempt:

```markdown
| Metric | Before | After Attempt #1 | After Attempt #2 | Target |
|--------|--------|------------------|------------------|--------|
| Metric 1 | X | Y | **Z** ← ADD | 100% |
| Metric 2 | A | B | **C** ← ADD | 0% |
```

**Calculate:**
- Success rate: `____%`
- Error rate: `____%`
- Improvement: `____% → ____%` (+ ____ %)

---

## ШАГ 6: Root Cause Re-evaluation 🧠

**Questions to answer:**

- [ ] Is current ROOT CAUSE understanding still correct?
  - YES → Continue with same approach
  - NO → Update understanding (see below)

- [ ] Do new logs reveal something we MISSED?
  - List new insights: `___________`

- [ ] Need to update **ROOT CAUSE EVOLUTION** in Thread?
  - YES → Add new entry with date
  - NO → Current understanding still valid

**If understanding changed:**

```markdown
### Updated Understanding (2025-XX-XX after Attempt #N):
[Explain what we learned from new logs]
[Why previous hypothesis was wrong/incomplete]
[New hypothesis based on evidence]
```

---

## ШАГ 7: Decision Matrix 🎯

Based on comparison (Step 3) and metrics (Step 5), choose ONE:

### Option A: ✅ FIX WORKED

**Criteria:**
- [ ] All expected events present in logs
- [ ] All test scenarios passed
- [ ] Metrics improved significantly (> 80%)
- [ ] No regressions
- [ ] Client confirmed success

**Action:**
- [ ] Mark attempt as **SUCCESS** in Thread
- [ ] Update METRICS table
- [ ] Add "What Got Better" list
- [ ] Change Thread status: 🔴 ACTIVE → 🟡 IN PROGRESS
- [ ] Update SUCCESS CRITERIA progress
- [ ] Plan monitoring period

---

### Option B: ❌ FIX FAILED

**Criteria:**
- [ ] Expected events MISSING in logs
- [ ] All/most test scenarios failed
- [ ] Metrics unchanged or worse
- [ ] Same error pattern as before

**Action:**
- [ ] Mark attempt as **FAILED** in Thread
- [ ] Update METRICS table (show no improvement)
- [ ] Add "What Got Worse" (if any)
- [ ] Analyze WHY fix failed:
  - [ ] Wrong hypothesis?
  - [ ] Implementation bug?
  - [ ] Missing piece?
- [ ] Update ROOT CAUSE EVOLUTION
- [ ] Plan NEW hypothesis (Attempt #N+1)
- [ ] Thread status remains: 🔴 ACTIVE

---

### Option C: 🔄 PARTIAL SUCCESS

**Criteria:**
- [ ] Some scenarios passed, some failed
- [ ] Metrics improved but not to target
- [ ] Some expected events present, some missing
- [ ] Improvement visible but incomplete

**Action:**
- [ ] Mark attempt as **PARTIAL** in Thread
- [ ] Update METRICS table (show partial improvement)
- [ ] List "What Got Better" AND "What's Still Broken"
- [ ] Identify which parts worked, which didn't
- [ ] Plan iteration to address remaining issues
- [ ] Thread status: 🔴 ACTIVE or 🟡 IN PROGRESS (depending on severity)

---

## ШАГ 8: Update Thread Timeline 📝

**Add new entry in THREAD-XXX:**

```markdown
### 📅 2025-XX-XX: ATTEMPT #N Result

**Test Result:** ✅ SUCCESS / ❌ FAILED / 🔄 PARTIAL

**Client Testing:**
[Quote client feedback or describe test scenarios]

**Diagnostic Logs:**
- Scenario 1: `docs/fix-history/logs/filename1.json`
- Scenario 2: `docs/fix-history/logs/filename2.json`
- Scenario 3: `docs/fix-history/logs/filename3.json`

**What Got Better:**
- [Specific improvement 1] (Evidence: `[quote log]`)
- [Specific improvement 2] (Evidence: `[quote log]`)
- OR: Nothing improved.

**What Got Worse:**
- [Regression 1] (Evidence: `[quote log]`)
- OR: Nothing worse.

**What Stayed Same:**
- [Issue still present] (Evidence: `[quote log]`)

**Logs Evidence:**
```
[Key log entries showing result]
```

**Root Cause Update:**
[If understanding changed, explain]

**Next Steps:**
- [ ] Action 1
- [ ] Action 2
```

---

## ШАГ 9: Communication 💬

**If FIX WORKED (✅):**
- [ ] Notify client: "Fix deployed, please continue testing"
- [ ] Request continued monitoring logs
- [ ] Set monitoring period (e.g., 1 week)

**If FIX FAILED (❌):**
- [ ] Acknowledge issue to client
- [ ] Explain what we learned
- [ ] Set expectation for next attempt
- [ ] Request patience

**If PARTIAL (🔄):**
- [ ] Celebrate improvements
- [ ] Acknowledge remaining issues
- [ ] Share plan for completion
- [ ] Request targeted testing of specific scenarios

---

## ШАГ 10: Next Actions Planning 🚀

### If SUCCESS:
- [ ] Monitor logs for 1-2 weeks
- [ ] Update Thread status → 🟢 RESOLVED when stable
- [ ] Document lessons learned
- [ ] Close Thread after 2+ weeks no recurrence

### If FAILED or PARTIAL:
- [ ] Create NEW hypothesis
- [ ] Design Attempt #N+1
- [ ] Get user approval for new plan
- [ ] Implement and test
- [ ] Repeat this checklist when new logs arrive

---

## Quick Reference: Thread Status Transitions

```
🔴 ACTIVE (issue exists, needs fix)
    ↓
🟡 IN PROGRESS (fix deployed, testing)
    ↓
🟢 RESOLVED (fix confirmed working, monitoring)
    ↓
⚫ CLOSED (stable for 2+ weeks, no recurrence)
```

**Regression path:**
```
🟢 RESOLVED or ⚫ CLOSED
    ↓ (issue returns)
🔴 ACTIVE (reopened with new timeline entry)
```

---

## Templates for Quick Copy-Paste

### Comparison Table Template
```markdown
| Expected | Reality | Evidence | Status |
|----------|---------|----------|--------|
|          |         |          | ✅ / ❌ |
```

### Timeline Entry Template
```markdown
### 📅 2025-XX-XX: ATTEMPT #N Result

**Test Result:** ✅ / ❌ / 🔄

**What Got Better:**
-

**What Got Worse:**
-

**Logs Evidence:**
```
[logs]
```

**Next Steps:**
- [ ]
```

---

**Created:** 2025-10-21
**Last Updated:** 2025-10-21
