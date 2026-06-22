import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../providers/tax_provider.dart';
import '../../models/tax_profile.dart';
import '../../services/analytics_service.dart';
import '../../services/monitoring_service.dart';
import '../../theme/design_system.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isDark = true;

  // Onboarding parameters
  String _profession = 'developer';
  String _regime = 'new';
  String _section = '44ada';
  final TextEditingController _incomeController = TextEditingController(text: '1200000');
  bool _smsPermissionGranted = false;

  @override
  Widget build(BuildContext context) {
    _isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _isDark ? DesignSystem.backgroundDark : DesignSystem.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DesignSystem.md),
          child: Column(
            children: [
              // Top Progress bar
              _buildProgressIndicator(),
              const SizedBox(height: DesignSystem.lg),

              // Page contents
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (val) {
                    setState(() {
                      _currentStep = val;
                    });
                  },
                  children: [
                    _buildWelcomeStep(),
                    _buildPermissionStep(),
                    _buildProfileSetupStep(),
                    _buildOnboardingValueStep(),
                  ],
                ),
              ),

              // Bottom control buttons
              _buildBottomControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: List.generate(4, (index) {
        final isActive = index <= _currentStep;
        return Expanded(
          child: Container(
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: isActive ? DesignSystem.primary : Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }

  // STEP 1: Welcome
  Widget _buildWelcomeStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: DesignSystem.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.rocket_launch_outlined, color: DesignSystem.primary, size: 64),
        ),
        const SizedBox(height: DesignSystem.lg),
        Text(
          'Welcome to GigTax',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: _isDark ? Colors.white : Colors.black87,
              ),
        ),
        const SizedBox(height: DesignSystem.sm),
        const Text(
          'Indian presumptive tax intelligence platform for freelancers, gig workers, and self-employed consultants.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: DesignSystem.lg),
        _buildBenefitRow(Icons.check_circle_outline, 'Real-time SMS & statement intelligence'),
        _buildBenefitRow(Icons.check_circle_outline, 'ITR-4 slab optimization and tax advice'),
        _buildBenefitRow(Icons.check_circle_outline, 'Automated advance tax deadline tracking'),
      ],
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, color: DesignSystem.success, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(color: _isDark ? Colors.white70 : Colors.black87, fontSize: 13))),
        ],
      ),
    );
  }

  // STEP 2: Permissions
  Widget _buildPermissionStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.sms_outlined, color: DesignSystem.primary, size: 56),
        const SizedBox(height: DesignSystem.md),
        const Text(
          'SMS Automation & Permissions',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        const SizedBox(height: DesignSystem.sm),
        const Text(
          'GigTax scans local transactional SMS messages to extract UPI credits and client receipts automatically. No personal messages are read or uploaded.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: DesignSystem.lg),
        CheckboxListTile(
          title: const Text('Allow SMS read permissions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: const Text('Enables automatic parsing of UPI/bank credit alerts.', style: TextStyle(fontSize: 11)),
          value: _smsPermissionGranted,
          activeColor: DesignSystem.primary,
          onChanged: (val) {
            setState(() {
              _smsPermissionGranted = val ?? false;
            });
          },
        ),
      ],
    );
  }

  // STEP 3: Profile Setup
  Widget _buildProfileSetupStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: Icon(Icons.person_pin_outlined, color: DesignSystem.primary, size: 56)),
          const SizedBox(height: DesignSystem.md),
          const Center(
            child: Text(
              'Tax Profile Settings',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          const SizedBox(height: DesignSystem.lg),

          // Expected Annual Income
          TextField(
            controller: _incomeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Expected Annual Income (₹)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: DesignSystem.md),

          // Profession Dropdown
          DropdownButtonFormField<String>(
            value: _profession,
            decoration: const InputDecoration(labelText: 'Profession Type', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'developer', child: Text('Software Developer')),
              DropdownMenuItem(value: 'consultant', child: Text('Consultant')),
              DropdownMenuItem(value: 'freelancer', child: Text('Freelancer')),
              DropdownMenuItem(value: 'gig', child: Text('Gig Worker')),
              DropdownMenuItem(value: 'delivery', child: Text('Delivery Partner')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _profession = val;
                });
              }
            },
          ),
          const SizedBox(height: DesignSystem.md),

          // Presumptive Scheme
          DropdownButtonFormField<String>(
            value: _section,
            decoration: const InputDecoration(labelText: 'Presumptive Tax Scheme', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: '44ada', child: Text('Section 44ADA (Professional - 50% Profit)')),
              DropdownMenuItem(value: '44ad', child: Text('Section 44AD (Business - 6% Profit)')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _section = val;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  // STEP 4: Onboarding Value reaching
  Widget _buildOnboardingValueStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.insights_outlined, color: DesignSystem.success, size: 64),
        const SizedBox(height: DesignSystem.md),
        const Text(
          'Onboarding Successful!',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        const SizedBox(height: DesignSystem.sm),
        const Text(
          'Your profile is configured. You are ready to start importing transactions and generating legislative tax reports.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: DesignSystem.lg),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DesignSystem.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DesignSystem.success.withValues(alpha: 0.2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_outline, color: DesignSystem.success, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your data is encrypted locally and isolated inside secure Firestore rules.',
                  style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentStep > 0)
          TextButton(
            onPressed: () {
              _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
            },
            child: const Text('Back'),
          )
        else
          const SizedBox.shrink(),
        DesignSystem.gradientButton(
          text: _currentStep == 3 ? 'Launch GigTax' : 'Continue',
          onPressed: () async {
            if (_currentStep == 3) {
              // Save completed onboarding flag
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('onboarding_completed_v1', true);
              
              // Log onboarding complete
              await AnalyticsService.logOnboardingComplete();
              MonitoringService.recordAppReady();

              // Update tax profile service
              final taxProvider = context.read<TaxProvider>();
              final double expectedIncome = double.tryParse(_incomeController.text) ?? 1200000;
              final updatedProfile = TaxProfile(
                professionType: _profession,
                taxRegime: _regime,
                businessCategory: _section,
                expectedAnnualIncome: expectedIncome,
                businessType: _profession == 'developer' ? 'Software Development' : 'Freelance Consulting',
                deductions: TaxDeductions(),
                updatedAt: DateTime.now(),
              );
              await taxProvider.updateProfile(updatedProfile);

              widget.onComplete();
            } else {
              _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
            }
          },
        ),
      ],
    );
  }
}
