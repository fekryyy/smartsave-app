import 'package:flutter/material.dart';
import '../../data/repositories/financial_advisor_repository_impl.dart';
import '../../data/models/financial_advisor_models.dart';

class FinancialAdvisorProvider extends ChangeNotifier {
  final FinancialAdvisorRepositoryImpl _repository = FinancialAdvisorRepositoryImpl();

  // State
  FullFinancialAnalysis? _analysis;
  FinancialScore? _score;
  List<FinancialInsight> _insights = [];
  List<ActionPlan> _actionPlans = [];
  List<FinancialPrediction> _predictions = [];
  List<ConversationResponse> _chatHistory = [];
  bool _isLoading = false;
  bool _isChatLoading = false;
  String? _errorMessage;

  // Getters
  FullFinancialAnalysis? get analysis => _analysis;
  FinancialScore? get score => _score;
  List<FinancialInsight> get insights => _insights;
  List<ActionPlan> get actionPlans => _actionPlans;
  List<FinancialPrediction> get predictions => _predictions;
  List<ConversationResponse> get chatHistory => _chatHistory;
  bool get isLoading => _isLoading;
  bool get isChatLoading => _isChatLoading;
  String? get errorMessage => _errorMessage;

  // Load all data — primary path: single /analysis call (it returns everything)
  Future<void> loadAll() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _analysis = await _repository.getFullAnalysis();
      _score = _analysis!.score;
      _insights = _analysis!.insights;
      _actionPlans = _analysis!.actionPlans;
      _predictions = _analysis!.predictions;
    } catch (e) {
      // Primary /analysis call failed — try individual endpoints
      await _loadIndividually();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Fallback: load each data piece from its own endpoint
  Future<void> _loadIndividually() async {
    bool anyLoaded = false;

    try {
      _score = await _repository.getScore();
      anyLoaded = true;
    } catch (_) {}
    try {
      _insights = await _repository.getInsights();
    } catch (_) {}
    try {
      _actionPlans = await _repository.getActionPlans();
    } catch (_) {}
    try {
      _predictions = await _repository.getPredictions();
    } catch (_) {}

    if (anyLoaded) {
      // Construct a partial analysis so the screen can render
      _analysis = FullFinancialAnalysis(
        score: _score ?? FinancialScore(score: 0, level: 'N/A'),
        health: FinancialHealth(status: 'needs_attention'),
        insights: _insights,
        actionPlans: _actionPlans,
        predictions: _predictions,
      );
      _errorMessage = null;
    } else {
      _errorMessage = _errorMessage ?? 'Unable to load financial data';
    }
  }

  // Reload specific sections
  Future<void> refreshScore() async {
    try {
      _score = await _repository.getScore();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshInsights() async {
    try {
      _insights = await _repository.getInsights();
      notifyListeners();
    } catch (_) {}
  }

  // Chat
  Future<void> askQuestion(String question) async {
    if (question.trim().isEmpty) return;

    _isChatLoading = true;
    notifyListeners();

    // Add user message placeholder
    final userResponse = ConversationResponse(
      answer: question,
      type: 'user',
    );
    _chatHistory.add(userResponse);
    notifyListeners();

    try {
      final result = await _repository.askQuestion(question);
      _chatHistory.add(result);

      // Refresh data after question if it might have changed
      if (result.type == 'advice' || result.type == 'analysis') {
        refreshScore();
        refreshInsights();
      }
    } catch (e) {
      _chatHistory.add(ConversationResponse(
        answer: 'Sorry, I encountered an error. Please try again.',
        type: 'error',
      ));
    }

    _isChatLoading = false;
    notifyListeners();
  }

  void clearChat() {
    _chatHistory.clear();
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
