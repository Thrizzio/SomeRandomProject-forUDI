# Implementation Guide - Using Production Services

## 🎯 How to Use New Services in Your Screens

### 1. Firebase Authentication

#### Setup in main.dart (Already Done ✅)
```dart
MultiProvider(
  providers: [
    Provider<FirebaseAuthService>(
      create: (_) => FirebaseAuthService(),
    ),
    ChangeNotifierProvider<AuthProvider>(
      create: (context) => AuthProvider(
        authService: context.read<FirebaseAuthService>(),
      )..init(),
    ),
  ],
  child: MaterialApp(...)
)
```

#### Use in Screens
```dart
// Access auth state
final authProvider = context.watch<AuthProvider>();

if (!authProvider.isAuthenticated) {
  return LoginScreen();
}

// Check loading state
if (authProvider.loading) {
  return LoadingIndicator();
}

// Show error if any
if (authProvider.error != null) {
  return ErrorDisplay(
    error: authProvider.error!,
    onRetry: () => authProvider.clearError(),
  );
}

// Logout
onPressed: () => authProvider.logout(),
```

---

### 2. Firestore Database Operations

#### In Your Transaction List Screen

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/firestore_service.dart';

class TransactionListScreen extends StatefulWidget {
  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  late FirestoreService _firestoreService;
  final _uiState = UiStateProvider();

  @override
  void initState() {
    super.initState();
    _firestoreService = FirestoreService();
  }

  Future<void> _loadTransactions() async {
    _uiState.setLoading(true);
    try {
      final transactions = await _firestoreService.getTransactions();
      // Update UI with transactions
      setState(() {});
    } catch (e) {
      _uiState.setError('Failed to load transactions: $e');
    } finally {
      _uiState.setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ProductionAppBar(
        title: 'Transactions',
        onBack: () => Navigator.pop(context),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadTransactions,
        child: Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildBody() {
    if (_uiState.isLoading) {
      return LoadingIndicator(message: 'Loading transactions...');
    }

    if (_uiState.errorMessage != null) {
      return ErrorDisplay(
        error: _uiState.errorMessage!,
        onRetry: _loadTransactions,
      );
    }

    // Build your transaction list
    return ListView(
      children: [
        // Transactions list items
      ],
    );
  }
}
```

#### Real-time Updates with Stream
```dart
@override
Widget build(BuildContext context) {
  return StreamBuilder<List<Transaction>>(
    stream: _firestoreService.getTransactionsStream(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return LoadingIndicator();
      }

      if (snapshot.hasError) {
        return ErrorDisplay(
          error: snapshot.error.toString(),
          onRetry: () => setState(() {}),
        );
      }

      final transactions = snapshot.data ?? [];
      
      if (transactions.isEmpty) {
        return EmptyStateWidget(
          title: 'No Transactions',
          message: 'Add your first transaction to get started',
        );
      }

      return ListView.builder(
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          return TransactionCard(transaction: transaction);
        },
      );
    },
  );
}
```

---

### 3. Error Handling Pattern

#### Template for All Async Operations
```dart
Future<void> performAsyncOperation() async {
  _uiState.setLoading(true);
  try {
    // Perform your async operation
    final result = await someAsyncService.doSomething();
    
    // Success
    _uiState.setSuccess('Operation completed successfully!');
    
    // Update state if needed
    setState(() {
      // Update your data
    });
  } on AuthException catch (e) {
    _uiState.setError('Authentication failed: ${e.message}');
  } on NetworkException catch (e) {
    _uiState.setError('Network error: Please check your connection');
  } on DatabaseException catch (e) {
    _uiState.setError('Database error: Please try again');
  } catch (e) {
    AppLogger.error('ScreenName', 'Operation failed', e);
    _uiState.setError('An unexpected error occurred: $e');
  } finally {
    _uiState.setLoading(false);
  }
}
```

---

### 4. Logging Throughout Your Code

#### Replace All debugPrint with AppLogger
```dart
// Old - Avoid this
debugPrint('Processing transaction: $transaction');

// New - Use this
AppLogger.info('TransactionService', 'Processing transaction: $transaction');
```

#### Logging Levels
```dart
// Debug - Detailed info, not needed in production
AppLogger.debug('Tag', 'Variable values: $value');

// Info - Important information
AppLogger.info('Tag', 'User logged in successfully');

// Warning - Something unexpected but not critical
AppLogger.warning('Tag', 'User has no transactions');

// Error - An error occurred
AppLogger.error('Tag', 'Failed to save transaction', exception, stackTrace);

// Critical - System-level error
AppLogger.critical('Tag', 'Database connection failed', exception, stackTrace);
```

---

### 5. UI Component Usage

#### Error Messages
```dart
// Inline error with retry
if (error != null) {
  ErrorDisplay(
    error: error,
    onRetry: () => _loadData(),
    padding: EdgeInsets.all(16),
  );
}

// Custom error handling
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Error'),
    content: Text(error),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Dismiss'),
      ),
      TextButton(
        onPressed: () {
          Navigator.pop(context);
          _retry();
        },
        child: Text('Retry'),
      ),
    ],
  ),
);
```

#### Loading States
```dart
// Loading overlay
if (isLoading) {
  return Stack(
    children: [
      // Your content
      Opacity(
        opacity: 0.3,
        child: IgnorePointer(child: YourWidget()),
      ),
      // Loading indicator overlay
      LoadingIndicator(message: 'Please wait...'),
    ],
  );
}
```

#### Empty States
```dart
if (items.isEmpty) {
  return EmptyStateWidget(
    title: 'No Data',
    message: 'Start by adding your first item',
    icon: Icons.add_box_outlined,
    actionLabel: 'Add Item',
    onAction: () => _showAddDialog(),
  );
}
```

---

### 6. Setting Up Providers

#### In main.dart (Already configured ✅)
```dart
MultiProvider(
  providers: [
    // Auth
    Provider<FirebaseAuthService>(
      create: (_) => FirebaseAuthService(),
    ),
    ChangeNotifierProvider<AuthProvider>(
      create: (context) => AuthProvider(
        authService: context.read<FirebaseAuthService>(),
      )..init(),
    ),
    
    // UI State
    ChangeNotifierProvider<UiStateProvider>(
      create: (_) => UiStateProvider(),
    ),
    
    // Firestore (optional - create only when needed)
    // Provider<FirestoreService>(
    //   create: (_) => FirestoreService(),
    // ),
  ],
  child: MaterialApp(...)
)
```

#### Access in Screens
```dart
// Watch for changes
final authProvider = context.watch<AuthProvider>();
final uiState = context.watch<UiStateProvider>();

// Read without watching (doesn't rebuild on change)
final firestore = context.read<FirestoreService>();
```

---

### 7. Transaction Model Usage

#### Creating Transactions
```dart
// From parsed bank statement
final transaction = Transaction(
  amount: '1500.00',
  sender: 'Swiggy',
  messageBody: 'Delivery completed',
  transactionType: 'income',
  date: DateTime.now().toIso8601String(),
);

// Validate before saving
if (transaction.isValid()) {
  await firestoreService.addTransaction(transaction);
}
```

#### Parsing Transactions
```dart
// From Firestore document
final transaction = Transaction.fromJson(firestoreDoc.data());

// Get DateTime when needed
final dateTime = transaction.getDateTime();
final formattedDate = DateFormat('dd MMM yyyy').format(dateTime);
```

---

### 8. Complete Screen Example

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/firestore_service.dart';
import 'providers/auth_provider.dart';
import 'providers/ui_state_provider.dart';
import 'widgets/error_and_loading_widgets.dart';

class DashboardScreen extends StatefulWidget {
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late FirestoreService _firestoreService;

  @override
  void initState() {
    super.initState();
    _firestoreService = FirestoreService();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final uiState = context.read<UiStateProvider>();
    uiState.setLoading(true);
    try {
      // Load transactions
      final transactions = await _firestoreService.getTransactions();
      AppLogger.info('Dashboard', 'Loaded ${transactions.length} transactions');
    } catch (e) {
      uiState.setError('Failed to load transactions: $e');
    } finally {
      uiState.setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final uiState = context.watch<UiStateProvider>();

    // Not authenticated
    if (!authProvider.isAuthenticated) {
      return LoginScreen();
    }

    // Loading
    if (uiState.isLoading) {
      return Scaffold(
        body: LoadingIndicator(message: 'Loading your dashboard...'),
      );
    }

    // Error
    if (uiState.errorMessage != null) {
      return Scaffold(
        body: Center(
          child: ErrorDisplay(
            error: uiState.errorMessage!,
            onRetry: _loadTransactions,
          ),
        ),
      );
    }

    // Success
    return Scaffold(
      appBar: ProductionAppBar(
        title: 'GigTax Dashboard',
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => authProvider.logout(),
          ),
        ],
      ),
      body: StreamBuilder(
        stream: _firestoreService.getTransactionsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorDisplay(error: snapshot.error.toString());
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return LoadingIndicator();
          }

          final transactions = snapshot.data ?? [];

          if (transactions.isEmpty) {
            return EmptyStateWidget(
              title: 'No Transactions',
              message: 'Upload your first bank statement to get started',
            );
          }

          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final txn = transactions[index];
              return ListTile(
                title: Text(txn.sender),
                subtitle: Text(txn.messageBody),
                trailing: Text('₹${txn.amount}'),
              );
            },
          );
        },
      ),
    );
  }
}
```

---

## 🔧 Migration Checklist

For each screen that needs updating:

- [ ] Replace `debugPrint` with `AppLogger`
- [ ] Add try-catch to all async operations
- [ ] Use `UiStateProvider` for loading/error states
- [ ] Use error/loading UI components
- [ ] Remove LocalStorage references
- [ ] Use `FirestoreService` for data operations
- [ ] Test authentication flow
- [ ] Test error scenarios
- [ ] Test with real Firebase project
- [ ] Verify user data isolation

---

## ⚡ Quick Reference

### Imports Required
```dart
import 'services/firebase_auth_service.dart';
import 'services/firestore_service.dart';
import 'services/app_logger.dart';
import 'providers/auth_provider.dart';
import 'providers/ui_state_provider.dart';
import 'widgets/error_and_loading_widgets.dart';
import 'models/transaction.dart';
```

### Common Patterns
```dart
// Check authentication
if (!context.read<AuthProvider>().isAuthenticated) return;

// Show loading
context.read<UiStateProvider>().setLoading(true);

// Show error
context.read<UiStateProvider>().setError('Error message');

// Show success
context.read<UiStateProvider>().setSuccess('Success message');

// Log event
AppLogger.info('Tag', 'Event message');

// Log error
AppLogger.error('Tag', 'Error message', exception, stackTrace);
```

---

**Need help?** Refer to `PRODUCTION_UPGRADE_GUIDE.md` for more details.
