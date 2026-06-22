import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/analytics_service.dart';
import '../../services/monitoring_service.dart';
import '../../theme/design_system.dart';

class MonetizationPortalScreen extends StatefulWidget {
  const MonetizationPortalScreen({super.key});

  @override
  State<MonetizationPortalScreen> createState() => _MonetizationPortalScreenState();
}

class _MonetizationPortalScreenState extends State<MonetizationPortalScreen> {
  bool _isDark = true;
  bool _isPro = false;
  bool _upgrading = false;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
  }

  Future<void> _loadSubscriptionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isPro = prefs.getBool('is_pro_member') ?? false;
    });
  }

  Future<void> _toggleSubscription() async {
    setState(() => _upgrading = true);
    await Future.delayed(const Duration(seconds: 1)); // Mock checkout API
    
    final prefs = await SharedPreferences.getInstance();
    final nextState = !_isPro;
    await prefs.setBool('is_pro_member', nextState);
    
    if (nextState) {
      await AnalyticsService.logProUpgrade('Pro Yearly', 4999.0);
    }

    setState(() {
      _isPro = nextState;
      _upgrading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nextState ? 'Upgraded to GigTax Pro successfully!' : 'Cancelled subscription.'),
          backgroundColor: DesignSystem.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _isDark ? DesignSystem.backgroundDark : DesignSystem.backgroundLight,
      appBar: AppBar(
        title: const Text('Monetization & Pro Plans'),
        backgroundColor: _isDark ? DesignSystem.backgroundDark : Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DesignSystem.md),
        child: Column(
          children: [
            // Header Promo Banner
            _buildPromoHeader(),
            const SizedBox(height: DesignSystem.lg),

            // Plan Comparison Matrices
            _buildComparisonCard('GigTax Free', '₹0', 'Perfect for tracking initial client payments.', [
              'Income and invoice tracking',
              'Basic tax estimates (Section 44AD)',
              'Standard Dashboard charts',
              'Limited to 1 report download per month',
            ], false),
            const SizedBox(height: DesignSystem.lg),

            _buildComparisonCard('GigTax Pro (Highly Recommended)', '₹4,999 / year', 'For serious freelancers and consultants optimizing taxes.', [
              'All Free capabilities',
              'Presumptive tax optimization algorithms',
              'Unlimited CA-ready reports (PDF exports)',
              'What-If Income Tax Simulator',
              'Interactive AI Tax Assistant (Local Rules)',
              'Priority 24/7 CA Customer Support tickets',
            ], true),
            const SizedBox(height: DesignSystem.xl),

            // Action upgrade button
            _buildUpgradeButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: DesignSystem.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Optimize. Save. Comply.',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            _isPro 
                ? 'Thank you for supporting GigTax as a Pro Member!'
                : 'Join 5,000+ Indian freelancers saving an average of ₹45,000 annually in taxes.',
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCard(String name, String price, String desc, List<String> features, bool isProHighlight) {
    return DesignSystem.glassCard(
      isDark: _isDark,
      borderRadius: 20,
      border: isProHighlight ? Border.all(color: DesignSystem.primary.withValues(alpha: 0.4), width: 1.5) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isProHighlight ? DesignSystem.primary : (_isDark ? Colors.white : Colors.black87))),
              Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: DesignSystem.success)),
            ],
          ),
          const SizedBox(height: 6),
          Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const Divider(height: 24),
          ...features.map((feat) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                const Icon(Icons.check, color: DesignSystem.success, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(feat, style: TextStyle(fontSize: 12, color: _isDark ? Colors.white70 : Colors.black87))),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildUpgradeButton() {
    return Center(
      child: DesignSystem.gradientButton(
        text: _isPro ? 'Downgrade Subscription' : 'Upgrade to GigTax Pro',
        isLoading: _upgrading,
        icon: _isPro ? Icons.remove_circle_outline : Icons.star_border_outlined,
        onPressed: _toggleSubscription,
      ),
    );
  }
}
