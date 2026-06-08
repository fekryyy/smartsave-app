// ──────────────────────────────────────────────
// Financial Score Model
// ──────────────────────────────────────────────
class FinancialScore {
  final int score;
  final String level;
  final int maxScore;
  final List<ScoreDetail> details;

  FinancialScore({
    required this.score,
    required this.level,
    this.maxScore = 100,
    this.details = const [],
  });

  factory FinancialScore.fromJson(Map<String, dynamic> json) {
    return FinancialScore(
      score: (json['score'] ?? 0).toInt(),
      level: json['level'] ?? 'N/A',
      maxScore: (json['maxScore'] ?? 100).toInt(),
      details: (json['details'] as List?)
              ?.map((d) => ScoreDetail.fromJson(d))
              .toList() ??
          [],
    );
  }
}

class ScoreDetail {
  final String component;
  final int score;
  final int max;
  final String detail;

  ScoreDetail({
    required this.component,
    required this.score,
    required this.max,
    required this.detail,
  });

  factory ScoreDetail.fromJson(Map<String, dynamic> json) {
    return ScoreDetail(
      component: json['component'] ?? '',
      score: (json['score'] ?? 0).toInt(),
      max: (json['max'] ?? 0).toInt(),
      detail: json['detail'] ?? '',
    );
  }
}

// ──────────────────────────────────────────────
// Financial Insight Model
// ──────────────────────────────────────────────
class FinancialInsight {
  final String type;
  final String icon;
  final String title;
  final String message;
  final String category;
  final String priority;
  final double? change;
  final double? value;
  final double? progress;

  FinancialInsight({
    required this.type,
    required this.icon,
    required this.title,
    required this.message,
    this.category = '',
    this.priority = 'medium',
    this.change,
    this.value,
    this.progress,
  });

  factory FinancialInsight.fromJson(Map<String, dynamic> json) {
    return FinancialInsight(
      type: json['type'] ?? 'insight',
      icon: json['icon'] ?? 'lightbulb',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      category: json['category'] ?? '',
      priority: json['priority'] ?? 'medium',
      change: (json['change'] as num?)?.toDouble(),
      value: (json['value'] as num?)?.toDouble(),
      progress: (json['progress'] as num?)?.toDouble(),
    );
  }
}

// ──────────────────────────────────────────────
// Financial Health Model
// ──────────────────────────────────────────────
class FinancialHealth {
  final String status;
  final List<String> strengths;
  final List<String> issues;
  final String summary;

  FinancialHealth({
    required this.status,
    this.strengths = const [],
    this.issues = const [],
    this.summary = '',
  });

  factory FinancialHealth.fromJson(Map<String, dynamic> json) {
    return FinancialHealth(
      status: json['status'] ?? 'needs_attention',
      strengths: (json['strengths'] as List?)?.map((s) => s.toString()).toList() ?? [],
      issues: (json['issues'] as List?)?.map((s) => s.toString()).toList() ?? [],
      summary: json['summary'] ?? '',
    );
  }
}

// ──────────────────────────────────────────────
// Advice Item Model
// ──────────────────────────────────────────────
class AdviceItem {
  final String type;
  final String title;
  final String message;
  final String category;
  final double? potentialSavings;

  AdviceItem({
    required this.type,
    required this.title,
    required this.message,
    this.category = '',
    this.potentialSavings,
  });

  factory AdviceItem.fromJson(Map<String, dynamic> json) {
    return AdviceItem(
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      category: json['category'] ?? '',
      potentialSavings: (json['potentialSavings'] as num?)?.toDouble(),
    );
  }
}

// ──────────────────────────────────────────────
// Savings Opportunity Model
// ──────────────────────────────────────────────
class SavingsOpportunity {
  final String area;
  final String description;
  final double estimatedSavings;
  final String effort;
  final String impact;

  SavingsOpportunity({
    required this.area,
    required this.description,
    this.estimatedSavings = 0,
    this.effort = 'medium',
    this.impact = 'medium',
  });

  factory SavingsOpportunity.fromJson(Map<String, dynamic> json) {
    return SavingsOpportunity(
      area: json['area'] ?? '',
      description: json['description'] ?? '',
      estimatedSavings: (json['estimatedSavings'] as num?)?.toDouble() ?? 0,
      effort: json['effort'] ?? 'medium',
      impact: json['impact'] ?? 'medium',
    );
  }
}

// ──────────────────────────────────────────────
// Action Plan Step Model
// ──────────────────────────────────────────────
class ActionPlanStep {
  final String week;
  final String action;
  final String tip;

  ActionPlanStep({
    required this.week,
    required this.action,
    this.tip = '',
  });

  factory ActionPlanStep.fromJson(Map<String, dynamic> json) {
    return ActionPlanStep(
      week: json['week'] ?? '',
      action: json['action'] ?? '',
      tip: json['tip'] ?? '',
    );
  }
}

// ──────────────────────────────────────────────
// Action Plan Model
// ──────────────────────────────────────────────
class ActionPlan {
  final String type;
  final String title;
  final double expectedMonthlySavings;
  final String duration;
  final List<ActionPlanStep> steps;

  ActionPlan({
    required this.type,
    required this.title,
    this.expectedMonthlySavings = 0,
    this.duration = '',
    this.steps = const [],
  });

  factory ActionPlan.fromJson(Map<String, dynamic> json) {
    return ActionPlan(
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      expectedMonthlySavings: (json['expectedMonthlySavings'] as num?)?.toDouble() ?? 0,
      duration: json['duration'] ?? '',
      steps: (json['steps'] as List?)
              ?.map((s) => ActionPlanStep.fromJson(s))
              .toList() ??
          [],
    );
  }
}

// ──────────────────────────────────────────────
// Budget Overrun Prediction Model
// ──────────────────────────────────────────────
class BudgetOverrunPrediction {
  final String category;
  final double budgeted;
  final double projectedSpend;
  final double expectedOverrun;
  final String risk;

  BudgetOverrunPrediction({
    required this.category,
    this.budgeted = 0,
    this.projectedSpend = 0,
    this.expectedOverrun = 0,
    this.risk = 'low',
  });

  factory BudgetOverrunPrediction.fromJson(Map<String, dynamic> json) {
    return BudgetOverrunPrediction(
      category: json['category'] ?? '',
      budgeted: (json['budgeted'] as num?)?.toDouble() ?? 0,
      projectedSpend: (json['projectedSpend'] as num?)?.toDouble() ?? 0,
      expectedOverrun: (json['expectedOverrun'] as num?)?.toDouble() ?? 0,
      risk: json['risk'] ?? 'low',
    );
  }
}

// ──────────────────────────────────────────────
// Goal Prediction Model
// ──────────────────────────────────────────────
class GoalPrediction {
  final String name;
  final double currentProgress;
  final int monthsRemaining;
  final String estimatedCompletionDate;
  final bool onTrack;

  GoalPrediction({
    required this.name,
    this.currentProgress = 0,
    this.monthsRemaining = 0,
    this.estimatedCompletionDate = '',
    this.onTrack = true,
  });

  factory GoalPrediction.fromJson(Map<String, dynamic> json) {
    return GoalPrediction(
      name: json['name'] ?? '',
      currentProgress: (json['currentProgress'] as num?)?.toDouble() ?? 0,
      monthsRemaining: (json['monthsRemaining'] as num?)?.toInt() ?? 0,
      estimatedCompletionDate: json['estimatedCompletionDate'] ?? '',
      onTrack: json['onTrack'] ?? true,
    );
  }
}

// ──────────────────────────────────────────────
// Prediction Model
// ──────────────────────────────────────────────
class FinancialPrediction {
  final String type;
  final String title;
  final double? value;
  final String? detail;
  final String? confidence;
  final List<BudgetOverrunPrediction>? budgetItems;
  final int? budgetCount;
  final List<GoalPrediction>? goalPredictions;
  final double? estimatedIncome;
  final double? estimatedExpenses;
  final double? estimatedSavings;

  FinancialPrediction({
    required this.type,
    required this.title,
    this.value,
    this.detail,
    this.confidence,
    this.budgetItems,
    this.budgetCount,
    this.goalPredictions,
    this.estimatedIncome,
    this.estimatedExpenses,
    this.estimatedSavings,
  });

  factory FinancialPrediction.fromJson(Map<String, dynamic> json) {
    return FinancialPrediction(
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      value: (json['value'] as num?)?.toDouble(),
      detail: json['detail'],
      confidence: json['confidence'],
      budgetItems: (json['items'] as List?)
          ?.map((i) => BudgetOverrunPrediction.fromJson(i))
          .toList(),
      budgetCount: (json['count'] as num?)?.toInt(),
      goalPredictions: (json['goals'] as List?)
          ?.map((g) => GoalPrediction.fromJson(g))
          .toList(),
      estimatedIncome: (json['estimatedIncome'] as num?)?.toDouble(),
      estimatedExpenses: (json['estimatedExpenses'] as num?)?.toDouble(),
      estimatedSavings: (json['estimatedSavings'] as num?)?.toDouble(),
    );
  }
}

// ──────────────────────────────────────────────
// Conversation Response Model
// ──────────────────────────────────────────────
class ConversationResponse {
  final String answer;
  final String type;
  final FinancialScore? score;
  final List<String>? suggestedActions;

  ConversationResponse({
    required this.answer,
    this.type = 'info',
    this.score,
    this.suggestedActions,
  });

  factory ConversationResponse.fromJson(Map<String, dynamic> json) {
    return ConversationResponse(
      answer: json['answer'] ?? '',
      type: json['type'] ?? 'info',
      score: json['score'] != null ? FinancialScore.fromJson(json['score']) : null,
      suggestedActions: (json['suggestedActions'] as List?)?.map((s) => s.toString()).toList(),
    );
  }
}

// ──────────────────────────────────────────────
// Full Financial Analysis Model
// ──────────────────────────────────────────────
class FullFinancialAnalysis {
  final FinancialScore score;
  final FinancialHealth health;
  final List<FinancialInsight> insights;
  final List<AdviceItem> advice;
  final List<SavingsOpportunity> opportunities;
  final List<ActionPlan> actionPlans;
  final List<FinancialPrediction> predictions;

  FullFinancialAnalysis({
    required this.score,
    required this.health,
    this.insights = const [],
    this.advice = const [],
    this.opportunities = const [],
    this.actionPlans = const [],
    this.predictions = const [],
  });

  factory FullFinancialAnalysis.fromJson(Map<String, dynamic> json) {
    return FullFinancialAnalysis(
      score: FinancialScore.fromJson(json['score'] ?? {}),
      health: FinancialHealth.fromJson(json['health'] ?? {}),
      insights: (json['insights'] as List?)
              ?.map((i) => FinancialInsight.fromJson(i))
              .toList() ??
          [],
      advice: (json['advice'] as List?)
              ?.map((a) => AdviceItem.fromJson(a))
              .toList() ??
          [],
      opportunities: (json['opportunities'] as List?)
              ?.map((o) => SavingsOpportunity.fromJson(o))
              .toList() ??
          [],
      actionPlans: (json['actionPlans'] as List?)
              ?.map((a) => ActionPlan.fromJson(a))
              .toList() ??
          [],
      predictions: (json['predictions'] as List?)
              ?.map((p) => FinancialPrediction.fromJson(p))
              .toList() ??
          [],
    );
  }
}
