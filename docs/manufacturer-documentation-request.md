# BigBattery Bluetooth Protocol Documentation Request

**Date:** October 10, 2025
**Purpose:** Request comprehensive technical documentation for BigBattery BMS Bluetooth protocol
**Requested by:** iOS Development Team

---

## Executive Summary

We are developing an iOS application for BigBattery BMS monitoring and configuration. During development and testing, we've encountered several edge cases and behaviors that require official documentation to implement correctly. This request outlines specific technical documentation needs organized by priority.

---

## 🔴 CRITICAL PRIORITY

These items are blocking proper error handling and user experience:

### 1. Response Packet Error Codes

**What we observe:**
- Battery response packets have format: `[0x10, command_id, length, status_byte, ...crc]`
- `status_byte` (byte[3]) appears to indicate success/failure
- We currently interpret: `0x00 = success`, `0x01+ = error`

**Log evidence** (`bigbattery_logs_20251010_122737.json`):
```
Module ID response: 10070100b4b5  → bytes[3] = 0x00 (success) ✅
CAN response:       1006010124b5  → bytes[3] = 0x01 (failed)  ❌
RS485 response:     10050101d4b5  → bytes[3] = 0x01 (failed)  ❌
```

**Documentation needed:**
- [ ] Complete specification of response packet structure
- [ ] What does `bytes[3] == 0x00` mean? (we assume: success)
- [ ] What does `bytes[3] == 0x01` mean? (we observe: when trying to set duplicate value)
- [ ] What does `bytes[3] == 0x02` mean?
- [ ] What does `bytes[3] == 0x03` mean?
- [ ] Full list of all possible error codes with descriptions
- [ ] When each error code is returned (conditions/causes)

---

### 2. Duplicate Value Behavior

**What we observe:**
- When attempting `setRS485(value)` where `value` is already set → error code 0x01
- When attempting `setCAN(value)` where `value` is already set → error code 0x01
- When attempting `setModuleId(value)` where `value` is already set → appears to succeed

**Log evidence** (`bigbattery_logs_20251010_122737.json`):
```json
"currentValues": {
  "moduleId": "ID 2",
  "rs485Protocol": "P02-LUX",
  "canProtocol": "P06-LUX"
}
```
User attempts to set these SAME values again:
- Module ID: succeeds (0x00)
- RS485: fails (0x01)
- CAN: fails (0x01)

**Documentation needed:**
- [ ] Should battery accept `setModuleId` with current value?
- [ ] Should battery accept `setRS485` with current value?
- [ ] Should battery accept `setCAN` with current value?
- [ ] What is the recommended application behavior?
  - Should app prevent sending duplicate values?
  - Or should app send and handle error code 0x01?
- [ ] Is error code 0x01 specifically for "duplicate value"?
- [ ] Or can 0x01 mean other errors too?

---

### 3. Reconnection After Disconnect

**What we observe:**
- After battery disconnect (restart/power off), iOS app sometimes shows "INVALID DEVICE" error
- Reconnection requires restarting the app
- Logs show "phantom connection" warnings

**Log evidence** (`bigbattery_logs_20251010_122330.json`):
```json
"recentLogs": [
  "[12:22:59] [CONNECTION] ⚠️ PHANTOM: No peripheral but BMS timer running!"
],
"events": [
  {
    "message": "No device connected",
    "timestamp": "12:23:29"
  }
]
```

**Documentation needed:**
- [ ] Proper disconnect procedure from iOS app perspective
  - What state should be cleared?
  - What should be retained?
- [ ] Proper reconnect procedure
  - Any special initialization required?
  - Should characteristics be re-discovered?
- [ ] Minimum time between disconnect and reconnect?
- [ ] How to detect if battery is ready for reconnection?
- [ ] Are there any "stale connection" scenarios we should handle?

---

## 🟡 HIGH PRIORITY

These items would improve reliability and user experience:

### 4. Bluetooth Protocol Specification

**Documentation needed:**
- [ ] Complete control data command format specification
- [ ] **Get Module ID** (0x02):
  - Request packet structure
  - Response packet structure
  - Response data interpretation
- [ ] **Set Module ID** (0x07):
  - Request packet structure
  - Parameter range (1-16?)
  - Response packet structure
- [ ] **Get RS485** (0x03):
  - Request/response packets
  - Protocol list encoding
- [ ] **Set RS485** (0x05):
  - Request/response packets
  - Protocol index encoding
- [ ] **Get CAN** (0x04):
  - Request/response packets
  - Protocol list encoding
- [ ] **Set CAN** (0x06):
  - Request/response packets
  - Protocol index encoding
- [ ] **CRC16 Algorithm**:
  - Which CRC16 variant? (MODBUS? CCITT? Other?)
  - Polynomial value
  - Initial value
  - Is reflection used?
  - Example calculation

---

### 5. Battery Auto-Restart Behavior

**What we observe:**
- `setModuleId` command causes battery to automatically restart
- Restart takes approximately 5-10 seconds
- App loses connection during restart

**Documentation needed:**
- [ ] Which commands trigger automatic restart?
  - Does `setModuleId` always trigger restart?
  - Do `setRS485` / `setCAN` trigger restart?
  - Any other commands that cause restart?
- [ ] How long does restart typically take?
- [ ] How can app detect that restart is complete?
- [ ] Is there any way to set Module ID without restart?
- [ ] Should app wait for restart before allowing reconnection?
- [ ] Best practices for handling restart from app perspective

---

### 6. Request Timing and Rate Limiting

**What we implement:**
- Minimum 500ms interval between Bluetooth requests
- 10 second timeout for each request

**Documentation needed:**
- [ ] Minimum interval between control data requests?
- [ ] Maximum rate of requests (requests per second)?
- [ ] What happens if requests sent too quickly?
  - Does battery ignore excess requests?
  - Does battery queue requests?
  - Does battery return error?
- [ ] Are there different timing requirements for different commands?
- [ ] Recommended timeout values for each command type?

---

## 🟢 MEDIUM PRIORITY

These items would help with comprehensive implementation:

### 7. Protocol Compatibility and Constraints

**Documentation needed:**
- [ ] Complete list of supported RS485 protocols:
  - P01-GRW
  - P02-LUX
  - P03-SCH
  - P04-INH
  - P05-VOL
  - Others?
- [ ] Complete list of supported CAN protocols:
  - P01-GRW through P11-STU
  - Full list with descriptions
- [ ] Module ID range: 1-16?
- [ ] Protocol compatibility matrix:
  - Which RS485/CAN combinations are valid?
  - Any forbidden combinations?
  - Does Module ID affect protocol availability?
- [ ] What does each protocol do?
  - Brief description of each protocol's purpose
  - Which inverter brands/models use which protocols?

---

### 8. BMS Data Packet Format

**Documentation needed:**
- [ ] Complete BMS data packet structure
- [ ] All fields and their byte positions
- [ ] Data types and encoding
- [ ] How to calculate cell voltages from bytes
- [ ] How to calculate temperatures from bytes
- [ ] Status flags interpretation
- [ ] Protection status bits
- [ ] Expected frequency of BMS data updates
- [ ] Conditions when BMS data is not sent

---

### 9. Device States and Transitions

**Documentation needed:**
- [ ] All possible battery states:
  - Standby
  - Charging
  - Discharging
  - Error/Protection
  - Others?
- [ ] Which commands are allowed in which states?
- [ ] State transition diagram
- [ ] How to query current state?
- [ ] How to detect state changes?

---

## 🟢 LOW PRIORITY

Nice to have for optimal implementation:

### 10. Bluetooth Characteristics

**Documentation needed:**
- [ ] Service UUID significance
- [ ] Write characteristic purpose and capabilities
- [ ] Notify characteristic behavior
- [ ] Maximum packet size
- [ ] Is packet fragmentation used?
- [ ] MTU recommendations

---

### 11. Testing and Validation

**Documentation needed:**
- [ ] Recommended test scenarios for apps
- [ ] Known edge cases that must be handled
- [ ] Common integration mistakes to avoid
- [ ] Validation/certification requirements
- [ ] Performance benchmarks

---

### 12. Firmware Versions

**Documentation needed:**
- [ ] How to query firmware version?
- [ ] Protocol differences between firmware versions?
- [ ] Backward compatibility guarantees?
- [ ] Changelog for protocol changes?

---

## Example Problematic Scenarios

To illustrate why this documentation is critical, here are specific scenarios causing issues:

### Scenario 1: User Changes Protocols Multiple Times

**Steps:**
1. User connects to battery (ID 2, RS485: P02-LUX, CAN: P06-LUX)
2. User opens Settings, changes protocols
3. User saves → all 3 values save successfully ✅
4. User immediately tries to change protocols again
5. User saves → RS485 and CAN fail with error 0x01 ❌

**Question:** Is this expected? Should app prevent re-saving same values?

**Log reference:** `bigbattery_logs_20251010_122737.json`

---

### Scenario 2: Reconnection After Battery Restart

**Steps:**
1. User connects to battery
2. User changes Module ID → triggers restart
3. Battery restarts automatically (5-10 seconds)
4. User tries to reconnect
5. App shows "INVALID DEVICE" error ❌
6. User must restart app to reconnect

**Question:** What is proper reconnection procedure?

**Log reference:** `bigbattery_logs_20251010_122330.json`

---

### Scenario 3: Rapid Protocol Loading

**Steps:**
1. App connects to battery
2. App immediately requests: getModuleId, getRS485, getCAN
3. App uses 500ms interval between requests
4. Sometimes requests timeout or fail

**Question:** Is 500ms sufficient? What's the recommended interval?

---

## Additional Information We Can Provide

If helpful for your technical team, we can provide:

- [ ] Complete diagnostic logs from iOS app
- [ ] Bluetooth packet captures (if needed)
- [ ] Video demonstrations of issues
- [ ] Specific firmware version information
- [ ] Battery model numbers experiencing issues

---

## Delivery Format

We can work with documentation in any format:
- PDF specification documents
- Word/Markdown technical docs
- Example code/pseudocode
- Wireshark packet captures with annotations
- Technical support call/video conference
- Email correspondence with technical team

---

## Priority Summary

**IMMEDIATE NEED (This Week):**
- Error code definitions (especially 0x01)
- Duplicate value behavior guidance
- Reconnection procedure

**SHORT TERM (Next 2 Weeks):**
- Complete protocol specification
- Auto-restart behavior details
- Timing/rate limiting guidance

**LONG TERM (Next Month):**
- Protocol descriptions
- BMS packet format
- State machine documentation

---

## Contact Information

**Project:** BigBattery iOS BMS Monitor App
**Development Team:** [Your team name]
**Technical Contact:** [Your contact info]
**Response Priority:** High - blocking proper error handling

---

## Appendix: Current Implementation

For reference, here's how we currently interpret responses (subject to correction):

```swift
// Current implementation (needs verification):
struct ResponseData {
    var success: Bool
    var errorCode: UInt8?

    init?(_ bytes: [UInt8]) {
        guard bytes.count >= 4 else { return nil }

        if bytes[3] == 0 {
            self.success = true
            self.errorCode = nil
        } else {
            self.success = false
            self.errorCode = bytes[3]  // Assumption: error code here
        }
    }

    // Guessed error meanings (need official confirmation):
    func errorMessage() -> String? {
        guard let code = errorCode else { return nil }

        switch code {
        case 0x01: return "Duplicate value or invalid parameter?" // Observed
        case 0x02: return "Device busy?" // Guess
        case 0x03: return "Invalid state?" // Guess
        default: return "Unknown error"
        }
    }
}
```

This is based purely on observation and needs official confirmation.

---

Thank you for your assistance in providing this critical documentation!
