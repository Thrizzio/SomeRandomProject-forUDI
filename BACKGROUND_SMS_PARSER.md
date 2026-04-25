# Background SMS Parser Implementation

## Overview
This implementation adds comprehensive background SMS parsing capabilities to the GigTax application. The system automatically processes incoming SMS messages from gig platforms (Swiggy, Zomato, Uber, Ola, Zepto) in both foreground and background modes.

## Features

### ✅ Core Features
- **Real-time Foreground Parsing**: Processes SMS messages instantly when the app is active
- **Background Processing**: Continues listening to SMS even when the app is in the background
- **Automatic Parsing**: Detects and parses gig income SMS messages automatically
- **Periodic Background Checks**: Scheduled background tasks ensure continuous monitoring
- **Error Handling**: Robust error handling with retry mechanisms
- **Database Integration**: Automatically stores parsed transactions in the local database
- **Permissions Management**: Handles SMS and background processing permissions gracefully
- **Statistics Tracking**: Monitors listener status and processing metrics

## Architecture

### Components

#### 1. **BackgroundSmsService** (`background_sms_service.dart`)
- Core service managing SMS listening in background
- Handles both foreground and background SMS reception
- Manages WorkManager tasks for periodic checks
- Stores transactions to database
- Key Methods:
  - `initialize()`: Set up background service and permissions
  - `startListening()`: Start foreground + background SMS listening
  - `stopListening()`: Stop SMS listening
  - `isListenerActive()`: Check listener status
  - `getStatistics()`: Get service statistics

#### 2. **ForegroundSmsHandler** (`foreground_sms_handler.dart`)
- UI-layer manager for background SMS service
- Provides high-level control methods
- Manages service lifecycle
- Key Methods:
  - `initialize()`: Initialize the handler
  - `enableBackgroundSmsListener()`: Enable SMS background listening
  - `disableBackgroundSmsListener()`: Disable SMS background listening
  - `isListenerActive()`: Check listener status
  - `getServiceStats()`: Get service statistics

#### 3. **BackgroundSmsConfig** (`background_sms_config.dart`)
- Configuration constants for the background service
- Customizable settings:
  - Check interval (default: 15 minutes)
  - Maximum retry attempts (default: 3)
  - Retry delay (default: 30 seconds)
  - Supported platforms (Swiggy, Zomato, Uber, Ola, Zepto)
  - Debug logging toggle

### Dependencies Added
```yaml
workmanager: ^0.5.2                         # Background task scheduling
flutter_background_service: ^5.3.0          # Background service
flutter_background_service_android: ^5.3.0  # Android support
flutter_background_service_ios: ^5.3.0      # iOS support
```

## Usage

### Initialization
The background SMS service is initialized automatically in `main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final smsHandler = ForegroundSmsHandler();
  await smsHandler.initialize();
  
  runApp(const MyApp());
}
```

### Programmatic Control

#### Enable Background Listening
```dart
final handler = ForegroundSmsHandler();
await handler.initialize();
final success = await handler.enableBackgroundSmsListener();
```

#### Disable Background Listening
```dart
final handler = ForegroundSmsHandler();
final success = await handler.disableBackgroundSmsListener();
```

#### Check Listener Status
```dart
final handler = ForegroundSmsHandler();
final isActive = await handler.isListenerActive();
```

#### Get Service Statistics
```dart
final handler = ForegroundSmsHandler();
final stats = await handler.getServiceStats();
print('IsInitialized: ${stats['isInitialized']}');
print('IsListening: ${stats['isListening']}');
print('Total Processed: ${stats['totalProcessed']}');
print('Last Check: ${stats['lastCheck']}');
```

## Platform-Specific Setup

### Android Configuration
**File**: `android/app/src/main/AndroidManifest.xml`

Added permissions:
- `android.permission.RECEIVE_SMS` - Receive SMS messages
- `android.permission.READ_SMS` - Read SMS messages
- `android.permission.SCHEDULE_EXACT_ALARM` - Schedule background tasks
- `android.permission.WAKE_LOCK` - Keep device awake during processing
- `android.permission.INTERNET` - Network access for future features

The SMS receiver from telephony plugin automatically handles SMS in background.

### iOS Configuration
**File**: `ios/Runner/Info.plist`

iOS requires:
- `NSLocalNetworkUsageDescription` - For network operations
- `NSBonjourServiceTypes` - For service discovery
- Background modes configured in Xcode project settings

Note: iOS has limitations on background SMS processing. The app will receive SMS when:
- The app is in foreground
- The app is resumed from background within a short time window
- Through push notifications (if implemented)

## How It Works

### Foreground Mode
1. User receives SMS
2. System delivers SMS to the app
3. BackgroundSmsService receives the SMS message
4. SmsParser analyzes the message
5. If valid gig income → Extract amount, source, date
6. Store transaction in local database
7. UI updates automatically via Provider pattern

### Background Mode
1. WorkManager schedules periodic checks (every 15 minutes by default)
2. `callbackDispatcher()` function runs in background
3. Checks if listener is active, re-initializes if needed
4. Updates last check timestamp
5. Ensures continuous SMS monitoring even if app is killed

### SMS Parsing Logic
The existing `SmsParser` from `read_sms.dart` is reused:

1. Check if message is an income message (contains "credited", "received", etc.)
2. Check if message is from gig platform (Swiggy, Zomato, etc.)
3. Extract amount using regex patterns (₹, INR, RS)
4. Extract source platform name
5. Extract date from SMS metadata
6. Create `ParsedIncome` object
7. Convert to Transaction and store in database

## Error Handling

### Permission Errors
- If SMS permissions are denied, the service logs a debug message and returns
- Users can grant permissions via system settings

### Database Errors
- Transaction storage failures are caught and logged
- Errors don't crash the background service
- Retries are attempted based on configuration

### Background Task Errors
- Background task failures are caught in `callbackDispatcher()`
- Service re-initializes if listener becomes inactive
- Errors are logged but don't prevent future runs

## Monitoring & Debugging

### Debug Logs
Enable debug logging via `BackgroundSmsConfig.debugLogging = true`

Log patterns:
- `🚀` - Service initialization
- `📱` - Listener start/stop
- `📨` - SMS received
- `✅` - Success operations
- `❌` - Error operations
- `⏭️` - Skipped operations
- `💾` - Database operations

### SharedPreferences State
The service tracks state in SharedPreferences:
- `sms_listener_active` - Listener active status
- `sms_last_check` - Last background check timestamp
- `sms_total_processed` - Total SMS processed count

## Testing Checklist

- [x] SMS permissions requested and handled
- [x] Foreground SMS reception working
- [x] Background SMS listening initialized
- [x] WorkManager periodic tasks scheduled
- [x] Database transactions stored correctly
- [x] Error handling and logging in place
- [x] Statistics tracking implemented
- [x] Service lifecycle management complete
- [x] Configuration options provided
- [x] UI handler abstraction created

## Troubleshooting

### SMS Not Being Parsed
1. Check if SMS permissions are granted
2. Verify SMS is from supported platform (Swiggy, Zomato, etc.)
3. Ensure SMS contains amount (₹, INR, RS)
4. Check debug logs for parsing failures

### Background Listener Not Active
1. Check SharedPreferences `sms_listener_active` value
2. Verify app has not been force-stopped
3. Check battery optimization settings on device
4. Enable debug logging to see initialization status

### Database Storage Issues
1. Verify DatabaseService is initialized
2. Check database file permissions
3. Ensure sufficient device storage
4. Check debug logs for specific errors

## Performance Considerations

- **Battery**: Background tasks every 15 minutes (configurable) to minimize battery drain
- **Memory**: Singleton pattern ensures only one service instance
- **CPU**: SMS parsing happens asynchronously to avoid blocking
- **Network**: No network required for local SMS parsing and storage

## Security

- SMS data is stored locally in SQLite
- No data is sent to external servers
- Permissions requested transparently with permission dialogs
- User can disable background listening at any time

## Future Enhancements

1. Add SMS encryption for stored data
2. Implement cloud backup option
3. Add custom SMS pattern configuration UI
4. Add analytics dashboard for SMS processing stats
5. Implement SMS filtering (by sender, date range, etc.)
6. Add automatic transaction categorization
7. Implement smart duplicate detection

## References

- [Workmanager Package](https://pub.dev/packages/workmanager)
- [Flutter Background Service](https://pub.dev/packages/flutter_background_service)
- [Telephony Package](https://pub.dev/packages/telephony)
- [SharedPreferences](https://pub.dev/packages/shared_preferences)
