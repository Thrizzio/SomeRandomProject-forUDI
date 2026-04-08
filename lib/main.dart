import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import 'dart:io';

// Must be top-level for background SMS handling
void backgroundMessageHandler(SmsMessage message) {
  debugPrint("Background SMS: ${message.body}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GigPay SMS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: SMSPage(),
    );
  }
}

class SMSPage extends StatefulWidget {
  const SMSPage({super.key});

  @override
  _SMSPageState createState() => _SMSPageState();
}

class _SMSPageState extends State<SMSPage> {
  final Telephony telephony = Telephony.instance;
  List<Map<String, String>> parsedMessages = [];
  bool isLoading = false;
  String statusMessage = "Listening for new credited SMS...";

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      listenForNewSMS();
    }
  }

  bool _isIncomeMessage(String body) {
    final lower = body.toLowerCase();
    return lower.contains("credited");
  }

  Map<String, String>? _parseMessage(SmsMessage message) {
    final body = message.body ?? "";
    if (!_isIncomeMessage(body)) return null;

    final match = RegExp(r'(?:₹|Rs\.?|INR)\s?([\d,]+(?:\.\d{2})?)', caseSensitive: false).firstMatch(body);
    if (match == null) return null;

    final amount = match.group(1)!.replaceAll(',', '');
    final sender = message.address ?? "Unknown";
    final date = message.date != null
        ? _formatDate(DateTime.fromMillisecondsSinceEpoch(message.date!))
        : "Unknown date";

    return {
      "amount": amount,
      "sender": sender,
      "date": date,
    };
  }

  String _formatDate(DateTime dt) {
    const months = [
      "Jan","Feb","Mar","Apr","May","Jun",
      "Jul","Aug","Sep","Oct","Nov","Dec"
    ];
    return "${dt.day} ${months[dt.month - 1]}";
  }

  void fetchSMS() async {
    if (!Platform.isAndroid) {
      setState(() {
        isLoading = false;
        statusMessage = "SMS features only available on Android.";
      });
      return;
    }
    try {
      bool? granted = await telephony.requestSmsPermissions;

      if (granted != true) {
        setState(() {
          isLoading = false;
          statusMessage = "SMS permission denied.";
        });
        return;
      }

      List<SmsMessage> messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      for (var msg in messages) {
        debugPrint("SMS FROM: ${msg.address} | BODY: ${msg.body}");
      }

      List<Map<String, String>> results = [];
      for (var msg in messages) {
        final parsed = _parseMessage(msg);
        if (parsed != null) results.add(parsed);
      }

      setState(() {
        parsedMessages = results;
        isLoading = false;
        statusMessage = "${results.length} income messages found";
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        statusMessage = "Error: $e";
      });
    }
  }

  void listenForNewSMS() {
    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        final parsed = _parseMessage(message);
        if (parsed != null) {
          setState(() {
            parsedMessages.insert(0, {
              ...parsed,
              "date": "just now",
            });
          });
        }
      },
      onBackgroundMessage: backgroundMessageHandler,
      listenInBackground: true,
    );
  }

  void _addTestSMS() {
    // Simulate parsing a test message
    final testBody = "Your account has been credited with ₹1,250.50. Balance: ₹5,000.00";
    final match = RegExp(r'(?:₹|Rs\.?|INR)\s?([\d,]+(?:\.\d{2})?)', caseSensitive: false).firstMatch(testBody);
    if (match != null) {
      final amount = match.group(1)!.replaceAll(',', '');
      setState(() {
        parsedMessages.insert(0, {
          "amount": amount,
          "sender": "TestBank",
          "date": "test",
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("💰 Credited SMS"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(24),
          child: Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              statusMessage,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : parsedMessages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sms_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        "No credited SMS found",
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Send a message with 'credited' + ₹ amount",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.all(12),
                  itemCount: parsedMessages.length,
                  separatorBuilder: (_, _) => Divider(),
                  itemBuilder: (context, index) {
                    final msg = parsedMessages[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.deepPurple.shade100,
                        child: Icon(Icons.currency_rupee,
                            color: Colors.deepPurple),
                      ),
                      title: Text(
                        "₹${msg['amount']}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      subtitle: Text(msg['sender'] ?? ""),
                      trailing: Text(
                        msg['date'] ?? "",
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTestSMS,
        tooltip: 'Add Test SMS',
        child: Icon(Icons.add),
      ),
    );
  }
}