import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../app/routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;
  String _selectedCurrency = 'USD';
  Map<String, bool> _prefs = {
    'budgetWarnings': true,
    'goalReminders': true,
    'weeklySummary': true,
    'savingSuggestions': true,
  };

  final _pages = [
    _OnboardingPageData(
      icon: Icons.savings_rounded,
      title: 'Welcome to SmartSave',
      subtitle: 'Take control of your finances with smart budgeting, goal tracking, and insightful analytics.',
      color: AppColors.primary,
    ),
    _OnboardingPageData(
      icon: Icons.auto_graph_rounded,
      title: 'Track Everything',
      subtitle: 'Log expenses & income, scan receipts, set budgets, track savings goals, and get personalized insights.',
      color: AppColors.success,
    ),
    _OnboardingPageData(
      icon: Icons.tune_rounded,
      title: 'Almost Ready!',
      subtitle: 'Choose your currency and notification preferences to get started.',
      color: AppColors.secondary,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final auth = context.read<AuthProvider>();
    await auth.updateProfile({'currency': _selectedCurrency, 'notificationPreferences': _prefs});
    await auth.updateProfile({'onboardingCompleted': true});
    if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _page = i),
              children: [
                _buildPage(0, isDark),
                _buildPage(1, isDark),
                _buildPage(2, isDark),
              ],
            ),
          ),
          // Dots + Buttons
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              TextButton(
                onPressed: _page < 2 ? () => _pageController.jumpToPage(2) : null,
                child: Text(_page < 2 ? 'Skip' : '', style: TextStyle(color: isDark ? AppColors.grey500 : AppColors.grey400)),
              ),
              Row(children: List.generate(3, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _page == i ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(color: _page == i ? AppColors.primary : AppColors.grey300, borderRadius: BorderRadius.circular(4)),
              ))),
              _page < 2
                  ? ElevatedButton(
                      onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Next'),
                    )
                  : ElevatedButton(
                      onPressed: _finish,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Get Started'),
                    ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildPage(int index, bool isDark) {
    final data = _pages[index];
    final body = Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(color: data.color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(data.icon, size: 72, color: data.color),
        ),
        const SizedBox(height: 40),
        Text(data.title, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Text(data.subtitle, style: TextStyle(fontSize: 15, color: isDark ? AppColors.grey400 : AppColors.grey500, height: 1.5), textAlign: TextAlign.center),
        if (index == 2) ...[
          const SizedBox(height: 32),
          _buildSetup(isDark),
        ],
      ]),
    );
    return index == 2 ? SingleChildScrollView(child: body) : body;
  }

  Widget _buildSetup(bool isDark) {
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final hintCol = isDark ? AppColors.grey500 : AppColors.grey400;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? AppColors.darkCard : const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Currency', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: hintCol)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCurrency,
          decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), filled: true, fillColor: isDark ? AppColors.darkCardAlt : Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          style: TextStyle(fontSize: 15, color: textCol),
          dropdownColor: isDark ? AppColors.darkCard : Colors.white,
          items: AppConstants.currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) { if (v != null) setState(() => _selectedCurrency = v); },
        ),
        const SizedBox(height: 20),
        Text('Notifications', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: hintCol)),
        const SizedBox(height: 4),
        ..._prefs.entries.map((e) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_prefLabel(e.key), style: TextStyle(fontSize: 14, color: textCol)),
            Switch(
              value: e.value,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _prefs[e.key] = v),
            ),
          ]),
        )),
      ]),
    );
  }

  String _prefLabel(String key) {
    switch (key) {
      case 'budgetWarnings': return 'Budget Warnings';
      case 'goalReminders': return 'Goal Reminders';
      case 'weeklySummary': return 'Weekly Summary';
      case 'savingSuggestions': return 'Saving Suggestions';
      default: return key;
    }
  }
}

class _OnboardingPageData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _OnboardingPageData({required this.icon, required this.title, required this.subtitle, required this.color});
}
