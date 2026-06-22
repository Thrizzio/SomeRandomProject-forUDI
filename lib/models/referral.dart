import 'package:cloud_firestore/cloud_firestore.dart';

class Referral {
  final String id;
  final String referrerEmail;
  final String referralCode;
  final List<String> referredEmails;
  final double totalRewardsEarned;
  final bool isFlaggedForFraud;
  final String fraudReason;

  Referral({
    required this.id,
    required this.referrerEmail,
    required this.referralCode,
    required this.referredEmails,
    required this.totalRewardsEarned,
    required this.isFlaggedForFraud,
    required this.fraudReason,
  });

  factory Referral.fromMap(Map<String, dynamic> map, String id) {
    return Referral(
      id: id,
      referrerEmail: map['referrerEmail'] ?? '',
      referralCode: map['referralCode'] ?? '',
      referredEmails: List<String>.from(map['referredEmails'] ?? []),
      totalRewardsEarned: (map['totalRewardsEarned'] ?? 0.0).toDouble(),
      isFlaggedForFraud: map['isFlaggedForFraud'] ?? false,
      fraudReason: map['fraudReason'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'referrerEmail': referrerEmail,
      'referralCode': referralCode,
      'referredEmails': referredEmails,
      'totalRewardsEarned': totalRewardsEarned,
      'isFlaggedForFraud': isFlaggedForFraud,
      'fraudReason': fraudReason,
    };
  }

  Referral copyWith({
    List<String>? referredEmails,
    double? totalRewardsEarned,
    bool? isFlaggedForFraud,
    String? fraudReason,
  }) {
    return Referral(
      id: id,
      referrerEmail: referrerEmail,
      referralCode: referralCode,
      referredEmails: referredEmails ?? this.referredEmails,
      totalRewardsEarned: totalRewardsEarned ?? this.totalRewardsEarned,
      isFlaggedForFraud: isFlaggedForFraud ?? this.isFlaggedForFraud,
      fraudReason: fraudReason ?? this.fraudReason,
    );
  }
}
