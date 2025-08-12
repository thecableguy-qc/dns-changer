# Auto-Start Feature

## Overview
The TheCableGuy DNS app now includes an auto-start feature that allows the application to automatically launch when the device boots up.

## How to Use
1. Open the TheCableGuy DNS app
2. Scroll down to the "Settings" section
3. Toggle the "Start on boot" switch to enable/disable auto-start

## Technical Implementation

### Flutter Side
- Added `shared_preferences` package to store user preference
- Added settings UI with a toggle switch
- Added localization strings for English, French, and Spanish
- Uses platform method channel to communicate with Android native code

### Android Side
- **MainActivity.kt**: Added `setAutoStart` method to enable/disable the boot receiver
- **BootReceiver.kt**: Broadcast receiver that listens for boot events and launches the app
- **AndroidManifest.xml**:
  - Added required permissions (`RECEIVE_BOOT_COMPLETED`, `QUICKBOOT_POWERON`, `SYSTEM_ALERT_WINDOW`)
  - Registered BootReceiver with intent filters for various boot events
  - Receiver is disabled by default and only enabled when user toggles the setting

### Permissions Required
- `RECEIVE_BOOT_COMPLETED`: Standard Android boot permission
- `QUICKBOOT_POWERON`: For devices with quick boot (like some Xiaomi devices)
- `SYSTEM_ALERT_WINDOW`: For some manufacturers that require this for auto-start

### Supported Boot Events
- `ACTION_BOOT_COMPLETED`: Standard Android boot
- `ACTION_QUICKBOOT_POWERON`: Quick boot on some devices
- `ACTION_MY_PACKAGE_REPLACED`: App updates

## Device-Specific Considerations
Some manufacturers (Xiaomi, Huawei, OnePlus, etc.) have aggressive battery optimization that may prevent auto-start. Users may need to:

1. **Xiaomi (MIUI)**: Go to Security > Auto-start > Enable for TheCableGuy DNS
2. **Huawei**: Phone Manager > Startup Manager > Enable for TheCableGuy DNS
3. **OnePlus**: Settings > Battery > Battery Optimization > Not Optimized > Select TheCableGuy DNS
4. **Samsung**: Settings > Apps > TheCableGuy DNS > Battery > Allow background activity

The app will work best when these device-specific settings are also configured by the user.
