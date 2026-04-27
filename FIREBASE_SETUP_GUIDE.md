# Firebase Setup & Configuration Guide

## 🔥 Step-by-Step Firebase Setup

### Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click **"Create a project"**
3. Enter project name: `GigTax` (or your preferred name)
4. Agree to terms and click **Create project**
5. Wait for project creation (2-3 minutes)

---

### Step 2: Install FlutterFire CLI

```bash
# Install flutterfire CLI
dart pub global activate flutterfire_cli

# Verify installation
flutterfire --version
```

---

### Step 3: Configure Firebase for Flutter

In your project root directory, run:

```bash
flutterfire configure
```

This will:
- Detect your Flutter project
- Prompt you to select the Firebase project
- Create platform-specific Firebase configuration files
- Update `firebase_options.dart` automatically

**Follow the prompts:**
```
Which Firebase project do you want to associate with this Flutter app?
❯ GigTax (your-project-id)

Which platforms should your configuration support?
❯ Android
  iOS
  macOS
  Windows
  Web

# Select your target platforms
```

---

### Step 4: Update firebase_options.dart

After running `flutterfire configure`, your `firebase_options.dart` will be automatically updated. Verify it contains your Firebase credentials:

```dart
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'YOUR_ACTUAL_KEY',
  appId: 'YOUR_ACTUAL_APP_ID',
  messagingSenderId: 'YOUR_ACTUAL_SENDER_ID',
  projectId: 'your-firebase-project-id',
  databaseURL: 'https://your-firebase-project-id.firebaseio.com',
  storageBucket: 'your-firebase-project-id.appspot.com',
);
```

---

### Step 5: Enable Authentication Methods

In Firebase Console:

1. Navigate to **Authentication** (in left sidebar)
2. Click **Sign-in method** tab
3. Enable **Email/Password**:
   - Click on "Email/Password"
   - Toggle **Enable**
   - Click **Save**
4. (Optional) Enable **Google Sign-In**:
   - Click on "Google"
   - Toggle **Enable**
   - Provide project support email
   - Click **Save**

---

### Step 6: Configure Firestore Database

In Firebase Console:

1. Navigate to **Firestore Database**
2. Click **Create database**
3. Choose location (closest to your users)
4. Start in **Test mode** for development
5. Click **Enable**

**Important:** Test mode allows anyone to read/write. Update security rules before going to production!

---

### Step 7: Set Firestore Security Rules

In Firebase Console:

1. Go to **Firestore Database** → **Rules** tab
2. Replace default rules with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // User profiles
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
      
      // User's transactions subcollection
      match /transactions/{transactionId} {
        allow read, write: if request.auth.uid == userId;
      }
      
      // User's income sources subcollection
      match /income_sources/{sourceId} {
        allow read, write: if request.auth.uid == userId;
      }
    }

    // Deny access to other paths
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

3. Click **Publish**

---

### Step 8: Create Firestore Indexes (Optional but Recommended)

For better query performance, create these indexes:

**Index 1: Transactions by Date (Descending)**
1. Go to **Firestore Database** → **Indexes**
2. Click **Create Index**
3. Collection: `users/{userId}/transactions`
4. Fields: `date` (Descending)
5. Click **Create Index**

**Index 2: Transactions by Type and Date**
1. Click **Create Index** again
2. Collection: `users/{userId}/transactions`
3. Fields: `transactionType` (Ascending), `date` (Descending)
4. Click **Create Index**

---

### Step 9: Update pubspec.yaml

Verify these dependencies are in your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^3.0.0
  firebase_auth: ^4.0.0
  cloud_firestore: ^4.0.0
  provider: ^6.1.2
```

Run:
```bash
flutter pub get
```

---

### Step 10: Test Firebase Connection

Create a test file `test_firebase.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully!');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
  }
}
```

Run:
```bash
flutter run
```

You should see: ✅ Firebase initialized successfully!

---

## 🔐 Security Checklist

### Development (Test Mode)
- [ ] Test mode enabled (anyone can read/write)
- [ ] Basic security rules published
- [ ] Local testing configured

### Before Production
- [ ] Stricter security rules implemented
- [ ] Authentication required for all operations
- [ ] User data isolation enforced
- [ ] Test security rules thoroughly
- [ ] Enable backups in Firestore
- [ ] Set up monitoring and alerts
- [ ] Test with real Firebase project
- [ ] Remove test data
- [ ] Production rules deployed

### Production Rules Template

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Only authenticated users
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      allow create: if request.auth != null && 
                       request.auth.uid == userId &&
                       request.resource.data.keys().hasAll(['email', 'createdAt']);
      
      match /transactions/{transactionId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
        allow delete: if request.auth != null && request.auth.uid == userId;
      }
    }

    // Deny all other access
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## 📱 Platform-Specific Setup

### Android Setup

1. **Register SHA-1 Certificate** (if using Google Sign-In)
   ```bash
   cd android
   ./gradlew signingReport
   ```
   - Copy SHA1 from output
   - Go to Firebase Console → Project Settings → Your App → Signing Certificates
   - Paste SHA1

2. **Enable MultiDex** (if needed)
   - Edit `android/app/build.gradle`
   - Set `minSdkVersion 21`

### iOS Setup

1. **Update iOS deployment target**
   - Edit `ios/Podfile`
   - Set `platform :ios, '12.0'`

2. **Update GoogleService-Info.plist**
   - Already handled by `flutterfire configure`

### Web Setup (Optional)

1. Run:
   ```bash
   flutterfire configure --platforms=web
   ```

2. Add to `web/index.html`:
   ```html
   <!-- Firebase SDKs -->
   <script src="https://www.gstatic.com/firebasejs/10.0.0/firebase-app.js"></script>
   <script src="https://www.gstatic.com/firebasejs/10.0.0/firebase-auth.js"></script>
   <script src="https://www.gstatic.com/firebasejs/10.0.0/firebase-firestore.js"></script>
   ```

---

## 🧪 Testing Firebase Locally

### Emulator Setup (Optional)

```bash
# Install Firebase emulator
firebase install --emulator

# Start emulator
firebase emulators:start --import=backup --export-on-exit
```

**In your app (development only):**
```dart
if (kDebugMode) {
  // Connect to local emulator
  await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  await FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
}
```

---

## 🐛 Troubleshooting

### Issue: "Firebase app not initialized"
**Solution:**
- Ensure `Firebase.initializeApp()` is called in `main()`
- Verify `firebase_options.dart` is configured correctly
- Check internet connection

### Issue: "Permission denied" errors in Firestore
**Solution:**
- Check security rules are published
- Verify user is authenticated
- Check UID matches security rule requirements
- Review Firestore rules in console

### Issue: "Android build fails"
**Solution:**
```bash
cd android
./gradlew clean
cd ..
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run
```

### Issue: "iOS build fails"
**Solution:**
```bash
cd ios
pod repo update
pod install --repo-update
cd ..
flutter clean
flutter run
```

---

## 📊 Firebase Quotas & Limits

### Free Tier Limits
- **Firestore:** 1 GB storage, 50k reads/day
- **Authentication:** Unlimited users
- **Cloud Functions:** 125k invocations/month
- **Storage:** 5 GB

### Production Considerations
- Monitor usage in Firebase Console
- Set budget alerts
- Plan for scaling
- Consider Blaze plan for high traffic

---

## 🔄 Backup & Recovery

### Enable Firestore Backups

In Firebase Console:

1. Go to **Firestore Database** → **Backups**
2. Click **Set up backups**
3. Configure retention policy
4. Select frequency (daily, weekly, monthly)
5. Enable automatic backups

### Restore from Backup
1. Go to **Backups** tab
2. Click **Restore** on desired backup
3. Confirm operation
4. Wait for restoration

---

## 📈 Monitoring & Analytics

### Enable Firebase Analytics

In Firebase Console:

1. Go to **Analytics**
2. Click **Configure Google Analytics**
3. Select or create Analytics account
4. Click **Enable Google Analytics**

**In your app (automatic):**
- Events are tracked automatically
- Monitor in Analytics dashboard

### Set Custom Events

```dart
import 'package:firebase_analytics/firebase_analytics.dart';

final analytics = FirebaseAnalytics.instance;

// Log custom event
await analytics.logEvent(
  name: 'transaction_created',
  parameters: {
    'amount': 1500.00,
    'type': 'income',
  },
);
```

---

## ✅ Verification Checklist

- [ ] Firebase project created
- [ ] FlutterFire CLI installed
- [ ] `flutterfire configure` executed
- [ ] `firebase_options.dart` updated
- [ ] Email/Password authentication enabled
- [ ] Firestore database created
- [ ] Security rules published
- [ ] Test connection successful
- [ ] App runs without Firebase errors
- [ ] Authentication flows work
- [ ] Firestore read/write operations work
- [ ] User data isolation verified

---

## 🚀 Going Live Checklist

- [ ] All security rules reviewed
- [ ] Production security rules deployed
- [ ] Backups configured
- [ ] Monitoring alerts set up
- [ ] Error logging configured
- [ ] Performance optimizations applied
- [ ] User testing completed
- [ ] Data migration plan created (if from SQLite)
- [ ] Rollback plan prepared
- [ ] Firebase billing configured

---

**Reference:** [Firebase Documentation](https://firebase.flutter.dev/)

**Last Updated:** April 2026
