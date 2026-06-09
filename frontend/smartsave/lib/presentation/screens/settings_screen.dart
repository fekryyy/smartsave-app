import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_util.dart';
import '../../presentation/providers/theme_provider.dart';
import '../../presentation/providers/auth_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final prefs = user?.notificationPreferences ?? {};
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Appearance
          Text('Appearance', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.grey500)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? AppColors.grey800 : AppColors.grey100)),
            child: SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Toggle dark theme'),
              secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: AppColors.primary),
              value: isDark,
              onChanged: (_) => themeProvider.toggleTheme(),
            ),
          ),
          const SizedBox(height: 24),

          // Currency
          Text('Currency', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.grey500)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? AppColors.grey800 : AppColors.grey100)),
            child: ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.attach_money, color: AppColors.primary)),
              title: const Text('Default Currency'),
              subtitle: Text('${user?.currency ?? 'USD'} (${CurrencyUtil.getSymbol(user?.currency)})'),
              trailing: const Icon(Icons.chevron_right, color: AppColors.grey400),
              onTap: () => _showCurrencyPicker(context),
            ),
          ),
          const SizedBox(height: 24),

          // Notifications
          Text('Notifications', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.grey500)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? AppColors.grey800 : AppColors.grey100)),
            child: Column(children: [
              SwitchListTile(title: const Text('Budget Warnings'), subtitle: const Text('Get notified when nearing budget limits'), secondary: const Icon(Icons.warning_amber_outlined, color: AppColors.warning), value: prefs['budgetWarnings'] ?? true, onChanged: (v) => _togglePref(context, 'budgetWarnings', v)),
              const Divider(height: 1, indent: 56),
              SwitchListTile(title: const Text('Goal Reminders'), subtitle: const Text('Reminders about your savings goals'), secondary: const Icon(Icons.flag_outlined, color: AppColors.primary), value: prefs['goalReminders'] ?? true, onChanged: (v) => _togglePref(context, 'goalReminders', v)),
              const Divider(height: 1, indent: 56),
              SwitchListTile(title: const Text('Weekly Summary'), subtitle: const Text('Weekly financial summary'), secondary: const Icon(Icons.summarize_outlined, color: AppColors.success), value: prefs['weeklySummary'] ?? true, onChanged: (v) => _togglePref(context, 'weeklySummary', v)),
              const Divider(height: 1, indent: 56),
              SwitchListTile(title: const Text('Saving Suggestions'), subtitle: const Text('Personalized saving recommendations'), secondary: const Icon(Icons.lightbulb_outline, color: AppColors.secondary), value: prefs['savingSuggestions'] ?? true, onChanged: (v) => _togglePref(context, 'savingSuggestions', v)),
            ]),
          ),
          const SizedBox(height: 24),

          // Security
          Text('Security', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.grey500)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? AppColors.grey800 : AppColors.grey100)),
            child: ListTile(
              leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.lock_outline, color: AppColors.danger)),
              title: const Text('Change Password'),
              trailing: const Icon(Icons.chevron_right, color: AppColors.grey400),
              onTap: () => _showChangePasswordDialog(context),
            ),
          ),
        ],
      ),
    );
  }

  void _togglePref(BuildContext context, String key, bool value) {
    final auth = context.read<AuthProvider>();
    final prefs = Map<String, dynamic>.from(auth.user?.notificationPreferences ?? {});
    prefs[key] = value;
    auth.updateProfile({'notificationPreferences': prefs});
  }

  void _showCurrencyPicker(BuildContext context) {
    showDialog(context: context, builder: (ctx) => SimpleDialog(
      title: const Text('Select Currency'),
      children: AppConstants.currencies.map((currency) => SimpleDialogOption(
        onPressed: () async {
          await context.read<AuthProvider>().updateProfile({'currency': currency});
          if (ctx.mounted) Navigator.pop(ctx);
        },
        child: Row(children: [
          const Icon(Icons.attach_money, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(currency, style: Theme.of(context).textTheme.bodyLarge),
        ]),
      )).toList(),
    ));
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Change Password'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: currentCtrl, decoration: const InputDecoration(labelText: 'Current Password'), obscureText: true),
        const SizedBox(height: 12),
        TextField(controller: newCtrl, decoration: const InputDecoration(labelText: 'New Password'), obscureText: true),
        const SizedBox(height: 12),
        TextField(controller: confirmCtrl, decoration: const InputDecoration(labelText: 'Confirm Password'), obscureText: true),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () async {
          if (newCtrl.text != confirmCtrl.text) return;
          final success = await context.read<AuthProvider>().changePassword(currentCtrl.text, newCtrl.text);
          if (success && ctx.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed')));
          }
        }, child: const Text('Change')),
      ],
    ));
  }
}
