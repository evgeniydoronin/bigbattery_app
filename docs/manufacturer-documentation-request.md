# Request for BigBattery BMS Technical Documentation

Hi Michael,

I'm working on the iOS app for BigBattery BMS and need technical documentation on the Bluetooth protocol. Currently reverse engineering everything from logs and running into issues I can't solve without official specs.

## What I need:

**Bluetooth Protocol Specification:**
- Command packet formats for Module ID, RS485, CAN (get/set operations)
- Response packet structure and error codes
- What does bytes[3] in response packets mean? Seeing 0x00 for success, 0x01 for failures
- Complete list of error codes and their meanings
- CRC16 variant details (polynomial, initial value, reflection settings)

**Protocol Behavior:**
- Why does battery return error 0x01 when setting RS485/CAN to same value twice but Module ID accepts duplicates?
- Which commands trigger battery auto-restart? Currently seeing restart after setModuleId
- How long does battery restart take?
- Recommended timing between Bluetooth requests and timeout values

**Reconnection:**
- Proper disconnect/reconnect procedure after battery restart
- How to detect when battery is ready for reconnection after restart
- What Bluetooth state needs to be cleared for clean reconnection

**Protocol Lists:**
- Complete list of supported RS485 protocols
- Complete list of supported CAN protocols
- Any compatibility rules or restrictions between RS485/CAN combinations
- What does Module ID actually control?

**BMS Data Packets:**
- Packet structure and field positions
- How to parse cell voltages and temperatures
- What status flags mean
- Expected data transmission frequency

## Current Issues:

Having problems with:
- Users getting "INVALID DEVICE" errors after battery restart
- Phantom connections where app thinks it's connected but battery is offline
- Request timeouts even with 500ms intervals
- Need better error handling and diagnostics

Can provide diagnostic logs, packet captures, or videos if helpful.

Thanks
