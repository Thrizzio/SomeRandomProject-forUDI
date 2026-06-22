import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/notification_service.dart';
import '../../services/analytics_service.dart';
import '../../theme/design_system.dart';
import '../../models/transaction.dart';
import '../founder/founder_dashboard_screen.dart';
import '../monetization/monetization_portal_screen.dart';

class SettingsCenterScreen extends StatefulWidget {
  const SettingsCenterScreen({super.key});

  @override
  State<SettingsCenterScreen> createState() => _SettingsCenterScreenState();
}

class _SettingsCenterScreenState extends State<SettingsCenterScreen> {
  bool _smsParsingEnabled = true;
  bool _statementImportsEnabled = true;
  bool _notificationHistoryEnabled = true;
  bool _isDark = true;

  @override
  Widget build(BuildContext context) {
    _isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: _isDark ? DesignSystem.backgroundDark : DesignSystem.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DesignSystem.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Screen Title
              Text(
                'Settings Center',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _isDark ? Colors.white : Colors.black87,
                    ),
              ),
              const SizedBox(height: DesignSystem.lg),

              // Section: Account Profile
              _buildSectionHeader('Account Info'),
              const SizedBox(height: DesignSystem.sm),
              DesignSystem.glassCard(
                isDark: _isDark,
                borderRadius: 18,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: DesignSystem.primary.withValues(alpha: 0.1),
                    radius: 24,
                    child: Text(
                      user?.email?.isNotEmpty == true ? user!.email![0].toUpperCase() : '?',
                      style: const TextStyle(color: DesignSystem.primary, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  title: Text(
                    user?.email ?? 'Not Logged In',
                    style: TextStyle(
                      color: _isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: const Text('Verified Member', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.logout, color: DesignSystem.error),
                    onPressed: () async {
                      await auth.logout();
                    },
                  ),
                ),
              ),
              const SizedBox(height: DesignSystem.lg),

              // Section: Preferences Toggles
              _buildSectionHeader('System & Toggles'),
              const SizedBox(height: DesignSystem.sm),
              DesignSystem.glassCard(
                isDark: _isDark,
                borderRadius: 18,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildToggleTile(
                      title: 'Automatic SMS Parsing',
                      subtitle: 'Process financial receipt SMS in the background',
                      value: _smsParsingEnabled,
                      onChanged: (val) => setState(() => _smsParsingEnabled = val),
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    _buildToggleTile(
                      title: 'Automatic Statement Imports',
                      subtitle: 'Allow CSV & text statement conversions',
                      value: _statementImportsEnabled,
                      onChanged: (val) => setState(() => _statementImportsEnabled = val),
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    _buildToggleTile(
                      title: 'Save Notification History',
                      subtitle: 'Store in-app notifications in local history',
                      value: _notificationHistoryEnabled,
                      onChanged: (val) => setState(() => _notificationHistoryEnabled = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DesignSystem.lg),

              // Section: Startup, Monetization & Referrals
              _buildSectionHeader('Monetization & Startup Growth'),
              const SizedBox(height: DesignSystem.sm),
              DesignSystem.glassCard(
                isDark: _isDark,
                borderRadius: 18,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.star_border_outlined, color: Colors.amber),
                      title: Text('Upgrade to GigTax Pro', style: TextStyle(color: _isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('Access What-If simulator, local AI tax advisor, and unlimited PDF exports', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const MonetizationPortalScreen()),
                        );
                      },
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    ListTile(
                      leading: const Icon(Icons.rocket_launch_outlined, color: DesignSystem.primary),
                      title: Text('Founder Command Center', style: TextStyle(color: _isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('Real-time startup health, user retention cohorts, support tickets, and performance indicators', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const FounderDashboardScreen()),
                        );
                      },
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    ListTile(
                      leading: const Icon(Icons.forum_outlined, color: DesignSystem.success),
                      title: Text('Submit Support Ticket & Feedback', style: TextStyle(color: _isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('Rate experience, submit bug reports, feature requests, or contact support', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                      onTap: _showFeedbackDialog,
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    ListTile(
                      leading: const Icon(Icons.share_outlined, color: DesignSystem.warning),
                      title: Text('Referral Program & Rewards', style: TextStyle(color: _isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('Share your referral code and earn ₹500 in Pro credits', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 12),
                      onTap: _showReferralDialog,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DesignSystem.lg),

              // Section: Data & Resets
              _buildSectionHeader('Storage & Management'),
              const SizedBox(height: DesignSystem.sm),
              DesignSystem.glassCard(
                isDark: _isDark,
                borderRadius: 18,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Clear Transaction Logs', style: TextStyle(color: DesignSystem.error, fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('Wipe out all local and cached transactional records', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      trailing: const Icon(Icons.delete_sweep_outlined, color: DesignSystem.error),
                      onTap: () => _confirmReset(context),
                    ),
                    const Divider(color: Colors.white10, height: 1),
                    ListTile(
                      title: Text('Import Test Data', style: TextStyle(color: _isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('Add 10+ mock transaction receipts for dashboard testing', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      trailing: const Icon(Icons.input_outlined, color: DesignSystem.primary),
                      onTap: () => _importMockData(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: TextStyle(
          color: _isDark ? Colors.white70 : Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: TextStyle(
          color: _isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      value: value,
      activeColor: DesignSystem.primary,
      onChanged: onChanged,
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text('This action will delete all recorded income transactions permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: DesignSystem.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Wipe Data', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseService.clearAllTransactions();
      await NotificationService.clearNotifications();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transactions wiped successfully!')),
        );
      }
    }
  }

  Future<void> _importMockData(BuildContext context) async {
    final mockTransactions = [
      Transaction(amount: '4500.00', sender: 'Uber', messageBody: 'Credited INR 4500.00 to account', transactionType: 'income', date: DateTime.now().toIso8601String()),
      Transaction(amount: '2800.00', sender: 'Swiggy', messageBody: 'Credited INR 2800.00', transactionType: 'income', date: DateTime.now().subtract(const Duration(days: 2)).toIso8601String()),
      Transaction(amount: '6700.00', sender: 'Zomato', messageBody: 'Credited INR 6700.00', transactionType: 'income', date: DateTime.now().subtract(const Duration(days: 4)).toIso8601String()),
      Transaction(amount: '12000.00', sender: 'Freelance', messageBody: 'Client payout for designing', transactionType: 'income', date: DateTime.now().subtract(const Duration(days: 10)).toIso8601String()),
      Transaction(amount: '150.00', sender: 'Zepto', messageBody: 'Zepto runner tip INR 150.00', transactionType: 'income', date: DateTime.now().subtract(const Duration(days: 12)).toIso8601String()),
      Transaction(amount: '9500.00', sender: 'Uber', messageBody: 'Credited INR 9500.00', transactionType: 'income', date: DateTime.now().subtract(const Duration(days: 32)).toIso8601String()),
    ];

    for (final tx in mockTransactions) {
      await DatabaseService.insertTransaction(tx);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mock transactions imported!')),
      );
    }
  }

  void _showFeedbackDialog() {
    int rating = 5;
    String category = 'experience';
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Submit Feedback / Support Ticket'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            Icons.star,
                            color: index < rating ? Colors.amber : Colors.grey,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              rating = index + 1;
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(labelText: 'Feedback Type', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'experience', child: Text('Rate Experience')),
                        DropdownMenuItem(value: 'bug', child: Text('Report a Bug')),
                        DropdownMenuItem(value: 'feature_request', child: Text('Request a Feature')),
                        DropdownMenuItem(value: 'support', child: Text('Contact CA / Tech Support')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            category = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Subject / Title', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: messageController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Details / Description', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.isEmpty || messageController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill out all fields.')),
                      );
                      return;
                    }
                    final auth = context.read<AuthProvider>();
                    final email = auth.user?.email ?? 'anonymous@gigtax.in';
                    
                    await FirebaseFirestore.instance.collection('feedback_tickets').add({
                      'userEmail': email,
                      'rating': rating,
                      'category': category,
                      'title': titleController.text,
                      'message': messageController.text,
                      'status': 'open',
                      'createdAt': FieldValue.serverTimestamp(),
                      'response': '',
                    });

                    await AnalyticsService.logEvent(
                      eventName: 'feedback_submitted',
                      category: 'growth',
                      parameters: {'type': category, 'rating': rating},
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Thank you! Your ticket has been submitted to the support queue.')),
                      );
                    }
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showReferralDialog() {
    final code = 'GIGTAX_${(context.read<AuthProvider>().user?.email ?? "USER").split("@")[0].toUpperCase()}';
    showDialog(
      context: context,
      builder: (context) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('referrals')
              .where('referrerEmail', isEqualTo: context.read<AuthProvider>().user?.email ?? '')
              .snapshots(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            final referralDoc = docs.isNotEmpty ? docs.first : null;
            final count = referralDoc != null ? List<String>.from(referralDoc['referredEmails'] ?? []).length : 0;
            final rewards = referralDoc != null ? referralDoc['totalRewardsEarned'] ?? 0.0 : 0.0;

            return AlertDialog(
              title: const Text('Referral Program'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Invite fellow freelancers to GigTax and earn ₹500 in Pro credits for every friend who activates their profile!',
                      style: TextStyle(fontSize: 12, height: 1.3), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: DesignSystem.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(code, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: DesignSystem.primary)),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Referral code copied to clipboard!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatsMini('Invites', '$count'),
                      _buildStatsMini('Rewards', '₹$rewards'),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatsMini(String label, String val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: DesignSystem.success)),
      ],
    );
  }
}
