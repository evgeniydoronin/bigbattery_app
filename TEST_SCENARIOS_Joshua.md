# BigBattery App Testing Scenarios

## IMPORTANT

**After each test**:
1. Open the **Diagnostics** tab (heartbeat/ECG icon)
2. Tap **Send Logs to Developer** button
3. Send the email with logs

## Test 1: Phantom Connection Issue

### Steps:
1. Connect to the battery
2. Wait for data to appear on the home screen
3. **Physically turn off the battery using the power button**
4. Wait 10 seconds
5. Check the connection status in the app

### Expected Result:
- App should show "Not Connected"
- Data should disappear

**After this test**:
1. Open the **Diagnostics** tab (heartbeat/ECG icon)
2. Tap **Send Logs to Developer** button
3. Send the email with logs

## Test 2: CAN/RS485 Protocol Issue

### Steps:
1. Connect to the battery
2. Open **Settings** (gear icon)
3. Tap **Module ID** and select **ID 1**
4. Try tapping **CAN Protocol** - should work/be clickable
5. Try tapping **RS485 Protocol** - should work/be clickable
6. Change **Module ID** to **ID 2**
7. Try tapping **CAN Protocol** - should be blocked/grayed out
8. Try tapping **RS485 Protocol** - should be blocked/grayed out
9. Check CAN and RS485 values - should show "--"

**After this test**:
1. Open the **Diagnostics** tab (heartbeat/ECG icon)
2. Tap **Send Logs to Developer** button
3. Send the email with logs


## Test 3: Protocol Display on Home Screen

### Steps:
1. Connect to the battery
2. On the home screen, find these 3 buttons:
   - **Selected: ID X**
   - **Selected: CAN XXX**
   - **Selected: RS485 XXX**
3. Note down the values
4. Tap any of these buttons - should open Settings
5. In Settings, change Module ID from 1 to 2
6. Tap **Save**
7. Reconnect to the battery
8. Return to the home screen
9. Check the button values

### Expected Result:
- When Module ID = 1: real protocol values should be shown
- When Module ID != 1: CAN and RS485 should show "--"

**After this test**:
1. Open the **Diagnostics** tab (heartbeat/ECG icon)
2. Tap **Send Logs to Developer** button
3. Send the email with logs


## Test 4: Settings Save

### Steps:
1. Connect to the battery
2. Open Settings
3. Change any setting (for example, Module ID)
4. Tap **Save**
5. Wait for "Settings Saved" message
6. Check if the device disconnected automatically
7. Reconnect to the battery
8. Open Settings again
9. Verify that changes were saved

**After this test**:
1. Open the **Diagnostics** tab (heartbeat/ECG icon)
2. Tap **Send Logs to Developer** button
3. Send the email with logs


## Test 5: Reconnection After Battery Restart

### Steps:
1. Connect to the battery
2. Note all data on the home screen
3. Restart the battery using power button (turn off/on)
4. Wait 30 seconds
5. Try to reconnect through the app
6. Check if data appears

**After this test**:
1. Open the **Diagnostics** tab (heartbeat/ECG icon)
2. Tap **Send Logs to Developer** button
3. Send the email with logs