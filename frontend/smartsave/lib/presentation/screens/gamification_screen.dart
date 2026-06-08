import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../presentation/providers/challenge_provider.dart';
import '../../data/models/gamification_model.dart';

class GamificationScreen extends StatefulWidget {
  const GamificationScreen({super.key});

  @override
  State<GamificationScreen> createState() => _GamificationScreenState();
}

class _GamificationScreenState extends State<GamificationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChallengeProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChallengeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Gamification'),
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(children: [
        // Streak Header
        if (provider.streak != null)
          _buildStreakHeader(provider.streak!, isDark),
        TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.grey400,
          tabs: const [Tab(text: 'Challenges'), Tab(text: 'Badges'), Tab(text: 'Join New')],
        ),
        Expanded(child: TabBarView(
          controller: _tabController,
          children: [
            _buildChallenges(provider, isDark),
            _buildBadges(provider, isDark),
            _buildJoinForm(isDark),
          ],
        )),
      ]),
    );
  }

  Widget _buildStreakHeader(UserStreakModel streak, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _streakItem(Icons.local_fire_department_rounded, '${streak.loginStreak}', 'Day Streak'),
        _streakItem(Icons.emoji_events_rounded, '${streak.totalPoints}', 'Points'),
        _streakItem(Icons.block_rounded, '${streak.noSpendStreak}', 'No-Spend'),
      ]),
    );
  }

  Widget _streakItem(IconData icon, String value, String label) {
    return Column(children: [
      Icon(icon, color: Colors.yellowAccent, size: 24),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]);
  }

  Widget _buildChallenges(ChallengeProvider provider, bool isDark) {
    if (provider.isLoading) return const Center(child: CircularProgressIndicator());
    final active = provider.challenges.where((c) => c.status == 'active').toList();
    final completed = provider.challenges.where((c) => c.status == 'completed').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Active Challenges', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
        const SizedBox(height: 12),
        if (active.isEmpty)
          Container(width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: isDark ? AppColors.darkCard : Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Text('No active challenges. Join one in the "Join New" tab!', style: TextStyle(color: isDark ? AppColors.grey500 : AppColors.grey400)))
        else
          ...active.map((c) => _buildChallengeCard(c, isDark)),
        if (completed.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Completed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
          const SizedBox(height: 12),
          ...completed.map((c) => _buildChallengeCard(c, isDark)),
        ],
      ]),
    );
  }

  Widget _buildChallengeCard(ChallengeModel c, bool isDark) {
    final isDone = c.status == 'completed';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDone ? AppColors.success.withOpacity(0.3) : (isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(_challengeIcon(c.type), size: 22, color: isDone ? AppColors.success : AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(c.title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: isDark ? Colors.white : const Color(0xFF0F172A)))),
          if (c.points > 0)
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Text('+${c.points} pts', style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600))),
        ]),
        if (c.description.isNotEmpty) ...[const SizedBox(height: 6), Text(c.description, style: TextStyle(fontSize: 12, color: isDark ? AppColors.grey400 : AppColors.grey500))],
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(
          value: c.progressPct,
          backgroundColor: isDone ? AppColors.success.withOpacity(0.1) : (isDark ? AppColors.darkCardAlt : const Color(0xFFF1F5F9)),
          valueColor: AlwaysStoppedAnimation<Color>(isDone ? AppColors.success : AppColors.primary),
          minHeight: 8,
        )),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${(c.progressPct * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.grey400 : AppColors.grey500)),
          if (isDone)
            const Text('Completed!', style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600))
          else
            Text('${c.progress.toStringAsFixed(0)} / ${c.goal.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: isDark ? AppColors.grey500 : AppColors.grey400)),
        ]),
      ]),
    );
  }

  Widget _buildBadges(ChallengeProvider provider, bool isDark) {
    if (provider.isLoading) return const Center(child: CircularProgressIndicator());
    final badges = provider.achievements;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your Badges (${badges.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
        const SizedBox(height: 16),
        if (badges.isEmpty)
          Container(width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: isDark ? AppColors.darkCard : Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Text('No badges yet. Complete challenges and activities to earn badges!', style: TextStyle(color: isDark ? AppColors.grey500 : AppColors.grey400)))
        else
          Wrap(spacing: 12, runSpacing: 12, children: badges.map((b) => _buildBadgeCard(b, isDark)).toList()),
      ]),
    );
  }

  Widget _buildBadgeCard(AchievementModel a, bool isDark) {
    return Container(
      width: (MediaQuery.of(context).size.width - 52) / 2,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
      ),
      child: Column(children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.emoji_events_rounded, color: AppColors.warning, size: 28)),
        const SizedBox(height: 10),
        Text(a.title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(DateFormat('MMM dd').format(a.unlockedAt), style: TextStyle(fontSize: 11, color: isDark ? AppColors.grey500 : AppColors.grey400)),
      ]),
    );
  }

  Widget _buildJoinForm(bool isDark) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final goalCtrl = TextEditingController();
    String type = 'savings';
    int points = 50;
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Create a Custom Challenge', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textCol)),
        const SizedBox(height: 16),
        StatefulBuilder(builder: (ctx, setLocal) => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: isDark ? AppColors.darkCard : Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(children: [
            TextField(controller: titleCtrl, style: TextStyle(color: textCol),
              decoration: InputDecoration(labelText: 'Title', labelStyle: TextStyle(color: isDark ? AppColors.grey500 : AppColors.grey400),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, style: TextStyle(color: textCol), maxLines: 2,
              decoration: InputDecoration(labelText: 'Description (optional)', labelStyle: TextStyle(color: isDark ? AppColors.grey500 : AppColors.grey400),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: type, style: TextStyle(color: textCol),
              dropdownColor: isDark ? AppColors.darkCard : Colors.white,
              decoration: InputDecoration(labelText: 'Type', labelStyle: TextStyle(color: isDark ? AppColors.grey500 : AppColors.grey400),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              items: const [
                DropdownMenuItem(value: 'savings', child: Text('Savings Goal')),
                DropdownMenuItem(value: 'no_spend', child: Text('No-Spend Days')),
                DropdownMenuItem(value: 'transaction_count', child: Text('Transaction Count')),
              ],
              onChanged: (v) { if (v != null) setLocal(() => type = v); },
            ),
            const SizedBox(height: 12),
            TextField(controller: goalCtrl, style: TextStyle(color: textCol), keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Target (e.g. 1000 for savings, 7 for days)',
                labelStyle: TextStyle(color: isDark ? AppColors.grey500 : AppColors.grey400, fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.isEmpty || goalCtrl.text.isEmpty) return;
                  final success = await context.read<ChallengeProvider>().joinChallenge({
                    'title': titleCtrl.text,
                    'description': descCtrl.text,
                    'type': type,
                    'goal': double.parse(goalCtrl.text),
                    'points': points,
                  });
                  if (success && ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Challenge created!')));
                    _tabController.animateTo(0);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text('Start Challenge'),
              ),
            ),
          ]),
        )),
      ]),
    );
  }

  IconData _challengeIcon(String type) {
    switch (type) {
      case 'savings': return Icons.savings_rounded;
      case 'no_spend': return Icons.block_rounded;
      case 'budget_streak': return Icons.trending_up_rounded;
      case 'transaction_count': return Icons.receipt_long_rounded;
      case 'login_streak': return Icons.login_rounded;
      default: return Icons.emoji_events_rounded;
    }
  }
}
