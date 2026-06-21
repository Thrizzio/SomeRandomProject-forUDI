import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_logger.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  bool isRead;
  final String type; // 'income', 'tax', 'report', 'milestone'

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
        'type': type,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        isRead: json['isRead'] as bool? ?? false,
        type: json['type'] as String? ?? 'info',
      );
}

class NotificationService {
  static const String _storageKey = 'app_notifications';
  static final List<AppNotification> _notifications = [];
  
  static final StreamController<List<AppNotification>> _controller = 
      StreamController<List<AppNotification>>.broadcast();

  static Stream<List<AppNotification>> get notificationsStream => _controller.stream;

  static Future<void> loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_storageKey);
      
      _notifications.clear();
      if (list != null) {
        _notifications.addAll(list.map((str) {
          return AppNotification.fromJson(json.decode(str) as Map<String, dynamic>);
        }));
        _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
      _controller.add(List.from(_notifications));
    } catch (e) {
      AppLogger.warning('NotificationService', 'Failed to load notifications: $e');
    }
  }

  static Future<void> addNotification({
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      final newNotif = AppNotification(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        body: body,
        timestamp: DateTime.now(),
        type: type,
      );

      _notifications.insert(0, newNotif);
      await _save();
      _controller.add(List.from(_notifications));
    } catch (e) {
      AppLogger.error('NotificationService', 'Error adding notification', e);
    }
  }

  static Future<void> markAllAsRead() async {
    for (final notif in _notifications) {
      notif.isRead = true;
    }
    await _save();
    _controller.add(List.from(_notifications));
  }

  static Future<void> clearNotifications() async {
    _notifications.clear();
    await _save();
    _controller.add(List.from(_notifications));
  }

  static Future<void> checkMilestones(double totalIncome) async {
    await loadNotifications();
    final milestones = [10000.0, 50000.0, 100000.0, 500000.0];
    
    for (final milestone in milestones) {
      final title = 'Milestone Reached! 🎉';
      final body = 'Congratulations! You have crossed ₹${milestone.toStringAsFixed(0)} in tracked income.';
      
      // Check if we already sent this milestone
      final exists = _notifications.any(
        (n) => n.type == 'milestone' && n.body.contains('₹${milestone.toStringAsFixed(0)}')
      );

      if (totalIncome >= milestone && !exists) {
        await addNotification(
          title: title,
          body: body,
          type: 'milestone',
        );
      }
    }
  }

  static Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _notifications.map((n) => json.encode(n.toJson())).toList();
      await prefs.setStringList(_storageKey, list);
    } catch (e) {
      // ignore
    }
  }
}
