import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/theme/app_colors.dart';
import '../providers/financial_advisor_provider.dart';
import '../../data/models/financial_advisor_models.dart';
import '../../app/app.dart';

class FinancialAdvisorScreen extends StatefulWidget {
  const FinancialAdvisorScreen({super.key});

  @override
  State<FinancialAdvisorScreen> createState() => _FinancialAdvisorScreenState();
}

class _FinancialAdvisorScreenState extends State<FinancialAdvisorScreen> with RouteAware {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _chatFocus = FocusNode();
  bool _showChat = false;
  bool _showAllInsights = false;
  bool _showAllPlans = false;

  static const List<String> _suggestedQuestions = [
    'How can I save more money?',
    'How healthy are my finances?',
    'What is my biggest spending problem?',
    'How much can I spend this week?',
    'When will I reach my savings goal?',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _chatController.dispose();
    _scrollController.dispose();
    _chatFocus.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadData();
  }

  void _loadData() {
    context.read<FinancialAdvisorProvider>().loadAll();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    context.read<FinancialAdvisorProvider>().askQuestion(text.trim());
    _chatController.clear();
    _chatFocus.unfocus();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinancialAdvisorProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // AppBar
            _buildAppBar(isDark),
            // Main content
            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : provider.consentRequired
                      ? _buildConsentPrompt(provider, isDark)
                      : provider.errorMessage != null && provider.analysis == null
                          ? _buildErrorState(provider, isDark)
                          : _buildContent(provider, isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ── AppBar ──
  Widget _buildAppBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border(
          bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.grey100),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCardAlt : AppColors.grey100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : AppColors.grey700, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Financial Advisor', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                Text('Personal AI-powered insights', style: TextStyle(fontSize: 12, color: isDark ? AppColors.grey400 : AppColors.grey500)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() => _showChat = !_showChat);
              if (_showChat) _scrollToBottom();
            },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _showChat ? AppColors.primary.withValues(alpha: 0.15) : (isDark ? AppColors.darkCardAlt : AppColors.grey100),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _showChat ? Icons.analytics_rounded : Icons.chat_rounded,
                color: _showChat ? AppColors.primary : (isDark ? AppColors.grey400 : AppColors.grey600),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Error State ──
  Widget _buildErrorState(FinancialAdvisorProvider provider, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 64, color: AppColors.grey300),
            const SizedBox(height: 16),
            Text('Unable to load financial analysis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
            const SizedBox(height: 8),
            const Text('Make sure your backend server is running and you have transactions added.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.grey500)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => provider.loadAll(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Consent Prompt ──
  Widget _buildConsentPrompt(FinancialAdvisorProvider provider, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 48, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to SmartSave Advisor',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            Text(
              'Your personal AI-powered financial assistant that provides:\n\n'
              '• Personalized spending insights\n'
              '• Smart savings recommendations\n'
              '• Action plans to reach your goals\n'
              '• Financial predictions & forecasts\n'
              '• Conversational Q&A about your finances',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.6, color: isDark ? AppColors.grey400 : AppColors.grey600),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.primary : AppColors.primary).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: (isDark ? AppColors.primary : AppColors.primary).withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your financial data will be processed by AI providers (OpenAI, Claude, or DeepSeek) to generate personalized insights. '
                      'Your data is encrypted in transit and never stored by third parties. You can revoke consent at any time.',
                      style: TextStyle(fontSize: 13, height: 1.5, color: isDark ? AppColors.grey400 : AppColors.grey700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => provider.acceptConsent(),
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Accept & Continue'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Not now', style: TextStyle(fontSize: 14, color: isDark ? AppColors.grey400 : AppColors.grey500)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Main Content ──
  Widget _buildContent(FinancialAdvisorProvider provider, bool isDark) {
    if (_showChat) {
      return _buildChatView(provider, isDark);
    }
    return _buildAnalysisView(provider, isDark);
  }

  // ── Analysis View (Default) ──
  Widget _buildAnalysisView(FinancialAdvisorProvider provider, bool isDark) {
    final analysis = provider.analysis;

    return RefreshIndicator(
      onRefresh: () => provider.loadAll(),
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Financial Score Card
            if (analysis?.score != null) ...[
              _buildScoreCard(analysis!.score, isDark),
              const SizedBox(height: 16),
            ],

            // Financial Health Card
            if (analysis?.health != null) ...[
              _buildHealthCard(analysis!.health, isDark),
              const SizedBox(height: 20),
            ],

            // Smart Insights
            if (provider.insights.isNotEmpty) ...[
              _buildSectionHeader('Smart Insights', Icons.lightbulb_outline_rounded, isDark),
              const SizedBox(height: 12),
              ...provider.insights.take(_showAllInsights ? provider.insights.length : 4).map((insight) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildInsightCard(insight, isDark),
              )),
              if (provider.insights.length > 4)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Center(
                    child: TextButton(
                      onPressed: () => setState(() => _showAllInsights = !_showAllInsights),
                      child: Text(
                        _showAllInsights ? 'Show Less' : 'Show All (${provider.insights.length})',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],

            // Savings Opportunities
            if (analysis?.opportunities != null && analysis!.opportunities.isNotEmpty) ...[
              _buildSectionHeader('Savings Opportunities', Icons.savings_outlined, isDark),
              const SizedBox(height: 12),
              ...analysis.opportunities.map((opp) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildOpportunityCard(opp, isDark),
              )),
              const SizedBox(height: 16),
            ],

            // Action Plans
            if (provider.actionPlans.isNotEmpty) ...[
              _buildSectionHeader('Action Plans', Icons.checklist_rounded, isDark),
              const SizedBox(height: 12),
              ...provider.actionPlans.take(_showAllPlans ? provider.actionPlans.length : 2).map((plan) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildActionPlanCard(plan, isDark),
              )),
              if (provider.actionPlans.length > 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Center(
                    child: TextButton(
                      onPressed: () => setState(() => _showAllPlans = !_showAllPlans),
                      child: Text(
                        _showAllPlans ? 'Show Less' : 'Show All (${provider.actionPlans.length})',
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],

            // Predictions
            if (provider.predictions.isNotEmpty) ...[
              _buildSectionHeader('Predictions & Projections', Icons.trending_up_rounded, isDark),
              const SizedBox(height: 12),
              ...provider.predictions.map((pred) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildPredictionCard(pred, isDark),
              )),
              const SizedBox(height: 16),
            ],

            // Ask a question CTA
            FadeInUp(
              child: GestureDetector(
                onTap: () => setState(() => _showChat = true),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.chat_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ask Your Financial Advisor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                            SizedBox(height: 4),
                            Text('Get personalized answers about your money', style: TextStyle(fontSize: 13, color: Colors.white70)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Chat View ──
  Widget _buildChatView(FinancialAdvisorProvider provider, bool isDark) {
    return Column(
      children: [
        // Chat messages
        Expanded(
          child: provider.chatHistory.isEmpty
              ? _buildChatEmptyState(provider, isDark)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.chatHistory.length,
                  itemBuilder: (ctx, index) {
                    final msg = provider.chatHistory[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildChatBubble(msg, isDark),
                    );
                  },
                ),
        ),
        // Chat input
        _buildChatInput(provider, isDark),
      ],
    );
  }

  Widget _buildChatEmptyState(FinancialAdvisorProvider provider, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 4))],
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 20),
                Text('Ask me anything about your finances', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                const SizedBox(height: 8),
                const Text('I can analyze your spending, find savings, check your financial health, and more.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.grey500)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Suggested questions
          ..._suggestedQuestions.map((q) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => _sendMessage(q),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.grey200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.help_outline_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(q, style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : AppColors.grey700))),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.grey400),
                  ],
                ),
              ),
            ),
          )),
          if (provider.isChatLoading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ConversationResponse msg, bool isDark) {
    final isUser = msg.type == 'user';
    final isError = msg.type == 'error';

    if (isUser) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(18).copyWith(bottomRight: Radius.zero),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Text(
                msg.answer,
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isError ? Icons.error_outline_rounded : Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 14,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isError
                  ? AppColors.danger.withValues(alpha: 0.1)
                  : (isDark ? AppColors.darkCard : AppColors.grey50),
              borderRadius: BorderRadius.circular(16).copyWith(topLeft: Radius.zero),
              border: Border.all(
                color: isError
                    ? AppColors.danger.withValues(alpha: 0.2)
                    : (isDark ? AppColors.darkBorder : AppColors.grey200),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg.answer,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isError ? AppColors.danger : (isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ),
                if (msg.score != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Score: ${msg.score!.score}/100 (${msg.score!.level})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ),
                ],
                if (msg.suggestedActions != null && msg.suggestedActions!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...msg.suggestedActions!.map((action) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.success),
                        const SizedBox(width: 6),
                        Expanded(child: Text(action, style: const TextStyle(fontSize: 12, color: AppColors.grey600))),
                      ],
                    ),
                  )),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatInput(FinancialAdvisorProvider provider, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border(
          top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.grey200),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _chatController,
                focusNode: _chatFocus,
                enabled: !provider.isChatLoading,
                textInputAction: TextInputAction.send,
                onSubmitted: _sendMessage,
                decoration: InputDecoration(
                  hintText: 'Ask a question...',
                  hintStyle: const TextStyle(color: AppColors.grey400, fontSize: 14),
                  filled: true,
                  fillColor: isDark ? AppColors.darkCardAlt : AppColors.grey100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: provider.isChatLoading ? null : () => _sendMessage(_chatController.text),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: provider.isChatLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Score Card ──
  Widget _buildScoreCard(FinancialScore score, bool isDark) {
    final scoreColor = score.score >= 90
        ? AppColors.success
        : score.score >= 75
            ? AppColors.primary
            : score.score >= 60
                ? AppColors.warning
                : AppColors.danger;

    return FadeInUp(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppColors.darkCard, AppColors.darkCardAlt]
                : [Colors.white, AppColors.grey50],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.grey100),
          boxShadow: [
            BoxShadow(
              color: scoreColor.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // Score gauge
            SizedBox(
              width: 88,
              height: 88,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: CircularProgressIndicator(
                      value: score.score / 100.0,
                      strokeWidth: 8,
                      backgroundColor: isDark ? AppColors.darkCardAlt : AppColors.grey200,
                      valueColor: AlwaysStoppedAnimation(scoreColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${score.score}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: scoreColor)),
                      const Text('/100', style: TextStyle(fontSize: 10, color: AppColors.grey400)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: scoreColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          score.level,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: scoreColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.grey400),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...score.details.take(3).map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        _buildMiniScoreBar(d.score, d.max, scoreColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            d.component,
                            style: TextStyle(fontSize: 11, color: isDark ? AppColors.grey400 : AppColors.grey600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniScoreBar(int current, int max, Color color) {
    final ratio = max > 0 ? current / max : 0.0;
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.grey200,
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.6 + ratio * 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  // ── Health Card ──
  Widget _buildHealthCard(FinancialHealth health, bool isDark) {
    final statusColor = health.status == 'excellent'
        ? AppColors.success
        : health.status == 'good'
            ? AppColors.primary
            : AppColors.warning;

    final statusIcon = health.status == 'excellent'
        ? Icons.verified_rounded
        : health.status == 'good'
            ? Icons.check_circle_outline_rounded
            : Icons.info_outline_rounded;

    return FadeInUp(
      delay: const Duration(milliseconds: 80),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.grey100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Financial Health', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    health.status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
            if (health.summary.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(health.summary, style: TextStyle(fontSize: 13, color: isDark ? AppColors.grey400 : AppColors.grey600)),
            ],
            if (health.strengths.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...health.strengths.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : AppColors.grey700))),
                  ],
                ),
              )),
            ],
            if (health.issues.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...health.issues.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : AppColors.grey700))),
                  ],
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }

  // ── Insight Card ──
  Widget _buildInsightCard(FinancialInsight insight, bool isDark) {
    final iconData = _getInsightIcon(insight.icon);
    final iconColor = _getInsightColor(insight.type);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.grey100),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(insight.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    ),
                    if (insight.priority == 'high')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('URGENT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.danger)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(insight.message, style: TextStyle(fontSize: 12, color: isDark ? AppColors.grey400 : AppColors.grey600, height: 1.4)),
                if (insight.change != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        insight.change! > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        size: 14,
                        color: insight.change! > 0 ? AppColors.danger : AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${insight.change! > 0 ? '+' : ''}${insight.change!.toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: insight.change! > 0 ? AppColors.danger : AppColors.success),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Opportunity Card ──
  Widget _buildOpportunityCard(SavingsOpportunity opp, bool isDark) {
    final effortIcon = opp.effort == 'low'
        ? Icons.sentiment_satisfied_rounded
        : opp.effort == 'medium'
            ? Icons.sentiment_neutral_rounded
            : Icons.sentiment_dissatisfied_rounded;
    final impactColor = opp.impact == 'high'
        ? AppColors.success
        : opp.impact == 'medium'
            ? AppColors.warning
            : AppColors.grey500;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.grey100),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [impactColor.withValues(alpha: 0.1), impactColor.withValues(alpha: 0.05)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.savings_outlined, color: impactColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(opp.area, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: impactColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(effortIcon, size: 10, color: impactColor),
                          const SizedBox(width: 3),
                          Text(opp.impact.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: impactColor)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(opp.description, style: TextStyle(fontSize: 12, color: isDark ? AppColors.grey400 : AppColors.grey600, height: 1.4)),
              ],
            ),
          ),
          if (opp.estimatedSavings > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '\$${opp.estimatedSavings.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.success),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Action Plan Card ──
  Widget _buildActionPlanCard(ActionPlan plan, bool isDark) {
    final planIcon = plan.type == 'savings'
        ? Icons.savings_outlined
        : plan.type == 'budget'
            ? Icons.account_balance_wallet_outlined
            : Icons.flag_outlined;
    final planColor = plan.type == 'savings'
        ? AppColors.success
        : plan.type == 'budget'
            ? AppColors.warning
            : AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.grey100),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: planColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(planIcon, color: planColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 12, color: AppColors.grey400),
                        const SizedBox(width: 4),
                        Text(plan.duration, style: const TextStyle(fontSize: 11, color: AppColors.grey500)),
                        if (plan.expectedMonthlySavings > 0) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.savings_outlined, size: 12, color: AppColors.success),
                          const SizedBox(width: 4),
                          Text('\$${plan.expectedMonthlySavings.toStringAsFixed(0)}/mo', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...plan.steps.asMap().entries.map((entry) {
            final step = entry.value;
            final isLast = entry.key == plan.steps.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: planColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('${entry.key + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: planColor)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkCardAlt : AppColors.grey100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(step.week, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.grey500)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(step.action, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : AppColors.grey700)),
                        if (step.tip.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.lightbulb_outline_rounded, size: 12, color: AppColors.warning),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(step.tip, style: const TextStyle(fontSize: 11, color: AppColors.grey500, fontStyle: FontStyle.italic)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Prediction Card ──
  Widget _buildPredictionCard(FinancialPrediction prediction, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.grey100),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                prediction.type == 'end_of_month_balance'
                    ? Icons.account_balance_rounded
                    : prediction.type == 'budget_overruns'
                        ? Icons.warning_amber_rounded
                        : prediction.type == 'goal_completion'
                            ? Icons.flag_rounded
                            : Icons.trending_up_rounded,
                size: 18,
                color: prediction.type == 'budget_overruns'
                    ? AppColors.warning
                    : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(prediction.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
              if (prediction.confidence != null) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: prediction.confidence == 'high'
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    prediction.confidence!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: prediction.confidence == 'high' ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (prediction.type == 'end_of_month_balance' && prediction.value != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  prediction.value! >= 0
                      ? '+\$${prediction.value!.toStringAsFixed(2)}'
                      : '-\$${prediction.value!.abs().toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: prediction.value! >= 0 ? AppColors.success : AppColors.danger,
                  ),
                ),
              ],
            ),
            if (prediction.detail != null) ...[
              const SizedBox(height: 4),
              Text(prediction.detail!, style: const TextStyle(fontSize: 12, color: AppColors.grey500)),
            ],
          ],
          if (prediction.type == 'budget_overruns' && prediction.budgetItems != null) ...[
            const SizedBox(height: 10),
            ...prediction.budgetItems!.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: item.risk == 'high'
                          ? AppColors.danger.withValues(alpha: 0.1)
                          : AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.risk.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: item.risk == 'high' ? AppColors.danger : AppColors.warning,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${item.category}: \$${item.expectedOverrun.toStringAsFixed(0)} over', style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : AppColors.grey700)),
                  ),
                ],
              ),
            )),
          ],
          if (prediction.type == 'goal_completion' && prediction.goalPredictions != null) ...[
            const SizedBox(height: 10),
            ...prediction.goalPredictions!.map((g) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    g.onTrack ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                    size: 14,
                    color: g.onTrack ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${g.name}: ${g.monthsRemaining} months (${g.currentProgress.toStringAsFixed(0)}%)',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : AppColors.grey700),
                    ),
                  ),
                ],
              ),
            )),
          ],
          if (prediction.type == 'next_month' && prediction.estimatedIncome != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _buildStatChip2('Income', '\$${prediction.estimatedIncome!.toStringAsFixed(0)}', AppColors.success),
                const SizedBox(width: 8),
                _buildStatChip2('Expenses', '\$${prediction.estimatedExpenses!.toStringAsFixed(0)}', AppColors.danger),
                const SizedBox(width: 8),
                _buildStatChip2('Savings', '\$${prediction.estimatedSavings!.toStringAsFixed(0)}', prediction.estimatedSavings! >= 0 ? AppColors.success : AppColors.danger),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip2(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  // ── Section Header ──
  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
      ],
    );
  }

  // ── Icon/Color Helpers ──
  IconData _getInsightIcon(String icon) {
    switch (icon) {
      case 'trending_up': return Icons.trending_up_rounded;
      case 'warning': return Icons.warning_amber_rounded;
      case 'credit_card': return Icons.credit_card_rounded;
      case 'savings': return Icons.savings_rounded;
      case 'trending_down': return Icons.trending_down_rounded;
      case 'flag': return Icons.flag_rounded;
      case 'calculator': return Icons.calculate_rounded;
      case 'subscriptions': return Icons.subscriptions_rounded;
      default: return Icons.lightbulb_outline_rounded;
    }
  }

  Color _getInsightColor(String type) {
    switch (type) {
      case 'warning': return AppColors.warning;
      case 'success': return AppColors.success;
      case 'insight': return AppColors.primary;
      default: return AppColors.primary;
    }
  }
}
