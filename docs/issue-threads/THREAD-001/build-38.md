# Build 38: Persistent Connection Request Pattern

**Date:** 2025-11-17
**Status:** ⏳ TESTING (awaiting results)
**Attempt:** #8

**Navigation:**
- ⬅️ Previous: [Build 37](build-37.md)
- ➡️ Next: [Build 39](build-39.md)
- 🏠 Main: [../THREAD-001.md](../THREAD-001.md)

---

## Build 38 Hypothesis:

After Build 37 failure and deep research into Apple CoreBluetooth documentation, we identified the FUNDAMENTAL architectural flaw:

**Problem:** Our cleanup logic IMPLICITLY CANCELS iOS connection requests by clearing peripheral references.

### Apple Documentation Discovery:

- "Connection requests do not time out"
- "iOS will automatically reconnect when peripheral comes back in range"
- **BUT ONLY IF** the connection request remains active!

### What We Were Doing Wrong (Builds 34-37):

1. Battery disconnects
2. We call `cleanConnection()` → clears `connectedPeripheralSubject`
3. This IMPLICITLY cancels the connection request at iOS level
4. iOS no longer "watching" for peripheral to return
5. Manual scan required every time

**Root Cause:** We were fighting AGAINST iOS CoreBluetooth design instead of working WITH it.

## Build 38 Solution:

**Core Strategy:** Persistent Connection Request Pattern

### Implementation:

1. **Persistent Storage (UserDefaults)**
   - Store last connected peripheral UUID across app sessions
   - Enable/disable auto-reconnect feature (default: enabled)
   - Lines: ZetaraManager.swift ~88-104

2. **UUID Persistence on Connection**
   - Save UUID to BOTH memory AND UserDefaults
   - Ensures UUID survives app restarts
   - Lines: ZetaraManager.swift ~380-386

3. **Modified didDisconnect Handler (CRITICAL)**
   - Call `cleanConnectionPartial()` instead of full cleanup
   - Trigger `attemptAutoReconnect()` if enabled
   - Keep connection foundation alive
   - Lines: ZetaraManager.swift ~128-159

4. **Partial Cleanup Method**
   - Clear ONLY invalidated data (characteristics)
   - Keep UUID, peripheral subject for reconnect
   - Apple: "All characteristics become invalidated after disconnect"
   - Lines: ZetaraManager.swift ~510-550

5. **Auto-Reconnect Method**
   - Use `retrievePeripherals(withIdentifiers:)` - NO scan needed!
   - Call `establishConnection()` - creates PERSISTENT request
   - Connection request survives power cycles
   - Lines: ZetaraManager.swift ~557-633

6. **Service Rediscovery**
   - Rediscover services/characteristics with fresh handles
   - Auto-load protocols after 1.5s
   - Start BMS timer after 5s
   - Lines: ZetaraManager.swift ~640-720

7. **Full Cleanup for Manual Disconnect**
   - Clear persistent UUID from UserDefaults
   - Disable auto-reconnect for this device
   - Lines: ZetaraManager.swift ~463-509

8. **UI Status Update**
   - Show "Reconnecting..." when auto-reconnect active
   - Lines: ConnectivityViewController.swift ~266-280

## Technical Details:

### Files Modified:

1. `BatteryMonitorBL.xcodeproj/project.pbxproj` - Version 37→38
2. `Zetara/Sources/ZetaraManager.swift` - ~200 lines added/modified
3. `BatteryMonitorBL/ConnectivityViewController.swift` - ~15 lines added

### Key Methods Added:

```swift
// Persistent storage properties
private let lastConnectedUUIDKey = "com.zetara.lastConnectedPeripheralUUID"
public var autoReconnectEnabled: Bool { get set }

// Partial cleanup - preserve UUID
private func cleanConnectionPartial()

// Auto-reconnect using retrievePeripherals
private func attemptAutoReconnect(peripheralUUID: String)

// Service rediscovery with fresh handles
private func rediscoverServicesAndCharacteristics(peripheral: Peripheral)
```

## Expected Behavior:

### Test Scenario 1: Battery Restart (Within Session)

```
1. Battery connected, protocols loaded
2. Battery powers off (restart)
3. iOS detects disconnect → didDisconnect fires
4. Partial cleanup (preserve UUID)
5. attemptAutoReconnect() called
6. retrievePeripherals(withIdentifiers:) gets fresh instance
7. establishConnection() creates persistent request
8. Battery powers back on
9. iOS AUTO-CONNECTS (no scan needed!)
10. Rediscover services/characteristics
11. Auto-load protocols
12. Resume BMS data
```

### Test Scenario 2: Battery Restart (Cross-Session)

```
1. Battery connected
2. Battery powers off
3. User closes app
4. User reopens app (new session)
5. App reads UUID from UserDefaults
6. Calls attemptAutoReconnect() at launch
7. establishConnection() creates persistent request
8. Battery powers back on
9. iOS AUTO-CONNECTS
10. Full reconnection sequence
```

### Test Scenario 3: Manual Disconnect

```
1. User taps "Disconnect" button
2. cleanConnection() called (full cleanup)
3. Clears UUID from UserDefaults
4. Auto-reconnect disabled for this device
5. User must manually scan next time
```

### Test Scenario 4: Settings Save (Battery Restart)

```
1. User changes protocol settings
2. Battery restarts (firmware requirement)
3. Auto-reconnect triggered
4. Connection re-established
5. Protocols auto-loaded with NEW settings
6. BMS data resumes
```

## Success Criteria:

**Build 38 = SUCCESS if:**
- ✅ Auto-reconnect works after battery restart (NO manual scan)
- ✅ Auto-reconnect works across app sessions
- ✅ "Reconnecting..." UI status displayed
- ✅ Protocols auto-load after reconnect
- ✅ BMS data resumes automatically
- ✅ NO regression in existing features (Settings display, etc.)

**Build 38 = PARTIAL if:**
- ⚠️ Auto-reconnect works sometimes (inconsistent)
- ⚠️ Works within session but NOT cross-session
- ⚠️ Requires multiple attempts

**Build 38 = FAILED if:**
- ❌ No auto-reconnect (same as Build 37)
- ❌ Manual scan still required
- ❌ Regressions in existing features
- ❌ Crashes or errors

## Expected Log Patterns:

### Successful Auto-Reconnect:

```
[DISCONNECT] 🔌 Device disconnected: BigBattery ETHOS
[DISCONNECT] UUID: 1997B63E-02F2-BB1F-C0DE-63B68D347427
[CLEANUP] Partial cleanup - preserving UUID for auto-reconnect
[RECONNECT] ⚡ Starting auto-reconnect sequence
[RECONNECT] ✅ Retrieved fresh peripheral instance
[RECONNECT] 🔌 Establishing persistent connection request
[RECONNECT] Persistent connection request established ✅
[RECONNECT] Waiting for peripheral to come back in range...
[RECONNECT] ✅ ✅ ✅ AUTO-RECONNECT SUCCESSFUL!
[RECONNECT] 🔍 Rediscovering services and characteristics
[RECONNECT] ✅ Characteristics rediscovered successfully
[RECONNECT] 🔄 Auto-loading protocols after reconnection
[RECONNECT] ⏱️ Starting BMS timer after reconnection
[RECONNECT] 🎉 🎉 🎉 AUTO-RECONNECTION COMPLETE!
```

### Manual Disconnect:

```
[CLEANUP] 🔴 Full cleanup requested (MANUAL disconnect)
[CLEANUP] Cleared persistent UUID from storage (auto-reconnect disabled)
[CONNECTION] Cached device UUID cleared (memory)
```

## Comparison with Build 37:

| Metric | Build 37 | Build 38 (Expected) |
|--------|----------|---------------------|
| Auto-reconnect | ❌ 0% | ✅ 95%+ |
| Manual scan required | ✅ Yes | ❌ No |
| Cross-session reconnect | ❌ No | ✅ Yes |
| Error 4 frequency | Present | ✅ Eliminated |
| Settings display | ✅ Works | ✅ Works |
| DiagnosticsViewController crash | ✅ Fixed | ✅ Fixed |
| UI feedback | Basic | ✅ "Reconnecting..." status |
| Code execution rate | 0% (blocked) | ✅ 100% |

## Architectural Advantages:

### Why This Approach Works:

1. **Works WITH iOS, not against it**
   - Uses Apple's intended persistent connection pattern
   - No fighting iOS lifecycle

2. **Minimal risk to existing features**
   - Partial cleanup preserves what's needed
   - Full cleanup still available for manual disconnect

3. **Cross-session persistence**
   - UserDefaults survives app restarts
   - Automatic reconnection even after app closed

4. **Comprehensive logging**
   - ~30 new log points
   - Easy to debug if issues arise

5. **User control**
   - Auto-reconnect can be toggled
   - Respects user's manual disconnect

## Potential Issues to Monitor:

1. **iOS peripheral retention**
   - What if iOS forgets peripheral between sessions?
   - Fallback: User sees "Reconnecting..." and can scan

2. **Battery UUID changes**
   - Some devices generate new UUIDs
   - Fallback: Manual scan required

3. **Multiple batteries**
   - Currently stores only ONE last connected UUID
   - Future: Could extend to multiple devices

4. **Connection timeout**
   - iOS connection requests don't timeout
   - But user might want manual cancel option

---

**Navigation:**
- ⬅️ Previous: [Build 37](build-37.md)
- ➡️ Next: [Build 39](build-39.md)
- 🏠 Main: [../THREAD-001.md](../THREAD-001.md)
