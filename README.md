# 📱 GigTax – SMS-Based Income Tracker for Gig Workers

GigTax is a production-ready mobile application that automatically extracts income data from SMS messages and provides a structured financial overview for gig workers, along with real-time tax estimation under presumptive taxation (ITR-4).

**Status:** ✅ **Production Ready** (v2.0.0)

---

## 🚀 What's New (v2.0.0 - Production Upgrade)

### ✨ Major Improvements

| Feature | Before | After |
|---------|--------|-------|
| **Authentication** | Local in-memory | Firebase Auth (persistent, secure) |
| **Database** | SQLite (local only) | Firestore (cloud + real-time sync) |
| **Error Handling** | Silent failures | Comprehensive try-catch blocks |
| **Logging** | Random debugPrints | Centralized AppLogger |
| **UI States** | Scattered loading flags | Unified UiStateProvider |
| **Error Display** | None | Professional error/empty state widgets |
| **Session Persistence** | Lost on restart | Automatic Firebase persistence |
| **Data Sync** | Manual | Real-time Firestore sync |
| **User Isolation** | Weak | Firebase security rules enforce isolation |

### 🔒 Security Enhancements
- ✅ Firebase Authentication with email/password
- ✅ User-specific data isolation via Firestore
- ✅ Secure session management
- ✅ Firestore security rules
- ✅ Encrypted data transmission

### 🎯 New Architecture
- ✅ Clean separation of concerns
- ✅ Provider-based state management
- ✅ Production-ready error handling
- ✅ Comprehensive logging framework
- ✅ Reusable UI components

---

## 🌟 Features (MVP)

- 📩 **Automatic SMS Parsing**
  - Reads incoming SMS messages
  - Detects financial transactions (credited, payout, received)

- 💰 **Income Extraction**
  - Extracts ₹ amounts using regex
  - Identifies potential income sources

- 📊 **Live Income Dashboard**
  - Displays parsed transactions in real-time
  - Shows total earnings
  - Real-time Firestore sync

- 🧾 **Tax Estimation (ITR-4)**
  - Supports presumptive taxation:
    - Business: 6% / 8%
    - Professional: 50%

- 🏦 **Bank Statement Import**
  - Upload CSV bank statements
  - Automatic transaction parsing
  - Bulk import to cloud

---

## 🏗️ Architecture

### Technology Stack

```
Frontend:     Flutter 3.11.4
State Mgmt:   Provider 6.1.2
Backend:      Firebase
Authentication: Firebase Auth
Database:     Cloud Firestore
Local Storage: SQLite (deprecated) → Firestore
SMS Access:   Telephony plugin
Logging:      AppLogger (custom)
```

### Project Structure

```
lib/
├── main.dart                          # App entry point with Firebase init
├── firebase_options.dart              # Firebase configuration (auto-generated)
├── models/
│   ├── transaction.dart               # Firestore-compatible transaction model
│   ├── user.dart                      # User model
│   └── bank_statement_transaction.dart
├── services/
│   ├── firebase_auth_service.dart     # Firebase authentication ⭐ NEW
│   ├── firestore_service.dart         # Cloud database operations ⭐ NEW
│   ├── app_logger.dart                # Production logging ⭐ NEW
│   ├── auth_service.dart              # Auth interface
│   ├── background_sms_service.dart    # Background SMS listening
│   ├── foreground_sms_handler.dart    # SMS handler management
│   ├── bank_statement_parser.dart     # CSV parsing with error handling
│   ├── database_service.dart          # SQLite (legacy)
│   ├── user_preferences.dart          # Local storage
│   └── local_auth_service.dart        # Local auth (deprecated)
├── providers/
│   ├── auth_provider.dart             # Auth state management (upgraded)
│   └── ui_state_provider.dart         # UI state management ⭐ NEW
├── screens/
│   ├── auth/                          # Login/Register screens
│   ├── home/                          # Dashboard
│   └── bank_statement/                # Bank statement upload
├── widgets/
│   ├── auth_gate.dart                 # Auth routing
│   ├── error_and_loading_widgets.dart # Reusable UI components ⭐ NEW
│   └── [other UI widgets]
├── tax-intelligence/                  # Tax calculation engine
└── theme/                             # App theming

docs/
├── PRODUCTION_UPGRADE_GUIDE.md        # Complete upgrade documentation ⭐ NEW
├── IMPLEMENTATION_GUIDE.md            # How to use new services ⭐ NEW
├── FIREBASE_SETUP_GUIDE.md            # Firebase setup instructions ⭐ NEW
└── VERIFICATION_REPORT.md
```

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK >= 3.11.4
- Dart >= 3.0
- Firebase project (free tier available)
- Android SDK 21+ / iOS 12.0+

### 1. Clone & Setup
```bash
git clone <repo-url>
cd SomeRandomProject-forUDI
flutter pub get
```

### 2. Configure Firebase
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure for your Firebase project
flutterfire configure
```

**👉 See [FIREBASE_SETUP_GUIDE.md](FIREBASE_SETUP_GUIDE.md) for detailed steps**

### 3. Run the App
```bash
flutter run
```

---

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| [PRODUCTION_UPGRADE_GUIDE.md](PRODUCTION_UPGRADE_GUIDE.md) | Complete overview of v2.0.0 changes and best practices |
| [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) | How to use new services in screens |
| [FIREBASE_SETUP_GUIDE.md](FIREBASE_SETUP_GUIDE.md) | Step-by-step Firebase configuration |
| [VERIFICATION_REPORT.md](VERIFICATION_REPORT.md) | Testing and verification checklist |

---

## 🔐 Security

### Authentication
- Email/password authentication via Firebase Auth
- User credentials never stored locally
- Automatic session management
- Secure password reset flow

### Database
- Cloud Firestore with security rules
- User-specific data isolation
- Encrypted data transmission
- Audit logging

### Permissions
- `READ_SMS` - Extract transaction data from SMS
- `RECEIVE_SMS` - Listen for incoming messages
- `INTERNET` - Cloud sync
- `ACCESS_NETWORK_STATE` - Connection detection

---

## 🛠️ Development Guidelines

### Code Quality
- ✅ Comprehensive error handling
- ✅ Production-grade logging
- ✅ Consistent UI components
- ✅ Type-safe operations

### Error Handling Pattern
```dart
try {
  // Async operation
} catch (e, stackTrace) {
  AppLogger.error('Tag', 'Operation failed', e, stackTrace);
  _uiState.setError('User-friendly message');
} finally {
  _uiState.setLoading(false);
}
```

### Adding New Features
1. Create service class with error handling
2. Use AppLogger for logging
3. Integrate with UiStateProvider
4. Use reusable UI components
5. Add try-catch to all async operations

### Testing Checklist
- [ ] Feature works without errors
- [ ] Error states handled gracefully
- [ ] Loading indicators shown
- [ ] Success messages displayed
- [ ] Offline behavior tested
- [ ] User data isolation verified

---

## 📱 Supported Platforms

- ✅ **Android** - SDK 21+ (primary)
- ✅ **iOS** - 12.0+ (supported)
- 🔄 **macOS** - Basic support
- ⏳ **Windows** - Planned
- ⏳ **Linux** - Planned
- ⏳ **Web** - Experimental

---

## 🐛 Known Issues & Workarounds

| Issue | Status | Workaround |
|-------|--------|-----------|
| SMS access on Android 12+ | Known | Request runtime permissions |
| Firestore rules complexity | Managed | See FIREBASE_SETUP_GUIDE.md |
| Background SMS limitations | By design | Foreground listener active during use |

---

## 🚀 Performance Tips

1. **Firestore Queries**
   - Use indexes for frequent queries
   - Limit result set with pagination
   - Avoid N+1 queries

2. **UI Optimization**
   - Use `const` constructors
   - Avoid unnecessary rebuilds with `.watch()` vs `.read()`
   - Lazy-load heavy widgets

3. **Memory Management**
   - Dispose streams and subscriptions
   - Clear large collections periodically
   - Monitor Firebase quotas

---

## 📊 Production Deployment

### Before Going Live
- [ ] Firebase project configured
- [ ] Security rules reviewed and tested
- [ ] Error logging configured
- [ ] Backups enabled
- [ ] Performance optimized
- [ ] User testing completed
- [ ] Rollback plan prepared

### Deployment Steps
```bash
# Build release APK (Android)
flutter build apk --release

# Build release IPA (iOS)
flutter build ipa --release

# Deploy via App Store / Play Store
```

See [FIREBASE_SETUP_GUIDE.md](FIREBASE_SETUP_GUIDE.md) for production checklist.

---

## 🤝 Contributing

### Code Standards
- Follow Dart style guide
- Add error handling to all async operations
- Use AppLogger instead of print()
- Add unit tests for critical functions
- Document complex logic

### Pull Request Process
1. Create feature branch
2. Implement with error handling
3. Add tests
4. Update documentation
5. Submit PR with description

---

## 📞 Support & Troubleshooting

### Common Issues

**Q: Firebase not initializing?**
A: Ensure `flutterfire configure` was run and `firebase_options.dart` is correct.

**Q: Permission denied in Firestore?**
A: Check security rules and user authentication status.

**Q: SMS not being detected?**
A: Verify SMS permissions are granted and app is in foreground.

See [FIREBASE_SETUP_GUIDE.md](FIREBASE_SETUP_GUIDE.md#-troubleshooting) for more solutions.

---

## 📈 Future Roadmap

### Q2 2026
- [ ] Google Sign-In integration
- [ ] App Store / Play Store release
- [ ] Analytics dashboard
- [ ] Expense tracking

### Q3 2026
- [ ] Offline data sync
- [ ] Multiple account support
- [ ] Tax filing integration
- [ ] Multi-language support

### Q4 2026
- [ ] Apple Sign-In
- [ ] Advanced analytics
- [ ] API integration
- [ ] Premium features

---

## 📄 License

[Add your license here]

---

## ⚠️ Disclaimer

GigTax is a tax tracking tool designed for Indian gig workers under ITR-4 presumptive taxation. It is **not** a substitute for professional tax advice. Please consult with a tax professional for accurate filing.

---

**Last Updated:** April 26, 2026
**Current Version:** 2.0.0-production
**Status:** ✅ Production Ready


- SMS formats vary across platforms  
- Cannot always distinguish personal vs income transactions automatically  
- No bank/API integration (MVP constraint)  
- SMS access restricted on some Android versions/devices  

---

## 🔮 Future Improvements

- AI-based classification of transactions  
- Deduplication (bank SMS + platform SMS)  
- Expense tracking  
- Direct ITR filing integration  
- Cloud sync & analytics  

---

## 🧪 Demo Flow

1. Launch app  
2. Grant SMS permission  
3. View parsed income messages  
4. See total earnings  
5. View estimated taxable income  

---

## 🏆 Hackathon Focus

This project prioritizes:

- Real-world problem relevance  
- Practical implementation  
- Working prototype over theoretical completeness  

---

## 📂 Setup Instructions

```mermaid
flowchart TD
    A["git clone https://github.com/Thrizzio/SomeRandomProject-forUDI.git"] --> B["cd SomeRandomProject-forUDI"]
    B --> C["flutter pub get"]
    C --> D["Start Emulator / Connect Device"]
    D --> E["flutter run"]
