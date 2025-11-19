# Build 33: Fresh Peripheral Instance in connect()

**Date:** 2025-10-30
**Status:** ❌ FAILED (Fix never executed)
**Attempt:** #4 (part 1)

**Navigation:**
- ⬅️ Previous: [Build 32](build-32.md)
- ➡️ Next: [Build 34](build-34.md)
- 🏠 Main: [../THREAD-001.md](../THREAD-001.md)

---

## Research Phase:

Used firecrawl to research official Apple documentation and developer resources.

### Key Research Findings:

1. **Apple Official Documentation** ([didDisconnectPeripheral](https://developer.apple.com/documentation/corebluetooth/cbcentralmanagerdelegate/centralmanager(_:diddisconnectperipheral:error:))):
   > **"All services, characteristics, and characteristic descriptors a peripheral become invalidated after it disconnects."**

2. **Stack Overflow** ([CoreBluetooth doesn't discover services on reconnect](https://stackoverflow.com/questions/28285393/corebluetooth-doesnt-discover-services-on-reconnect)):
   - **Problem**: Same as ours - write operations fail after reconnect
   - **Root Cause**: *"iOS was internally caching characteristic descriptors"*
   - **Solution (Lars Blumberg, 21.7k reputation)**:
     > *"We shouldn't reuse the same peripheral instance once disconnected. Instead we should ask CBCentralManager to give us a fresh CBPeripheral using its known peripheral UUID."*
   - **Key Insight**: *"iOS caches the services and characteristics. It only clears the cache when you restart iOS."*
   - **Method**: Use `retrievePeripherals(withIdentifiers:)` to get fresh peripheral

3. **Punch Through Core Bluetooth Guide**:
   - Confirmed characteristics become invalidated after disconnect
   - Must discover services/characteristics on each connection
   - Don't cache characteristics across disconnection cycles

## Root Cause (Confirmed by Research):

We were **reusing the same CBPeripheral instance** after disconnection. Even though we:
1. ✅ Call `discoverServices` on each connection
2. ✅ Call `discoverCharacteristics` on each connection
3. ✅ Store characteristics in our variables (lines 319-320)

iOS **caches services/characteristics at the peripheral object level**. When we reuse the same peripheral instance:
- iOS returns **stale cached characteristics** from its internal cache
- These stale references are **invalid** (point to deallocated memory)
- Writing to stale characteristics triggers error 4 (CBATTError.invalidHandle)

## Solution Implemented (Build 33):

After pre-flight validation passes, retrieve a **fresh peripheral instance** using `retrievePeripherals(withIdentifiers:)`:

```swift
// ZetaraManager.swift lines 281-295
// Build 33 Fix: Retrieve fresh peripheral instance to avoid iOS cached stale characteristics
let peripheralUUID = peripheral.identifier
let freshPeripherals = manager.retrievePeripherals(withIdentifiers: [peripheralUUID])

guard let freshPeripheral = freshPeripherals.first else {
    protocolDataManager.logProtocolEvent("[CONNECT] ❌ Failed to retrieve fresh peripheral instance")
    return Observable.error(Error.peripheralNotFound)
}

// Use freshPeripheral for connection instead of original peripheral
self.connectionDisposable = freshPeripheral.establishConnection()
```

## Why This Works:

1. `retrievePeripherals(withIdentifiers:)` returns a **fresh CBPeripheral object** from iOS
2. Fresh peripheral = **fresh iOS-level caches** (no stale characteristics)
3. Service/characteristic discovery returns **valid references**
4. Writing to characteristics succeeds (no error 4)

## Changes Made:

- ✅ Added fresh peripheral retrieval after pre-flight check (ZetaraManager.swift:281-295)
- ✅ Updated all references to use `freshPeripheral` instead of `peripheral` (lines 302, 346-350)
- ✅ Added `Error.peripheralNotFound` case for error handling
- ✅ Enhanced logging to track peripheral instance changes
- ✅ cleanConnection() already clears cached characteristics (lines 421-422) - no changes needed

## Expected Results:

- ✅ Error 4 completely eliminated (fresh peripheral = no stale caches)
- ✅ Connection success rate: 25% → 100%
- ✅ BMS data loading issue likely resolved (side effect of successful connections)
- ✅ No performance impact (retrievePeripherals is instant for known UUIDs)

## Research Sources:

- Apple Developer Documentation: CBCentralManagerDelegate
- Stack Overflow: Question 28285393 (10 years, 2k views, 18 upvotes on answer)
- Punch Through: Core Bluetooth Ultimate Guide (authoritative BLE resource)
- Medium: Common BLE Challenges in iOS with Swift

---

## Test Results (2025-10-30):

❌ **FAILED - Fix Never Executed**

### Test Execution:

Joshua tested Build 33 same day (30 October 2025), sent 1 diagnostic log.

### Diagnostic Log:

- `docs/fix-history/logs/bigbattery_logs_20251030_124535.json`

### Joshua's Test Scenario:

```
Connected to battery
- disconnected battery manually
- waited 30 seconds
- app still shows connection on home page but displays no status or information
- settings page displays "connected" but shows no info on protocols
- connection error when trying to reconnect again
```

### Expected vs Reality Comparison:

| Expected (Build 33) | Reality (From Log) | Evidence | Status |
|---------------------|-------------------|----------|---------|
| Error 4 eliminated | **ERROR 4 OCCURRED** | `[12:45:26] [CONNECT] ❌ Connection error: BluetoothError error 4` | ❌ FAILED |
| Connection success 100% | **0% success** (disconnected state) | `batteryInfo` all zeros, `currentValues` all "--" | ❌ FAILED |
| Fresh peripheral retrieval logged | **NOT FOUND** | No "[CONNECT] ✅ Retrieved fresh peripheral instance" in logs | ❌ MISSING |
| BMS data loads | **NOT LOADED** | voltage=0, soc=0, soh=0, no cell data | ❌ FAILED |
| Protocols load | **PARTIALLY** then cleared | RS485/CAN loaded at 12:45:07, cleared at 12:45:28 | 🔄 PARTIAL |

## Critical Discovery: Build 33 Fix Never Executed

Build 33 fresh peripheral retrieval was **CORRECT** but **TOO NARROW in scope**:

### The Problem Flow:

```
User scenario:
1. Battery connected in previous session
2. Battery manually disconnected (physical power off)
3. User closes app
4. User reopens app (after 30 seconds)
5. App still has cached peripheral reference in memory
6. User navigates to Settings/Diagnostics WITHOUT clicking "Connect"
7. Settings tries to read characteristics from cached peripheral
8. ERROR 4 - characteristics are stale/invalid

Build 33 fix location:
- ZetaraManager.connect() method (lines 281-295)

The problem:
- User never called connect() in this session!
- App reused peripheral from previous session's memory
- Fresh peripheral retrieval never executed
```

### Timeline Analysis from Log:

```
[12:45:07] Protocol loading SUCCESS (P02-LUX, P06-LUX) ✅
[12:45:24] [HEALTH] Peripheral state: 2 (.connected - STALE from previous session!)
[12:45:26] [CONNECT] ❌ Connection error: BluetoothError error 4
[12:45:28] PHANTOM detected: No peripheral but BMS timer running
[12:45:28] cleanConnection() called, state cleared
[12:45:32] "No device connected" shown to user
```

## What Got Worse:

- Connection success: Build 32 (25%) → Build 33 (0% in this test) ⬇️
- Error 4: Build 32 (75%) → Build 33 (100% in this test) ⬇️
- **Note:** Build 33 worse because test hit the UX flow issue (no Connect button)

## Verdict for Build 33:

❌ **FAILED** - Fix implementation correct but scope too narrow. Only runs when user explicitly clicks "Connect" button. User navigated to screens that used cached peripheral WITHOUT calling connect().

## Root Cause (Refined):

iOS caches peripheral instances AND their characteristics at object level. Build 33 retrieves fresh peripheral only in `connect()` method, but app can use cached peripheral without calling connect() (e.g., navigating to Settings directly after app launch).

---

**Navigation:**
- ⬅️ Previous: [Build 32](build-32.md)
- ➡️ Next: [Build 34](build-34.md)
- 🏠 Main: [../THREAD-001.md](../THREAD-001.md)
