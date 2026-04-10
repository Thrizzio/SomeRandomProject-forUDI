import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';

class ReadSmsScreen extends StatefulWidget {
  const ReadSmsScreen({super.key});

  @override
  State<ReadSmsScreen> createState() => _ReadSmsScreenState();
}

class _ReadSmsScreenState extends State<ReadSmsScreen> {
  final Telephony telephony = Telephony.instance;

  bool isIncomeMessage(String body) {
  final text = body.toLowerCase();

  // Reject obvious debits first
  if (text.contains("debited") ||
      text.contains("dr.") ||
      text.contains("spent") ||
      text.contains("withdrawn")) {
    return false;
  }

  // Accept credits
  return text.contains("credited") ||
         text.contains("received") ||
         text.contains("deposited") ||
         text.contains("cr.");
}

  
  bool isPersonalTransaction(String body) {
  final text = body.toLowerCase();

  return text.contains("upi") ||
         text.contains("from") ||
         text.contains("transfer") ||
         text.contains("sent by") ||
         text.contains("neft") ||
         text.contains("imps");
}
  
  bool isGigIncome(String body) {
  final text = body.toLowerCase();

  return text.contains("swiggy") ||
         text.contains("zomato") ||
         text.contains("uber") ||
         text.contains("ola") ||
         text.contains("zepto") ||
         text.contains("earnings") ||
         text.contains("payout") ||
         text.contains("settlement");
}
  
  
  bool isValidGigIncome(String body) {
  if (!isIncomeMessage(body)) return false;

  final personal = isPersonalTransaction(body);
  final gig = isGigIncome(body);

  // Strong gig signal → accept
  if (gig) return true;

  // Looks like personal → reject
  if (personal) return false;

  // fallback (weak signal)
  return false;
}

  String textReceived = "";

  void startListening() {
    print("Starting to listen for incoming SMS...");
    telephony.listenIncomingSms(
		onNewMessage: (SmsMessage message) {
    final body = message.body ?? "";

    if (isIncomeMessage(body)) {
       setState(() {
         textReceived = body;
    });
  }
},
		listenInBackground: false
	);
  }

  @override
  void initState() {
    // TODO: implement initState
    startListening();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title:Text("Read Incoming SMS"),),
      body : Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(child: Text("Message received: $textReceived")),
      )
    );
  }
}