import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackTicket {
  final String id;
  final String userEmail;
  final int rating; // 1-5
  final String category; // 'bug', 'feature_request', 'experience', 'support'
  final String title;
  final String message;
  final String status; // 'open', 'processing', 'closed'
  final DateTime createdAt;
  final String response;

  FeedbackTicket({
    required this.id,
    required this.userEmail,
    required this.rating,
    required this.category,
    required this.title,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.response,
  });

  factory FeedbackTicket.fromMap(Map<String, dynamic> map, String id) {
    return FeedbackTicket(
      id: id,
      userEmail: map['userEmail'] ?? 'anonymous@gigtax.in',
      rating: map['rating'] ?? 5,
      category: map['category'] ?? 'experience',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      status: map['status'] ?? 'open',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      response: map['response'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userEmail': userEmail,
      'rating': rating,
      'category': category,
      'title': title,
      'message': message,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'response': response,
    };
  }

  FeedbackTicket copyWith({
    String? status,
    String? response,
  }) {
    return FeedbackTicket(
      id: id,
      userEmail: userEmail,
      rating: rating,
      category: category,
      title: title,
      message: message,
      status: status ?? this.status,
      createdAt: createdAt,
      response: response ?? this.response,
    );
  }
}
