import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/currency_util.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/providers/analytics_provider.dart';
import '../../app/routes.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final analyticsProvider = context.watch<AnalyticsProvider>();
    final user = authProvider.user;
    final format = CurrencyUtil.getFormat(user?.currency);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5))],
            ),
            child: Column(children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'S', style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              Text(user?.name ?? 'Smart Saver', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(user?.email ?? '', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 4),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)), child: Text(user?.currency ?? 'USD', style: const TextStyle(color: Colors.white, fontSize: 12))),
            ]),
          ),
          const SizedBox(height: 20),

          // Stats
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? AppColors.grey800 : AppColors.grey100)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _buildStat(context, 'Balance', format.format((analyticsProvider.dashboardData?.balance ?? 0)), isDark),
              _buildStat(context, 'Expenses', format.format((analyticsProvider.dashboardData?.monthlyExpenses ?? 0)), isDark),
              _buildStat(context, 'Goals', authProvider.isAuthenticated ? '3' : '0', isDark),
            ]),
          ),
          const SizedBox(height: 24),

          // Menu Items
          _buildMenuItem(context, Icons.account_balance_wallet_outlined, 'Budgets', () => Navigator.pushNamed(context, AppRoutes.budget)),
          _buildMenuItem(context, Icons.flag_outlined, 'Savings Goals', () => Navigator.pushNamed(context, AppRoutes.goals)),
          _buildMenuItem(context, Icons.notifications_outlined, 'Notifications', () => Navigator.pushNamed(context, AppRoutes.notifications)),
          _buildMenuItem(context, Icons.settings_outlined, 'Settings', () => Navigator.pushNamed(context, AppRoutes.settings)),
          _buildMenuItem(context, Icons.download_outlined, 'Export Data', () => _showExportOptions(context)),
          _buildMenuItem(context, Icons.info_outline, 'About', () => _showAbout(context)),
          const SizedBox(height: 24),

          // Logout
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout, color: AppColors.danger),
              label: const Text('Sign Out', style: TextStyle(color: AppColors.danger)),
              onPressed: () async {
                await context.read<AuthProvider>().logout();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
                }
              },
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger), padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(BuildContext context, String label, String value, bool isDark) {
    return Column(children: [Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), Text(label, style: Theme.of(context).textTheme.bodySmall)]);
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (isDark ? AppColors.darkCard : AppColors.grey50), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: AppColors.primary, size: 22)),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        trailing: const Icon(Icons.chevron_right, color: AppColors.grey400),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isDark ? AppColors.darkSurface : AppColors.white,
      ),
    );
  }

  void _showExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Export Data', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            ListTile(leading: const Icon(Icons.picture_as_pdf, color: AppColors.danger), title: const Text('PDF Report'), onTap: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF export coming soon'))); }),
            ListTile(leading: const Icon(Icons.table_chart, color: AppColors.success), title: const Text('Excel Report'), onTap: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel export coming soon'))); }),
            ListTile(leading: const Icon(Icons.description, color: AppColors.primary), title: const Text('CSV Report'), onTap: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV export coming soon'))); }),
          ]),
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(context: context, applicationName: 'SmartSave', applicationVersion: '1.0.0', applicationLegalese: '\u00a9 2024 SmartSave', children: [
      const Text('SmartSave helps you track expenses, analyze spending habits, and achieve your savings goals.'),
    ]);
  }
}
